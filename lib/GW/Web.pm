package GW::Web;
use strict;
use warnings;
use Wanage::HTTP;
use Path::Class;
use Encode;
use MIME::Base64 qw(decode_base64);
use GW::Warabe::App;

our $APIKey;

sub load_api_key_by_env {
    my $file_name = $ENV{GW_API_KEY_FILE_NAME}
        or die "|GW_API_KEY_FILE_NAME| not specified";
    $APIKey = decode 'utf-8', decode_base64 scalar file($file_name)->slurp;
}

sub psgi_app {
    my (undef, $reg, $cached_d) = @_;
    return sub {
        my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
        my $app = GW::Warabe::App->new_from_http ($http);
        
        return $http->send_response(onready => sub {
            $app->execute (sub {
                GW::Web->process ($app, $reg, $cached_d);
            });
        });
    };
}

sub auth {
    my (undef, $app, $is_api) = @_;
    if ($is_api) {
        $app->requires_basic_auth({api_key => $APIKey}, realm => 'API');
    } else {
        $app->requires_basic_auth({develop => $APIKey}, realm => 'Pages');
    }
}

sub process {
    my ($class, $app, $reg, $cached_d) = @_;

    # XXX Origin: test against CSRF attack

    my $path = $app->path_segments;
    if ($path->[0] eq 'hook') {
        # /hook
        $class->auth($app, 1);
        $app->requires_request_method({POST => 1});

        my $json = $app->request_json;
        my $branch = $json->{ref} || '';
        $branch =~ s{^refs/heads/}{};
        
        require GW::Action::InsertJob;
        my $action = GW::Action::InsertJob->new_from_repository(
            $json->{repository}->{url}
                || $app->throw_error(400, reason_phrase => 'bad repository.url'),
            $branch
                || $app->throw_error(400, reason_phrase => 'bad ref'),
            $json->{after}
                || $app->throw_error(400, reason_phrase => 'bad after'),
        );
        $action->db_registry($reg);
        $action->insert_job(
            $json->{hook_args}->{action_type}
                || $app->throw_error(400, reason_phrase => 'bad hook_args.action_type'),
            $json->{hook_args}->{action_args} || {},
       );

        $app->http->set_status(202, reason_phrase => 'Accepted');
        $app->http->send_response_body_as_text("202 Accepted\n");
        $app->http->close_response_body;
        return $app->throw;
    } elsif ($path->[0] eq 'sets' and
             defined $path->[1] and $path->[1] =~ /.\.json\z/ and
             not defined $path->[2]) {
        # /sets/{set_name}.json
        $class->auth($app, 1);
        my $set_name = $path->[1];
        $set_name =~ s/\.json\z//;
        if ($app->http->request_method eq 'POST') {
            my $action = $app->bare_param('action') || '';
            if ($action eq 'command') {
                require GW::Action::ScheduleCommandByRepositorySet;
                my $scheduler = GW::Action::ScheduleCommandByRepositorySet->new_from_dbreg_and_set_name($reg, $set_name);
                my $command = $app->bare_param('command') 
                    or $app->throw_error(400, reason_phrase => 'Bad command');
                $scheduler->schedule_command($command);
                $app->http->set_status(202, reason_phrase => 'Accepted');
                $app->http->send_response_body_as_text("202 Accepted\n");
                $app->http->close_response_body;
                return $app->throw;
            } else {
                return $app->throw_error(400, reason_phrase => 'Bad action');
            }
        } else {
            require GW::Loader::RepositorySet;
            my $loader = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($reg, $set_name);
            return $app->send_json([keys %{$loader->get_repository_urls}]);
        }
    } elsif ($path->[0] eq 'repos' and
             defined $path->[1] and $path->[1] eq 'statuses' and
             defined $path->[2] and $path->[2] =~ /.\.json\z/ and
             not defined $path->[3]) {
        # /repos/statuses/{sha}.json

        # <http://developer.github.com/v3/repos/statuses/>
        # <https://github.com/blog/1227-commit-status-api>

        $class->auth($app, 1);
        my $url = $app->bare_param('repository_url')
            or $app->throw_error(400, reason_phrase => 'No repository_url');
        my $sha = $path->[2];
        $sha =~ s/\.json\z//;
        require GW::Defs::Statuses;
        if ($app->http->request_method eq 'POST') {
            require GW::Action::AddCommitStatus;
            my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($reg, $url);
            my $state = $app->bare_param('state') || '';
            $state = $GW::Defs::Statuses::CommitStatusNameToCode->{$state}
                or $app->throw_error(400, reason_phrase => 'Bad state');
            my $target_url = $app->bare_param('target_url');
            my $desc = $app->text_param('description');
            $action->add_commit_status(
                sha => $sha,
                state => $state,
                target_url => $target_url,
                description => $desc,
            );
            
            $app->http->set_status(201);
            $app->send_json({
                state => $GW::Defs::Statuses::CommitStatusCodeToName->{$state},
                target_url => $target_url,
                description => $desc,
            });
            return $app->throw;
        } else {
            require GW::Loader::CommitStatuses;
            my $loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($reg, $url);
            $app->send_json($loader->get_commit_statuses($sha)->map(sub {
                return {
                    state => $GW::Defs::Statuses::CommitStatusCodeToName->{$_->{state}},
                    target_url => $_->{target_url},
                    description => $_->{description},
                    id => $_->{id},
                };
            }));
            return $app->throw;
        }
    } elsif ($path->[0] eq 'jobs') {
        # /jobs
        $class->auth($app, 1);
        $app->requires_request_method ({POST => 1});

        my $http = $app->http;
        require GW::Action::ProcessJobs;
        my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
        $action->db_registry($reg);
        $action->onmessage(sub {
            my ($msg, %args) = @_;
            my $message = '[' . (scalar gmtime) . '] ' . $msg . "\n";
            $http->send_response_body_as_text($message);
            if ($args{die}) {
                die $message;
            } else {
                warn $message;
            }
        });
        $http->set_status(200);
        $action->process_jobs_as_cv->cb(sub {
            $http->close_response_body;
        });
        return $app->throw;
    }

    return $app->throw_error(404);
}

1;

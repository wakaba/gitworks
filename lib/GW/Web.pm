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
        $app->requires_basic_auth({api_key => $APIKey,
                                   develop => $APIKey}, realm => 'Pages');
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
             defined $path->[1] and $path->[1] =~ /./ and
             not defined $path->[2]) {
        # /sets/{set_name}[.json]
        my $set_name = $path->[1];
        my $is_json = $set_name =~ s/\.json\z//;
        $class->auth($app, $is_json);
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
            if ($is_json) {
                return $app->send_json([keys %{$loader->get_repository_urls}]);
            } else {
                $class->process_temma(
                    $app, ['sets.html.tm'], {
                        set_name => $set_name,
                        urls => $loader->get_repository_urls,
                    },
                );
                return $app->throw;
            }
        }
    } elsif ($path->[0] eq 'repos') {
        my $url = $app->bare_param('repository_url')
            or $app->throw_error(400, reason_phrase => 'No repository_url');
        if (not defined $path->[1]) {
            # /repos?repository_url={url}
            $class->auth($app, 0);
            $class->process_temma(
                $app, ['repos.index.html.tm'], {
                    repository_url => $url,
                },
            );
            return $app->throw;
        } elsif (defined $path->[1] and $path->[1] eq 'git' and
                 defined $path->[2] and $path->[2] eq 'commits' and
                 defined $path->[3] and $path->[3] =~ /.\.json\z/ and
                 not defined $path->[4]) {
            # /repos/git/commits/{sha}.json
            $class->auth($app, 1);
            
            my $sha = $path->[3];
            $sha =~ s/\.json\z//;
            my $action = $class->process_repository_action($url, $cached_d);
            require GW::Loader::Commits;
            my $loader = GW::Loader::Commits->new_from_process_repository_action($action);
            $loader->get_commit_as_github_jsonable_as_cv($sha)->cb(sub {
                my $json = $_[0]->recv;
                if ($json) {
                    $app->send_json($json);
                } else {
                    $app->send_error(404, reason_phrase => 'Commit not found');
                }
            });
            return $app->throw;
        } elsif (defined $path->[1] and
                 ($path->[1] eq 'commits' or $path->[1] eq 'commits.json') and
                 not defined $path->[2]) {
            # /repos/commits
            # /repos/commits.json
            $class->auth($app, $path->[1] =~ /\.json$/);

            # <http://developer.github.com/v3/repos/commits/#list-commits-on-a-repository>

            my $action = $class->process_repository_action($url, $cached_d);
            require GW::Loader::Commits;
            my $loader = GW::Loader::Commits->new_from_process_repository_action($action);
            my $sha = $app->bare_param('sha') || 'master';
            $loader->get_commit_list_as_github_jsonable_as_cv($sha)->cb(sub {
                my $json = $_[0]->recv;
                if ($json) {
                    if ($path->[1] eq 'commits.json') {
                        $app->send_json($json);
                    } else {
                        require GW::Loader::CommitStatuses;
                        my $loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($reg, $url);
                        my $statuses = $loader->get_commit_statuses_list([map { $_->{sha} } @$json]);
                        
                        $class->process_temma(
                            $app, ['repos.commits.html.tm'], {
                                repository_url => $url,
                                commits => $json,
                                commit_statuses => $statuses,
                            },
                        );
                    }
                } else {
                    $app->send_error(404, reason_phrase => 'Commit not found');
                }
            });
            return $app->throw;

        } elsif (defined $path->[1] and $path->[1] eq 'statuses' and
                 defined $path->[2] and $path->[2] =~ /.\.json\z/ and
                 not defined $path->[3]) {
            # /repos/statuses/{sha}.json
            $class->auth($app, 1);

            # <http://developer.github.com/v3/repos/statuses/>
            # <https://github.com/blog/1227-commit-status-api>

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
        } elsif (defined $path->[1] and
                 ($path->[1] eq 'logs' or $path->[1] eq 'logs.json') and
                 not defined $path->[2]) {
            # /repos/logs
            # /repos/logs.json
            $class->auth($app, $path->[1] =~ /\.json$/);
            if ($app->http->request_method eq 'POST' and
                $path->[1] eq 'logs.json') {
                require GW::Action::AddLog;
                my $action = GW::Action::AddLog->new_from_dbreg_and_repository_url($reg, $url);
                my $sha = $app->bare_param('sha')
                    or $app->throw_error(400, reason_phrase => 'Bad sha');
                my $data = {
                    sha => $sha,
                    branch => $app->bare_param('branch'),
                    data => $app->text_param('data'),
                };
                $action->add_log(%$data);
                $app->http->set_status(201);
                $app->send_json($data);
                return $app->throw;
            } else {
                require GW::Loader::Logs;
                my $loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($reg, $url);
                my $list = $loader->get_logs(
                    sha => $app->bare_param('sha'),
                    branch => $app->bare_param('branch'),
                );
                if ($path->[1] eq 'logs.json') {
                    $app->send_json($list->map(sub { return {
                        id => $_->{id},
                        branch => $_->{branch},
                        sha => $_->{sha},
                        data => $_->{data},
                        created => $_->{created},
                    } }));
                } else {
                    $class->process_temma(
                        $app, ['repos.logs.html.tm'], {
                            repository_url => $url,
                            logs => $list,
                        },
                    );
                }
                return $app->throw;
            }
        } elsif (defined $path->[1] and $path->[1] eq 'branches.json' and
                 not defined $path->[2]) {
            # /repos/branches.json
            $class->auth($app, 1);
            my $action = $class->process_repository_action($url, $cached_d);
            $action->get_branches_as_cv->cb(sub {
                $app->send_json([map { +{name => $_->[1], commit => {sha => $_->[0]}} } @{$_[0]->recv}]);
            });
            return $app->throw;
        } elsif (defined $path->[1] and $path->[1] eq 'tags.json' and
                 not defined $path->[2]) {
            # /repos/tags.json
            $class->auth($app, 1);
            my $action = $class->process_repository_action($url, $cached_d);
            $action->get_tags_as_cv->cb(sub {
                $app->send_json([map { +{name => $_->[1], commit => {sha => $_->[0]}} } @{$_[0]->recv}]);
            });
            return $app->throw;
        }
    } elsif ($path->[0] eq 'jobs') {
        # /jobs
        $class->auth($app, 1);
        $app->requires_request_method ({POST => 1});

        my $http = $app->http;

        my $allow = $app->bare_param_list('action_type');
        my $disallow = $app->bare_param_list('not_action_type');
        my $id = int rand 10000;
        warn "$id: Processing jobs (+@$allow -@$disallow)\n";

        require GW::Action::ProcessJobs;
        my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
        $action->db_registry($reg);
        $action->onmessage(sub {
            my ($msg, %args) = @_;
            my $message = '[' . (scalar gmtime) . '] ' . $msg . "\n";
            $http->send_response_body_as_text($message);
            if ($args{die}) {
                die "$id: $message";
            } else {
                warn "$id: $message";
            }
        });
        $http->set_status(200);
        $action->process_jobs_as_cv(
            action_types => $app->bare_param_list('action_type'),
            not_action_types => $app->bare_param_list('not_action_type'),
        )->cb(sub {
            warn "$id: Done\n";
            $http->close_response_body;
        });
        return $app->throw;
    }

    return $app->throw_error(404);
}

sub process_repository_action {
    my (undef, $url, $cached_d) = @_;
    require GW::Action::ProcessRepository;
    return GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $url}, $cached_d);
}

my $templates_d = file(__FILE__)->dir->parent->parent->resolve->subdir('templates');

sub process_temma {
    my ($class, $app, $template_path, $args) = @_;
    my $http = $app->http;
    $http->response_mime_type->set_value('text/html');
    $http->response_mime_type->set_param(charset => 'utf-8');
    my $fh = GW::Web::Printer->new_from_http($http);
    require Temma;
    Temma->process_html(
        $templates_d->file(@$template_path), $args => $fh,
        sub { $http->close_response_body },
    );
}

package GW::Web::Printer;

sub new_from_http {
    return bless {http => $_[1]}, $_[0];
}

sub print {
    $_[0]->{http}->send_response_body_as_text($_[1]);
};

1;

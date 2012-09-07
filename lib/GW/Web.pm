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

sub process {
    my ($class, $app, $reg, $cached_d) = @_;

    my $path = $app->path_segments;
    if ($path->[0] eq 'hook') {
        $app->requires_request_method({POST => 1});
        $app->requires_basic_auth({api_key => $APIKey});

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
    } elsif ($path->[0] eq 'jobs') {
        $app->requires_request_method ({POST => 1});
        $app->requires_basic_auth({api_key => $APIKey});

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

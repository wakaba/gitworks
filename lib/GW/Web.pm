package GW::Web;
use strict;
use warnings;
use Wanage::HTTP;
use GW::Warabe::App;

sub psgi_app {
    return sub {
        my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
        my $app = GW::Warabe::App->new_from_http ($http);
        
        return $http->send_response(onready => sub {
            $app->execute (sub {
                GW::Web->process ($app);
            });
        });
    };
}

sub process {
    my ($class, $app) = @_;

    my $path = $app->path_segments;
    if ($path->[0] eq 'hook') {
        $app->requires_request_method ({POST => 1});

        my $json = $app->request_json;
        my $branch = $json->{refname} || '';
        $branch =~ s{^refs/heads/}{};

        require GW::Action::InsertJob;
        my $action = GW::Action::InsertJob->new_from_repository(
            $json->{repository}->{url}
                || $app->throw_error(400, reason_phrase => 'bad repository.url'),
            $branch
                || $app->throw_error(400, reason_phrase => 'bad refname'),
            $json->{after}
                || $app->throw_error(400, reason_phrase => 'bad after'),
        );
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
        my $http = $app->http;
        require GW::Action::ProcessJobs;
        my $action = GW::Action::ProcessJobs->new;
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

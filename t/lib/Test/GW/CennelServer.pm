package Test::GW::CennelServer;
use strict;
use warnings;
use Test::AnyEvent::plackup;

my $http_server = Test::AnyEvent::plackup->new;
$http_server->set_app_code(q{
    use strict;
    use warnings;
    use Wanage::HTTP;
    use JSON::Functions::XS qw(perl2json_bytes);
    my $jobs = {};
    return sub {
        my $http = Wanage::HTTP->new_from_psgi_env($_[0]);
        my $path = $http->url->{path};
        if ($path =~ m{^/(\d+)/jobs$}) {
            push @{$jobs->{$1} ||= []}, ${$http->request_body_as_ref};
            $http->set_status(201);
            $http->close_response_body;
            return $http->send_response;
        } elsif ($path =~ m{^/(\d+)/devel/jobs$}) {
            $http->set_response_header('Content-Type' => 'application/json');
            $http->send_response_body_as_ref(\('[' . (join ',', @{$jobs->{$1} or []}) . ']'));
            $http->close_response_body;
            return $http->send_response;
        }
        return [404, [], ['404']];
    };
});

my ($server_start_cv, $server_stop_cv);
my $server_host;

sub start_server_as_cv {
    ($server_start_cv, $server_stop_cv) = $http_server->start_server;
    $server_host = 'localhost:' . $http_server->port;
    return $server_start_cv;
}

sub server_host {
    return $server_host;
}

sub stop_server_as_cv {
    $http_server->stop_server;
    undef $http_server;
    return $server_stop_cv;
}

1;

use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use Test::GW::CennelServer;

Test::GW::CennelServer->start_server_as_cv->recv;
$Test::GW::Server::CennelHost = Test::GW::CennelServer->server_host;
$Test::GW::Server::CennelKey = int rand 10000;

my $server_cv;
my $server = sub { $server_cv ||= mysql_and_web_as_cv };

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    http_get
        url => qq<http://$host/cennel>,
        basic_auth => [develop => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                like $res->content, qr{</html>};
                done $c;
                undef $c;
            } $c;
        };
} n => 2, wait => $server, name => 'cennel list - empty';

run_tests;
Test::GW::CennelServer->stop_server_as_cv->recv;

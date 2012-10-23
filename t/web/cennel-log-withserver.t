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

    my $cv = AE::cv;
    http_post_data
        url => qq<http://$Test::GW::Server::CennelHost/$Test::GW::Server::CennelKey/devel/operation/12345.json>,
        basic_auth => [develop => 'testapikey'],
        content => perl2json_bytes {
            repository => {url => q<hogeAAA>},
        },
        anyevent => 1,
        cb => sub {
            $cv->send;
        };

    $cv->cb(sub {
        test {
            http_get
                url => qq<http://$host/cennel/12345>,
                basic_auth => [develop => 'testapikey'],
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        like $res->content, qr{hogeAAA};
                        like $res->content, qr{</html>};
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 3, wait => $server, name => 'cennel log - empty';

run_tests;
Test::GW::CennelServer->stop_server_as_cv->recv;

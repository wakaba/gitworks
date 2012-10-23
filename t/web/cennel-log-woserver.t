use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;

my $server_cv;
my $server = sub { $server_cv ||= mysql_and_web_as_cv };

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    http_get
        url => qq<http://$host/cennel/logs/12345>,
        basic_auth => [develop => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 404;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'cennel log - empty';

run_tests;

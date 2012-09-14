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

    my $url = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos>,
        basic_auth => [develop => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'no repository';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos>,
        params => {
            repository_url => $url,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'unknown repository, no api key';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<aabbr425gaaaaa?:aaaa>;
    http_get
        url => qq<http://$host/repos>,
        params => {
            repository_url => $url,
        },
        basic_auth => [develop => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                is $res->header('Content-Type'), 'text/html; charset=utf-8';
                like $res->content, qr{/repos/branches\?repository_url=aabbr425gaaaaa%3F%3Aaaaa};
                like $res->content, qr{</html>};
                #warn $res->content;
                done $c;
                undef $c;
            } $c;
        };
} n => 4, wait => $server, name => 'unknown repository';

run_tests;

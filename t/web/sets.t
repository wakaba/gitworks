use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;

my $server = mysql_and_web_as_cv;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/sets/abc>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                done $c;
            } $c;
        };
} n => 1, wait => $server;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/sets/abc>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                eq_or_diff $json, [];
                done $c;
            } $c;
        };
} n => 2, wait => $server, name => 'empty';

run_tests;

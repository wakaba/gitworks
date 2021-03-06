use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New && git tag ho.ge";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    http_get
        url => qq<http://$host/repos/tags.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $temp_d,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                eq_or_diff $json, [{name => 'ho.ge', commit => {sha => $rev}}];
                done $c;
                undef $c;
            } $c;
        };
} n => 2, wait => mysql_and_web_as_cv;

run_tests;

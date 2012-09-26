use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;

my $server = mysql_and_web_as_cv;

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    http_get
        url => qq<http://$host/repos/commits.json>,
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
                is scalar @$json, 1;
                is $json->[0]->{sha}, $rev;
                ok $json->[0]->{author}->{name};
                ok $json->[0]->{committer}->{name};
                is $json->[0]->{message}, q{New};
                eq_or_diff $json->[0]->{parents}, [];
                done $c;
                undef $c;
            } $c;
        };
} n => 7, wait => $server, name => 'found, no sha';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    http_get
        url => qq<http://$host/repos/commits.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $temp_d,
            sha => q<hagtawfaaeeeeeee>,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 404;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'rev not found';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    http_get
        url => qq<http://$host/repos/commits.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => q<http://notfound.test/>,
            sha => q<gaetaewgarfeageaee>,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 404;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'repo not found';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && touch hoge && git add hoge && git commit -m hoge";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    http_get
        url => qq<http://$host/repos/commits.json>,
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
                is scalar @$json, 2;
                is $json->[0]->{sha}, $rev2;
                eq_or_diff $json->[0]->{parents}, [{sha => $rev}];
                is $json->[1]->{sha}, $rev;
                ok $json->[1]->{author}->{name};
                ok $json->[1]->{committer}->{name};
                is $json->[1]->{message}, q{New};
                eq_or_diff $json->[1]->{parents}, [];
                done $c;
                undef $c;
            } $c;
        };
} n => 9, wait => $server, name => 'found, revs';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && touch hoge && git add hoge && git commit -m hoge";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    http_get
        url => qq<http://$host/repos/commits.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $temp_d,
            sha => $rev,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                is scalar @$json, 1;
                is $json->[0]->{sha}, $rev;
                ok $json->[0]->{author}->{name};
                ok $json->[0]->{committer}->{name};
                is $json->[0]->{message}, q{New};
                eq_or_diff $json->[0]->{parents}, [];
                done $c;
                undef $c;
            } $c;
        };
} n => 7, wait => $server, name => 'found, rev specified';

run_tests;

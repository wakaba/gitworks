use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use AnyEvent;
use Path::Class;
use File::Temp qw(tempdir);
use GW::Action::ProcessJobs;
use GW::MySQL;

my $cv1;
my $default_server = sub { $cv1 ||= mysql_and_web_as_cv };

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/jobs>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 405;
                done $c;
            } $c;
        };
} name => 'get', n => 1, wait => $default_server;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_post
        url => qq<http://$host/jobs>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                done $c;
                undef $c;
            } $c;
        };
} name => 'post no apikey', n => 1, wait => $default_server;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    my $temp2_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > @{[$temp2_d]}/foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $cv1 = AE::cv;
    http_post
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        content => perl2json_bytes {
            repository => {url => $temp_d->stringify},
            ref => 'refs/heads/master',
            after => $rev,
            hook_args => {
                action_type => 'make',
                action_args => {rule => 'hoge'},
            },
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 202;
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        test {
            http_post_data
                url => qq<http://$host/jobs>,
                basic_auth => [api_key => 'testapikey'],
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        $cv2->send;
                    } $c;
                };
        } $c;
    });

    $cv2->cb(sub {
        test {
            is scalar $temp2_d->file('foo.txt')->slurp, "1234\n";

            my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($c->received_data->cached_repo_set_d);
            $action->db_registry($reg);
            my $jobs = $action->get_jobs;
            is $jobs->length, 0;

            done $c;
            undef $c;
        } $c;
    });
} n => 4, wait => sub { mysql_and_web_as_cv };

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    my $temp2_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > @{[$temp2_d]}/foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $cv1 = AE::cv;
    http_post
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        content => perl2json_bytes {
            repository => {url => $temp_d->stringify},
            ref => 'refs/heads/master',
            after => $rev,
            hook_args => {
                action_type => 'make',
                action_args => {rule => 'hoge'},
            },
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 202;
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        my $timer; $timer = AE::timer 7, 0, sub {
            test {
                undef $timer;
                $cv2->send;
            } $c;
        };
    });

    $cv2->cb(sub {
        test {
            is scalar $temp2_d->file('foo.txt')->slurp, "1234\n";

            my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($c->received_data->cached_repo_set_d);
            $action->db_registry($reg);
            my $jobs = $action->get_jobs;
            is $jobs->length, 0;

            done $c;
            undef $c;
        } $c;
    });
} n => 3, wait => sub { mysql_and_web_and_workaholicd_as_cv },
    name => 'by workaholicd';

run_tests;

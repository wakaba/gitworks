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
    http_post
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
    http_post
        url => qq<http://$host/sets/abc>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
            } $c;
        };
} n => 1, wait => $server, name => 'no action';

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_post
        url => qq<http://$host/sets/abc>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            action => 'command',
            command => 'hogecommand',
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 202;
                done $c;
            } $c;
        };
} n => 1, wait => $server, name => 'no list';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $cv1 = AE::cv;
    http_post_data
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        content => perl2json_bytes {
            repository => {url => q{git://hoge/fuga}},
            ref => 'refs/heads/hogefugabranch',
            after => '521451abacee',
            hook_args => {
                action_type => 'repository_set.add',
                action_args => {set_name => 'abc'},
            },
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        test {
            http_post
                url => qq<http://$host/jobs>,
                basic_auth => [api_key => 'testapikey'],
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        $cv2->send;
                    } $c;
                };
        } $c;
    });

    $cv2->cb(sub {
        test {
            http_post
                url => qq<http://$host/sets/abc>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    action => 'command',
                    command => 'hogecommand',
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 202;

                        require GW::Action::ProcessJobs;
                        my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($c->received_data->cached_repo_set_d);
                        my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
                        $action->db_registry($reg);
                        my $jobs = $action->get_jobs;
                        is $jobs->length, 1;
                        ok $jobs->[0]->{job_id};
                        eq_or_diff $jobs->[0], {
                            job_id => $jobs->[0]->{job_id},
                            repository_url => q{git://hoge/fuga},
                            repository_branch => q{master},
                            repository_revision => q{master},
                            action_type => 'command',
                            args => {command => 'hogecommand'},
                        };
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 4, wait => sub { mysql_and_web_as_cv }, name => 'non empty list';

run_tests;

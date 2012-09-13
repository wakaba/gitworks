use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use GW::Action::ProcessJobs;
use GW::MySQL;

my $cv1 = mysql_and_web_as_cv;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/hook>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                done $c;
            } $c;
        };
} name => 'get', n => 1, wait => $cv1;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 405;
                done $c;
            } $c;
        };
} name => 'get', n => 1, wait => $cv1;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_post
        url => qq<http://$host/hook>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                done $c;
            } $c;
        };
} name => 'post no args, no api key', n => 1, wait => $cv1;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_post
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
            } $c;
        };
} name => 'post no args', n => 1, wait => $cv1;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    http_post_data
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        content => perl2json_bytes {
            repository => {url => q{git://hoge/fuga}},
            ref => 'refs/heads/hogefugabranch',
            after => '521451abacee',
            hook_args => {
                action_type => '14242',
                action_args => {12 => 31},
            },
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 202;

                my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($c->received_data->cached_repo_set_d);
                $action->db_registry($reg);
                my $jobs = $action->get_jobs;
                is $jobs->length, 1;
                ok $jobs->[0]->{job_id};
                eq_or_diff $jobs->[0], {
                    job_id => $jobs->[0]->{job_id},
                    repository_url => q{git://hoge/fuga},
                    repository_branch => q{hogefugabranch},
                    repository_revision => q{521451abacee},
                    action_type => '14242',
                    args => {12 => 31},
                };

                done $c;
            } $c;
        };
} n => 4, wait => mysql_and_web_as_cv;

run_tests;

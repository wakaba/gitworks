use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW::Web;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::UserAgent::Functions qw(http_get http_post http_post_data);
use JSON::Functions::XS qw(perl2json_bytes);
use Path::Class;
use Test::AnyEvent::MySQL::CreateDatabase;
use GW::Action::ProcessJobs;

my $root_d = file(__FILE__)->dir->parent->parent;
my $prep_f = $root_d->file('db', 'preparation.txt');

sub get_cv () {
    my $mysql_cv = Test::AnyEvent::MySQL::CreateDatabase->prep_f_to_cv($prep_f);
    
    my $server = start_web_server;
    
    my $cv = AE::cv;
    $cv->begin(sub { $_[0]->send($server) });
    $cv->begin;
    $mysql_cv->cb(sub { $cv->end });
    $cv->begin;
    $server->start_cv->cb(sub { $cv->end });
    $cv->end;
    return $cv;
}

my $cv = get_cv;

test {
    my $c = shift;

    my $host = $c->received_data->host;
    http_get
        url => qq<http://$host/hook>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 405;
                done $c;
            } $c;
        };
} n => 1, wait => $cv;

test {
    my $c = shift;

    my $host = $c->received_data->host;
    http_post
        url => qq<http://$host/hook>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
            } $c;
        };
} n => 1, wait => $cv;

test {
    my $c = shift;

    my $host = $c->received_data->host;
    http_post_data
        url => qq<http://$host/hook>,
        content => perl2json_bytes {
            repository => {url => q{git://hoge/fuga}},
            refname => 'refs/heads/hogefugabranch',
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

                my $action = GW::Action::ProcessJobs->new;
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
} n => 4, wait => get_cv;

run_tests;

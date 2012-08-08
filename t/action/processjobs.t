use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use Test::X1;
use Test::More;
use Test::Differences;
use Test::AnyEvent::MySQL::CreateDatabase;
use GW::Action::InsertJob;
use GW::Action::ProcessJobs;
use Path::Class;

my $root_d = file(__FILE__)->dir->parent->parent;
my $prep_f = $root_d->file('db', 'preparation.txt');
my $mysql_cv = Test::AnyEvent::MySQL::CreateDatabase->prep_f_to_cv($prep_f);

test {
    my $c = shift;

    local $Dongry::Database::Registry = {};
    GW::MySQL->load_by_f($c->received_data->json_f);

    my $action = GW::Action::ProcessJobs->new;
    my $jobs = $action->get_jobs;
    is $jobs->length, 0;

    done $c;
} n => 1, wait => $mysql_cv;

test {
    my $c = shift;

    local $Dongry::Database::Registry = {};
    GW::MySQL->load_by_f($c->received_data->json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $branch = q<devel/hoge>;
    my $hash = q<12344abc>;
    my $act = GW::Action::InsertJob->new_from_repository($url, $branch, $hash);

    $act->insert_job('testaction1', {12 => 31});

    my $action = GW::Action::ProcessJobs->new;
    my $jobs = $action->get_jobs;
    is $jobs->length, 1;
    eq_or_diff $jobs->[0], {
        repository_url => $url,
        repository_branch => $branch,
        repository_revision => $hash,
        action_type => 'testaction1',
        args => {12 => 31},
    };
    
    $c->done;
} n => 2, wait => $mysql_cv;

run_tests;

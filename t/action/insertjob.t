use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use GW::Action::InsertJob;
use GW::MySQL;

my $mysql_cv = mysql_as_cv;

test {
    my $c = shift;

    local *Dongry::Database::Registry = {};
    GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $branch = q<devel/hoge>;
    my $hash = q<12344abc>;
    my $act = GW::Action::InsertJob->new_from_repository($url, $branch, $hash);

    $act->insert_job('testaction1', {12 => 31});

    my $row = Dongry::Database->load('gitworks')->table('job')->find({repository_url => $url}, source_name => 'master');
    ok $row;
    ok $row->get('id');
    is $row->get('repository_revision'), $hash;
    is $row->get('repository_branch'), $branch;
    is $row->get('action_type'), 'testaction1';
    eq_or_diff $row->get('args'), {12 => 31};
    
    $c->done;
} n => 6, wait => $mysql_cv;

run_tests;

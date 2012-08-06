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
use GW::Action::InsertJob;

test {
    my $c = shift;

    my $url = q<git://hoge/fuga> . rand;
    my $hash = q<12344abc>;
    my $act = GW::Action::InsertJob->new_from_repository($url, $hash);

    $act->insert_job('testaction1', {12 => 31});

    my $row = Dongry::Database->load('gitworks')->table('job')->find({repository_url => $url}, source_name => 'master');
    ok $row;
    ok $row->get('id');
    is $row->get('repository_revision'), $hash;
    is $row->get('action_type'), 'testaction1';
    eq_or_diff $row->get('args'), {12 => 31};
    
    $c->done;
};

run_tests;

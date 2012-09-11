use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use GW::Action::EditRepositorySet;
use GW::Loader::RepositorySet;
use GW::MySQL;

my $mysql_cv = mysql_as_cv;

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $set_name1 = rand;
    my $set_name2 = rand;
    my $action1 = GW::Action::EditRepositorySet->new_from_dbreg_and_set_name($reg, $set_name1);
    my $action2 = GW::Action::EditRepositorySet->new_from_dbreg_and_set_name($reg, $set_name2);
    my $loader1 = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($reg, $set_name1);
    my $loader2 = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($reg, $set_name2);

    eq_or_diff $loader1->get_repository_urls, {};
    eq_or_diff $loader2->get_repository_urls, {};

    my $url = q<git://hoge/fuga> . rand;
    $action1->add_repository($url);

    eq_or_diff $loader1->get_repository_urls, {$url => 1};
    eq_or_diff $loader2->get_repository_urls, {};

    my $url2 = q<git://hoge/fuga> . rand;
    $action2->add_repository($url2);

    eq_or_diff $loader1->get_repository_urls, {$url => 1};
    eq_or_diff $loader2->get_repository_urls, {$url2 => 1};
    
    $c->done;
} n => 6, wait => $mysql_cv;

run_tests;

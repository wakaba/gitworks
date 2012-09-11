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

    my $set_name = rand;
    my $action = GW::Action::EditRepositorySet->new_from_dbreg_and_set_name($reg, $set_name);
    my $loader = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($reg, $set_name);

    eq_or_diff $loader->get_repository_urls, {};

    my $url = q<git://hoge/fuga> . rand;
    $action->add_repository($url);
    $action->add_repository($url);

    delete $reg->{Instances};

    eq_or_diff $loader->get_repository_urls, {$url => 1};

    my $url2 = q<git://hoge/fuga> . rand;
    $action->add_repository($url2);

    delete $reg->{Instances};

    eq_or_diff $loader->get_repository_urls, {$url => 1, $url2 => 1};

    $action->delete_repository($url);

    delete $reg->{Instances};

    eq_or_diff $loader->get_repository_urls, {$url2 => 1};
    
    $c->done;
} n => 4, wait => $mysql_cv;

run_tests;

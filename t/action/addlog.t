use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use GW::Action::AddLog;
use GW::Loader::Logs;
use GW::MySQL;

my $mysql_cv = mysql_as_cv;

test {
    my $c = shift;

    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga>;
    my $action = GW::Action::AddLog->new_from_dbreg_and_repository_url($dbreg, $url);
    
    my $sha = q<heaewegaegeeefwagfeeeagaggag4rrrrrr>;
    $action->add_log(
        sha => $sha,
        branch => q<hhtrpfeaege>,
        data => qq<afee\x{4e00}agageee xya>,
    );

    delete $dbreg->{Instances};

    my $loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $url);
    my $list = $loader->get_logs(sha => $sha);

    is $list->length, 1;
    ok $list->[0]->{id};
    delete $list->[0]->{id};
    ok $list->[0]->{created};
    delete $list->[0]->{created};
    delete $list->[0]->{repository_id};
    eq_or_diff $list->[0], {
        sha => $sha,
        branch => q<hhtrpfeaege>,
        data => qq<afee\x{4e00}agageee xya>,
    };

    my $timer; $timer = AE::timer 1, 0, sub {
        test {
            undef $timer;
            $action->add_log(
                sha => $sha,
            );

            my $list = $loader->get_logs(sha => $sha);
            
            is $list->length, 2;
            delete $list->[0]->{id};
            delete $list->[0]->{created};
            delete $list->[0]->{repository_id};
            delete $list->[1]->{id};
            delete $list->[1]->{created};
            delete $list->[1]->{repository_id};
            eq_or_diff $list->[1], {
                sha => $sha,
                branch => q<hhtrpfeaege>,
                data => qq<afee\x{4e00}agageee xya>,
            };
            eq_or_diff $list->[0], {
                sha => $sha,
                branch => undef,
                data => '',
            };

            $c->done;
            undef $c;
        } $c;
    };
} n => 7, wait => $mysql_cv;

run_tests;

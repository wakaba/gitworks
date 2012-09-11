use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use GW::MySQL;
use GW::Action::ProcessRepository;
use GW::Loader::RepositorySet;

my $mysql = mysql_as_cv;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => 1));
    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $cv1 = AE::cv;
    {
        my $job = {
            repository_url => $temp_d->stringify,
            repository_branch => 'master',
            repository_revision => $rev,
            action_type => 'repository_set.add',
            args => {
                set_name => 'hogefua',
            },
        };
        my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
        $action->command_dir_d($temp2_d);
        $action->dbreg($dbreg);
        $action->run_action_as_cv->cb(sub {
            test {
                my $loader = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($dbreg, 'hogefua');
                eq_or_diff $loader->get_repository_urls, {$temp_d => 1};
                $cv1->send;
            } $c;
        });
    }

    $cv1->cb(sub {
        test {
            my $job = {
                repository_url => $temp_d->stringify,
                repository_branch => 'master',
                repository_revision => $rev,
                action_type => 'repository_set.delete',
                args => {
                    set_name => 'hogefua',
                },
            };
            my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
            $action->command_dir_d($temp2_d);
            $action->dbreg($dbreg);
            $action->run_action_as_cv->cb(sub {
                test {
                    my $loader = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($dbreg, 'hogefua');
                    eq_or_diff $loader->get_repository_urls, {};
                    done $c;
                } $c;
            });
        } $c;
    });
} n => 2, name => 'repository_set.add, delete', wait => $mysql;

run_tests;

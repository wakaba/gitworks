use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use GW::Action::ProcessRepository;
use GW::Defs::Statuses;
use GW::MySQL;
use Karasuma::Config::JSON;

my $DEBUG = $ENV{GW_DEBUG};

my $mysql = mysql_as_cv;

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp2_d && echo \"echo 5566 > foo.txt\" > hoge.sh";

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->command_dir_d($temp2_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "5566\n";
            done $c;
        } $c;
    });
} n => 1, name => 'command found', wait => $mysql;

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => 1));
    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->command_dir_d($temp2_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            ok !-f $action->temp_repo_d->file('foo.txt');
            done $c;
        } $c;
    });
} n => 1, name => 'command not found', wait => $mysql;

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp2_d && echo \"echo 5566 > foo.txt\" > hoge.sh";

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->command_dir_d($temp2_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            my $temp_d = $action->temp_repo_d;
            undef $action;

            my $watch; $watch = AE::timer 0.1, 0, sub {
                test {
                    ok !-d $temp_d;
                    done $c;
                    undef $c;
                    undef $watch;
                } $c;
            };
        } $c;
    });
} n => 1, name => 'temp directory deleted', wait => $mysql;

run_tests;

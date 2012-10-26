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

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'make',
        args => {
            rule => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            done $c;
        } $c;
    });
} n => 1, wait => $mysql;

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    system "cd $temp_d && echo 'hoge:\n\techo 9999 > foo.txt' > Makefile && git add Makefile && git commit -m Old";

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'make',
        args => {
            rule => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            done $c;
        } $c;
    });
} n => 1, wait => $mysql;

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'make',
        args => {
            rule => 'hoge',
        },
    };

    my $cv2 = AE::cv;
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            ok -f $action->cached_repo_d->file('config');
            is `cd @{[$action->temp_repo_d]} && git rev-parse HEAD`, $rev;
            $cv2->send;
        } $c;
    });

    my $cv3 = AE::cv;
    $cv2->cb(sub {
        system "cd $temp_d && touch aa && git add aa && git commit -m aa";
        my $rev2 = `cd $temp_d && git rev-parse HEAD`;
        $job->{repository_revision} = $rev2;
        my $action2 = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
        $action2->dbreg($dbreg);
        $action2->karasuma_config($config);
        is $action2->cached_repo_d->stringify, $action->cached_repo_d->stringify;
        $action2->run_action_as_cv->cb(sub {
            test {
                ok -f $action2->cached_repo_d->file('config');
                is `cd @{[$action2->temp_repo_d]} && git rev-parse HEAD`, $rev2;
                $cv3->send;
            } $c;
        });
    });

    my $cv4 = AE::cv;
    $cv3->cb(sub {
        $job->{repository_revision} = $rev;
        my $action3 = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
        $action3->dbreg($dbreg);
        $action3->karasuma_config($config);
        $action3->run_action_as_cv->cb(sub {
            test {
                ok -f $action3->cached_repo_d->file('config');
                is `cd @{[$action3->temp_repo_d]} && git rev-parse HEAD`, $rev;
                $cv4->send;
            } $c;
        });
    });

    $cv4->cb(sub {
        test {
            done $c;
            undef $c;
        } $c;
    });
} n => 7, name => 'cached repo', wait => $mysql;

run_tests;

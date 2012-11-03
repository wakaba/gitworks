use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use GW::Defs::Statuses;
use GW::Loader::CommitStatuses;
use GW::Loader::Logs;
use GW::Action::ProcessRepository;
use GW::Defs::Statuses;
use GW::MySQL;
use Karasuma::Config::JSON;
use URL::PercentEncode qw(percent_encode_c);

my $DEBUG = $ENV{GW_DEBUG};

my $mysql = mysql_as_cv;

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        "gitworks.web.scheme" => "http",
        "gitworks.web.hostname" => "192.168.131.12",
        "gitworks.web.port" => 6016,
        'gitworks.githookhub.hook_url' => q<//GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

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
    $action->onmessage(sub { warn $_[0] });
    my $cv1 = AE::cv;
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            $cv1->send;
        } $c;
    });

    $cv1->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 2;
            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, 'http://192.168.131.12:6016/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks action - make hoge - Succeeded';
            is $cses->[0]->{state}, COMMIT_STATUS_SUCCESS;

            is $cses->[1]->{sha}, $rev;
            is $cses->[1]->{target_url}, undef;
            is $cses->[1]->{description}, 'GitWorks action - make hoge - Started';
            is $cses->[1]->{state}, COMMIT_STATUS_PENDING;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{make hoge}m;
            like $logs->[0]->{data}, qr{^Exited with status 0}m;
            #warn $logs->[0]->{data};
            is $logs->[0]->{title}, 'GitWorks action - make hoge - Succeeded';

            done $c;
            undef $c;
        } $c;
    });
} n => 15, wait => $mysql, name => 'ok';

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        "gitworks.web.scheme" => "http",
        "gitworks.web.hostname" => "192.168.131.12",
        "gitworks.web.port" => 6016,
        'gitworks.githookhub.hook_url' => q<//GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        action_type => 'make',
        args => {
            rule => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->onmessage(sub { warn $_[0] });
    my $cv1 = AE::cv;
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            $cv1->send;
        } $c;
    });

    $cv1->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 2;
            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, 'http://192.168.131.12:6016/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks action - make hoge - Succeeded';
            is $cses->[0]->{state}, COMMIT_STATUS_SUCCESS;

            is $cses->[1]->{sha}, $rev;
            is $cses->[1]->{target_url}, undef;
            is $cses->[1]->{description}, 'GitWorks action - make hoge - Started';
            is $cses->[1]->{state}, COMMIT_STATUS_PENDING;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{make hoge}m;
            like $logs->[0]->{data}, qr{^Exited with status 0}m;
            #warn $logs->[0]->{data};
            is $logs->[0]->{title}, 'GitWorks action - make hoge - Succeeded';

            done $c;
            undef $c;
        } $c;
    });
} n => 15, wait => $mysql, name => 'ok - only branch is specified';

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<//GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt\n\tfalse' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

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
    my $cv1 = AE::cv;
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            $cv1->send;
        } $c;
    });

    $cv1->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 2;

            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, '/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks action - make hoge - Failed';
            is $cses->[0]->{state}, COMMIT_STATUS_FAILURE;

            is $cses->[1]->{sha}, $rev;
            is $cses->[1]->{target_url}, undef;
            is $cses->[1]->{description}, 'GitWorks action - make hoge - Started';
            is $cses->[1]->{state}, COMMIT_STATUS_PENDING;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{make hoge}m;
            like $logs->[0]->{data}, qr{^Exited with status 2}m;
            #warn $logs->[0]->{data};
            is $logs->[0]->{title}, 'GitWorks action - make hoge - Failed';

            done $c;
            undef $c;
        } $c;
    });
} n => 15, wait => $mysql, name => 'make rule failed';

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<//GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt\n\tfalse' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'make',
        args => {
            rule => 'hoge2',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    my $cv1 = AE::cv;
    $action->run_action_as_cv->cb(sub {
        test {
            ok !-f $action->temp_repo_d->file('foo.txt');
            $cv1->send;
        } $c;
    });

    $cv1->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 2;

            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, '/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks action - make hoge2 - Failed';
            is $cses->[0]->{state}, COMMIT_STATUS_FAILURE;

            is $cses->[1]->{sha}, $rev;
            is $cses->[1]->{target_url}, undef;
            is $cses->[1]->{description}, 'GitWorks action - make hoge2 - Started';
            is $cses->[1]->{state}, COMMIT_STATUS_PENDING;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{make hoge2}m;
            like $logs->[0]->{data}, qr{^Exited with status 2}m;
            #warn $logs->[0]->{data};
            is $logs->[0]->{title}, 'GitWorks action - make hoge2 - Failed';

            done $c;
            undef $c;
        } $c;
    });
} n => 15, wait => $mysql, name => 'make rule not found';

test {
    my $c = shift;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<//GHH/hook>,
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
        'gitworks.githookhub.hook_url' => q<//GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

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
            my $rev1 = `cd @{[$action->temp_repo_d]} && git rev-parse HEAD`;
            chomp $rev1;
            is $rev1, $rev;
            $cv2->send;
        } $c;
    });

    my $rev2;
    my $cv3 = AE::cv;
    $cv2->cb(sub {
        system "cd $temp_d && touch aa && git add aa && git commit -m aa";
        $rev2 = `cd $temp_d && git rev-parse HEAD`;
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
$action3->onmessage(sub { warn $_[0] });
        $action3->run_action_as_cv->cb(sub {
            test {
                ok -f $action3->cached_repo_d->file('config');
                my $rev4 = `cd @{[$action3->temp_repo_d]} && git rev-parse HEAD`;
                chomp $rev4;
                is $rev4, $rev;
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

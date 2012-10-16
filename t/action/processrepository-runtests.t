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
use GW::MySQL;
use GW::Action::ProcessRepository;
use GW::Loader::CommitStatuses;
use GW::Loader::Logs;
use URL::PercentEncode qw(percent_encode_c);

my $mysql = mysql_as_cv;

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'run-test',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->run_action_as_cv->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 1;
            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, '/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks repository test - Failed';
            is $cses->[0]->{state}, COMMIT_STATUS_FAILURE;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            is $logs->[0]->{title}, 'GitWorks repository test - Failed';
            like $logs->[0]->{data}, qr{^cd \\/tmp\\/\S+ && make test 2>&1}m;
            like $logs->[0]->{data}, qr{^Exited with status 2}m;
            
            done $c;
            undef $c;
        } $c;
    });
} n => 10, wait => $mysql, name => 'failed (no rule)';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'test:\n\techo 1234 > foo.txt\n\techo PATH=\$\$PATH' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'run-test',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->run_action_as_cv->cb(sub {
        test {
            delete $dbreg->{Instances};
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 1;
            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, '/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks repository test - Succeeded';
            is $cses->[0]->{state}, COMMIT_STATUS_SUCCESS;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{^cd \\/tmp\\/\S+ && make test 2>&1}m;
            like $logs->[0]->{data}, qr{^Exited with status 0}m;
            #warn $logs->[0]->{data};
            is $logs->[0]->{title}, 'GitWorks repository test - Succeeded';
            
            done $c;
            undef $c;
        } $c;
    });
} n => 10, wait => $mysql, name => 'success';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'test:\n\tfalse > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'run-test',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->run_action_as_cv->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 1;
            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, '/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks repository test - Failed';
            is $cses->[0]->{state}, COMMIT_STATUS_FAILURE;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{^cd \\/tmp\\/\S+ && make test 2>&1}m;
            like $logs->[0]->{data}, qr{^Exited with status 2}m;
            is $logs->[0]->{title}, 'GitWorks repository test - Failed';
            
            done $c;
            undef $c;
        } $c;
    });
} n => 10, wait => $mysql, name => 'failed (make failed)';

run_tests;

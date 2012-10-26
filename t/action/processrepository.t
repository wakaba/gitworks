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
use GW::MySQL;
use Karasuma::Config::JSON;
use URL::PercentEncode qw(percent_encode_c);

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
    chomp $rev;

    my $temp2_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp2_d && echo \"echo 5566 > foo.txt\" > hoge.sh";

    my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'fuga',
        args => {
            command => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    my $cv1 = AE::cv;
    $action->command_dir_d($temp2_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            $cv1->send;
        } $c;
    });

    $cv1->cb(sub {
        test {
            my $cs_loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $cses = $cs_loader->get_commit_statuses($rev);
            is $cses->length, 1;
            is $cses->[0]->{sha}, $rev;
            $cses->[0]->{target_url} =~ s/log-\d+$/log-hoge/;
            is $cses->[0]->{target_url}, '/repos/logs?repository_url=' . (percent_encode_c $temp_d) . '&sha=' . $rev . '#log-hoge';
            is $cses->[0]->{description}, 'GitWorks action - fuga - Failed';
            is $cses->[0]->{state}, COMMIT_STATUS_FAILURE;

            my $log_loader = GW::Loader::Logs->new_from_dbreg_and_repository_url($dbreg, $temp_d->stringify);
            my $logs = $log_loader->get_logs(sha => $rev);
            is $logs->length, 1;
            is $logs->[0]->{sha}, $rev;
            like $logs->[0]->{data}, qr{^fuga$}m;
            like $logs->[0]->{data}, qr{^Action \|fuga\| is not supported}m;
            #warn $logs->[0]->{data};
            is $logs->[0]->{title}, 'GitWorks action - fuga - Failed';

            done $c;
            undef $c;
        } $c;
    });
} n => 10, name => 'unknown action', wait => $mysql;

run_tests;

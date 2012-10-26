use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use Path::Class;
use File::Temp qw(tempdir);
use GW::MySQL;
use GW::Action::InsertJob;
use GW::Action::ProcessJobs;
use Karasuma::Config::JSON;

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $cached_d = dir(tempdir(CLEANUP => 1));
    my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
    $action->db_registry($reg);
    my $jobs = $action->get_jobs;
    is $jobs->length, 0;

    done $c;
} n => 1, wait => mysql_as_cv;

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $branch = q<devel/hoge>;
    my $hash = q<12344abc>;
    my $act = GW::Action::InsertJob->new_from_repository($url, $branch, $hash);
    $act->db_registry($reg);
    $act->insert_job('testaction1', {12 => 31});

    my $cached_d = dir(tempdir(CLEANUP => 1));
    my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
    $action->db_registry($reg);
    my $jobs = $action->get_jobs;
    is $jobs->length, 1;
    ok $jobs->[0]->{job_id};
    eq_or_diff $jobs->[0], {
        job_id => $jobs->[0]->{job_id},
        repository_url => $url,
        repository_branch => $branch,
        repository_revision => $hash,
        action_type => 'testaction1',
        args => {12 => 31},
    };

    $action->delete_job($jobs->[0]->{id});
    $action->delete_job(5213233);

    is $action->get_jobs->length, 0;
    
    $c->done;
} n => 4, wait => mysql_as_cv;

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $branch = q<devel/hoge>;
    my $hash = q<12344abc>;
    my $act = GW::Action::InsertJob->new_from_repository($url, $branch, $hash);
    $act->db_registry($reg);
    $act->insert_job('testaction1', {12 => 31});

    my $cached_d = dir(tempdir(CLEANUP => 1));
    my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
    $action->db_registry($reg);

    is $action->get_jobs(action_types => ['testaction1'])->length, 1;
    is $action->get_jobs(action_types => ['testaction2'])->length, 0;
    
    $c->done;
} n => 2, wait => sub { mysql_as_cv }, name => 'action_types';

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $branch = q<devel/hoge>;
    my $hash = q<12344abc>;
    my $act = GW::Action::InsertJob->new_from_repository($url, $branch, $hash);
    $act->db_registry($reg);
    $act->insert_job('testaction1', {12 => 31});

    my $cached_d = dir(tempdir(CLEANUP => 1));
    my $action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
    $action->db_registry($reg);
    my $jobs = $action->get_jobs;

    is $action->get_jobs(not_action_types => ['testaction1'])->length, 0;
    
    $c->done;
} n => 1, wait => sub { mysql_as_cv }, name => 'not_action_types';

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    my $temp2_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > @{[$temp2_d]}/foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $job_action = GW::Action::InsertJob->new_from_repository(
        $temp_d->stringify,
        'master',
        $rev,
    );
    $job_action->db_registry($reg);
    $job_action->insert_job('make', {rule => 'hoge'});

    my $cached_d = dir(tempdir(CLEANUP => 1));
    my $process_action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
    $process_action->db_registry($reg);
    $process_action->karasuma_config($config);
    $process_action->process_jobs_as_cv->cb(sub {
        test {
            is scalar $temp2_d->file('foo.txt')->slurp, "1234\n";
            done $c;
        } $c;
    });
} n => 1, wait => mysql_as_cv, name => 'process_jobs a job';

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });

    my $temp2_d = dir(tempdir(CLEANUP => 1));
    for my $i (1..2) {
        my $temp_d = dir(tempdir(CLEANUP => 1));
        system "cd $temp_d && git init && echo 'hoge:\n\techo 1234-$i > @{[$temp2_d]}/foo-$i.txt' > Makefile && git add Makefile && git commit -m New";
        my $rev = `cd $temp_d && git rev-parse HEAD`;
        
        my $job_action = GW::Action::InsertJob->new_from_repository(
            $temp_d->stringify,
            'master',
            $rev,
        );
        $job_action->db_registry($reg);
        $job_action->insert_job('make', {rule => 'hoge'});
    }

    my $cached_d = dir(tempdir(CLEANUP => 1));
    my $process_action = GW::Action::ProcessJobs->new_from_cached_repo_set_d($cached_d);
    $process_action->db_registry($reg);
    $process_action->karasuma_config($config);
    $process_action->process_jobs_as_cv->cb(sub {
        $process_action->process_jobs_as_cv->cb(sub {
            test {
                is scalar $temp2_d->file('foo-1.txt')->slurp, "1234-1\n";
                is scalar $temp2_d->file('foo-2.txt')->slurp, "1234-2\n";
                done $c;
            } $c;
        });
    });
} n => 2, wait => mysql_as_cv, name => 'process_jobs multiple job';

run_tests;

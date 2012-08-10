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

test {
    my $c = shift;

    my $reg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $action = GW::Action::ProcessJobs->new;
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

    my $action = GW::Action::ProcessJobs->new;
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

    my $process_action = GW::Action::ProcessJobs->new;
    $process_action->db_registry($reg);
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

    my $process_action = GW::Action::ProcessJobs->new;
    $process_action->db_registry($reg);
    $process_action->process_jobs_as_cv->cb(sub {
        test {
            is scalar $temp2_d->file('foo-1.txt')->slurp, "1234-1\n";
            is scalar $temp2_d->file('foo-2.txt')->slurp, "1234-2\n";
            done $c;
        } $c;
    });
} n => 2, wait => mysql_as_cv, name => 'process_jobs multiple job';

run_tests;

package GW::Action::ProcessJobs;
use strict;
use warnings;
use AnyEvent;
use Dongry::Database;
use GW::MySQL;
use GW::Action::ProcessRepository;

sub new {
    return bless {}, $_[0];
}

sub job_count {
    return 5;
}

sub timeout {
    return 10*60;
}

sub get_jobs {
    my $self = shift;

    my $db = Dongry::Database->load('gitworks');
    my $pid = $db->execute(
        'SELECT UUID_SHORT() AS `id`',
        {},
        source_name => 'master',
    )->first->{id};
    $db->update(
        'job',
        {
            process_id => $pid,
            process_started => time,
        },
        where => {
            process_started => {'<', time - $self->timeout},
        },
        order => ['created' => 'ASC'],
        limit => $self->job_count,
    );
    return $db->select(
        'job',
        {process_id => $pid},
        source_name => 'master',
    )->all_as_rows->map(sub {
        my $job = $_;
        return {
            job_id => $job->get('id'),
            repository_url => $job->get('repository_url'),
            repository_branch => $job->get('repository_branch'),
            repository_revision => $job->get('repository_revision'),
            action_type => $job->get('action_type'),
            args => $job->get('args'),
        };
    });
}

sub delete_job {
    my ($self, $job_id) = @_;

    my $db = Dongry::Database->load('gitworks');
    $db->delete('job', {id => $job_id});
}

sub process_jobs_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $cv->begin;

    $self->get_jobs->each(sub {
        my $job = $_;
        my $repo_action = GW::Action::ProcessRepository->new_from_job($job);
        $cv->begin;
        $repo_action->run_action_as_cv->cb(sub {
            $self->delete_job($job->{job_id});
            $cv->end;
        });
    });

    $cv->end;
    return $cv;
}

1;

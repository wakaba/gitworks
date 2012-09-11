package GW::Action::ProcessJobs;
use strict;
use warnings;
use AnyEvent;
use Dongry::Database;
use GW::MySQL;
use GW::Action::ProcessRepository;

sub new_from_cached_repo_set_d {
    return bless {cached_repo_set_d => $_[1]}, $_[0];
}

sub cached_repo_set_d {
    return $_[0]->{cached_repo_set_d};
}

sub job_count {
    return 5;
}

sub timeout {
    return 10*60;
}

sub onmessage {
    if (@_ > 1) {
        $_[0]->{onmessage} = $_[1];
    }
    return $_[0]->{onmessage};
}

sub db_registry {
    if (@_ > 1) {
        $_[0]->{db_registry} = $_[1];
    }
    return $_[0]->{db_registry};
}

sub get_jobs {
    my $self = shift;

    my $db = $self->db_registry->load('gitworks');
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

    $self->db_registry->load('gitworks')->delete('job', {id => $job_id});
}

sub process_jobs_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $cv->begin(sub { $_[0]->send });

    my $cached_d = $self->cached_repo_set_d;
    my $dbreg = $self->db_registry;
    $self->get_jobs->each(sub {
        my $job = $_;
        my $repo_action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
        $repo_action->dbreg($dbreg);
        $repo_action->onmessage($self->onmessage);
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

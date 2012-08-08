package GW::Action::ProcessJobs;
use strict;
use warnings;
use Dongry::Database;
use GW::MySQL;

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

1;

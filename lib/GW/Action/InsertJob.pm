package GW::Action::InsertJob;
use strict;
use warnings;
use Dongry::Database;

sub new_from_repository {
    return bless {repository_url => $_[1], repository_revision => $_[2]}, $_[0];
}

sub repository_url {
    return $_[0]->{repository_url};
}

sub repository_revision {
    return $_[0]->{repository_revision};
}

sub insert_job {
    my ($self, $action_type, $args, %opts) = @_;
    
    my $db = Dongry::Database->load('gitworks');
    $db->table('job')->insert(
        [{
            id => $db->bare_sql_fragment('UUID_SHORT()'),
            created => time,
            
            repository_url => $self->repository_url,
            repository_revision => $self->repository_revision,
            action_type => $action_type,
            args => $args,
            
            process_id => 0,
            process_started => 0,
        }],
    );
}

1;

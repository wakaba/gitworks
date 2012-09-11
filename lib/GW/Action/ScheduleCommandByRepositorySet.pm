package GW::Action::ScheduleCommandByRepositorySet;
use strict;
use warnings;
use GW::Loader::RepositorySet;
use GW::Action::InsertJob;

sub new_from_dbreg_and_set_name {
    return bless {dbreg => $_[1], set_name => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub set_name {
    return $_[0]->{set_name};
}

sub schedule_command {
    my ($self, $command) = @_;

    my $dbreg = $self->dbreg;
    my $loader = GW::Loader::RepositorySet->new_from_dbreg_and_set_name($dbreg, $self->set_name);
    my $urls = $loader->get_repository_urls;
    
    for my $url (keys %$urls) {
        my $action = GW::Action::InsertJob->new_from_repository($url, 'master', 'master');
        $action->db_registry($dbreg);
        $action->insert_job('command', {command => $command});
    }
}

1;

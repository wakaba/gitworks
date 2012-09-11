package GW::Action::EditRepositorySet;
use strict;
use warnings;

sub new_from_dbreg_and_set_name {
    return bless {dbreg => $_[1], set_name => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub set_name {
    return $_[0]->{set_name};
}

sub add_repository {
    my ($self, $url) = @_;

    my $db = $self->dbreg->load('gitworks');
    my $name = $self->set_name;

    $db->insert('repository_set', [{
        id => $db->bare_sql_fragment('UUID_SHORT()'),
        created => time,
        set_name => $name,
        repository_url => $url,
    }], duplicate => 'ignore');
}

sub delete_repository {
    my ($self, $url) = @_;

    my $db = $self->dbreg->load('gitworks');
    my $name = $self->set_name;

    $db->delete('repository_set', {
        set_name => $name,
        repository_url => $url,
    });
}

1;

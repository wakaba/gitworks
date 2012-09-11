package GW::Loader::RepositorySet;
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

sub get_repository_urls {
    my $self = shift;

    my $db = $self->dbreg->load('gitworks');
    my $name = $self->set_name;

    return {
        $db->select('repository_set', {
            set_name => $name,
        })->all->map(sub { $_->{repository_url} => 1 })->to_list,
    };
}

1;

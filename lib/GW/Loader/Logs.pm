package GW::Loader::Logs;
use strict;
use warnings;
use List::Ish;
use Dongry::Type;

sub new_from_dbreg_and_repository_url {
    return bless {dbreg => $_[1], repository_url => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub repository_url {
    return $_[0]->{repository_url};
}

sub per_page {
    return 100; # XXX pager
}

sub get_logs {
    my ($self, %args) = @_;
    
    my $db = $self->dbreg->load('gitworks');
    my $repo_id = ($db->select('repository', {repository_url => $self->repository_url})->first or {})->{id}
        or return List::Ish->new;

    my $where = {repository_id => $repo_id};
    $where->{sha} = $args{sha} if defined $args{sha};
    $where->{repository_branch} = $args{branch} if defined $args{branch};
    #$where->{created} = ...; # XXX pager
    
    return $self->dbreg->load('gitworkslogs')->select(
        'log',
        $where,
        order => ['created' => 'DESC'],
        limit => $self->per_page,
    )->all->map(sub {
        $_->{data} = Dongry::Type->parse('text', $_->{data});
        $_->{branch} = delete $_->{repository_branch};
        $_->{branch} = undef unless length $_->{branch};
        $_;
    });
}

1;

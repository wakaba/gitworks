package GW::Loader::CommitStatuses;
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

sub get_commit_statuses {
    my ($self, $sha) = @_;
    
    my $db = $self->dbreg->load('gitworks');
    my $repo_id = ($db->select('repository', {repository_url => $self->repository_url})->first or {})->{id}
        or return List::Ish->new;
    
    return $db->select(
        'commit_status',
        {repository_id => $repo_id, sha => $sha},
        order => ['created' => 'DESC'],
    )->all->map(sub {
        $_->{description} = Dongry::Type->parse('text', $_->{description});
        $_->{description} = undef unless length $_->{description};
        $_->{target_url} = undef unless length $_->{target_url};
        $_;
    });
}

sub get_commit_statuses_list {
    my ($self, $sha_list) = @_;
    return {} unless @$sha_list;
    
    my $db = $self->dbreg->load('gitworks');
    my $repo_id = ($db->select('repository', {repository_url => $self->repository_url})->first or {})->{id}
        or return {};

    my $result = {};
    $db->select(
        'commit_status',
        {repository_id => $repo_id, sha => {-in => $sha_list}},
        order => ['created' => 'DESC'],
    )->all->each(sub {
        $_->{description} = Dongry::Type->parse('text', $_->{description});
        $_->{description} = undef unless length $_->{description};
        $_->{target_url} = undef unless length $_->{target_url};
        ($result->{$_->{sha}} ||= List::Ish->new)->push($_);
    });
    return $result;
}

1;

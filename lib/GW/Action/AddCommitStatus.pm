package GW::Action::AddCommitStatus;
use strict;
use warnings;
use Dongry::Type;
use Time::HiRes qw(time);

sub new_from_dbreg_and_repository_url {
    return bless {dbreg => $_[1], repository_url => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub repository_url {
    return $_[0]->{repository_url};
}

sub add_commit_status {
    my ($self, %args) = @_;

    my $db = $self->dbreg->load('gitworks');
    
    my $url = $self->repository_url or die "No repository_url";
    my $repo_id = ($db->select('repository', {repository_url => $url}, field => 'id')->first || {})->{id};
    unless ($repo_id) {
        $db->insert('repository', [{
            id => $db->bare_sql_fragment('UUID_SHORT()'),
            repository_url => $url,
            created => time,
        }], duplicate => 'ignore');
        $repo_id = $db->select('repository', {repository_url => $url}, field => 'id', source_name => 'master')->first->{id};
    }

    $db->insert('commit_status', [{
        id => $db->bare_sql_fragment('UUID_SHORT()'),
        created => time,
        repository_id => $repo_id,
        sha => ($args{sha} || die "No sha"),
        state => $args{state} || 0,
        target_url => $args{target_url} || '',
        description => Dongry::Type->serialize('text', defined $args{description} ? $args{description} : ''),
    }]);
}

1;
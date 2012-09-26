package GW::Action::AddLog;
use strict;
use warnings;
use Dongry::Type;
use Time::HiRes qw(time);
use URL::PercentEncode qw(percent_encode_c);

sub new_from_dbreg_and_repository_url {
    return bless {dbreg => $_[1], repository_url => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub repository_url {
    return $_[0]->{repository_url};
}

sub add_log {
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

    my $sha = ($args{sha} || die "No sha");
    my $id = $db->execute('SELECT UUID_SHORT() AS uuid')->first->{uuid};
    $self->dbreg->load('gitworkslogs')->insert('log', [{
        id => $id,
        created => time,
        repository_id => $repo_id,
        repository_branch => defined $args{branch} ? $args{branch} : '',
        sha => $sha,
        title => Dongry::Type->serialize('text', defined $args{title} ? $args{title} : ''),
        data => Dongry::Type->serialize('text', defined $args{data} ? $args{data} : ''),
    }]);

    return {
        log_id => $id,
        logs_url => (sprintf '/repos/logs?repository_url=%s&sha=%s#log-%s',
                         (percent_encode_c $url),
                         (percent_encode_c $sha),
                         (percent_encode_c $id)),
    };
}

1;

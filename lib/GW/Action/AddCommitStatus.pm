package GW::Action::AddCommitStatus;
use strict;
use warnings;
use Dongry::Type;
use Time::HiRes qw(time);
use Web::UserAgent::Functions qw(http_post_data);
use JSON::Functions::XS qw(perl2json_bytes);
use AnyEvent;
use GW::Defs::Statuses;

sub new_from_dbreg_and_repository_url {
    return bless {dbreg => $_[1], repository_url => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub repository_url {
    return $_[0]->{repository_url};
}

sub karasuma_config {
    if (@_ > 1) {
        $_[0]->{karasuma_config} = $_[1];
    }
    return $_[0]->{karasuma_config};
}

sub ghh_hook_url {
    return $_[0]->karasuma_config->get_text('gitworks.githookhub.hook_url');
}

sub ghh_api_key {
    return $_[0]->karasuma_config->get_file_base64_text('gitworks.githookhub.api_key');
}

sub add_commit_status_as_cv {
    my ($self, %args) = @_;
    my $cv = AE::cv;

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

    my $time = time;
    $db->insert('commit_status', [{
        id => $db->bare_sql_fragment('UUID_SHORT()'),
        created => $time,
        repository_id => $repo_id,
        sha => ($args{sha} || die "No sha"),
        state => $args{state} || 0,
        target_url => $args{target_url} || '',
        description => Dongry::Type->serialize('text', defined $args{description} ? $args{description} : ''),
    }]);

    http_post_data
        url => $self->ghh_hook_url,
        basic_auth => [api_key => $self->ghh_api_key],
        content => perl2json_bytes +{
            repository => {url => $url},
            ref => ($args{branch} ? (q<refs/heads/> . $args{branch}) : undef),
            after => $args{sha},
            hook_event => 'addcommitstatus',
            hook_args => {
                created => time,
                state => $GW::Defs::Statuses::CommitStatusCodeToName->{$args{state} || 0},
                target_url => $args{target_url} || '',
                description => $args{description},
            },
        },
        anyevent => 1,
        cb => sub {
            $cv->send;
        };
    return $cv;
}

1;

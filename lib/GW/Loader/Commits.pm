package GW::Loader::Commits;
use strict;
use warnings;
use AnyEvent;
use GW::Action::ProcessRepository;

sub new_from_process_repository_action {
    return bless {process_repository_action => $_[1]}, $_[0];
}

sub process_repository_action {
    return $_[0]->{process_repository_action};
}

sub _datetime ($) {
    my @time = gmtime $_[0];
    return sprintf '%04d-%02d-%02dT%02d:%02d:%02d-00:00',
        $time[5] + 1900, $time[4] + 1, $time[3], $time[2], $time[1], $time[0];
}

sub get_commit_as_github_jsonable_as_cv {
    my ($self, $sha) = @_;
    my $cv = AE::cv;
    my $action = $self->process_repository_action;
    $action->get_commit_info_as_cv($sha)->cb(sub {
        my $info = $_[0]->recv;
        if ($info) {
            # <http://developer.github.com/v3/git/commits/#get-a-commit>
            $cv->send({
                sha => $info->{commit},
                #url
                author => {
                    date => _datetime $info->{author}->{time},
                    name => $info->{author}->{name},
                    email => $info->{author}->{mail},
                },
                committer => {
                    date => _datetime $info->{committer}->{time},
                    name => $info->{committer}->{name},
                    email => $info->{committer}->{mail},
                },
                message => $info->{body},
                tree => {
                    #url
                    sha => $info->{tree},
                },
                parents => [
                    map { +{
                        #url
                        sha => $_,
                    } } @{$info->{parent}},
                ],
            });
        } else {
            $cv->send(undef);
        }
    });
    return $cv;
}

1;

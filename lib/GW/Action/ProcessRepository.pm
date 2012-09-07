package GW::Action::ProcessRepository;
use strict;
use warnings;
use File::Temp;
use Path::Class;
use AnyEvent;
use AnyEvent::Util;
use Encode;
use Digest::SHA1 qw(sha1_hex);

my $DEBUG = $ENV{GW_DEBUG};

sub new_from_job_and_cached_repo_set_d {
    return bless {job => $_[1], cached_repo_set_d => $_[2]}, $_[0];
}

sub url {
    return $_[0]->{job}->{repository_url};
}

sub url_as_hash {
    return $_[0]->{url_as_hash} ||= sha1_hex encode 'utf-8', $_[0]->url;
}

sub branch {
    return $_[0]->{job}->{repository_branch};
}

sub revision {
    return $_[0]->{job}->{repository_revision};
}

sub onmessage {
    if (@_ > 1) {
        $_[0]->{onmessage} = $_[1];
    }
    return $_[0]->{onmessage} ||= sub { };
}

sub print_message {
    my ($self, $msg) = @_;
    $self->onmessage->($msg);
}

sub die_message {
    my ($self, $msg) = @_;
    $self->onmessage->($msg, die => 1);
    die $msg;
}

sub cached_repo_set_d {
    return $_[0]->{cached_repo_set_d};
}

sub cached_repo_d {
    return $_[0]->{cached_repo_d} ||= $_[0]->cached_repo_set_d->subdir($_[0]->url_as_hash);
}

sub has_cached_repo_d_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    my $d = $self->cached_repo_d;
    if (not -d $d) {
        $cv->send(0);
    } elsif (not -f $d->file('config')) {
        $cv->send(0);
    } else {
        my $rev;
        run_cmd(
            qq{cd \Q$d\E && git rev-parse HEAD},
            '>' => \$rev,
        )->cb(sub {
            $cv->send($rev && $rev =~ /[0-9a-z]/);
        });
    }
    return $cv;
}

sub temp_repo_temp {
    my $self = shift;
    return $self->{temp_repo_temp} ||= File::Temp->newdir(CLEANUP => !$DEBUG);
}

sub temp_repo_d {
    my $self = shift;
    return $self->{temp_repo_d} ||= dir($self->temp_repo_temp->dirname);
}

sub git_as_cv {
    my ($self, $cmd, %args) = @_;
    $self->print_message('$ ' . join ' ', 'git', @$cmd);
    my $onmessage = $self->onmessage;
    my $d = $args{d} || $self->temp_repo_d;
    $cmd = ['sh', '-c', 'cd ' . (quotemeta $d) . ' && git ' . join ' ', map { quotemeta } @$cmd];
    return run_cmd $cmd, 
        '>' => $args{onstdout} || sub {
            $onmessage->($_[0]) if defined $_[0];
        },
        '2>' => sub {
            $onmessage->($_[0]) if defined $_[0];
        },
    ;
}

sub clone_as_cv {
    my $self = shift;
    my $cv = AE::cv;

    my $cv1 = AE::cv;
    $self->has_cached_repo_d_as_cv->cb(sub {
        if ($_[0]->recv) {
            $self->git_as_cv(['fetch', 'origin'], d => $self->cached_repo_d)->cb(sub {
                $cv1->send;
            });
        } else {
            $self->git_as_cv(['clone', '--mirror', $self->url => $self->cached_repo_d])->cb(sub {
                $cv1->send;
            });
        }
    });

    $cv1->cb(sub {
        my $clone_cv = $self->git_as_cv(['clone', $self->cached_repo_d => $self->temp_repo_d->stringify], d => $self->cached_repo_d)->cb(sub {
            $self->git_as_cv(['checkout', $self->revision])->cb(sub {
                $self->git_as_cv(['submodule', 'update', '--init'])->cb(sub {
                    $self->git_as_cv(['remote', 'set-url', '--push', 'origin', $self->url])->cb(sub {
                        $cv->send;
                    });
                });
            });
        });
    });
    return $cv;
}

sub command_dir_d {
    if (@_ > 1) {
        $_[0]->{command_dir_d} = $_[1];
    }
    return $_[0]->{command_dir_d} || $GW::CommandDirD || dir('commanddirnotspecified');
}

sub get_command_f {
    my ($self, $command) = @_;
    return $self->command_dir_d->file($command . '.sh');
}

sub run_action_as_cv {
    my $self = shift;
    my $action = $self->{job}->{action_type};
    my $args = $self->{job}->{args};

    my $cv = AE::cv;
    $self->clone_as_cv->cb(sub {
        if ($action eq 'make') {
            my $run_cv = run_cmd
                "cd @{[quotemeta $self->temp_repo_d]} && (make @{[quotemeta $args->{rule}]})";
            $run_cv->cb(sub { $cv->send });
        } elsif ($action eq 'command') {
            my $command = $args->{command};
            if ($command =~ /\A[0-9A-Za-z_]+\z/ and
                -f (my $command_f = $self->get_command_f($command))) {
                my $run_cv = run_cmd
                    "cd @{[quotemeta $self->temp_repo_d]} && sh @{[$command_f->absolute]}";
                $run_cv->cb(sub {
                    my $return = $_[0]->recv;
                    if ($return >> 8) {
                        warn "@{[$command_f->absolute]} exited with status @{[$return >> 8]}\n";
                    }
                    $cv->send;
                });
            } else {
                warn "Command |$command| (@{[$self->get_command_f($command)]}) is not defined";
                $cv->send;
            }
        } else {
            warn "Action |$action| is not supported";
            $cv->send;
        }
    });
    return $cv;
}

1;

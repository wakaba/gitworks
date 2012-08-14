package GW::Action::ProcessRepository;
use strict;
use warnings;
use File::Temp;
use Path::Class;
use AnyEvent;
use AnyEvent::Util;

my $DEBUG = $ENV{GW_DEBUG};

sub new_from_job {
    return bless {job => $_[1]}, $_[0];
}

sub url {
    return $_[0]->{job}->{repository_url};
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
    if ($cmd->[0] ne 'clone') {
        $cmd = ['sh', '-c', 'cd ' . (quotemeta $self->temp_repo_d) . ' && git ' . join ' ', map { quotemeta } @$cmd];
    } else {
        $cmd = ['git', @$cmd];
    }
    return run_cmd $cmd, 
        '>' => $args{onstdout} || sub {
            $onmessage->($_[0]) if defined $_[0];
        },
        '2>' => sub {
            $onmessage->($_[0]) if defined $_[0];
        },
    ;
}

sub clone_depth {
    return 200;
}

sub clone_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    my $clone_cv = $self->git_as_cv(['clone', '--depth' => $self->clone_depth, $self->url => $self->temp_repo_d->stringify])->cb(sub {
        $self->git_as_cv(['checkout', $self->revision])->cb(sub {
            $self->git_as_cv(['submodule', 'update', '--init'])->cb(sub {
                $cv->send;
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
                $run_cv->cb(sub { $cv->send });
            } else {
                warn "Command |$command| is not defined";
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

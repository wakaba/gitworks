package GW::Action::ProcessRepository;
use strict;
use warnings;
use File::Temp;
use Path::Class;
use AnyEvent;
use AnyEvent::Util;
use List::Ish;
use Encode;
use Digest::SHA1 qw(sha1_hex);
use GW::Defs::Statuses;
use Time::HiRes qw(time);

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

sub dbreg {
    if (@_ > 1) {
        $_[0]->{dbreg} = $_[1];
    }
    return $_[0]->{dbreg};
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

sub log_action {
    require GW::Action::AddLog;
    return $_[0]->{log_action} ||= GW::Action::AddLog->new_from_dbreg_and_repository_url($_[0]->dbreg, $_[0]->url);
}

sub commit_status_action {
    require GW::Action::AddCommitStatus;
    return $_[0]->{commit_status_action} ||= GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($_[0]->dbreg, $_[0]->url);
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
    return $self->{temp_repo_temp} ||= File::Temp->newdir('GW-ProcessRepository-XXXXXX', CLEANUP => !$DEBUG);
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

sub prepare_cached_repo_d_as_cv {
    my $self = shift;
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
    return $cv1;
}

sub clone_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $clone_cv = $self->git_as_cv(['clone', $self->cached_repo_d => $self->temp_repo_d->stringify], d => $self->cached_repo_d)->cb(sub {
            $self->git_as_cv(['checkout', $self->revision])->cb(sub {
                $self->git_as_cv(['remote', 'set-url', 'origin', $self->url])->cb(sub {
                    $self->git_as_cv(['submodule', 'update', '--init'])->cb(sub {
                        $cv->send;
                    });
                });
            });
        });
    });
    return $cv;
}

sub get_branches_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['show-ref', '--dereference', '--heads'],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            $cv->send(List::Ish->new([map { $_->[1] =~ s{^refs/heads/}{}; $_ } map { [split /\s+/, $_] } split /\n/, $result]));
        });
    });
    return $cv;
}

sub get_tags_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['show-ref', '--dereference', '--tags'],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            $cv->send(List::Ish->new([map { $_->[1] =~ s{^refs/tags/}{}; $_ } map { [split /\s+/, $_] } split /\n/, $result]));
        });
    });
    return $cv;
}

sub get_commit_info_as_cv {
    my ($self, $sha) = @_;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['show', '--raw', '--format=raw', $sha],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            require Git::Parser::Log;
            my $parsed = (defined $result and length $result)
                ? Git::Parser::Log->parse_format_raw(decode 'utf-8', $result)->{commits}->[0]
                : undef;
            $cv->send($parsed);
        });
    });
    return $cv;
}

sub get_commit_info_list_as_cv {
    my ($self, $sha) = @_;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['log', '--raw', '--format=raw', $sha],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            require Git::Parser::Log;
            my $parsed = (defined $result and length $result)
                ? Git::Parser::Log->parse_format_raw(decode 'utf-8', $result)->{commits}
                : undef;
            $cv->send($parsed);
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

sub run_test_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    my $d = $self->temp_repo_d;
    my $onmessage = $self->onmessage;
    my $command = "cd \Q$d\E && make test 2>&1";
    my $output = $command . "\n";
    my $start_time = time;
    run_cmd(
        $command,
        '>' => sub {
            if (defined $_[0]) {
                $output .= $_[0];
                $onmessage->($_[0]);
            }
        },
    )->cb(sub {
        my $return = $_[0]->recv;
        my $failed = $return >> 8;
        my $end_time = time;
        $output .= sprintf "Exited with status %d (%.2fs)\n",
            $return >> 8, $end_time - $start_time;
        
        my $title = 'GitWorks repository test - ' . ($failed ? 'Failed' : 'Succeeded');
        my $log_info = $self->log_action->add_log(
            branch => $self->branch,
            sha => $self->revision,
            title => $title,
            data => $output,
        );
        $self->commit_status_action->add_commit_status(
            sha => $self->revision,
            state => $failed ? COMMIT_STATUS_FAILURE : COMMIT_STATUS_SUCCESS,
            target_url => $log_info->{logs_url},
            description => $title,
        );
        $cv->send;
    });
    return $cv;
}

sub run_action_as_cv {
    my $self = shift;
    my $action = $self->{job}->{action_type};
    my $args = $self->{job}->{args};

    my $cv = AE::cv;
    if ($action eq 'repository_set.add' or
        $action eq 'repository_set.delete') {
        my $set_name = $args->{set_name};
        if (defined $set_name and length $set_name) {
            require GW::Action::EditRepositorySet;
            my $edit_action = GW::Action::EditRepositorySet->new_from_dbreg_and_set_name($self->dbreg, $set_name);
            my $method = $action =~ /delete/
                ? 'delete_repository' : 'add_repository';
            $edit_action->$method($self->url);
        } else {
            warn "|set_name| is not specified";
        }
        $cv->send;
        return $cv;
    }

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
        } elsif ($action eq 'run-test') {
            $self->run_test_as_cv->cb(sub { $cv->send });
        } else {
            warn "Action |$action| is not supported";
            $cv->send;
        }
    });
    return $cv;
}

1;

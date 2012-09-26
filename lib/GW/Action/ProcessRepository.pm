package GW::Action::ProcessRepository;
use strict;
use warnings;
use AnyEvent::Git::Repository;
push our @ISA, qw(AnyEvent::Git::Repository);
use Path::Class;
use AnyEvent;
use AnyEvent::Util;
use Encode;
use GW::Defs::Statuses;
use Time::HiRes qw(time);

sub new_from_job_and_cached_repo_set_d {
    my $self = $_[0]->new_from_url_and_cached_repo_set_d($_[1]->{repository_url}, $_[2]);
    $self->branch($_[1]->{repository_branch});
    $self->revision($_[1]->{repository_revision});
    $self->{job} = $_[1];
    return $self;
}

sub dbreg {
    if (@_ > 1) {
        $_[0]->{dbreg} = $_[1];
    }
    return $_[0]->{dbreg};
}

sub log_action {
    require GW::Action::AddLog;
    return $_[0]->{log_action} ||= GW::Action::AddLog->new_from_dbreg_and_repository_url($_[0]->dbreg, $_[0]->url);
}

sub commit_status_action {
    require GW::Action::AddCommitStatus;
    return $_[0]->{commit_status_action} ||= GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($_[0]->dbreg, $_[0]->url);
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
    my $prefix = file(__FILE__)->dir->parent->parent->parent->absolute;
    local $ENV{PATH} = join ':', grep {not /^\Q$prefix\E\// } split /:/, $ENV{PATH};
    local $ENV{PERL5LIB} = '';
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

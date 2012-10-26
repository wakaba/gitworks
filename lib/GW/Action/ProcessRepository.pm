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
use JSON::Functions::XS qw(file2perl perl2json_bytes);
use Web::UserAgent::Functions qw(http_post_data);

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
    return $_[0]->{commit_status_action} ||= do {
        my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($_[0]->dbreg, $_[0]->url);
        $action->karasuma_config($_[0]->karasuma_config);
        $action;
    };
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

sub run_system_command_as_cv {
    my ($self, $command, $label) = @_;
    my $cv = AE::cv;

    my $cv1 = AE::cv;
    {
        my $title = 'GitWorks action - ' . $label . ' - Started';
        $self->commit_status_action->add_commit_status_as_cv(
            sha => $self->revision,
            branch => $self->branch,
            state => COMMIT_STATUS_PENDING,
            description => $title,
        )->cb(sub { $cv1->send });
    }

    $cv1->cb(sub {
        my $d = $self->temp_repo_d;
        my $onmessage = $self->onmessage;
        my $output = $label . "\n" .
            '$ ' . (ref $command ? join ' ', @$command : $command) . "\n";
        my $start_time = time;
        my $prefix = file(__FILE__)->dir->parent->parent->parent->absolute;
        local $ENV{PATH} = $ENV{PMBP_ORIG_PATH} || join ':', grep {not /^\Q$prefix\E\// } split /:/, $ENV{PATH};
        local $ENV{PERL5LIB} = '';
        run_cmd(
            $command,
            '>' => sub {
                if (defined $_[0]) {
                    $output .= $_[0];
                    $onmessage->($_[0]);
                }
            },
            '2>' => sub {
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
        
            my $title = 'GitWorks action - ' . $label . ' - ' . ($failed ? 'Failed' : 'Succeeded');
            my $log_info = $self->log_action->add_log(
                branch => $self->branch,
                sha => $self->revision,
                title => $title,
                data => $output,
            );
            $self->commit_status_action->add_commit_status_as_cv(
                sha => $self->revision,
                branch => $self->branch,
                state => $failed ? COMMIT_STATUS_FAILURE : COMMIT_STATUS_SUCCESS,
                target_url => $log_info->{logs_url},
                description => $title,
            )->cb(sub { $cv->send });
        });
    });

    return $cv;
}

sub report_failure_as_cv {
    my ($self, $message, $label) = @_;
    my $cv = AE::cv;
    
    my $output = $label . "\n" . $message;
    my $title = 'GitWorks action - ' . $label . ' - Failed';
    my $log_info = $self->log_action->add_log(
        branch => $self->branch,
        sha => $self->revision,
        title => $title,
        data => $output,
    );
    $self->commit_status_action->add_commit_status_as_cv(
        sha => $self->revision,
        branch => $self->branch,
        state => COMMIT_STATUS_FAILURE,
        target_url => $log_info->{logs_url},
        description => $title,
    )->cb(sub { $cv->send });

    return $cv;
}

sub cennel_add_operations_as_cv {
    my $self = shift;
    my $cv = AE::cv;

    my $repo_d = $self->temp_repo_d;
    my $defs_d = $repo_d->subdir('config', 'cennel', 'deploy');

    if (-d $defs_d) {
        $cv->begin;
        my $this_branch = $self->branch;
        for ($defs_d->children) {
            next unless $_ =~ m{/[^/]+\.json$} and -f $_;
            $cv->begin;
            my $json = file2perl $_;
            if ($json and ref $json eq 'HASH') {
                if (defined $json->{branch} and
                    defined $this_branch and
                    $json->{branch} eq $this_branch) {
                    $self->cennel_add_operation_as_cv($json->{role}, $json->{task})->cb(sub {
                        $cv->end;
                    });
                } else {
                    $cv->end;
                }
            } else {
                $cv->end;
            }
        }
        $cv->end;
    } else {
        $cv->send;
    }

    return $cv;
}

sub karasuma_config {
    if (@_ > 1) {
        $_[0]->{karasuma_config} = $_[1];
    }
    return $_[0]->{karasuma_config};
}

sub cennel_jobs_url {
    return $_[0]->karasuma_config->get_text('gitworks.cennel.jobs_url');
}

sub cennel_api_key {
    return $_[0]->karasuma_config->get_file_base64_text('gitworks.cennel.api_key');
}

sub cennel_add_operation_as_cv {
    my ($self, $role, $task) = @_;
    my $cv = AE::cv;

    http_post_data
        url => $self->cennel_jobs_url,
        basic_auth => [api_key => $self->cennel_api_key],
        header_fields => {'Content-Type' => 'application/json'},
        content => perl2json_bytes +{
            repository => {url => $self->url},
            ref => q{refs/heads/} . $self->branch,
            after => $self->revision,
            hook_args => {
                role => $role,
                task => $task,
            },
        },
        anyevent => 1,
        cb => sub {
            $cv->send;
        };

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
            $self->run_system_command_as_cv(
                "cd @{[quotemeta $self->temp_repo_d]} && (make @{[quotemeta $args->{rule}]})",
                "make $args->{rule}",
            )->cb(sub {
                $cv->send;
            });
        } elsif ($action eq 'command') {
            my $command = $args->{command};
            my $onmessage = $self->onmessage;
            if ($command =~ /\A[0-9A-Za-z_]+\z/ and
                -f (my $command_f = $self->get_command_f($command))) {
                $self->run_system_command_as_cv(
                    "cd @{[quotemeta $self->temp_repo_d]} && sh @{[$command_f->absolute]}",
                    $command,
                )->cb(sub {
                    $cv->send;
                });
            } else {
                $self->report_failure_as_cv(
                    "Command |$command| (@{[$self->get_command_f($command)]}) is not defined",
                    $command,
                )->cb(sub {
                    $cv->send;
                });
            }
        } elsif ($action eq 'cennel.add-operations') {
            $self->cennel_add_operations_as_cv->cb(sub { $cv->send });
        } else {
            $self->report_failure_as_cv(
                "Action |$action| is not supported",
                $action,
            )->cb(sub {
                $cv->send;
            });
        }
    });
    return $cv;
}

1;

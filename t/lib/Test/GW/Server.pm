package Test::GW::Server;
use strict;
use warnings;
use Path::Class;
use AnyEvent;
use AnyEvent::Util;
use MIME::Base64 qw(encode_base64);
use Scalar::Util qw(weaken);
use File::Temp;
use Test::AnyEvent::MySQL::CreateDatabase;
use Test::AnyEvent::plackup;
use JSON::Functions::XS qw(perl2json_bytes);

sub new {
    return bless {workaholicd_boot_cv => AE::cv}, $_[0];
}

sub root_d {
    return file(__FILE__)->resolve->dir->parent->parent->parent->parent;
}

sub temp_dir {
    my $self = shift;
    return $self->{temp_dir} ||= File::Temp->newdir('Test-GW-Server-XX'.'XX'.'XX', TMPDIR => 1);
}

sub temp_d {
    my $self = shift;
    return $self->{temp_d} ||= dir($self->temp_dir->dirname);
}

# ------ Config ------

sub karasuma_config_json_f {
    my $self = shift;
    return $self->{karasuma_config_json_f} ||= $self->temp_d->file('config.json');
}

sub karasuma_config_keys_d {
    my $self = shift;
    return $self->{karasuma_config_keys_d} ||= $self->temp_d->subdir('keys');
}

our $CennelHost;
sub cennel_host {
    if (@_ > 1) {
        $_[0]->{cennel_host} = $_[1];
    }
    return $_[0]->{cennel_host} || $CennelHost || 'CENNEL';
}

our $CennelKey;
sub cennel_key {
    if (@_ > 1) {
        $_[0]->{cennel_key} = $_[1];
    }
    return $_[0]->{cennel_key} || $CennelKey || 0;
}

sub write_config {
    my $self = shift;
    my $json_f = $self->karasuma_config_json_f;
    $json_f->dir->mkpath;
    print { $json_f->openw } perl2json_bytes +{
        'gitworks.cennel.jobs_url' => q<http://>.$self->cennel_host.q</>.$self->cennel_key.q<jobs>,
        'gitworks.cennel.get_operation_list_url' => q<http://>.$self->cennel_host.q</>.$self->cennel_key.q</operation/list.json>,
        'gitworks.cennel.get_operation_log_url' => q<http://>.$self->cennel_host.q</>.$self->cennel_key.q</operation/%s.json>,
        'gitworks.cennel.api_key' => 'hoge/fuga.txt',
    };
    my $key_f = $self->karasuma_config_keys_d->file('hoge', 'fuga,txt');
    $key_f->dir->mkpath;
    print { $key_f->openw } encode_base64 $self->cennel_api_key;
}

sub cennel_api_key {
    my $self = shift;
    return $self->{cennel_api_key} ||= rand 100000;
}

# ------ MySQL server ------

sub prep_f {
    my $self = shift;
    return $self->{prep_f} ||= $self->root_d->file('db', 'preparation.txt');
}

sub mysql_server {
    my $self = shift;
    return $self->{mysql_server} ||= Test::AnyEvent::MySQL::CreateDatabase->new;
}

sub cached_repo_set_d {
    my $self = shift;
    return $self->{cached_repo_set_d} ||= $self->temp_d->subdir('repos');
}

sub dsns_json_f {
    my $self = shift;
    return $self->mysql_server->json_f;
}

sub _start_mysql_server {
    weaken(my $self = shift);
    $self->{mysql_cv} = $self->mysql_server->prep_f_to_cv($self->prep_f);
}

sub start_mysql_server_as_cv {
    weaken(my $self = shift);
    
    $self->_start_mysql_server;

    my $cv = AE::cv;
    $cv->begin(sub { $_[0]->send($self) });
    $cv->begin;
    $self->{mysql_cv}->cb(sub {
        $self->{mysql_context} = $_[0]->recv;
        $cv->end;
    });
    $cv->end;

    return $cv;
}

# ------ Web server ------

sub psgi_f {
    my $self = shift;
    return $self->{psgi_f} ||= $self->root_d->file('bin', 'server.psgi');
}

sub api_key_f {
    my $self = shift;
    return $self->{api_key_f} ||= do {
        $self->{api_key_file_temp} = File::Temp->new;
        my $f = file($self->{api_key_file_temp}->filename);
        my $fh = $f->openw;
        print $fh encode_base64 'testapikey';
        close $fh;
        $f;
    };
}

sub _start_web_server {
    my $self = shift;
    $self->write_config;

    local $ENV{GW_DSNS_JSON} = $self->dsns_json_f;
    local $ENV{GW_API_KEY_FILE_NAME} = $self->api_key_f;
    local $ENV{GW_CACHED_REPO_SET_DIR_NAME} = $self->cached_repo_set_d;
    local $ENV{KARASUMA_CONFIG_JSON} = $self->karasuma_config_json_f;
    local $ENV{KARASUMA_CONFIG_FILE_DIR_NAME} = $self->karasuma_config_keys_d;

    $self->{web_server} = my $server = Test::AnyEvent::plackup->new;
    $server->app($self->psgi_f);
    $server->server('Twiggy');

    $self->{web_start_cv} = my $cv1 = AE::cv;
    $self->{web_stop_cv} = my $cv2 = AE::cv;

    my ($start_cv, $stop_cv) = $server->start_server;
    $start_cv->cb(sub {
        my $cv = $cv1;
        undef $cv1;
        $cv->send;
    });
    $stop_cv->cb(sub {
        $cv1->send if $cv1;
        $cv2->send;
    });
}

sub start_mysql_and_web_servers_as_cv {
    weaken(my $self = shift);

    $self->_start_mysql_server;

    my $cv = AE::cv;
    $cv->begin(sub { $_[0]->send($self) });
    $cv->begin;
    $self->{mysql_cv}->cb(sub {
        $self->{mysql_context} = $_[0]->recv;
        $self->_start_web_server;
        $self->{workaholicd_boot_cv}->send;
        $self->{web_start_cv}->cb(sub {
            $cv->end;
        });
    });
    $cv->end;

    return $cv;
}

# ------ Workaholicd ------

sub workaholicd_f {
    my $self = shift;
    return $self->{workaholicd_f} ||= $self->root_d->file('bin', 'workaholicd.pl');
}

sub workaholicd_conf_f {
    my $self = shift;
    return $self->{workaholicd_conf_f} ||= $self->root_d->file('config', 'workaholicd.pl');
}

sub start_workaholicd_as_cv {
    weaken(my $self = shift);
    my $cv = AE::cv;
    $self->{workaholicd_boot_cv}->cb(sub {
        local $ENV{GW_DSNS_JSON} = $self->dsns_json_f;
        local $ENV{GW_API_KEY_FILE_NAME} = $self->api_key_f;
        local $ENV{GW_WEB_HOSTNAME} = $self->web_hostname;
        local $ENV{GW_WEB_PORT} = $self->web_port;
        
        my $pid;
        $self->{workaholicd_cv} = run_cmd
            [
                'perl',
                $self->workaholicd_f->stringify, 
                $self->workaholicd_conf_f->stringify,
            ],
            '$$' => \$pid;
        $self->{workaholicd_stop_cv} = AE::cv;
        $self->{workaholicd_cv}->cb(sub {
            if (my $return = $_[0]->recv >> 8) {
                die "Can't start workaholicd: " . $return;
            }
            $self->{workaholicd_stop_cv}->send;
        });
        $self->{workaholicd_pid} = $pid;
    });
    $cv->send;
    return $cv;
}

# ------ Contextial ------

sub web_hostname {
    return 'localhost';
}

sub web_port {
    return $_[0]->{web_server}->port;
}

sub web_host {
    return 'localhost:' . $_[0]->{web_server}->port;
}

sub context_begin {
    $_[0]->{rc}++;
    if ($_[0]->{mysql_context}) {
        $_[0]->{mysql_context}->context_begin($_[1]);
    } else {
        $_[1]->();
    }
}

sub context_end {
    my ($self, $cb) = @_;
    my $cb2 = sub {
        if ($self->{mysql_context}) {
            $self->{mysql_context}->context_end($cb);
        } else {
            $cb->();
        }
        undef $self;
    };
    if (--$self->{rc} > 0) {
        $cb2->();
    } else {
        if ($self->{workaholicd_pid}) {
            kill 15, $self->{workaholicd_pid}; # SIGTERM
        }
        if ($self->{web_stop_cv}) {
            $self->{web_stop_cv}->cb(sub {
                $cb2->();
            });
        } else {
            $cb2->();
        }
        if ($self->{workaholicd_stop_cv}) {
            $self->{workaholicd_stop_cv}->cb(sub {
                $self->{web_server}->stop_server if $self->{web_server};
            });
        } else {
            $self->{web_server}->stop_server if $self->{web_server};
        }
    }
}

sub DESTROY {
    {
        local $@;
        eval { die };
        if ($@ =~ /during global destruction/) {
            warn "Detected (possibly) memory leak";
        }
    }
    $_[0]->context_end;
}

1;

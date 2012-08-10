package Test::GW::Web;
use strict;
BEGIN {
    my $file_name = __FILE__; $file_name =~ s{[^/]+$}{}; $file_name ||= '.';
    $file_name .= '/../../../../config/perl/libs.txt';
    open my $file, '<', $file_name or die "$0: $file_name: $!";
    unshift @INC, split /:/, <$file>;
}
use warnings;
use Exporter::Lite;

our @EXPORT = qw(start_web_server);
sub start_web_server () {
    return Test::GW::Web::Server->start_server;
}

package Test::GW::Web::Server;
use Path::Class;
use AnyEvent;
use Test::AnyEvent::plackup;
use GW::MySQL;

my $root_d = file(__FILE__)->dir->parent->parent->parent->parent->parent->parent;
my $json_f = $root_d->subdir('t', 'tmp')->file('dsns.json');
my $server_psgi_f = $root_d->subdir('bin')->file('server.psgi');
GW::MySQL->load_by_f($json_f);

sub start_server {
    local $ENV{GW_DSNS_JSON} = $json_f->stringify;
    
    my $server = Test::AnyEvent::plackup->new;
    $server->plackup($ENV{PLACKUP_PATH} || 'plackup');
    $server->app($server_psgi_f);
    $server->server('Twiggy');

    my $cv1 = AE::cv;
    my $cv2 = AE::cv;
    my $self = bless {
        start_cv => $cv1,
        stop_cv => $cv1,
        server => $server,
    }, $_[0];

    my ($start_cv, $stop_cv) = $server->start_server;
    $start_cv->cb(sub {
        my $cv = $cv1;
        undef $cv1;
        $cv->send($self);
    });
    $stop_cv->cb(sub {
        $cv1->send($self) if $cv1;
        $cv2->send($self);
    });

    return $self;
}

sub start_cv {
    return $_[0]->{start_cv};
}

sub host {
    return 'localhost:' . $_[0]->{server}->port;
}

sub context_begin {
    $_[0]->{rc}++;
    $_[1]->();
}

sub context_end {
    my ($self, $cb) = @_;
    if ($self->{rc}--) {
        $cb->();
    } else {
        $self->{stop_cv}->cb(sub {
            $cb->();
        });
        $self->{server}->stop_server;
    }
}

1;

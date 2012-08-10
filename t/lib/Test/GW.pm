package Test::GW;
use strict;
BEGIN {
    my $file_name = __FILE__; $file_name =~ s{[^/]+$}{}; $file_name ||= '.';
    $file_name .= '/../../../config/perl/libs.txt';
    open my $file, '<', $file_name or die "$0: $file_name: $!";
    unshift @INC, split /:/, <$file>;
}
use warnings;
use Exporter::Lite;
use Test::GW::Server;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::UserAgent::Functions qw(http_get http_post http_post_data);
use JSON::Functions::XS qw(perl2json_bytes);

our @EXPORT = (
    @Test::More::EXPORT, @Test::Differences::EXPORT,
    @Test::X1::EXPORT,
    qw(http_get http_post http_post_data perl2json_bytes),
);

my $Servers = [];

push @EXPORT, qw(mysql_as_cv);
sub mysql_as_cv () {
    my $server = Test::GW::Server->new;
    push @$Servers, $server;
    return $server->start_mysql_server_as_cv;
}

push @EXPORT, qw(mysql_and_web_as_cv);
sub mysql_and_web_as_cv () {
    my $server = Test::GW::Server->new;
    push @$Servers, $server;
    return $server->start_mysql_and_web_servers_as_cv;
}

1;

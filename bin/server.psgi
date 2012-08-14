#!/usr/bin/perl
use strict;
BEGIN {
    my $file_name = __FILE__;
    $file_name =~ s{[^/]+$}{};
    $file_name ||= '.';
    $file_name .= '/../config/perl/libs.txt';
    open my $file, '<', $file_name or die "$0: $file_name: $!";
    unshift @INC, split /:/, scalar <$file>;
}
use warnings;
use GW::MySQL;
use GW::Web;
use Path::Class;

if ($ENV{GW_COMMAND_DIR_NAME}) {
    $GW::CommandDirD = dir($ENV{GW_COMMAND_DIR_D});
}

my $reg = GW::MySQL->load_by_env;
GW::Web->load_api_key_by_env;
return GW::Web->psgi_app($reg);

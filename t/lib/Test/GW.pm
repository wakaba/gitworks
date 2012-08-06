package Test::GW;
use strict;
BEGIN {
    my $file_name = __FILE__; $file_name =~ s{[^/]+$}{}; $file_name ||= '.';
    $file_name .= '/../../../config/perl/libs.txt';
    open my $file, '<', $file_name or die "$0: $file_name: $!";
    unshift @INC, split /:/, <$file>;
}
use warnings;
use Path::Class;
use GW::MySQL;

my $json = file(__FILE__)->dir->parent->parent->subdir('tmp')->file('dsns.json');
GW::MySQL->load_by_f($json);

1;

#!/usr/bin/perl
use strict;
use warnings;

sub git;

chdir git('rev-parse --git-dir') . '/..';

my @submodules = map [split /\s+/]->[-1], grep /^160000 /, git 'ls-files --stage';

foreach my $submodule (@submodules) {
    print "Upgrading $submodule... ";

    my $branch = git "config --file .gitmodules submodule.$submodule.track";
    chomp $branch;
    $branch ||= 'master';
    print "checkout $branch.\n";

    system "cd $submodule; git fetch origin && git checkout $branch";
    system "git add $submodule";
}

sub git {
    my $command = join ' ', 'git', @_;
    my $result = `$command`;

    return split /\n/, $result if wantarray;

    chomp $result;
    $result;
}

# Original: <https://gist.github.com/294447> by motemen.

use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use GW::Action::ProcessRepository;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'make',
        args => {
            rule => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            done $c;
        } $c;
    });
} n => 1;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    system "cd $temp_d && echo 'hoge:\n\techo 9999 > foo.txt' > Makefile && git add Makefile && git commit -m Old";

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'make',
        args => {
            rule => 'hoge',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->run_action_as_cv->cb(sub {
        test {
            is scalar $action->temp_repo_d->file('foo.txt')->slurp, "1234\n";
            done $c;
        } $c;
    });
} n => 1;

run_tests;

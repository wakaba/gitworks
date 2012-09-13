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
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $temp_d->stringify}, $cached_d);
    $action->get_branches_as_cv->cb(sub {
        my $branches = $_[0]->recv;
        test {
            eq_or_diff $branches, [[$rev, 'master']];
            done $c;
            undef $c;
        } $c;
    });
} n => 1;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && git checkout -b abc/def && touch aaa && git add aaa && git commit -m aaa";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $temp_d->stringify}, $cached_d);
    $action->get_branches_as_cv->cb(sub {
        my $branches = $_[0]->recv;
        test {
            eq_or_diff $branches, [[$rev2, 'abc/def'], [$rev, 'master']];
            done $c;
            undef $c;
        } $c;
    });
} n => 1;

run_tests;

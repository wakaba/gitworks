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
            eq_or_diff $branches->to_a, [[$rev, 'master']];
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
            eq_or_diff $branches->to_a, [[$rev2, 'abc/def'], [$rev, 'master']];
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

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $temp_d->stringify}, $cached_d);
    $action->get_tags_as_cv->cb(sub {
        my $branches = $_[0]->recv;
        test {
            eq_or_diff $branches->to_a, [];
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => "n otags";

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && touch aaa && git add aaa && git commit -m aaa && git tag abc/de";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $temp_d->stringify}, $cached_d);
    $action->get_tags_as_cv->cb(sub {
        my $branches = $_[0]->recv;
        test {
            eq_or_diff $branches->to_a, [[$rev2, 'abc/de']];
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => 'has tag';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && touch aaa && git add aaa && git commit -m aaa && git tag abc/de";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $temp_d->stringify}, $cached_d);
    $action->get_commit_info_as_cv($rev)->cb(sub {
        my $parsed = $_[0]->recv;
        test {
            ok $parsed->{author}->{name};
            ok $parsed->{author}->{mail};
            is $parsed->{body}, 'New';
            is $parsed->{commit}, $rev;
            ok $parsed->{committer}->{name};
            ok $parsed->{committer}->{time};
            ok $parsed->{files}->{Makefile};
            ok $parsed->{tree};
            done $c;
            undef $c;
        } $c;
    });
} n => 8, name => 'commit info';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && touch aaa && git add aaa && git commit -m aaa && git tag abc/de";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({repository_url => $temp_d->stringify}, $cached_d);
    $action->get_commit_info_as_cv(rand)->cb(sub {
        my $parsed = $_[0]->recv;
        test {
            is $parsed, undef;
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => 'commit info - commit not found';

run_tests;

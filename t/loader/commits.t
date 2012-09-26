use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use GW::Loader::Commits;
use GW::Action::ProcessRepository;

test {
    my $c = shift;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => q<http://foo.example/bar>,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_as_github_jsonable_as_cv('agfeawtagfagfaee')->cb(sub {
        my $json = $_[0]->recv;
        test {
            is $json, undef;
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => 'repo not found';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && echo \"echo 5566 > foo.txt\" > hoge.sh && git add hoge.sh && git commit -m rev2";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_as_github_jsonable_as_cv($rev2.$rev)->cb(sub {
        my $json = $_[0]->recv;
        test {
            is $json, undef;
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => 'rev not found';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && echo \"echo 5566 > foo.txt\" > hoge.sh && git add hoge.sh && git commit -m rev2";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_as_github_jsonable_as_cv($rev2)->cb(sub {
        my $json = $_[0]->recv;
        test {
            is $json->{sha}, $rev2;
            ok $json->{author}->{name};
            ok $json->{author}->{email};
            ok $json->{author}->{date} =~ /T/;
            ok $json->{committer}->{name};
            ok $json->{committer}->{email};
            ok $json->{committer}->{date} =~ /T/;
            is $json->{message}, 'rev2';
            eq_or_diff $json->{parents}, [{sha => $rev}];
            ok $json->{tree}->{sha};
            isnt $json->{tree}->{sha}, $rev2;
            done $c;
            undef $c;
        } $c;
    });
} n => 11;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && echo \"echo 5566 > foo.txt\" > hoge.sh && git add hoge.sh && git commit -m rev2";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    system "cd $temp_d && git checkout $rev && echo aaa > abc && git add abc && git commit -m abc";
    my $rev3 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev3;

    system "cd $temp_d && git merge $rev2";
    my $rev4 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev4;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_as_github_jsonable_as_cv($rev4)->cb(sub {
        my $json = $_[0]->recv;
        test {
            is $json->{sha}, $rev4;
            ok $json->{author}->{name};
            ok $json->{author}->{email};
            ok $json->{author}->{date} =~ /T/;
            ok $json->{committer}->{name};
            ok $json->{committer}->{email};
            ok $json->{committer}->{date} =~ /T/;
            ok $json->{message};
            eq_or_diff $json->{parents}, [{sha => $rev3}, {sha => $rev2}];
            ok $json->{tree}->{sha};
            done $c;
            undef $c;
        } $c;
    });
} n => 10, name => 'merge';

test {
    my $c = shift;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => q<http://foo.example/bar>,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_list_as_github_jsonable_as_cv('agfeawtagfagfaee')->cb(sub {
        my $json = $_[0]->recv;
        test {
            is $json, undef;
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => 'list, repo not found';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && echo \"echo 5566 > foo.txt\" > hoge.sh && git add hoge.sh && git commit -m rev2";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_list_as_github_jsonable_as_cv($rev2.$rev)->cb(sub {
        my $json = $_[0]->recv;
        test {
            is $json, undef;
            done $c;
            undef $c;
        } $c;
    });
} n => 1, name => 'list, rev not found';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && echo \"echo 5566 > foo.txt\" > hoge.sh && git add hoge.sh && git commit -m rev2";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_list_as_github_jsonable_as_cv($rev2)->cb(sub {
        my $json = $_[0]->recv;
        test {
            is scalar @$json, 2;
            is $json->[0]->{sha}, $rev2;
            ok $json->[0]->{author}->{name};
            ok $json->[0]->{author}->{email};
            ok $json->[0]->{author}->{date} =~ /T/;
            ok $json->[0]->{committer}->{name};
            ok $json->[0]->{committer}->{email};
            ok $json->[0]->{committer}->{date} =~ /T/;
            is $json->[0]->{message}, 'rev2';
            eq_or_diff $json->[0]->{parents}, [{sha => $rev}];
            ok $json->[0]->{tree}->{sha};
            isnt $json->[0]->{tree}->{sha}, $rev2;
            is $json->[1]->{sha}, $rev;
            ok $json->[1]->{author}->{name};
            ok $json->[1]->{author}->{email};
            ok $json->[1]->{author}->{date} =~ /T/;
            ok $json->[1]->{committer}->{name};
            ok $json->[1]->{committer}->{email};
            ok $json->[1]->{committer}->{date} =~ /T/;
            is $json->[1]->{message}, 'New';
            eq_or_diff $json->[1]->{parents}, [];
            ok $json->[1]->{tree}->{sha};
            isnt $json->[1]->{tree}->{sha}, $rev;
            done $c;
            undef $c;
        } $c;
    });
} n => 23, name => ['list', 'normal'];

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    system "cd $temp_d && echo \"echo 5566 > foo.txt\" > hoge.sh && git add hoge.sh && git commit -m rev2";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev2;

    system "cd $temp_d && git checkout $rev && echo aaa > abc && git add abc && git commit -m abc";
    my $rev3 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev3;

    system "cd $temp_d && git merge $rev2";
    my $rev4 = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev4;

    my $cached_d = dir(tempdir(CLEANUP => 1));
    
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d,
    }, $cached_d);
    my $loader = GW::Loader::Commits->new_from_process_repository_action($action);

    $loader->get_commit_list_as_github_jsonable_as_cv($rev4)->cb(sub {
        my $json = $_[0]->recv;
        test {
            is scalar @$json, 4;
            is $json->[0]->{sha}, $rev4;
            ok $json->[0]->{author}->{name};
            ok $json->[0]->{author}->{email};
            ok $json->[0]->{author}->{date} =~ /T/;
            ok $json->[0]->{committer}->{name};
            ok $json->[0]->{committer}->{email};
            ok $json->[0]->{committer}->{date} =~ /T/;
            ok $json->[0]->{message};
            eq_or_diff $json->[0]->{parents}, [{sha => $rev3}, {sha => $rev2}];
            ok $json->[0]->{tree}->{sha};
            done $c;
            undef $c;
        } $c;
    });
} n => 11, name => 'list, merge';

run_tests;

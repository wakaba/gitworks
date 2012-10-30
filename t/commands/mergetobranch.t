use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use GW::MySQL;
use Karasuma::Config::JSON;
use GW::Action::ProcessRepository;
use Test::Git::EditRepository;

my $commands_d = file(__FILE__)->dir->parent->parent->subdir('config', 'commands');
my $DEBUG = 0;

my $cached_d = dir(tempdir(CLEANUP => !$DEBUG));
my $mysql_cv;
my $mysql = sub {
    return $mysql_cv ||= mysql_as_cv;
};

sub run_command (&$$) {
    my ($code, $c, $job) = @_;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d($job, $cached_d);
    $action->command_dir_d($commands_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->onmessage(sub {
        note $_[0] if defined $_[0];
    });
    $action->run_action_as_cv->cb(sub {
        my $return = $_[0]->recv;
        test {
            $code->($return);
        } $c;
    });
}

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    git_checkout $repo_d, $rev0;
    create_git_files $repo_d,
        {name => 'branch2.txt'};
    git_commit $repo_d;
    my $rev2 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b devel 2> /dev/null";

    run_command (sub {
        my $return = $_[0];
        ok $return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        isnt $rev_main, $rev1;
        isnt $rev_main, $rev2;
        my $rev_main_prev = `cd $repo_d && git rev-parse main^`;
        chomp $rev_main_prev;
        is $rev_main_prev, $rev1;
        my $rev_devel = `cd $repo_d && git rev-parse devel`;
        chomp $rev_devel;
        is $rev_devel, $rev2;

        git_checkout $repo_d, $rev_main;
        ok -f $repo_d->file('branch1.txt');
        ok -f $repo_d->file('branch2.txt');

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev2,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 7, name => 'merged', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    my $rev2 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b devel 2> /dev/null";

    run_command (sub {
        my $return = $_[0];
        ok $return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev1;
        is $rev_main, $rev2;
        my $rev_devel = `cd $repo_d && git rev-parse devel`;
        chomp $rev_devel;
        is $rev_devel, $rev2;

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev2,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 4, name => 'same rev', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b devel 2> /dev/null";

    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";
    create_git_files $repo_d,
        {name => 'branch2.txt'};
    git_commit $repo_d;
    my $rev2 = get_git_revision $repo_d;

    run_command (sub {
        my $return = $_[0];
        ok $return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev2;
        my $rev_devel = `cd $repo_d && git rev-parse devel`;
        chomp $rev_devel;
        is $rev_devel, $rev1;

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev1,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 3, name => 'older', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    system "cd \Q$repo_d\E && git checkout -b devel 2> /dev/null";
    create_git_files $repo_d,
        {name => 'branch2.txt'};
    git_commit $repo_d;
    my $rev2 = get_git_revision $repo_d;

    run_command (sub {
        my $return = $_[0];
        ok $return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev2;
        my $rev_devel = `cd $repo_d && git rev-parse devel`;
        chomp $rev_devel;
        is $rev_devel, $rev2;

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev2,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 3, name => 'newer', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch.txt', data => 'branch1'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    git_checkout $repo_d, $rev0;
    create_git_files $repo_d,
        {name => 'branch.txt', data => 'branch2'};
    git_commit $repo_d;
    my $rev2 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b devel 2> /dev/null";

    run_command (sub {
        my $return = $_[0];
        ok !$return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev1;
        my $rev_devel = `cd $repo_d && git rev-parse devel`;
        chomp $rev_devel;
        is $rev_devel, $rev2;

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev2,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 3, name => 'conflict', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch2.txt'};
    git_commit $repo_d;
    my $rev2 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    run_command (sub {
        my $return = $_[0];
        ok !$return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev2;

        git_checkout $repo_d, $rev_main;
        ok -f $repo_d->file('branch1.txt');
        ok -f $repo_d->file('branch2.txt');

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'main',
        repository_revision => $rev1,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 4, name => 'same branch name', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    run_command (sub {
        my $return = $_[0];
        ok !$return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev1;
        my $rev_devel = `cd $repo_d && git rev-parse hoge`;
        chomp $rev_devel;
        is $rev_devel, 'hoge';

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'main',
        repository_revision => $rev1,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['hoge'],
        },
    });
} n => 3, name => 'no branch', wait => $mysql;

test {
    my $c = shift;

    my $repo_d = create_git_repository;
    create_git_files $repo_d,
        {name => 'foo.txt'};
    git_commit $repo_d;
    my $rev0 = get_git_revision $repo_d;

    create_git_files $repo_d,
        {name => 'branch1.txt'};
    git_commit $repo_d;
    my $rev1 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    git_checkout $repo_d, $rev0;
    create_git_files $repo_d,
        {name => 'branch2.txt'};
    git_commit $repo_d;
    my $rev2 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b devel 2> /dev/null";

    git_checkout $repo_d, 'main';
    create_git_files $repo_d,
        {name => 'branch1.txt', data => 'hoge'};
    git_commit $repo_d;
    my $rev3 = get_git_revision $repo_d;
    system "cd \Q$repo_d\E && git checkout -b main 2> /dev/null";

    run_command (sub {
        my $return = $_[0];
        ok !$return;

        my $rev_main = `cd $repo_d && git rev-parse main`;
        chomp $rev_main;
        is $rev_main, $rev3;
        my $rev_devel = `cd $repo_d && git rev-parse devel`;
        chomp $rev_devel;
        is $rev_devel, $rev2;

        done $c;
        undef $c;
    }, $c, {
        repository_url => $repo_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev2,
        action_type => 'command',
        args => {
            command => 'mergetobranch',
            command_args => ['main'],
        },
    });
} n => 3, name => 'merged but not pushable', wait => $mysql;

run_tests;

1;

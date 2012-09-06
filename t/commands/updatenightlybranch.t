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

my $commands_d = file(__FILE__)->dir->parent->parent->subdir('config', 'commands');
my $DEBUG = 0;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse HEAD`, $rev;
            is `cd $temp_d && git rev-parse nightly`, $rev;
            done $c;
            undef $c;
        } $c;
    });
} n => 2, name => 'noop';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    my $temp3_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp3_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    system "cd $temp_d && git submodule add $temp3_d temp3 && git commit -m submodule && git push";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse HEAD`, $rev;
            is `cd $temp_d && git rev-parse nightly`, $rev;
            done $c;
            undef $c;
        } $c;
    });
} n => 2, name => 'submodule noop';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    my $temp3_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp3_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev3 = `cd $temp3_d && git rev-parse HEAD`;

    system "cd $temp_d && git submodule add $temp3_d temp3 && git commit -m submodule";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp3_d && echo 124 > bar.txt && git add bar.txt && git commit -m bar.txt";

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse master`, $rev;
            isnt `cd $temp_d && git rev-parse nightly`, $rev;
            system "cd $temp_d && git checkout nightly && git submodule update --init";
            isnt `cd $temp_d/temp3 && git rev-parse HEAD`, $rev3;
            ok -f "$temp_d/temp3/bar.txt";
            done $c;
            undef $c;
        } $c;
    });
} n => 4, name => 'submodule updated';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse master`, $rev;
            is `cd $temp_d && git rev-parse nightly`, $rev;
            ok !-f "$temp_d/foo.txt";
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'make no change';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly:\n\techo 1234 > foo.txt\n\tgit add foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse master`, $rev;
            isnt `cd $temp_d && git rev-parse nightly`, $rev;
            system "cd $temp_d && git checkout nightly";
            ok -f "$temp_d/foo.txt";
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'make changed';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly:\n\techo 1234 > foo.txt\n\tgit add foo.txt\n\tfalse\n > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse master`, $rev;
            is `cd $temp_d && git rev-parse nightly`, $rev;
            system "cd $temp_d && git checkout nightly";
            ok !-f "$temp_d/foo.txt";
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'make died';

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly\n\techo 1234 > foo.txt\n\tgit add foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    my $temp2_d = dir(tempdir(CLEANUP => !$DEBUG));

    my $job = {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
    my $action = GW::Action::ProcessRepository->new_from_job($job);
    $action->command_dir_d($commands_d);
    $action->run_action_as_cv->cb(sub {
        test {
            is `cd $temp_d && git rev-parse master`, $rev;
            is `cd $temp_d && git rev-parse nightly`, $rev;
            system "cd $temp_d && git checkout nightly";
            ok !-f "$temp_d/foo.txt";
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'make broken Makefile';

run_tests;

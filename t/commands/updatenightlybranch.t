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

    my $temp0_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp0_d && git init --bare";

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && touch abc && git add abc && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp_d && echo 1234 > abc && git add abc && git commit -m abc=1234";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp_d && git checkout @{[substr $rev, 0, 10]} && git checkout -b nightly && echo xyzw > xyz && git add xyz && git commit -m abc=xyzw";
    my $rev3 = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp_d && git remote add origin $temp0_d";
    system "cd $temp_d && git checkout master && git push origin master";
    system "cd $temp_d && git checkout nightly && git push origin nightly";

    my $job = {
        repository_url => $temp0_d->stringify,
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
            isnt `cd $temp0_d && git rev-parse nightly`, $rev2;
            isnt `cd $temp0_d && git rev-parse nightly`, $rev3;
            system "cd $temp_d && git checkout nightly && git pull origin nightly";
            is scalar $temp_d->file('abc')->slurp, "1234\n";
            is scalar $temp_d->file('xyz')->slurp, "xyzw\n";
            done $c;
            undef $c;
        } $c;
    });
} n => 4, name => 'nightly branch found';

test {
    my $c = shift;

    my $temp0_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp0_d && git init --bare";

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && touch abc && git add abc && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp_d && echo 1234 > abc && git add abc && git commit -m abc=1234";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp_d && git checkout @{[substr $rev, 0, 10]} && git checkout -b nightly && echo xyzw > abc && git add abc && git commit -m abc=xyzw";
    my $rev3 = `cd $temp_d && git rev-parse HEAD`;

    system "cd $temp_d && git remote add origin $temp0_d";
    system "cd $temp_d && git checkout master && git push origin master";
    system "cd $temp_d && git checkout nightly && git push origin nightly";

    my $job = {
        repository_url => $temp0_d->stringify,
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
            isnt `cd $temp0_d && git rev-parse nightly`, $rev2;
            isnt `cd $temp0_d && git rev-parse nightly`, $rev3;
            system "cd $temp_d && git checkout nightly && git pull origin nightly";
            is scalar $temp_d->file('abc')->slurp, "1234\n";
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'conflict';

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

    # temp_d-m temp_d-n  temp3_d-m
    # o
    # o                  o
    #          $rev2     $rev4
    # $rev                         $rev3
    #                    $rev5
    # --------------------------------
    #          o         =rev5

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    my $temp3_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp3_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    system "cd $temp_d && git submodule add $temp3_d temp3 && git commit -m submodule";

    system "cd $temp3_d && echo 333 > hoge.txt && git add hoge.txt && git commit -m hoge.txt";
    my $rev4 = `cd $temp3_d && git rev-parse HEAD`;

    system "cd $temp_d && git checkout -b nightly && cd $temp_d/temp3 && git pull && cd $temp_d && git add temp3 && git commit -m submodule";
    my $rev2 = `cd $temp_d && git rev-parse HEAD`;
    system "cd $temp_d && git checkout master";

    system "cd $temp3_d && echo 124 > bar.txt && git add bar.txt && git commit -m bar.txt";
    my $rev5 = `cd $temp3_d && git rev-parse HEAD`;

    system "cd $temp3_d && git checkout @{[substr $rev4, 0, 10]} && echo aaa > aaa.txt && git add aaa.txt && git commit -m aaa.txt";
    system "cd $temp_d/temp3 && git pull && cd $temp_d && git add temp3 && git commit -m submodule";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    my $rev3 = `cd $temp_d/temp3 && git rev-parse HEAD`;

#die $temp_d;

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
            system "cd $temp_d && git checkout master && git submodule update --init";
            is `cd $temp_d && git rev-parse master`, $rev;
            is `cd $temp_d/temp3 && git rev-parse HEAD`, $rev3;
            system "cd $temp_d && git checkout nightly && git submodule update --init";
            isnt `cd $temp_d && git rev-parse nightly`, $rev;
            isnt `cd $temp_d && git rev-parse nightly`, $rev2;
            is `cd $temp_d/temp3 && git rev-parse HEAD`, $rev5;
            done $c;
            undef $c;
        } $c;
    });
} n => 5, name => 'submodule conflict';

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

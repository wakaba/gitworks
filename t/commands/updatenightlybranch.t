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
    $action->run_action_as_cv->cb(sub {
        test {
            $code->();
        } $c;
    });
}

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    run_command (sub {
        is `cd $temp_d && git rev-parse HEAD`, $rev;
        is `cd $temp_d && git rev-parse nightly`, $rev;
        done $c;
        undef $c;
    }, $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    });
} n => 2, name => 'noop', wait => $mysql;

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

    run_command {
        isnt `cd $temp0_d && git rev-parse nightly`, $rev2;
        isnt `cd $temp0_d && git rev-parse nightly`, $rev3;
        system "cd $temp_d && git checkout nightly && git pull origin nightly";
        is scalar $temp_d->file('abc')->slurp, "1234\n";
        is scalar $temp_d->file('xyz')->slurp, "xyzw\n";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp0_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 4, name => 'nightly branch found', wait => $mysql;

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

    run_command {
        isnt `cd $temp0_d && git rev-parse nightly`, $rev2;
        isnt `cd $temp0_d && git rev-parse nightly`, $rev3;
        system "cd $temp_d && git checkout nightly && git pull origin nightly";
        is scalar $temp_d->file('abc')->slurp, "1234\n";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp0_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 3, name => 'conflict', wait => $mysql;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    my $temp3_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp3_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";

    system "cd $temp_d && git submodule add $temp3_d temp3 && git commit -m submodule && git push";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    run_command {
        is `cd $temp_d && git rev-parse HEAD`, $rev;
        is `cd $temp_d && git rev-parse nightly`, $rev;
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 2, name => 'submodule noop', wait => $mysql;

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

    run_command {
        is `cd $temp_d && git rev-parse master`, $rev;
        isnt `cd $temp_d && git rev-parse nightly`, $rev;
        system "cd $temp_d && git checkout nightly && git submodule update --init";
        isnt `cd $temp_d/temp3 && git rev-parse HEAD`, $rev3;
        ok -f "$temp_d/temp3/bar.txt";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 4, name => 'submodule updated', wait => $mysql;

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

    run_command {
        system "cd $temp_d && git checkout master && git submodule update --init";
        is `cd $temp_d && git rev-parse master`, $rev;
        is `cd $temp_d/temp3 && git rev-parse HEAD`, $rev3;
        system "cd $temp_d && git checkout nightly && git submodule update --init";
        isnt `cd $temp_d && git rev-parse nightly`, $rev;
        isnt `cd $temp_d && git rev-parse nightly`, $rev2;
        is `cd $temp_d/temp3 && git rev-parse HEAD`, $rev5;
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 5, name => 'submodule conflict', wait => $mysql;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    run_command {
        is `cd $temp_d && git rev-parse master`, $rev;
        is `cd $temp_d && git rev-parse nightly`, $rev;
        ok !-f "$temp_d/foo.txt";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 3, name => 'make no change', wait => $mysql;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly:\n\techo 1234 > foo.txt\n\tgit add foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    run_command {
        is `cd $temp_d && git rev-parse master`, $rev;
        isnt `cd $temp_d && git rev-parse nightly`, $rev;
        system "cd $temp_d && git checkout nightly";
        ok -f "$temp_d/foo.txt";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 3, name => 'make changed', wait => $mysql;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly:\n\techo 1234 > foo.txt\n\tgit add foo.txt\n\tfalse\n' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    run_command {
        is `cd $temp_d && git rev-parse master`, $rev;
        is `cd $temp_d && git rev-parse nightly`, $rev;
        system "cd $temp_d && git checkout nightly";
        ok !-f "$temp_d/foo.txt";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 3, name => 'make died', wait => $mysql;

test {
    my $c = shift;

    my $temp_d = dir(tempdir(CLEANUP => !$DEBUG));
    system "cd $temp_d && git init && echo 'autoupdatenightly\n\techo 1234 > foo.txt\n\tgit add foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;

    run_command {
        is `cd $temp_d && git rev-parse master`, $rev;
        is `cd $temp_d && git rev-parse nightly`, $rev;
        system "cd $temp_d && git checkout nightly";
        ok !-f "$temp_d/foo.txt";
        done $c;
        undef $c;
    } $c, {
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'command',
        args => {
            command => 'updatenightlybranch',
        },
    };
} n => 3, name => 'make broken Makefile', wait => $mysql;

run_tests;

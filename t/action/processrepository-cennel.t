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
use GW::Action::ProcessRepository;
use Test::GW::CennelServer;
use Karasuma::Config::JSON;

Test::GW::CennelServer->start_server_as_cv->recv;

my $mysql = mysql_as_cv;
my $cennel_host = Test::GW::CennelServer->server_host;

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 1000000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system "cd $temp_d && git init && echo 'hoge:\n\techo 1234 > foo.txt' > Makefile && git add Makefile && git commit -m New";
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, [];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'empty';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 100000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system qq{cd $temp_d && git init && mkdir -p config/cennel/deploy && echo '{"branch":"master","role":"hoge 1","task":"task 1"}' > config/cennel/deploy/role1.json && git add config && git commit -m New};
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, [
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/master',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge 1',
                                    task => 'task 1',
                                },
                            },
                        ];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'has an item';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 100000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system qq{cd $temp_d && git init && mkdir -p config/cennel/deploy && echo '{"branch":"master","role":"hoge 1","task":"task 1"}' > config/cennel/deploy/role1.json && echo '{"branch":"devel","role":"hoge2","task":"task 2"}' > config/cennel/deploy/role2.json && git add config && git commit -m New};
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, [
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/master',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge 1',
                                    task => 'task 1',
                                },
                            },
                        ];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'branch filtered';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 100000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system qq{cd $temp_d && git init && mkdir -p config/cennel/deploy && echo '{"branch":"master","role":"hoge 1","task":"task 1"}' > config/cennel/deploy/role1.json && echo '{"branch":"devel","role":"hoge2","task":"task 2"}' > config/cennel/deploy/role2.json && git add config && git commit -m New && git checkout devel};
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, [
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/devel',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge2',
                                    task => 'task 2',
                                },
                            },
                        ];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'branch filtered non master';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 100000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system qq{cd $temp_d && git init && mkdir -p config/cennel && echo '[{"branch":"master","role":"hoge 1","task":"task 1"},{"branch":"devel","role":"hoge2","task":"task 2"}]' > config/cennel/deployrole2.json && git add config && git commit -m New && git checkout devel};
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'devel',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
        args => {operation_set_name => 'deployrole2'},
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, [
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/devel',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge2',
                                    task => 'task 2',
                                },
                            },
                        ];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'branch filtered non master - single json';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 100000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system qq{cd $temp_d && git init && mkdir -p config/cennel/deploy && echo '{"branch":"master","role":"hoge 1","task":"task 1"}' > config/cennel/deploy/role1.json && echo '{"branch":"master","role":"hoge2","task":"task 2"}' > config/cennel/deploy/role2.json && git add config && git commit -m New};
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff [sort { $a->{hook_args}->{task} cmp $b->{hook_args}->{task} } @$json], [sort { $a->{hook_args}->{task} cmp $b->{hook_args}->{task} } 
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/master',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge 1',
                                    task => 'task 1',
                                },
                            },
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/master',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge2',
                                    task => 'task 2',
                                },
                            },
                        ];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'multiple';

test {
    my $c = shift;
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $key = int rand 100000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.api_key' => undef,
    });

    my $temp_d = dir(tempdir(CLEANUP => 1));
    system qq{cd $temp_d && git init && mkdir -p config/cennel && echo '[{"branch":"master","role":"hoge 1","task":"task 1"},{"branch":"master","role":"hoge2","task":"task 2"}]' > config/cennel/ho-ge.json && git add config && git commit -m New};
    my $rev = `cd $temp_d && git rev-parse HEAD`;
    chomp $rev;

    my $cached_d = dir(tempdir(CLEANUP => 1));

    my $action = GW::Action::ProcessRepository->new_from_job_and_cached_repo_set_d({
        repository_url => $temp_d->stringify,
        repository_branch => 'master',
        repository_revision => $rev,
        action_type => 'cennel.add-operations',
        args => {operation_set_name => 'ho-ge'},
    }, $cached_d);
    $action->dbreg($dbreg);
    $action->karasuma_config($config);
    $action->run_action_as_cv->cb(sub {
        test {
            http_get
                url => qq<http://$cennel_host/$key/devel/jobs>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff [sort { $a->{hook_args}->{task} cmp $b->{hook_args}->{task} } @$json], [sort { $a->{hook_args}->{task} cmp $b->{hook_args}->{task} } 
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/master',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge 1',
                                    task => 'task 1',
                                },
                            },
                            {
                                repository => {url => $temp_d->stringify},
                                ref => 'refs/heads/master',
                                after => $rev,
                                hook_args => {
                                    role => 'hoge2',
                                    task => 'task 2',
                                },
                            },
                        ];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 1, wait => $mysql, name => 'multiple, one-file format';

run_tests;
Test::GW::CennelServer->stop_server_as_cv->recv;

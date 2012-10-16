use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use GW::Action::AddCommitStatus;
use GW::Loader::CommitStatuses;
use GW::MySQL;
use Karasuma::Config::JSON;
use Test::GW::GHHServer;

Test::GW::GHHServer->start_server_as_cv->recv;

my $mysql_cv = mysql_as_cv;
my $ghh_host = Test::GW::GHHServer->server_host;

test {
    my $c = shift;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => q<http://GHH/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($dbreg, $url);
    $action->karasuma_config($config);
    
    my $sha = q<heaewegaegeeefwagfeeeagaggag4rrrrrr>;
    $action->add_commit_status_as_cv(
        sha => $sha,
        state => 4,
        target_url => q<hhtrpfeaege>,
        description => qq<afee\x{4e00}agageee xya>,
    )->cb(sub {
        test {
            delete $dbreg->{Instances};
            
            my $loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $url);
            my $list = $loader->get_commit_statuses($sha);

            is $list->length, 1;
            ok $list->[0]->{id};
            delete $list->[0]->{id};
            ok $list->[0]->{created};
            delete $list->[0]->{created};
            delete $list->[0]->{repository_id};
            eq_or_diff $list->[0], {
                sha => $sha,
                state => 4,
                target_url => q<hhtrpfeaege>,
                description => qq<afee\x{4e00}agageee xya>,
            };

            my $timer; $timer = AE::timer 1, 0, sub {
                test {
                    undef $timer;
                    $action->add_commit_status_as_cv(
                        sha => $sha,
                        state => 1,
                        target_url => undef,
                        description => undef,
                    )->cb(sub {
                        test {
                            my $list = $loader->get_commit_statuses($sha);
                            
                            is $list->length, 2;
                            delete $list->[0]->{id};
                            delete $list->[0]->{created};
                            delete $list->[0]->{repository_id};
                            delete $list->[1]->{id};
                            delete $list->[1]->{created};
                            delete $list->[1]->{repository_id};
                            eq_or_diff $list->[1], {
                                sha => $sha,
                                state => 4,
                                target_url => q<hhtrpfeaege>,
                                description => qq<afee\x{4e00}agageee xya>,
                            };
                            eq_or_diff $list->[0], {
                                sha => $sha,
                                state => 1,
                                target_url => undef,
                                description => undef,
                            };
                            
                            $c->done;
                            undef $c;
                        } $c;
                    });
                } $c;
            };
        } $c;
    });
} n => 7, wait => $mysql_cv;

test {
    my $c = shift;

    my $key = int rand 100000;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => qq<http://$ghh_host/$key/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($dbreg, $url);
    $action->karasuma_config($config);
    
    my $sha = q<heaewegaegeeefwagfeeeagaggag4rrrrrr>;
    $action->add_commit_status_as_cv(
        sha => $sha,
        state => 4,
        target_url => q<hhtrpfeaege>,
        description => qq<afee\x{4e00}agageee xya>,
    )->cb(sub {
        test {
            http_get
                url => qq<http://$ghh_host/$key/devel/hook>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        ok $json->[0]->{hook_args}->{created};
                        delete $json->[0]->{hook_args}->{created};
                        eq_or_diff $json, [{
                            repository => {url => $url},
                            ref => undef,
                            after => $sha,
                            hook_event => q<addcommitstatus>,
                            hook_args => {
                                state => 'failure',
                                target_url => q<hhtrpfeaege>,
                                description => qq<afee\x{4e00}agageee xya>,
                            },
                        }];

                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 2, wait => $mysql_cv, name => 'hook';

test {
    my $c = shift;

    my $key = int rand 100000;
    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.githookhub.hook_url' => qq<http://$ghh_host/$key/hook>,
    });
    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);

    my $url = q<git://hoge/fuga> . rand;
    my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($dbreg, $url);
    $action->karasuma_config($config);
    
    my $sha = q<heaewegaegeeefwagfeeeagaggag4rrrrrr>;
    $action->add_commit_status_as_cv(
        sha => $sha,
        branch => q<devel1>,
        state => 4,
        target_url => q<hhtrpfeaege>,
        description => qq<afee\x{4e00}agageee xya>,
    )->cb(sub {
        test {
            http_get
                url => qq<http://$ghh_host/$key/devel/hook>,
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        ok $json->[0]->{hook_args}->{created};
                        delete $json->[0]->{hook_args}->{created};
                        eq_or_diff $json, [{
                            repository => {url => $url},
                            ref => 'refs/heads/devel1',
                            after => $sha,
                            hook_event => q<addcommitstatus>,
                            hook_args => {
                                state => 'failure',
                                target_url => q<hhtrpfeaege>,
                                description => qq<afee\x{4e00}agageee xya>,
                            },
                        }];

                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 2, wait => $mysql_cv, name => 'hook branched';

run_tests;
Test::GW::GHHServer->stop_server_as_cv->recv;

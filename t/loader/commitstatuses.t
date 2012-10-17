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

my $mysql_cv = mysql_as_cv;

test {
    my $c = shift;

    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $url = q<git://hoge/fuga> . rand;

    my $loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $url);
    eq_or_diff $loader->get_commit_statuses('aageeee')->to_a, [];

    my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($dbreg, $url);
    $action->karasuma_config(Karasuma::Config::JSON->new_from_config_data({}));
    
    my $sha = q<heaewegaegeeefwagfeeeagaggag4rrrrrr>;
    $action->add_commit_status_as_cv(
        sha => $sha,
        state => 4,
        target_url => q<hhtrpfeaege>,
        description => qq<afee\x{4e00}agageee xya>,
    )->cb(sub {
        test {
            delete $loader->dbreg->{Instances};

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
} n => 8, wait => $mysql_cv, name => 'single';

test {
    my $c = shift;

    my $dbreg = GW::MySQL->load_by_f($c->received_data->dsns_json_f);
    my $url = q<git://hoge/fuga> . rand;

    my $loader = GW::Loader::CommitStatuses->new_from_dbreg_and_repository_url($dbreg, $url);

    my $action = GW::Action::AddCommitStatus->new_from_dbreg_and_repository_url($dbreg, $url);
    $action->karasuma_config(Karasuma::Config::JSON->new_from_config_data({}));
    
    my $sha = q<heaewegaegeeefwagfeeeagaggag4rrrrrr>;
    my $sha2 = q<heaewegaegeeefwagfeee4aggag4rr452r>;

    eq_or_diff $loader->get_commit_statuses_list([$sha, $sha2]), {};

    my $cv1 = AE::cv;
    $cv1->begin;
    $cv1->begin;
    $action->add_commit_status_as_cv(
        sha => $sha,
        state => 4,
        target_url => q<hhtrpfeaege>,
        description => qq<afee\x{4e00}agageee xya>,
    )->cb(sub { $cv1->end });
    $cv1->begin;
    $action->add_commit_status_as_cv(
        sha => $sha2,
        state => 3,
        target_url => q<hhtrpfeaege12>,
        description => qq<afee\x{4e00}agageee>,
    )->cb(sub { $cv1->end });
    $cv1->end;

    $cv1->cb(sub {
        test {
            delete $dbreg->{Instances};

            my $result = $loader->get_commit_statuses_list([$sha, $sha2]);
            eq_or_diff {map { $_ => 1 } keys %$result}, {$sha => 1, $sha2 => 1};
            
            is $result->{$sha}->length, 1;
            is $result->{$sha2}->length, 1;
            
            delete $result->{$sha}->[0]->{id};
            delete $result->{$sha}->[0]->{created};
            delete $result->{$sha}->[0]->{repository_id};
            eq_or_diff $result->{$sha}->[0], {
                sha => $sha,
                state => 4,
                target_url => q<hhtrpfeaege>,
                description => qq<afee\x{4e00}agageee xya>,
            };
            
            delete $result->{$sha2}->[0]->{id};
            delete $result->{$sha2}->[0]->{created};
            delete $result->{$sha2}->[0]->{repository_id};
            eq_or_diff $result->{$sha2}->[0], {
                sha => $sha2,
                state => 3,
                target_url => q<hhtrpfeaege12>,
                description => qq<afee\x{4e00}agageee>,
            };

            done $c;
            undef $c;
        } $c;
    });
} n => 6, wait => $mysql_cv, name => 'multiple';

run_tests;

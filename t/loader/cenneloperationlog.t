use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use File::Temp qw(tempdir);
use Path::Class;
use Test::GW::CennelServer;
use Karasuma::Config::JSON;
use GW::Loader::CennelOperationLog;

Test::GW::CennelServer->start_server_as_cv->recv;

my $cennel_host = Test::GW::CennelServer->server_host;

test {
    my $c = shift;
    my $key = int rand 1000000;

    my $config = Karasuma::Config::JSON->new_from_config_data({
        'gitworks.cennel.jobs_url' => qq<http://$cennel_host/$key/jobs>,
        'gitworks.cennel.get_operation_log_url' => qq<http://$cennel_host/$key/operation/%s.json>,
        'gitworks.cennel.api_key' => undef,
    });
    my $loader = GW::Loader::CennelOperationLog->new_from_config_and_operation_id($config, 124142222);

    http_post_data
        url => qq<http://$cennel_host/$key/devel/operation/124142222.json>,
        content => perl2json_bytes [{
            repository => {
                url => 'hoge:afaefaee',
            },
        }],
        anyevent => 1,
        cb => sub {
            test {
                $loader->get_operation_log_as_cv->cb(sub {
                    my $data = $_[0]->recv;
                    test {
                        eq_or_diff $data, [{
                            repository => {
                                url => 'hoge:afaefaee',
                            },
                        }];
                        done $c;
                        undef $c;
                    } $c;
                });
            } $c;
        };
} n => 1;

run_tests;
Test::GW::CennelServer->stop_server_as_cv->recv;

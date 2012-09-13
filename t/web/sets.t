use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;

my $server = mysql_and_web_as_cv;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/sets/abc.json>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                done $c;
            } $c;
        };
} n => 1, wait => $server;

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/sets/abc.json>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                eq_or_diff $json, [];
                done $c;
            } $c;
        };
} n => 2, wait => $server, name => 'empty';

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/sets/abc>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                unlike $res->content, qr{</html>};
                done $c;
                undef $c;
            } $c;
        };
} n => 2, wait => $server, name => 'empty bad key';

test {
    my $c = shift;

    my $host = $c->received_data->web_host;
    http_get
        url => qq<http://$host/sets/abc>,
        basic_auth => [develop => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                is $res->header('Content-Type'), q{text/html; charset=utf-8};
                like $res->content, qr{</html>};
                done $c;
                undef $c;
            } $c;
        };
} n => 3, wait => $server, name => 'empty html';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $cv1 = AE::cv;
    http_post_data
        url => qq<http://$host/hook>,
        basic_auth => [api_key => 'testapikey'],
        content => perl2json_bytes {
            repository => {url => q{git://hoge/fuga}},
            ref => 'refs/heads/hogefugabranch',
            after => '521451abacee',
            hook_args => {
                action_type => 'repository_set.add',
                action_args => {set_name => 'abc'},
            },
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        test {
            http_post
                url => qq<http://$host/jobs>,
                basic_auth => [api_key => 'testapikey'],
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        $cv2->send;
                    } $c;
                };
        } $c;
    });

    $cv2->cb(sub {
        test {
            http_get
                url => qq<http://$host/sets/abc>,
                basic_auth => [develop => 'testapikey'],
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        like $res->content, qr{git://hoge/fuga};
                        like $res->content, qr{</html>};
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 3, wait => sub { mysql_and_web_as_cv }, name => 'non empty list';

run_tests;

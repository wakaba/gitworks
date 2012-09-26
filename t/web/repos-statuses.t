use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;

my $server_cv;
my $server = sub { $server_cv ||= mysql_and_web_as_cv };

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $sha = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'get no repository_url no auth';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $sha = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
        basic_auth => [api_key => 'testapikey'],
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'get no repository_url';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<htfaefeafeeeafafee/fefea/e.gfee?a>;
    http_get
        url => qq<http://$host/repos/statuses/.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $url,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 404;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'get bad sha';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<htfaefeafeeeafafee/fefea/e.gfee?a>;
    my $sha = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $url,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                eq_or_diff $json, [];
                done $c;
                undef $c;
            } $c;
        };
} n => 2, wait => $server, name => 'get no repo';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<htfaefeafeeeafafee/fefea/e.gfee?a>;
    my $sha = q<aabbr425gaaaaaaaaage>;

    my $cv1 = AE::cv;
    http_post
        url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
        params => {
            repository_url => $url,
            state => 'success',
            target_url => q<hrr grg aega>,
            description => qq<\x{452}\x{5623}aab>,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 401;
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        test {
            http_get
                url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, [];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 3, name => 'post no auth', wait => $server;

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<htfaefeafeeeafafee/fefea/e.gfee?a>;
    my $sha = q<aabbr425gaaaaaaaaage>;

    my $cv1 = AE::cv;
    http_post
        url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $url,
            state => 'success',
            target_url => q<hrr grg aega>,
            description => qq<\x{452}\x{5623}aab>,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 201;
                my $json = json_bytes2perl $res->content;
                eq_or_diff $json, {
                    state => 'success',
                    target_url => q<hrr grg aega>,
                    description => qq<\x{452}\x{5623}aab>,
                };
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        test {
            http_get
                url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        ok $json->[0]->{id};
                        delete $json->[0]->{id};
                        eq_or_diff $json, [{
                            state => 'success',
                            target_url => q<hrr grg aega>,
                            description => qq<\x{452}\x{5623}aab>,
                        }];
                        $cv2->send;
                    } $c;
                };
        } $c;
    });

    my $cv3 = AE::cv;
    $cv2->cb(sub {
        test {
            http_post
                url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    state => 'failure',
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 201;
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, {
                            state => 'failure',
                            target_url => undef,
                            description => undef,
                        };
                        $cv3->send;
                    } $c;
                };
        } $c;
    });

    $cv3->cb(sub {
        test {
            http_get
                url => qq<http://$host/repos/statuses/> . $sha . q<.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        ok $json->[0]->{id};
                        delete $json->[0]->{id};
                        ok $json->[1]->{id};
                        delete $json->[1]->{id};
                        eq_or_diff $json, [{
                            state => 'failure',
                            target_url => undef,
                            description => undef,
                        }, {
                            state => 'success',
                            target_url => q<hrr grg aega>,
                            description => qq<\x{452}\x{5623}aab>,
                        }];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} n => 11, wait => $server, name => 'post / get';

run_tests;

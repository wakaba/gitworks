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
        url => qq<http://$host/repos/logs.json>,
        params => {
            sha => $sha,
        },
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
        url => qq<http://$host/repos/logs>,
        params => {
            sha => $sha,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 400;
                done $c;
                undef $c;
            } $c;
        };
} n => 1, wait => $server, name => 'get no repository_url no auth html';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $sha = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos/logs.json>,
        params => {
            sha => $sha,
        },
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
        url => qq<http://$host/repos/logs/.json>,
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
    http_get
        url => qq<http://$host/repos/logs/>,
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
} n => 1, wait => $server, name => 'get bad sha html';

test {
    my $c = shift;
    my $host = $c->received_data->web_host;

    my $url = q<htfaefeafeeeafafee/fefea/e.gfee?a>;
    my $sha = q<aabbr425gaaaaaaaaa>;
    http_get
        url => qq<http://$host/repos/logs.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $url,
            sha => $sha,
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
    my $sha = q<aabbr425gaaaaaaaaa55>;

    my $cv1 = AE::cv;
    http_post
        url => qq<http://$host/repos/logs.json>,
        params => {
            repository_url => $url,
            sha => $sha,
            branch => q<hrr grg aega>,
            data => qq<\x{452}\x{5623}aab>,
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
                url => qq<http://$host/repos/logs.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    sha => $sha,
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
        url => qq<http://$host/repos/logs.json>,
        basic_auth => [api_key => 'testapikey'],
        params => {
            repository_url => $url,
            sha => $sha,
            branch => q<hrr grg aega>,
            data => qq<\x{452}\x{5623}aab>,
        },
        anyevent => 1,
        cb => sub {
            my ($req, $res) = @_;
            test {
                is $res->code, 201;
                my $json = json_bytes2perl $res->content;
                eq_or_diff $json, {
                    sha => $sha,
                    branch => q<hrr grg aega>,
                    data => qq<\x{452}\x{5623}aab>,
                };
                $cv1->send;
            } $c;
        };

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        test {
            http_get
                url => qq<http://$host/repos/logs.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    sha => $sha,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        ok $json->[0]->{id};
                        delete $json->[0]->{id};
                        ok $json->[0]->{created};
                        delete $json->[0]->{created};
                        eq_or_diff $json, [{
                            sha => $sha,
                            branch => q<hrr grg aega>,
                            data => qq<\x{452}\x{5623}aab>,
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
                url => qq<http://$host/repos/logs.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    sha => $sha,
                    data => q<aa>,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 201;
                        my $json = json_bytes2perl $res->content;
                        eq_or_diff $json, {
                            sha => $sha,
                            branch => undef,
                            data => q<aa>,
                        };
                        $cv3->send;
                    } $c;
                };
        } $c;
    });

    my $cv4 = AE::cv;
    $cv4->begin;
    $cv3->cb(sub {
        test {
            $cv4->begin;
            http_get
                url => qq<http://$host/repos/logs.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    sha => $sha,
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
                        ok $json->[0]->{created};
                        delete $json->[0]->{created};
                        ok $json->[1]->{created};
                        delete $json->[1]->{created};
                        eq_or_diff $json, [{
                            sha => $sha,
                            data => 'aa',
                        }, {
                            sha => $sha,
                            branch => q<hrr grg aega>,
                            data => qq<\x{452}\x{5623}aab>,
                        }];
                        $cv4->end;
                    } $c;
                };

            $cv4->begin;
            http_get
                url => qq<http://$host/repos/logs.json>,
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
                        is scalar @$json, 2;
                        $cv4->end;
                    } $c;
                };

            $cv4->begin;
            http_get
                url => qq<http://$host/repos/logs>,
                basic_auth => [develop => 'testapikey'],
                params => {
                    repository_url => $url,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        like $res->content, qr[\Q$sha\E];
                        $cv4->end;
                    } $c;
                };

            $cv4->begin;
            http_get
                url => qq<http://$host/repos/logs.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    branch => q<hrr grg aega>,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        is scalar @$json, 1;
                        $cv4->end;
                    } $c;
                };

            $cv4->begin;
            http_get
                url => qq<http://$host/repos/logs.json>,
                basic_auth => [api_key => 'testapikey'],
                params => {
                    repository_url => $url,
                    branch => q<hrr grg aega abc>,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        is scalar @$json, 0;
                        $cv4->end;
                    } $c;
                };

            $cv4->begin;
            http_get
                url => qq<http://$host/repos/logs>,
                basic_auth => [develop => 'testapikey'],
                params => {
                    repository_url => $url,
                    branch => q<hrr grg aega abc>,
                },
                anyevent => 1,
                cb => sub {
                    my ($req, $res) = @_;
                    test {
                        is $res->code, 200;
                        is $res->content_type, q{text/html};
                        $cv4->end;
                    } $c;
                };

            $cv4->end;
        } $c;
    });

    $cv4->cb(sub {
        test {
            done $c;
            undef $c;
        } $c;
    });
} n => 24, wait => $server, name => 'post / get';

run_tests;

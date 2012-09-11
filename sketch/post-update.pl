use strict;
use warnings;
use Web::UserAgent::Functions qw(http_post);
use JSON::Functions::XS qw(perl2json_bytes);
use MIME::Base64 qw(decode_base64);

$ENV{WEBUA_DEBUG} = 2;
Web::UserAgent::Functions->check_socksify;

my $host = shift or die "no host";
my $api_key = decode_base64 shift or die "no api key";
my $url = shift or die "no url";

my ($req, $res) = http_post
    url => qq<http://$host/hook>,
    basic_auth => [api_key => $api_key],
    header_fields => {'Content-Type' => 'application/json'},
    content => perl2json_bytes +{
        ref => 'master',
        repository => {
            url => $url,
        },
        after => 'master',
        hook_args => {
            action_type => 'command',
            action_args => {
                command => 'updatenightlybranch',
            },
        },
    };

use strict;
use warnings;
use Web::UserAgent::Functions qw(http_post);
use JSON::Functions::XS qw(perl2json_bytes);
use MIME::Base64 qw(decode_base64);
use URL::PercentEncode qw(percent_encode_c);

my ($host, $api_key, $set_name, $command) = @ARGV;
$api_key = decode_base64 $api_key;

Web::UserAgent::Functions->check_socksify;

my ($req, $res) = http_post
    url => qq<http://$host/sets/> . (percent_encode_c $set_name),
    basic_auth => [api_key => $api_key],
    params => {
        action => 'command',
        command => $command,
    };

use strict;
use warnings;
use Path::Class;
use JSON::Functions::XS qw(file2perl);
use MIME::Base64 qw(decode_base64);
use Encode;

my $dsns = do {
    my $file_name = $ENV{GW_DSNS_JSON}
        or die "|GW_DSNS_JSON| is not specified";
    my $json = file2perl file($file_name);
    $json->{dsns};
};

my $hostname = $ENV{GW_WEB_HOSTNAME} || 'localhost';
my $port = $ENV{GW_WEB_PORT} || 80;
my $url = qq<http://$hostname:$port/jobs>;

my $api_key = do {
    my $file_name = $ENV{GW_API_KEY_FILE_NAME}
        or die "|GW_API_KEY_FILE_NAME| not specified";
    decode 'utf-8', decode_base64 scalar file($file_name)->slurp;
};

my @task = (
    {
        interval => 3,
        dsns => $dsns,
        actions => [{
            db => 'gitworks',
            table_name => 'job',,
            sql => 'SELECT id FROM :table_name:id WHERE process_started < ? LIMIT 1',
            get_sql_args => sub {
                return {process_started => time};
            },
            url => $url,
            basic_auth => [api_key => $api_key],
            args => {},
        }],
    },
);

\@task;
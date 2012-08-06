package GW::MySQL;
use strict;
use warnings;
use Dongry::Type::JSON;
use JSON::Functions::XS qw(file2perl);
use Path::Class;

$Dongry::Database::Registry->{gitworks} = {
    schema => {
        job => {
            type => {
                args => 'json',
            },
        },
    },
};

sub load_by_env {
    my $file_name = $ENV{GW_DSNS_JSON}
        or die "|GW_DSNS_JSON| is not specified";
    shift->load_by_f(file($file_name));
}

sub load_by_f {
    my (undef, $f) = @_;
    my $dsns = file2perl $f;
    $Dongry::Database::Registry->{gitworks}->{sources}->{master}->{dsn}
        = $dsns->{dsns}->{gitworks} or die "|gitworks| is not defined";
    $Dongry::Database::Registry->{gitworks}->{sources}->{master}->{writable} = 1;
}

1;

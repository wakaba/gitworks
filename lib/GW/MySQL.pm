package GW::MySQL;
use strict;
use warnings;
use Dongry::Database;
use Dongry::Type::JSON;
use JSON::Functions::XS qw(file2perl);
use Path::Class;

sub load_by_env {
    my $file_name = $ENV{GW_DSNS_JSON}
        or die "|GW_DSNS_JSON| is not specified";
    return $_[0]->load_by_f(file($file_name));
}

sub load_by_f {
    my (undef, $f) = @_;
    my $dsns = file2perl $f;

    my $reg = Dongry::Database->create_registry;

    $reg->{Registry}->{gitworks} = {
        schema => {
            job => {
                type => {
                    args => 'json',
                },
            },
        },
    };

    $reg->{Registry}->{gitworks}->{sources}->{default}->{dsn}
        = $dsns->{dsns}->{gitworks} or die "|gitworks| is not defined";
    $reg->{Registry}->{gitworks}->{sources}->{master}->{dsn}
        = $dsns->{dsns}->{gitworks} or die "|gitworks| is not defined";
    $reg->{Registry}->{gitworks}->{sources}->{master}->{writable} = 1;

    return $reg;
}

1;

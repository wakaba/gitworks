package GW::Loader::CennelOperationLog;
use strict;
use warnings;
use AnyEvent;
use Web::UserAgent::Functions qw(http_get);
use JSON::Functions::XS qw(json_bytes2perl);

sub new_from_config_and_operation_id {
    return bless {config => $_[1], operation_id => $_[2]}, $_[0];
}

sub config {
    return $_[0]->{config};
}

sub operation_id {
    return $_[0]->{operation_id};
}

sub get_log_url {
    return $_[0]->config->get_text('gitworks.cennel.get_operation_log_url');
}

sub cennel_basic_auth {
    return [
        api_key => 
        $_[0]->config->get_file_base64_text('gitworks.cennel.api_key'),
    ];
}

sub get_operation_log_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    my $url = $self->get_log_url;
    $url =~ s/%s/$self->operation_id/e;
    http_get
        url => $url,
        basic_auth => $self->cennel_basic_auth,
        anyevent => 1,
        cb => sub {
            my (undef, $res) = @_;
            if ($res->code == 200) {
                $cv->send(json_bytes2perl $res->content);
            } else {
                $cv->send(undef);
            }
        };
    return $cv;
}

1;

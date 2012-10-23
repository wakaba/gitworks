package GW::Loader::CennelRecentOperations;
use strict;
use warnings;
use AnyEvent;
use Web::UserAgent::Functions qw(http_get);
use JSON::Functions::XS qw(json_bytes2perl);

sub new_from_config {
    return bless {config => $_[1]}, $_[0];
}

sub config {
    return $_[0]->{config};
}

sub get_list_url {
    return $_[0]->config->get_text('gitworks.cennel.get_operation_list_url');
}

sub get_recent_operations_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    http_get
        url => $self->get_list_url,
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

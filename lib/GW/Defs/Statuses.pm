package GW::Defs::Statuses;
use strict;
use warnings;
use Exporter::Lite;

our @EXPORT;

sub COMMIT_STATUS_PENDING () { 1 }
sub COMMIT_STATUS_SUCCESS () { 2 }
sub COMMIT_STATUS_ERROR () { 3 }
sub COMMIT_STATUS_FAILURE () { 4 }

push @EXPORT, qw(
  COMMIT_STATUS_PENDING COMMIT_STATUS_SUCCESS
  COMMIT_STATUS_ERROR COMMIT_STATUS_FAILURE
);

our $CommitStatusNameToCode = {
  pending => COMMIT_STATUS_PENDING,
  success => COMMIT_STATUS_SUCCESS,
  error => COMMIT_STATUS_ERROR,
  failure => COMMIT_STATUS_FAILURE,
};

our $CommitStatusCodeToName = {
  COMMIT_STATUS_PENDING, 'pending',
  COMMIT_STATUS_SUCCESS, 'success',
  COMMIT_STATUS_ERROR, 'error',
  COMMIT_STATUS_FAILURE, 'failure',
};

1;

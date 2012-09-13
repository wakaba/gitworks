use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/]+$}{}; $dir_name ||= '.';
    $dir_name .= '/../lib'; unshift @INC, $dir_name;
}
use warnings;
use Test::GW;
use GW::Defs::Statuses;

test {
    my $c = shift;

    ok COMMIT_STATUS_PENDING;
    ok COMMIT_STATUS_SUCCESS;
    ok COMMIT_STATUS_ERROR;
    ok COMMIT_STATUS_FAILURE;

    done $c;
} n => 4;

test {
    my $c = shift;

    ok keys %$GW::Defs::Statuses::CommitStatusNameToCode;
    ok keys %$GW::Defs::Statuses::CommitStatusCodeToName;

    for (keys %$GW::Defs::Statuses::CommitStatusNameToCode) {
        ok $GW::Defs::Statuses::CommitStatusNameToCode->{$_};
        is $GW::Defs::Statuses::CommitStatusCodeToName->{$GW::Defs::Statuses::CommitStatusNameToCode->{$_}}, $_;
    }

    for (keys %$GW::Defs::Statuses::CommitStatusCodeToName) {
        ok $GW::Defs::Statuses::CommitStatusCodeToName->{$_};
        is $GW::Defs::Statuses::CommitStatusNameToCode->{$GW::Defs::Statuses::CommitStatusCodeToName->{$_}}, $_;
    }

    done $c;
};

run_tests;

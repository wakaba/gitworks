#!/bin/sh
exec 2>&1
export PATH=@@LOCAL@@/perl-latest/pm/bin:@@LOCAL@@/perlbrew/perls/perl-latest/bin:${PATH}
export PERL5LIB=`cat @@ROOT@@/config/perl/libs.txt`
export GW_DSNS_JSON=@@INSTANCECONFIG@@/dsns.json
export GW_API_KEY_FILE_NAME=@@INSTANCECONFIG@@/apikey.txt
exec setuidgid @@USER@@ perl `which plackup` $PLACK_COMMAND_LINE_ARGS \
    -p @@PORT@@ @@ROOT@@/bin/server.psgi
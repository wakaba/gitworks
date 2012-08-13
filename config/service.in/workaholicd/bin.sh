#!/bin/sh
exec 2>&1
export PATH=@@LOCAL@@/perl-latest/pm/bin:@@LOCAL@@/perlbrew/perls/perl-latest/bin:${PATH}
export PERL5LIB=`cat @@ROOT@@/config/perl/libs.txt`
export GW_DSNS_JSON=@@INSTANCECONFIG@@/dsns.json
export GW_API_KEY_FILE_NAME=@@INSTANCECONFIG@@/apikey.txt
export GW_WEB_HOSTNAME=localhost
export GW_WEB_PORT=@@PORT@@
exec setuidgid @@USER@@ perl @@ROOT@@/bin/workaholicd.pl

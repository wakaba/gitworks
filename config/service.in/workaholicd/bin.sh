#!/bin/sh
exec 2>&1
export GW_DSNS_JSON=@@INSTANCECONFIG@@/dsns.json
export GW_API_KEY_FILE_NAME=@@INSTANCECONFIG@@/apikey.txt
export HOME=@@LOCAL@@/home

export WEBUA_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.WEBUA_DEBUG text`
export SQL_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.SQL_DEBUG text`
port=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl gitworks.web.port text`

export GW_WEB_HOSTNAME=localhost
export GW_WEB_PORT=$port

exec setuidgid @@USER@@ @@ROOT@@/perl @@ROOT@@/bin/workaholicd.pl @@ROOT@@/config/workaholicd.pl

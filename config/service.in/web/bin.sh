#!/bin/sh
exec 2>&1
export GW_DSNS_JSON=@@INSTANCECONFIG@@/dsns.json
export GW_API_KEY_FILE_NAME=@@INSTANCECONFIG@@/apikey.txt
export GW_COMMAND_DIR_NAME=@@INSTANCECONFIG@@/commands
export KARASUMA_CONFIG_JSON=@@INSTANCECONFIG@@/@@INSTANCENAME@@.json
export KARASUMA_CONFIG_FILE_DIR_NAME=@@LOCAL@@/keys
export HOME=@@LOCAL@@/home

export WEBUA_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.WEBUA_DEBUG text`
export SQL_DEBUG=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl env.SQL_DEBUG text`
port=`@@ROOT@@/perl @@ROOT@@/modules/karasuma-config/bin/get-json-config.pl gitworks.web.port text`

eval "exec setuidgid @@USER@@ @@ROOT@@/plackup $PLACK_COMMAND_LINE_ARGS \
    -p $port @@ROOT@@/bin/server.psgi"

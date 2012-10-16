all:

# ------ Setup ------

WGET = wget
GIT = git

local/bin/pmbp.pl: always
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

local-perl: pmbp-install

pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl

pmbp-update: pmbp-upgrade
	perl local/bin/pmbp.pl --update

pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
	    --create-perl-command-shortcut perl \
	    --create-perl-command-shortcut prove \
	    --create-perl-command-shortcut plackup

git-submodules:
	$(GIT) submodule update --init

deps: pmbp-install

always:

# ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps
	cd modules/rdb-utils && $(MAKE) deps

test-main:
	$(PROVE) \
	    t/defs/*.t t/action/*.t t/loader/*.t t/web/*.t t/commands/*.t

# ------ Local (example) ------

LOCAL_SERVER_ARGS = \
	    APP_NAME=gitworks \
	    SERVER_INSTANCE_NAME=gwlocal \
	    SERVER_PORT=6016 \
	    SERVER_ENV=default \
	    ROOT_DIR="$(abspath .)" \
	    SERVICE_DIR="/etc/service"

local-server:
	$(MAKE) --makefile=Makefile.service all $(LOCAL_SERVER_ARGS) \
	    SERVER_TYPE=web SERVER_TYPE_LOG=web
	$(MAKE) --makefile=Makefile.service all $(LOCAL_SERVER_ARGS) \
	    SERVER_TYPE=workaholicd SERVER_TYPE_LOG=workaholicd

install-local-server:
	$(MAKE) --makefile=Makefile.service install $(LOCAL_SERVER_ARGS) \
	    SERVER_TYPE=web SERVER_TYPE_LOG=web
	$(MAKE) --makefile=Makefile.service install $(LOCAL_SERVER_ARGS) \
	    SERVER_TYPE=workaholicd SERVER_TYPE_LOG=workaholicd

# ------ Deps ------

add-git-submodules:
	$(GIT) submodule foreach "git config -f .gitmodules --get-regexp ^submodule\\.modules/.*\\.url$$ || :" | grep ^submodule | sed 's/^\S\+\s//' | sort | uniq | sed 's/\(\([^\\/]\+\)\?\)$$/\1 modules\/\2/; s/\.git$$//; s/^/git submodule add /' | grep -v -f config/git/submodule-no-autoadd.txt | sh

autoupdatenightly:

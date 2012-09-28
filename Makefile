all:

# ------ Setup ------

WGET = wget
GIT = git
PERL = perl
PERL_VERSION = 5.16.1
PERL_ENV = PATH="$(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin):$(abspath local/perl-$(PERL_VERSION)/pm/bin):$(PATH)"

PMB_PMTAR_REPO_URL =
PMB_PMPP_REPO_URL = 

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120337

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

lperl lplackup lprove: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@ \
	    PMB_PMTAR_REPO_URL=$(PMB_PMTAR_REPO_URL) \
	    PMB_PMPP_REPO_URL=$(PMB_PMPP_REPO_URL) \
	    PERL_VERSION=$(PERL_VERSION)

local/bin/pmbp.pl: always
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

PMBP_OPTIONS = 

local-perl: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl $(PMBP_OPTIONS) --perl-version $(PERL_VERSION) --install-perl

pmbp-update: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl $(PMBP_OPTIONS) --update

pmbp-install: local/bin/pmbp.pl
	 $(PERL_ENV) $(PERL) local/bin/pmbp.pl $(PMBP_OPTIONS) --install

git-submodules:
	$(GIT) submodule update --init

deps: local-perl pmbp-install lperl

always:

# ------ Tests ------

PROVE = prove

test: test-deps test-main

test-deps: deps
	cd modules/rdb-utils && $(MAKE) deps

test-main:
	$(PERL_ENV) $(PROVE) \
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

all:

# ------ Setup ------

WGET = wget
GIT = git
PERL = perl
PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)

PMB_PMTAR_REPO_URL =
PMB_PMPP_REPO_URL = 

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120337

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

lperl lplackup lprove local-perl perl-version perl-exec \
pmb-install pmb-update local-submodules \
cinnamon: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@ \
	    PMB_PMTAR_REPO_URL=$(PMB_PMTAR_REPO_URL) \
	    PMB_PMPP_REPO_URL=$(PMB_PMPP_REPO_URL)

git-submodules:
	$(GIT) submodule update --init

deps: local-submodules pmb-install lperl

# ------ Tests ------

PERL_ENV = PATH="$(abspath local/perl-$(PERL_VERSION)/pm/bin):$(PERL_PATH):$(PATH)" PERL5LIB="$(shell cat config/perl/libs.txt)"
PREPARE_DB_SET_PL = modules/rdb-utils/bin/prepare-db-set.pl
DB_SET_JSON = t/tmp/dsns.json
PROVE = prove

test: test-deps test-main

test-deps: deps

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

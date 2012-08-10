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
: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@ \
	    PMB_PMTAR_REPO_URL=$(PMB_PMTAR_REPO_URL) \
	    PMB_PMPP_REPO_URL=$(PMB_PMPP_REPO_URL)

git-submodules:
	$(GIT) submodule update --init

# ------ Tests ------

PERL_ENV = PATH="bin/perl-$(PERL_VERSION)/pm/bin:$(PERL_PATH):$(PATH)" PERL5LIB="$(shell cat config/perl/libs.txt)"
PREPARE_DB_SET_PL = modules/rdb-utils/bin/prepare-db-set.pl
DB_SET_JSON = t/tmp/dsns.json
PROVE = prove

test: test-deps safetest

test-deps: local-submodules pmb-install

safetest:
	$(PERL_ENV) $(PROVE) t/action/*.t t/web/*.t


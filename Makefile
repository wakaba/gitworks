all:

# ------ Setup ------

WGET = wget
GIT = git

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

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

deps: git-submodules pmbp-install

# ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps test-home
	cd modules/rdb-utils && $(MAKE) deps

test-home:
	mkdir -p local/home
	git config --file local/home/.gitconfig user.name gitworks
	git config --file local/home/.gitconfig user.email gitworks@test

test-main:
	HOME="$(abspath local/home)" $(PROVE) \
	    t/defs/*.t t/action/*.t t/loader/*.t t/web/*.t t/commands/*.t

autoupdatenightly:

always:

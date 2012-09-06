#!/bin/sh
thisdir=`dirname $0`
bindir=$thisdir/../../bin

git checkout nightly || git checkout -b nightly
git merge --strategy=recursive --strategy-option=theirs origin/master && \
perl $bindir/git-submodule-track.pl && \
(perl -e 'system "make -q autoupdatenightly"; exit(($? >> 8) == 1 ? 1 : 0)' || make autoupdatenightly) && \
git commit -m updatenightlybranch
git push origin nightly

#!/bin/sh
(git checkout -b $1 origin/$1 || git checkout $1) &&
git merge $GITWORKS_REPOSITORY_SHA -m "Merge $GITWORKS_REPOSITORY_SHA ($GITWORKS_REPOSITORY_BRANCH) into $1" &&
git push origin $1

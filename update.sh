#!/bin/bash

set -e

branch_name=$(git symbolic-ref -q HEAD)
branch_name=${branch_name##refs/heads/}
branch_name=${branch_name:-HEAD}

if ! test -d ghc;
then
	echo "GHC checkout missing; getting it"
	git clone git://github.com/ghc/ghc -b $branch_name
	(cd ghc && ./sync-all -r git://github.com/ghc get --branch $branch_name)
fi

> msg.body

changes=""
for gitrepo in $(find ghc -name .git -type d|sort) # -type d excludes submodules
do
	wd=$(dirname $gitrepo)
	name=$(basename $wd)
	(cd $wd; git fetch --quiet)
	n=$(cd $wd; git log $branch_name..origin/$branch_name --oneline | wc -l)
	if [ $n -gt 0 ]
	then
		echo "Changes in $name, pulling"
		echo "Changes to $name:" >> msg.body
		(cd $wd; git log $branch_name..origin/$branch_name) >> msg.body
		if [ $n -gt 1 ]
		then
			changes="$changes $name($n)"
		else
			changes="$changes $name"
		fi
		echo "" >> msg.body
		(cd $wd; git pull)
	fi
done

echo "Updating submodules"
(cd ghc; git submodule update --recursive)

echo "Generating fingerprint"
./ghc/utils/fingerprint/fingerprint.py create -g ghc -o fingerprint

if ! git diff --quiet HEAD -- fingerprint
then
	(echo "Changes to$changes" ; echo; cat msg.body) | git commit -F - --author "ghc-complete autocommiter <mail@joachim-breitner.de>" fingerprint
	git push --quiet origin $branch_name
else
	echo "No changes!"
fi

rm msg.body

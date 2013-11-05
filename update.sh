#!/bin/bash

set -e

if ! test -d ghc;
then
	echo "GHC checkout missing; getting it"
	git clone git://github.com/ghc/ghc
	(cd ghc && ./sync-all -r git://github.com/ghc --testsuite get)
fi

> msg.body

changes=""
for gitrepo in $(find ghc -name .git -type d|sort) # -type d excludes submodules
do
	wd=$(dirname $gitrepo)
	name=$(basename $wd)
	(cd $wd; git fetch --quiet)
	n=$(cd $wd; git log master..origin/master --oneline | wc -l)
	if [ $n -gt 0 ]
	then
		echo "Changes in $name, pulling"
		echo "Changes to $name:" >> msg.body
		(cd $wd; git log master..origin/master) >> msg.body
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

echo "Generating fingerprint"
./ghc/utils/fingerprint/fingerprint.py create -g ghc -o fingerprint

if ! git diff --quiet HEAD -- fingerprint
then
	(echo "Changes to$changes" ; echo; cat msg.body) | git commit -F - --commiter "ghc-complete autocommiter <mail@joachim-breitner.de>" --author "ghc-complete autocommiter <mail@joachim-breitner.de>" fingerprint
	git push --quiet
else
	echo "No changes!"
fi

rm msg.body

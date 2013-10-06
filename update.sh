#!/bin/bash

set -e

if ! test -d ghc;
then
	echo "GHC checkout missing; getting it"
	git clone git://github.com/ghc/ghc
	(cd ghc && ./sync-all -r git://github.com/ghc --testsuite get)
fi

echo "Updated fingerprint file" > msg

# TODO: Fill msg with information about the pull

echo "Updating GHC to latest state"
(cd ghc && ./sync-all pull)

echo "Generating fingerprint"
./ghc/utils/fingerprint/fingerprint.py create -g ghc -o fingerprint

if ! git diff --quiet HEAD -- fingerprint
then
	git commit -F msg fingerprint
	git push
else
	echo "No changes!"
fi

rm msg

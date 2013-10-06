#!/bin/bash

set -e

if ! test -d ghc;
then
	echo "GHC checkout missing; getting it"
	git clone git://github.com/ghc/ghc
	(cd ghc && ./sync-all -r git://github.com/ghc get)
fi

echo "Updating GHC checkout"
(cd ghc && ./sync-all pull)

echo "Generating fingerprint"

./ghc/utils/fingerprint/fingerprint.py create -o fingerprint

if git diff-index --quiet HEAD -- fingerprint
then
	git commit -m 'Updated fingerprint file' fingerprint
	git push
fi

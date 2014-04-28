#!/bin/bash

echo "Running $0..."

set -e

if [ -n "$TRAVIS_BRANCH" ]
then
	branch_name=$(git symbolic-ref -q HEAD)
	branch_name=${branch_name##refs/heads/}
	branch_name=${branch_name:-HEAD}
else
	branch_name=$TRAVIS_BRANCH
fi
echo "On branch $branch_name"

if ! test -d ghc-validate;
then
	echo "GHC checkout missing; getting it"
	git clone git://github.com/ghc/ghc -b $branch_name ghc-validate
	(cd ghc-validate && ./sync-all -r git://github.com/ghc get)
else
        echo "Updating ghc-validate/"
	(cd ghc-validate && ./sync-all fetch)
fi

echo "Resetting to fingerprint"
./ghc-validate/utils/fingerprint/fingerprint.py restore -g ghc-validate -f fingerprint

cd ghc-validate

rm -f mk/build.mk
echo 'V = 0' >> mk/build.mk # otherwise we hit log file limits on travis.
# The quick settings:
echo 'SRC_HC_OPTS        = -H64m -O0 -fasm' >> mk/build.mk
echo 'GhcStage1HcOpts    = -O -fasm -Wall -fno-warn-name-shadowing -Werror' >> mk/build.mk
if [ "$DEBUG_STAGE2" = 'YES' ]
then
echo 'GhcStage2HcOpts    = -O -DDEBUG -fasm -Wall -fno-warn-name-shadowing -Werror' >> mk/build.mk
else
echo 'GhcStage2HcOpts    = -O -fasm -Wall -fno-warn-name-shadowing  -Werror' >> mk/build.mk
fi
echo 'GhcLibHcOpts       = -O -fasm' >> mk/build.mk
echo 'SplitObjs          = NO' >> mk/build.mk
echo 'HADDOCK_DOCS       = NO' >> mk/build.mk
echo 'BUILD_DOCBOOK_HTML = NO' >> mk/build.mk
echo 'BUILD_DOCBOOK_PS   = NO' >> mk/build.mk
echo 'BUILD_DOCBOOK_PDF  = NO' >> mk/build.mk
echo 'DYNAMIC_GHC_PROGRAMS = NO' >> mk/build.mk
echo 'GhcLibWays = v'          >> mk/build.mk
# Lets do it
perl boot
make distclean
./configure 
make -j3
make -C testsuite fast THREADS=3 VERBOSE=2 SKIP_PERF_TESTS=YES | tee testlog
grep '\<0 caused framework failures' testlog
grep '\<0 unexpected passes' testlog
grep '\<0 unexpected failures' testlog
! grep 'Some files are written by multiple tests' testlog

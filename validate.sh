#!/bin/bash

set -e

# https://github.com/travis-ci/travis-ci/issues/1949
unset PS4

if ! test -d ghc-validate;
then
	echo "GHC checkout missing; getting it"
	git clone git://github.com/ghc/ghc ghc-validate
	(cd ghc-validate && ./sync-all -r git://github.com/ghc get)
else
        echo "Updating ghc-validate/"
	(cd ghc-validate && ./sync-all fetch)
fi

echo "Resetting to fingerprint"
./ghc-validate/utils/fingerprint/fingerprint.py restore -g ghc-validate -f fingerprint

cd ghc-validate

echo "Removing dph and dependencies"
rm -rf libraries/vector libraries/primitive libraries/random libraries/dph

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
echo "Booting"
perl boot
echo "Cleaning"
make distclean || true
echo "Configuring"
./configure 
echo "Making"
make -j3
echo "Testing"
make -C testsuite fast THREADS=3 VERBOSE=2 SKIP_PERF_TESTS=YES | tee testlog
grep '\<0 caused framework failures' testlog
grep '\<0 unexpected passes' testlog
grep '\<0 unexpected failures' testlog
! grep 'Some files are written by multiple tests' testlog

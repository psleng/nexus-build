#!/bin/sh
sudo rm -rf nexus-build
git clone -q https://github.com/psleng/nexus-build
cd nexus-build

exec > iGOS-build.out 2>&1
echo 'Starting daily iGOS build...'
make spotless
date
echo 'Starting targ-ti-j7200 iGOS build...'
date
make targ-ti-j7200
make all
echo 'Finished targ-ti-j7200 iGOS build...'
date
ls -l .*built
make mostlyclean
echo 'Starting targ-ti-am64x iGOS build...'
date
make targ-ti-am64x
make all
ls -l .*built
date
echo 'Daily iGOS build completed! Please check *.ERR files for errors.'

exec > iGOS-deb-repo.out 2>&1
echo 'Checking iGOS binary repository for changes and updating if different.'
./check-update-apt-repo.sh --repo git@github.com:psleng --clean
echo status=$?

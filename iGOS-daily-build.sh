echo 'Starting daily iGOS build...' > iGOS-build.out
date >> iGOS-build.out
git pull
make clean
make targ-ti-evm
make all
ls -l .*built >>  iGOS-build.out
date >> iGOS-build.out
echo 'Daily iGOS build completed! Please check *.ERR files for errors.'  >> iGOS-build.out
echo 'Checking iGOS binary repository for changes and updating if different.' > iGOS-deb-repo.out
./check-update-apt-repo.sh --repo git@github.com:psleng >> iGOS-deb-repo.out


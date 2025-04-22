sudo rm -rf nexus-build
git clone https://github.com/psleng/nexus-build
cd nexus-build
echo 'Starting daily iGOS build...' > iGOS-build.out
make spotless
date >> iGOS-build.out
echo 'Starting targ-ti-j7200 iGOS build...' >> iGOS-build.out
date >> iGOS-build.out
make targ-ti-j7200
make all
echo 'Finished targ-ti-j7200 iGOS build...' >> iGOS-build.out
date >> iGOS-build.out
ls -l .*built >>  iGOS-build.out
make mostlyclean
echo 'Starting targ-ti-am64x iGOS build...' >> iGOS-build.out
date >> iGOS-build.out
make targ-ti-am64x
make all
ls -l .*built >>  iGOS-build.out
date >> iGOS-build.out
echo 'Daily iGOS build completed! Please check *.ERR files for errors.'  >> iGOS-build.out
echo 'Checking iGOS binary repository for changes and updating if different.' > iGOS-deb-repo.out
./check-update-apt-repo.sh --repo git@github.com:psleng --clean >> iGOS-deb-repo.out
cd -

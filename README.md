./buildvyoscontainer.sh

./rundocker.sh

sudo ./build_iGOS_TMDS64EVM_kernel.sh --repo https://github.com/psleng --clean

sudo ./build_iGOS_TMDS64EVM_fs.sh --repo https://github.com/psleng

sudo ./build_iGOS_drivers.sh --repo https://github.com/psleng

exit

sudo ./buildiGOSti.sh am64x_bookworm_09.00.00.006

sudo ./create-sdcard.sh am64x_bookworm_09.00.00.006

// to re-create the psleng.github.io apt binary repository:
./build-psleng-github-io.sh --repo https://github.com/psleng

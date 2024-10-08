set -x
set -e
ROOTDIR=$(pwd)

# Clean out the build-repo and copy all custom packages
rm -rf vyos-build
git clone -b sagitta --single-branch https://github.com/vyos/vyos-build

if [ ! -f build/telegraf*.deb ]; then
	pushd vyos-build/packages/telegraf
	git clone https://github.com/influxdata/telegraf.git -b v1.23.1 telegraf
	bash -x ./build.sh
	popd
	mkdir -p build
	cp vyos-build/packages/telegraf/telegraf/build/dist/telegraf_1.23.1-1_arm64.deb build/
fi

for a in $(find build -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
	echo "Copying package: $a"
	cp $a vyos-build/packages/
done

cd vyos-build

echo "Copy new default configuration to the vyos image"
cp ${ROOTDIR}/config.boot.default data/live-build-config/includes.chroot/opt/vyatta/etc/config.boot.default
cp ${ROOTDIR}/defaults.toml data/defaults.toml

# Build the image
#VYOS_BUILD_FLAVOR=data/generic-arm64.json
#./configure
#make iso
./build-vyos-image iso --architecture arm64

cd $ROOTDIR

# Check ISO file
LIVE_IMAGE_ISO=vyos-build/build/live-image-arm64.hybrid.iso

if [ ! -e ${LIVE_IMAGE_ISO} ]; then
  echo "File ${LIVE_IMAGE_ISO} not exists."
  exit -1
fi

# Build u-boot
bash build-u-boot.sh

# Generate CM4 image from the iso
#DEVTREE="bcm2711-rpi-cm4" PIVERSION=4 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Generate PI4 image from the iso
DEVTREE="bcm2711-rpi-4-b" PIVERSION=4 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Generate PI3B image from the iso
#DEVTREE="bcm2710-rpi-3-b" PIVERSION=3 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Generate PI3B+ image from the iso
#DEVTREE="bcm2710-rpi-3-b-plus" PIVERSION=3 bash build-pi-image.sh ${LIVE_IMAGE_ISO}

# Symlink pi4 image
#ln -s vyos-build/build/live-image-arm64.hybrid.img live-image-arm64.hybrid.img

#!/bin/bash
#
# Copy and Build DFU (Device Firmware Update) Images 
#

ROOTDIR=$(pwd)

. $ROOTDIR/.defs.mk

BUILD_FOLDER=build/$BUILDTYPE
IMAGES_FOLDER=images/$BUILDTYPE
DFU_IMG_FOLDER=dfu-images

UBOOT_IMG_FOLDER=$BUILD_FOLDER/tisdk-debian-*-boot
ROOTFS_IMG_FILE=$IMAGES_FOLDER/tisdk-debian-*-rootfs.squashfs
U_BOOT_FILES=(
    "tiboot3.bin"
    "tispl.bin"
    "u-boot.img"
)

if [ ! -d $UBOOT_IMG_FOLDER ]; then
    echo "E: \"$UBOOT_IMG_FOLDER\" folder is not exist. Try again after build images"
    exit 1
fi
if [ ! -f $ROOTFS_IMG_FILE ]; then
    echo "E: \"$ROOTFS_IMG_FILE\" file is not exist. Try again after build images"
    exit 1
fi

PKGS="dfu-util u-boot-tools"
for pkg in $PKGS; do
    status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
    if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
        echo "$pkg is not installed. status = $status"
        sudo apt install $pkg
#    else
#        echo "$pkg is installed. status = $status"
    fi
done

if [ ! -d $DFU_IMG_FOLDER ]; then
    echo "I: Creating \"$DFU_IMG_FOLDER\" folder..."
    mkdir $DFU_IMG_FOLDER
else
    while true; do
        read -p "$DFU_IMG_FOLDER is exist. Do you want to overwrite it? (y/n) " yn
        case $yn in
            [Yy]* ) echo "Overwriting..."; break;;
            [Nn]* ) echo "Exiting..."; exit 1;;
            * ) echo "Invalid input. Please answer 'y' or 'n'.";;
        esac
    done
fi

for file in "${U_BOOT_FILES[@]}"; do
    if [ ! -f $UBOOT_IMG_FOLDER/$file ]; then
        echo "$UBOOT_IMG_FOLDER/$file is not exist!! Exiting.."
        exit 1
    else
        echo "Copying $file..."
        cp $UBOOT_IMG_FOLDER/$file $DFU_IMG_FOLDER
    fi
done

echo "Creating uEnv.txt..."
cat << 'EOF' > $DFU_IMG_FOLDER/uEnv.txt
# This uEnv.txt file can contain additional environment settings that you
# want to set in U-Boot at boot time.  This can be simple variables such
# as the serverip or custom variables.  The format of this file is:
#    variable=value
# NOTE: This file will be evaluated after the bootcmd is run and the
#       bootcmd must be set to load this file if it exists (this is the
#       default on all newer U-Boot images.  This also means that some
#       variables such as bootdelay cannot be changed by this file since
#       it is not evaluated until the bootcmd is run.

addr_fit=0x90000000
arch=arm
args_all=setenv optargs earlycon=ns16550a,mmio32,0x02800000 ${mtdparts}
args_mmc=run finduuid;setenv bootargs console=${console} ${optargs} root=PARTUUID=${uuid} rw rootfstype=${mmcrootfstype}
args_nand=setenv bootargs console=${console} ${optargs} ubi.mtd=${nbootpart} root=${nbootvolume} rootfstype=ubifs
args_usb=run finduuid;setenv bootargs console=${console} ${optargs} root=PARTUUID=${uuid} rw rootfstype=${mmcrootfstype}
baudrate=115200
board=am64x
board_name=am64x_gpevm
board_rev=C
board_serial=0270
board_software_revision=01
boot=mmc
boot_a_script=load ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} ${prefix}${script}; source ${scriptaddr}
boot_efi_binary=load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} efi/boot/bootaa64.efi; if fdt addr -q ${fdt_addr_r}; then bootefi ${kernel_addr_r} ${fdt_addr_r};else bootefi ${kernel_addr_r} ${fdtcontroladdr};fi
boot_efi_bootmgr=if fdt addr -q ${fdt_addr_r}; then bootefi bootmgr ${fdt_addr_r};else bootefi bootmgr;fi
boot_extlinux=sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}${boot_syslinux_conf}
boot_fdt=try
boot_fit=0
boot_net_usb_start=usb start
boot_prefixes=/ /boot/
boot_rprocs=if test ${dorprocboot} -eq 1 && test ${boot} = mmc; then rproc init; run boot_rprocs_mmc; fi;
boot_rprocs_mmc=env set rproc_id; env set rproc_fw; env set secure_suffix; if test ${secure_rprocs} -eq 1; then env set secure_suffix -sec; fi; for i in ${rproc_fw_binaries} ; do if test -z "${rproc_id}" ; then env set rproc_id $i; else env set rproc_fw $i${secure_suffix}; run rproc_load_and_boot_one; env set rproc_id; env set rproc_fw; fi; done
boot_script_dhcp=boot.scr.uimg
boot_scripts=boot.scr.uimg boot.scr
boot_syslinux_conf=extlinux/extlinux.conf
boot_targets=ti_mmc mmc0 mmc1 usb0 pxe dhcp 
bootcmd=run envboot; run distro_bootcmd;
bootcmd_dhcp=devtype=dhcp; run boot_net_usb_start; if dhcp ${scriptaddr} ${boot_script_dhcp}; then source ${scriptaddr}; fi;setenv efi_fdtfile ${fdtfile}; setenv efi_old_vci ${bootp_vci};setenv efi_old_arch ${bootp_arch};setenv bootp_vci PXEClient:Arch:00011:UNDI:003000;setenv bootp_arch 0xb;if dhcp ${kernel_addr_r}; then tftpboot ${fdt_addr_r} dtb/${efi_fdtfile};if fdt addr -q ${fdt_addr_r}; then bootefi ${kernel_addr_r} ${fdt_addr_r}; else bootefi ${kernel_addr_r} ${fdtcontroladdr};fi;fi;setenv bootp_vci ${efi_old_vci};setenv bootp_arch ${efi_old_arch};setenv efi_fdtfile;setenv efi_old_arch;setenv efi_old_vci;
bootcmd_mmc0=devnum=0; run mmc_boot
bootcmd_mmc1=devnum=1; run mmc_boot
bootcmd_pxe=run boot_net_usb_start; dhcp; if pxe get; then pxe boot; fi
bootcmd_ti_mmc=run findfdt; run init_${boot}; if test ${do_main_cpsw0_qsgmii_phyinit} -eq 1; then run main_cpsw0_qsgmii_phyinit; fi; run boot_rprocs; if test ${boot_fit} -eq 1; then run get_fit_${boot}; run get_fit_overlaystring; run run_fit; else; run get_kern_${boot}; run get_fdt_${boot}; run get_overlay_${boot}; run run_kern; fi;
bootcmd_usb0=devnum=0; run usb_boot
bootdelay=2
bootdir=/boot
bootenvfile=uEnv.txt
bootm_size=0x10000000
bootpart=0:1
bootscript=echo Running bootscript from mmc${mmcdev} ...; source ${loadaddr}
console=ttyS0,115200n8
cpu=armv8
dfu_alt_info=rawemmc raw 0 0x800000 mmcpart 1; rootfs part 0 1; tiboot3.bin.raw raw 0x0 0x800 mmcpart 1; tispl.bin.raw raw 0x800 0x1000 mmcpart 1; u-boot.img.raw raw 0x1800 0x2000 mmcpart 1; u-env.raw raw 0x3800 0x100 mmcpart 1
dfu_alt_info_emmc=rawemmc raw 0 0x800000 mmcpart 1; rootfs part 0 1; tiboot3.bin.raw raw 0x0 0x800 mmcpart 1; tispl.bin.raw raw 0x800 0x1000 mmcpart 1; u-boot.img.raw raw 0x1800 0x2000 mmcpart 1; u-env.raw raw 0x3800 0x100 mmcpart 1
dfu_alt_info_mmc=boot part 1 1; rootfs part 1 2; tiboot3.bin fat 1 1; tispl.bin fat 1 1; u-boot.img fat 1 1; uEnv.txt fat 1 1; sysfw.itb fat 1 1
dfu_alt_info_nand=NAND.tiboot3 part 0 1; NAND.tispl part 0 2; NAND.tiboot3.backup part 0 3; NAND.u-boot part 0 4; NAND.u-boot-env part 0 5; NAND.u-boot-env.backup part 0 6; NAND.file-system part 0 7
dfu_alt_info_ospi=tiboot3.bin raw 0x0 0x100000; tispl.bin raw 0x100000 0x200000; u-boot.img raw 0x300000 0x400000; u-boot-env raw 0x700000 0x020000; rootfs raw 0x800000 0x3800000
dfu_alt_info_ospi_nand=ospi_nand.tiboot3 part 1; ospi_nand.tispl part 2; ospi_nand.u-boot part 3; ospi_nand.env part 4; ospi_nand.env.backup part 5; ospi_nand.rootfs part 6; ospi_nand.phypattern part 7
dfu_alt_info_ram=tispl.bin ram 0x80080000 0x200000; u-boot.img ram 0x81000000 0x400000
distro_bootcmd=for target in ${boot_targets}; do run bootcmd_${target}; done
dorprocboot=0
dtboaddr=0x89000000
efi_dtb_prefixes=/ /dtb/ /dtb/current/
envboot=mmc dev ${mmcdev}; if mmc rescan; then echo SD/MMC found on device ${mmcdev}; if run loadbootscript; then run bootscript; else if run loadbootenv; then echo Loaded env from ${bootenvfile}; run importbootenv; fi; if test -n $uenvcmd; then echo Running uenvcmd ...; run uenvcmd; fi; fi; fi;
eth1addr=70:ff:76:1f:3d:d7
eth2addr=70:ff:76:1f:3d:d8
eth3addr=70:ff:76:1f:3d:d9
ethaddr=1c:63:49:1a:d7:ea
fdt_addr_r=0x88000000
fdtaddr=0x88000000
fdtcontroladdr=fde8d810
fdtoverlay_addr_r=0x89000000
findfdt=if test $board_name = am64x_gpevm; then setenv name_fdt ti/k3-am642-evm.dtb; fi; if test $board_name = am64x_skevm; then setenv name_fdt ti/k3-am642-sk.dtb; fi; if test $name_fdt = undefined; then echo WARNING: Could not determine device tree to use; fi; setenv fdtfile ${name_fdt}
finduuid=part uuid ${boot} ${bootpart} uuid
fw_dev_part=0:1
fw_storage_interface=mmc
get_fdt_mmc=load mmc ${bootpart} ${fdtaddr} ${bootdir}/dtb/${name_fdt}
get_fdt_nand=ubifsload ${fdtaddr} ${bootdir}/${fdtfile};
get_fdt_usb=load usb ${bootpart} ${fdtaddr} ${bootdir}/${name_fdt}
get_fit_config=setexpr name_fit_config gsub / _ conf-${fdtfile}
get_fit_mmc=load mmc ${bootpart} ${addr_fit} ${bootdir}/${name_fit}
get_fit_nand=ubifsload ${addr_fit} ${bootdir}/${name_fit}
get_fit_overlaystring=for overlay in $name_overlays; do; setexpr name_fit_overlay gsub / _ conf-${overlay}; setenv overlaystring ${overlaystring}'#'${name_fit_overlay}; done;
get_fit_usb=load usb ${bootpart} ${addr_fit} ${bootdir}/${name_fit}
get_kern_mmc=load mmc ${bootpart} ${loadaddr} ${bootdir}/${name_kern}
get_kern_nand=ubifsload ${loadaddr} ${bootdir}/${name_kern}
get_kern_usb=load usb ${bootpart} ${loadaddr} ${bootdir}/${name_kern}
get_overlay_mmc=fdt address ${fdtaddr}; fdt resize 0x100000; for overlay in $name_overlays; do; load mmc ${bootpart} ${dtboaddr} ${bootdir}/dtb/ti/${overlay} && fdt apply ${dtboaddr}; done;
get_overlay_nand=fdt address ${fdtaddr}; fdt resize 0x100000; for overlay in $name_overlays; do; ubifsload ${dtboaddr} ${bootdir}/${overlay} && fdt apply ${dtboaddr}; done;
get_overlay_usb=fdt address ${fdtaddr}; fdt resize 0x100000; for overlay in $name_overlays; do; load usb ${bootpart} ${dtboaddr} ${bootdir}/${overlay} && fdt apply ${dtboaddr}; done;
importbootenv=echo Importing environment from mmc${mmcdev} ...; env import -t ${loadaddr} ${filesize}
init_mmc=run args_all args_mmc
init_nand=run args_all args_nand ubi_init
init_usb=run args_all args_usb
kernel_addr_r=0x82000000
load_efi_dtb=load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${prefix}${efi_fdtfile}
loadaddr=0x82000000
loadbootenv=fatload mmc ${mmcdev} ${loadaddr} ${bootenvfile}
loadbootscript=load mmc ${mmcdev} ${loadaddr} boot.scr
loadfdt=load ${devtype} ${bootpart} ${fdtaddr} ${bootdir}/dtb/${fdtfile}
loadimage=load ${devtype} ${bootpart} ${loadaddr} ${bootdir}/${bootfile}
mmc_boot=if mmc dev ${devnum}; then devtype=mmc; run scan_dev_for_boot_part; fi
mmcboot=mmc dev ${mmcdev}; devnum=${mmcdev}; devtype=mmc; if mmc rescan; then echo SD/MMC found on device ${mmcdev}; if run loadimage; then run args_mmc; if test ${boot_fit} -eq 1; then run run_fit; else run mmcloados; fi; fi; fi;
mmcdev=0
mmcloados=if test ${boot_fdt} = yes || test ${boot_fdt} = try; then if run get_fdt_mmc; then bootz ${loadaddr} - ${fdtaddr}; else if test ${boot_fdt} = try; then bootz; else echo WARN: Cannot load the DT; fi; fi; else bootz; fi;
mmcrootfstype=ext4 rootwait
mtdids=nand0=omap2-nand.0
mtdparts=omap2-nand.0:2m(NAND.tiboot3),2m(NAND.tispl),2m(NAND.tiboot3.backup),4m(NAND.u-boot),256k(NAND.u-boot-env),256k(NAND.u-boot-env.backup),-(NAND.file-system)
name_fit=fitImage
name_kern=Image
nandargs=setenv bootargs console=${console} ${optargs} root=${nandroot} rootfstype=${nandrootfstype}
nandboot=echo Booting from nand ...; run nandargs; nand read ${fdtaddr} NAND.u-boot-spl-os; nand read ${loadaddr} NAND.kernel; bootz ${loadaddr} - ${fdtaddr}
nandroot=ubi0:rootfs rw ubi.mtd=NAND.file-system,2048
nandrootfstype=ubifs rootwait
nbootpart=NAND.file-system
nbootvolume=ubi0:rootfs
partitions=name=rootfs,start=0,size=-,uuid=${uuid_gpt_rootfs}
pxefile_addr_r=0x80100000
ramdisk_addr_r=0x88080000
rd_spec=-
rdaddr=0x88080000
rproc_fw_binaries= 0 /lib/firmware/am64-main-r5f0_0-fw 1 /lib/firmware/am64-main-r5f0_1-fw 2 /lib/firmware/am64-main-r5f1_0-fw 3 /lib/firmware/am64-main-r5f1_1-fw
rproc_load_and_boot_one=if load mmc ${bootpart} $loadaddr ${rproc_fw}; then if rproc load ${rproc_id} ${loadaddr} ${filesize}; then rproc start ${rproc_id}; fi; fi
run_fit=run get_fit_config; bootm ${addr_fit}#${name_fit_config}${overlaystring}
run_kern=booti ${loadaddr} ${rd_spec} ${fdtaddr}
scan_dev_for_boot=echo Scanning ${devtype} ${devnum}:${distro_bootpart}...; for prefix in ${boot_prefixes}; do run scan_dev_for_extlinux; run scan_dev_for_scripts; done;run scan_dev_for_efi;
scan_dev_for_boot_part=part list ${devtype} ${devnum} -bootable devplist; env exists devplist || setenv devplist 1; for distro_bootpart in ${devplist}; do if fstype ${devtype} ${devnum}:${distro_bootpart} bootfstype; then part uuid ${devtype} ${devnum}:${distro_bootpart} distro_bootpart_uuid ; run scan_dev_for_boot; fi; done; setenv devplist
scan_dev_for_efi=setenv efi_fdtfile ${fdtfile}; for prefix in ${efi_dtb_prefixes}; do if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${efi_fdtfile}; then run load_efi_dtb; fi;done;run boot_efi_bootmgr;if test -e ${devtype} ${devnum}:${distro_bootpart} efi/boot/bootaa64.efi; then echo Found EFI removable media binary efi/boot/bootaa64.efi; run boot_efi_binary; echo EFI LOAD FAILED: continuing...; fi; setenv efi_fdtfile
scan_dev_for_extlinux=if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${boot_syslinux_conf}; then echo Found ${prefix}${boot_syslinux_conf}; run boot_extlinux; echo EXTLINUX FAILED: continuing...; fi
scan_dev_for_scripts=for script in ${boot_scripts}; do if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${script}; then echo Found U-Boot script ${prefix}${script}; run boot_a_script; echo SCRIPT FAILED: continuing...; fi; done
scriptaddr=0x80000000
secure_rprocs=0
serial#=0000000000000270
soc=k3
stderr=serial@2800000
stdin=serial@2800000
stdout=serial@2800000
ubi_init=ubi part ${nbootpart}; ubifsmount ${nbootvolume};
ubifs_boot=if ubi part ${bootubipart} ${bootubioff} && ubifsmount ubi0:${bootubivol}; then devtype=ubi; devnum=ubi0; bootfstype=ubifs; distro_bootpart=${bootubivol}; run scan_dev_for_boot; ubifsumount; fi
update_to_fit=setenv loadaddr ${addr_fit}; setenv bootfile ${name_fit}
usb_boot=usb start; if usb dev ${devnum}; then devtype=usb; run scan_dev_for_boot_part; fi
usbboot=setenv boot usb; setenv bootpart 0:2; usb start; run findfdt; run init_usb; run get_kern_usb; run get_fdt_usb; run run_kern;
uuid_gpt_rootfs=08226f6b-9c0c-fc4a-b930-c25a77cc7e87
vendor=ti
EOF

echo "Creating uEnv.raw..."
mkenvimage -s 0x20000 -o $DFU_IMG_FOLDER/uEnv.raw $DFU_IMG_FOLDER/uEnv.txt 

echo "Creating rootfs image..."
dd if=/dev/null of=$DFU_IMG_FOLDER/am64x-rootfs.ext4 bs=1M seek=4000
mkfs.ext4 -F $DFU_IMG_FOLDER/am64x-rootfs.ext4 
mkdir $DFU_IMG_FOLDER/tmp
sudo mount -t ext4 $DFU_IMG_FOLDER/am64x-rootfs.ext4 $DFU_IMG_FOLDER/tmp
sudo unsquashfs -f -d $DFU_IMG_FOLDER/tmp/ $ROOTFS_IMG_FILE
sudo umount $DFU_IMG_FOLDER/tmp
rm -rf $DFU_IMG_FOLDER/tmp 

echo "DFU images are created at $DFU_IMG_FOLDER"
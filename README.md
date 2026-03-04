# BUILDING VyOS

The PSL VyOS image can either be built via an automated
top level Makefile (the preferred method) or manually.
The two methods are presented below.

Both ways have to be done inside a suitably prepared Debian12 VM
on an arm64 based Mac or x86 laptop depending on the target.

There was support for arm64 emulation via qemu so you could do
the TI build on an x86 laptop, but this was extremely slow
and not very reliable and should no longer be attemped.

---
### AUTOMATICALLY

In a suitably prepared Debian12 VM or equivalent, type `make help`
for instructions on selecting the targets and displaying the current
target.  In short, you just need to say what kind of
build you want (currently TI TMDS64EVM or generic x86).

Then type `make all`.  If you get an error "`make: command not found`"
install make via `sudo apt install make` .  A full build typically
takes about an hour. After a successful build, you can create a
bootable SDcard image using the command `make sdcard`.

The `maake all` will effectively run all of the build steps in order
except for the `create-sdcardiGOS.sh` (for arm64) since that is interactive,
or writing the live .iso image to a USB stick (for x86).

Do *not* run the make in the background, as there are occasional programs that
may poll stdin leading to your make to get a SIGSTOP signal and stop running.

The Makefile will create checkpoint files so that if something goes
wrong it will try to pick up after the last successful step.
For reference these checkpoint files are:

- `.cont.built` after `./buildvyoscontainer.sh`
- `.kernel.built` after `./build_iGOS_TMDS64EVM_kernel.sh`
  with stdout/stderr stored to `kernel.ERR`
- `.filesystem.built` after `build_iGOS_TMDS64EVM_fs.sh`
  with stdout/stderr output stored to `filesystem.ERR`
- `.image.built` after `./buildiGOSti.sh` (for arm64).

Also, `build_iGOS_TMDS64EVM_fs.sh` creates its own checkpoints with
names of the form `.filesystem.*.built` so that it can too can
attempt to restart after an unexpected failure.  This is not always
reliable though, so a `make clean` followed by a new build is typically
safest.

There is also a `./build-psleng-github-io.sh` for populating the
psleng.github.io .deb binary repository, but most people will
not need to do that not need that. The automated daily build
normally keeps that repository up to date.

For reference, the normal command is:

	./build-psleng-github-io.sh --repo https://github.com/psleng

Note. You *must* use the psleng account for this so that signing works
and also know the signing password!

---
### MANUALLY

The following steps have been tested for TMDS64EVM only.

Do the following steps in order.  Note that two of the steps
are done inside a Docker container (via `rundocker.sh`) which
you must then exit to do the remaining steps.

```sh
	./buildvyoscontainer.sh

	./rundocker.sh

	./build_iGOS_TMDS64EVM_kernel.sh --repo https://github.com/psleng --clean

	./build_iGOS_TMDS64EVM_fs.sh --repo https://github.com/psleng

	exit

	sudo ./buildiGOSti.sh bookworm-am64xx-evm

	sudo ./ti-bdebstrap/create-sdcardiGOS.sh bookworm-am64xx-evm
```

---
## How to Generate Flashing Images (make dfuimg)

Before using JTAG, TFTP, or DFU flashing methods, you must generate the necessary binary images.

1) **Build the Image**: Compile your project to generate the base binaries.
2) **Generate Flashing Files**: Run the following command:

```Bash
make dfuimg
```

This command performs the following:

- Creates a `dfu-images/` folder containing the bootloaders, U-Boot images and rootfs.ext4.

- Creates a `dfu-images/sptimg/` subfolder.

- Automatically splits the large RootFS file into 512MB chunks (e.g., `am64x-rootfs.aa`, `am64x-rootfs.ab`, etc.) for use in the TFTP update procedure.

## How to Flash eMMC via JTAG (XDS110)

This procedure allows for initial flashing or recovery of the eMMC using a JTAG connection.

1) Requirements

- **XDS110 Debug Probe** connected to the target JTAG port.
- **[iolan-tool](https://github.com/Perle-Systems-Limited/iolan-tool)**: The primary automation script.
- **Images**: Uses the U-boot images generated in the `dfu-images/` folder 

2) Note on Source Code

The `iolan-tool` contains **prebuilt binaries** for the initialization and flashing applications. You only need to clone/build the following repositories if you intend to modify the underlying JTAG logic:
- [iolan-ccs_init](https://github.com/Perle-Systems-Limited/iolan-ccs_init): SoC/DDR initialization code.
- [iolan-flasher](https://github.com/Perle-Systems-Limited/iolan-flasher): The CCS-based flashing application.

3) Procedure

- Ensure Code Composer Studio (CCS) and XDS110 drivers are installed.
- Connect the XDS110 to the target.
- Make sure the boot mode is configured to **DEV Boot mode**
- Run the **iolan-tool** script (**[flash_emmc.js](https://github.com/Perle-Systems-Limited/iolan-tool/blob/master/flash_emmc.js)**). It will initialize the SoC using the prebuilt `iolan-ccs_init` and then stream the images from `dfu-images/` to the eMMC via `iolan-flasher`. Refer to iolan-tool's **[README.md](https://github.com/Perle-Systems-Limited/iolan-tool/blob/master/README.md)** for more details.

---
## How to Flash RootFS via TFTP (U-Boot)

Once the bootloaders are flashed and you can reach the U-Boot prompt (`IOLAN-2A >`), use this method to flash the RootFS over the network.

1) Network Configuration

In the U-Boot console, set your network parameters:

```Bash
setenv ipaddr 192.168.1.10
setenv serverip 192.168.1.100
setenv gatewayip 192.168.1.1
setenv netmask 255.255.255.0
ping $serverip
```

2) Flashing Script (Copy & Paste)
Copy the split files from `dfu-images/sptimg/` to your TFTP server root. Then, run these commands in U-Boot:

```Bash
# 1. Basic variables
setenv loadaddr 0xC0000000
setenv chunk_blocks 0x100000
setenv start_block 0x22

# 2. Helper macro
setenv flash_chunk 'tftp ${loadaddr} ${fname}; mmc write ${loadaddr} ${next_block} ${chunk_blocks}; setexpr next_block ${next_block} + ${chunk_blocks}'

# 3. Define sequences (Split to avoid buffer limits)
setenv flash_seq_1 'setenv next_block ${start_block}; setenv fname am64x-rootfs.aa; run flash_chunk; setenv fname am64x-rootfs.ab; run flash_chunk; setenv fname am64x-rootfs.ac; run flash_chunk; setenv fname am64x-rootfs.ad; run flash_chunk'
setenv flash_seq_2 'setenv fname am64x-rootfs.ae; run flash_chunk; setenv fname am64x-rootfs.af; run flash_chunk; setenv fname am64x-rootfs.ag; run flash_chunk; setenv fname am64x-rootfs.ah; run flash_chunk'

# 4. Final trigger
setenv flash_full 'gpt write mmc 0 ${partitions}; mmc dev 0; run flash_seq_1; run flash_seq_2; echo !!! ALL PARTS FLASHED SUCCESSFULLY !!!'
```

3) Execute Update

```Bash
run flash_full
```

---
## How to DFU (Device Firmware Update)

### Preparation: Build Images

1. **Build the Image:** Compile your project to generate the necessary binary files.

- Upon a successful build, verify the presence of the `build` and `images` folders in your project directory.

2. **Create DFU Images:** Run the following command to package the binaries for DFU:

```
	make dfuimg
```

- This command creates the `dfu-images` folder, containing all files required for the flashing process.

### Step 1: Initial DFU Transfer (Bootloader)

This step sends the initial bootloader to the device's RAM via DFU to enable further communication.

1. **Set DFU Boot Mode:** Configure the target device's **DIP switches** to the DFU boot mode setting: `1100 1010 0000 0000`.

2. **Connect Device:** Connect the board to your Linux host server using both the `USB0` (for DFU) and `UART USB` cables.

3. **Verify DFU Connection:** Check if the device is visible to the host using `dfu-util:`

```
	sudo dfu-util -l

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -l
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		Found DFU: [0451:6165] ver=0200, devnum=45, cfg=1, intf=0, path="1-3", alt=1, name="SocId", serial="01.00.00.00"
		Found DFU: [0451:6165] ver=0200, devnum=45, cfg=1, intf=0, path="1-3", alt=0, name="bootloader", serial="01.00.00.00"
```

Look for a result showing an interface name of `bootloader` and the correct vendor/product ID (e.g., `[0451:6165]`).

4. **Send Initial Bootloader (tiboot3.bin):** Transfer the first bootloader file. The `-R` flag resets the device after the transfer.

```
	sudo dfu-util -R -a bootloader -D tiboot3.bin

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -R -a bootloader -D tiboot3.bin
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #0 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 512
		Copying data from PC to DFU device
		Download	[=========================] 100%       611710 bytes
		Download done.
		DFU state(6) = dfuMANIFEST-SYNC, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!
		dfu-util: can't detach
		Resetting USB to switch back to Run-Time mode
```

5. **Confirm DFU Mode on UART:** Monitor the UART console output. You must see the message `Trying to boot from DFU`. If you don't see it, repeat the previous command (`sudo dfu-util -R -a bootloader -D tiboot3.bin`).

```
	example UART output>
		U-Boot SPL 2023.04-dirty (Nov 24 2025 - 17:32:23 +0000)
		Resetting on cold boot to workaround ErrataID:i2331
		Please resend tiboot3.bin in case of UART/DFU boot
		resetting ...

		U-Boot SPL 2023.04-dirty (Nov 24 2025 - 17:32:23 +0000)
		SYSFW ABI: 3.1 (firmware rev 0x0009 '9.2.8--v09.02.08 (Kool Koala)')
		SPL initial stack usage: 13392 bytes
		Trying to boot from DFU
```

### Step 2: Transfer SPL and U-Boot to RAM
Once in DFU mode, transfer the secondary program loader (SPL) and U-Boot files to the device's RAM.

1. **Verify New DFU Connection:** Run `dfu-util -l` again. The device should now show alternate interfaces named `tispl.bin` and `u-boot.img`, indicating it's ready for the next stage of boot files.

```
	sudo dfu-util -l

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -l
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		Found DFU: [0451:6165] ver=0224, devnum=42, cfg=1, intf=0, path="1-3", alt=1, name="u-boot.img", serial="UNKNOWN"
		Found DFU: [0451:6165] ver=0224, devnum=42, cfg=1, intf=0, path="1-3", alt=0, name="tispl.bin", serial="UNKNOWN"
```

2. **Send** `tispl.bin`: Transfer the SPL file.

```
	sudo dfu-util -R -a tispl.bin -D tispl.bin

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -R -a tispl.bin -D tispl.bin
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #0 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%       978027 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!
		Resetting USB to switch back to Run-Time mode

	example UART output>
		################################################DOWNLOAD ... OK
		Ctrl+C to exit ...
		Authentication passed
		Authentication passed
		Loading Environment from MMC... *** Warning - No MMC card found, using default environment

		init_env from device 10 not supported!
		Authentication passed
		Authentication passed
		Starting ATF on ARM64 core...

		NOTICE:  BL31: v2.10.0(release):v2.10.0-367-g00f1ec6b8
		NOTICE:  BL31: Built : 17:32:05, Nov 24 2025
		I/TC:
		I/TC: OP-TEE version: 4.5.0 (gcc version 12.2.0 (Debian 12.2.0-14+deb12u1)) #1 Mon Nov 24 17:32:16 UTC 2025 aarch64
		I/TC: WARNING: This OP-TEE configuration might be insecure!
		I/TC: WARNING: Please check https://optee.readthedocs.io/en/latest/architecture/porting_guidelines.html
		I/TC: Primary CPU initializing
		I/TC: GIC redistributor base address not provided
		I/TC: Assuming default GIC group status and modifier
		I/TC: SYSFW ABI: 3.1 (firmware rev 0x0009 '9.2.8--v09.02.08 (Kool Koala)')
		I/TC: Activated SA2UL device
		I/TC: Enabled firewalls for SA2UL TRNG device
		I/TC: SA2UL TRNG initialized
		I/TC: SA2UL Drivers initialized
		I/TC: HUK Initialized
		I/TC: Primary CPU switching to normal world boot

		U-Boot SPL 2023.04-dirty (Nov 24 2025 - 17:32:42 +0000)
		SYSFW ABI: 3.1 (firmware rev 0x0009 '9.2.8--v09.02.08 (Kool Koala)')
		Trying to boot from DFU
```

3. **Send** `u-boot.img`: Transfer the U-Boot image. **Be ready to press a key immediately after this transfer to stop autoboot.**

```
	sudo dfu-util -R -a u-boot.img -D u-boot.img

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -R -a u-boot.img -D u-boot.img
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #1 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%      1332607 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!
		Resetting USB to switch back to Run-Time mode
```

4. **Stop Autoboot:** Press `any key` in the UART console to enter the U-Boot prompt (`=>`) before it attempts to boot the operating system.

```
	example UART output>
		######DOWNLOAD ... OK
		Ctrl+C to exit ...
		Authentication passed
		Authentication passed

		U-Boot 2023.04-dirty (Nov 24 2025 - 17:32:42 +0000)

		SoC:   AM64X SR2.0 HS-FS
		Model: Texas Instruments AM642 EVM
		Board: AM64-EVM rev C
		DRAM:  2 GiB
		Core:  91 devices, 32 uclasses, devicetree: separate
		NAND:  0 MiB
		MMC:   mmc@fa10000: 0, mmc@fa00000: 1
		Loading Environment from MMC... OK
		In:    serial@2800000
		Out:   serial@2800000
		Err:   serial@2800000
		Net:   eth3: icssg1-eth, eth0: ethernet@8000000port@1
		Hit any key to stop autoboot:  2  1  0
		=>
```

### Step 3: Partition eMMC and Enter Flashing DFU Mode

The U-Boot environment is now loaded in RAM. This step partitions the eMMC and re-enters DFU mode, but configured for eMMC flashing.

1. **Partition eMMC:** Use the `gpt write` command in the U-Boot console to set up the partitions (the `${partitions}` variable should be defined in your build environment).

```
	gpt write mmc 0 ${partitions}
```

2. **Set DFU Configuration for eMMC:** Set the environment variable to define the eMMC-specific DFU alt-info.

```
	setenv dfu_alt_info ${dfu_alt_info_emmc}
```

3. **Enter eMMC Flashing DFU Mode:** Start the DFU process within U-Boot, which exposes the eMMC partitions over USB.

```
	dfu 0 mmc 0

	example UART output>
		=> gpt write mmc 0 ${partitions}
		Writing GPT: success!

		=> setenv dfu_alt_info ${dfu_alt_info_emmc}
		=> print dfu_alt_info
		dfu_alt_info=rawemmc raw 0 0x800000 mmcpart 1; rootfs part 0 1; tiboot3.bin.raw raw 0x0 0x800 mmcpart 1; tispl.bin.raw raw 0x800 0x1000 mmcpart 1; u-boot.img.raw raw 0x1800 0x2000 mmcpart 1; u-env.raw raw 0x3800 0x100 mmcpart 1

		=> dfu 0 mmc 0
```

### Step 4: Flash Images to eMMC

The host PC is now ready to detect the eMMC partitions for flashing.

1. **Verify eMMC DFU Partitions:** Run `dfu-util -l` one last time on the host. You should see multiple alternate interfaces representing the eMMC partitions (e.g., `tiboot3.bin.raw`, `tispl.bin.raw`, `u-boot.img.raw`, `rootfs`).

```
	sudo dfu-util -l

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -l
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		Found DFU: [0451:6165] ver=0224, devnum=49, cfg=1, intf=0, path="1-3", alt=5, name="u-env.raw", serial="0000000000000270"
		Found DFU: [0451:6165] ver=0224, devnum=49, cfg=1, intf=0, path="1-3", alt=4, name="u-boot.img.raw", serial="0000000000000270"
		Found DFU: [0451:6165] ver=0224, devnum=49, cfg=1, intf=0, path="1-3", alt=3, name="tispl.bin.raw", serial="0000000000000270"
		Found DFU: [0451:6165] ver=0224, devnum=49, cfg=1, intf=0, path="1-3", alt=2, name="tiboot3.bin.raw", serial="0000000000000270"
		Found DFU: [0451:6165] ver=0224, devnum=49, cfg=1, intf=0, path="1-3", alt=1, name="rootfs", serial="0000000000000270"
		Found DFU: [0451:6165] ver=0224, devnum=49, cfg=1, intf=0, path="1-3", alt=0, name="rawemmc", serial="0000000000000270"
```

2. **Transfer Images to eMMC:** Run the following commands to write the bootloaders, environment, and root filesystem to the corresponding eMMC partitions (`-a` specifies the target partition name, `-D` specifies the local file).

```
	# Transfer Bootloaders
	sudo dfu-util -a tiboot3.bin.raw -D tiboot3.bin
	sudo dfu-util -a tispl.bin.raw -D tispl.bin
	sudo dfu-util -a u-boot.img.raw -D u-boot.img

	# Transfer U-Boot Environment
	sudo dfu-util -a u-env.raw -D uEnv.raw

	# Transfer Root Filesystem
	sudo dfu-util -a rootfs -D am64x-rootfs.ext4

	example>
		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -a tiboot3.bin.raw -D tiboot3.bin
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #2 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%       611710 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!

		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -a tispl.bin.raw -D tispl.bin
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #3 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%       978027 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!

		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -a u-boot.img.raw -D u-boot.img
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #4 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%      1332607 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!

		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -a u-env.raw -D uEnv.raw
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #5 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%       131072 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!

		jack@hw-ubuntu24:~/project/am64x/nexus-build/dfu-images$ sudo dfu-util -a rootfs -D am64x-rootfs.ext4
		dfu-util 0.11

		Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
		Copyright 2010-2021 Tormod Volden and Stefan Schmidt
		This program is Free Software and has ABSOLUTELY NO WARRANTY
		Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

		dfu-util: Warning: Invalid DFU suffix signature
		dfu-util: A valid DFU suffix will be required in a future dfu-util release
		Opening DFU capable USB device...
		Device ID 0451:6165
		Device DFU version 0110
		Claiming USB DFU Interface...
		Setting Alternate Interface #1 ...
		Determining device status...
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		DFU mode device DFU version 0110
		Device returned transfer size 4096
		Copying data from PC to DFU device
		Download	[=========================] 100%   4194304000 bytes
		Download done.
		DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
		DFU state(2) = dfuIDLE, status(0) = No error condition is present
		Done!
```

### Step 5: Final Configuration and Boot

Perform the final configuration and switch the device to boot from the newly flashed eMMC.

1. **Set Boot Configuration (First Time Only):** In the **UART console** (U-Boot environment), run these commands to allow the ROM to access the eMMC boot partition:

```
	mmc partconf 0 1 1 1
	mmc bootbus 0 2 0 0
```

2. **Set eMMC Boot Mode:** Configure the target device's DIP switches to the eMMC boot mode setting: `1101 0010 0000 0000`.

3. **Power Cycle:** Recycle the power to the board. The device should now boot from the eMMC using the newly flashed images.

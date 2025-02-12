# BUILDING VyOS

The PSL VyOS image can either be built via an automated
top level Makefile (the preferred method) or manually.
The two methods are presented below.

Both ways have to be done inside a suitably prepared Debian12 VM
on an arm64 based Mac or x86 laptop depending on the target.

The was support for arm64 emulation so you could do the TI build
on an x86 laptop, but this was extremely slow and not very reliable
and should no longer be attemped.

---
### AUTOMATICALLY

In a suitably prepared Debian12 VM or equivalent, type `make help`
for instructions.  In short, you just need to say what kind of
build you want (currently TI TMDS64EVM or generic x86).

Then type `make all`.  If you get an error "`make: command not found`"
install make via `sudo apt install make` .  A full build typically
takes about an hour.

This will effectively run all of the build steps in order
except for the `create-sdcard.sh` (for arm64) since that is interactive,
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

	sudo ./create-sdcard.sh bookworm-am64xx-evm
```

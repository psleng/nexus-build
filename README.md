# BUILDING VyOS

The PSL VyOS image can either be built manually or via an
automated top level Makefile.  The two methods are presented below.

Both ways have to be done inside a suitably prepared Debian12 VM.

### MANUALLY

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

To re-create the psleng.github.io apt binary repository do this.
Note. You *must* use the psleng account for this so that signing works:

	./build-psleng-github-io.sh --repo https://github.com/psleng



### AUTOMATICALLY

In a suitably prepared Debian12 VM or equivalent, type `make all`.
If you get an error "`make: command not found`" install make via
`sudo apt install make`

This will effectively run all of the the above steps in order
except for the `create-sdcard.sh` since that is interactive.
and `./build-psleng-github-io.sh` since most people do not need that.

Do *not* run it in the background, as there are occasional programs that
may poll stdin leading to your make to get a SIGSTOP signal and stop running.

The Makefile will create checkpoint files so that if something goes
wrong it will try to pick up after the last successful step.
For reference these checkpoint files are:

- `.cont.built` after `./buildvyoscontainer.sh`
- `.kernel.built` after `./build_iGOS_TMDS64EVM_kernel.sh`
  with stdout/stderr stored to `kernel.ERR`
- `.filesystem.built` after `build_iGOS_TMDS64EVM_fs.sh`
  with stdout/stderr output stored to `filesystem.ERR`
- `.image.built` after `./buildiGOSti.sh`

Also, `build_iGOS_TMDS64EVM_fs.sh` creates its own checkpoints with
names of the form `.filesystem.*.built` so that it can too can
attempt to restart after an unexpected failure.

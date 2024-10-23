#
# Make PSL VyOS
#
# This attempts to encapsulate the README.md steps,
# except for the final writing to uSDcard.
#

REPO := https://github.com/psleng 

# Quasi targets
KERNEL_TARG   = .kernel.built
FS_TARG       = .filesystem.built
DRIVERS_TARG  = .drivers.built
IMAGE_TARG    = .image.built

# All targets
TARGS = $(KERNEL_TARG) $(FS_TARG) $(DRIVERS_TARG) $(IMAGE_TARG)

# A valid builds entry from builds.toml
BUILDTYPE = am64x_bookworm_09.00.00.006

.PHONY: help all sdcard clean

help:
	@echo 'Type "make all" to build an image.  This takes a very long time.'
	@echo 'Once complete, type "make sdcard" write to an sdcard.'
	@echo
	@echo 'Type "make clean" for a fresh start.'

all: $(IMAGE_TARG)

# Run a docker session.
define DOCKRUN
	@echo '### Making $(1) using $(2) for target $@. Check $(1).ERR for status.'
	./rundocker.sh /bin/sh -c 'sudo $(2) --repo $(REPO)' > $(1).ERR 2>&1
	@touch $@
endef

# Build the arm64 VyOS building container image
vyos-build-container:
	@echo '### Making build container image ($@)'
	docker image inspect vyos/vyos-build:current-arm64v8 > /dev/null 2>&1 || ./buildvyoscontainer.sh

# Build the kernel
$(KERNEL_TARG): vyos-build-container
	@$(call DOCKRUN,kernel,./build_iGOS_TMDS64EVM_kernel.sh)

# Build the root filesystem
$(FS_TARG): vyos-build-container $(KERNEL_TARG)
	@$(call DOCKRUN,filesystem,./build_iGOS_TMDS64EVM_fs.sh)

# Build drivers
$(DRIVERS_TARG): vyos-build-container $(FS_TARG)
	@$(call DOCKRUN,drivers,./build_iGOS_drivers.sh)

# Create a uSDcard image
$(IMAGE_TARG): $(DRIVERS_TARG)
	@echo '### Making uSDcard image'
	sudo ./buildiGOSti.sh $(BUILDTYPE)
	@touch $@

# Write to a uSDcard.
sdcard: $(IMAGE_TARG)
	@echo '### Making $@'
	sudo ./create-sdcard.sh $(BUILDTYPE)

# clean. TODO should also make a distclean target.
clean:
	sudo rm -rf vyos-build vyos-build-container $(TARGS)
	docker image rm vyos/vyos-build:current-arm64v8 || true
	rm -f *.ERR

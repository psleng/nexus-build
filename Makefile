#
# Make PSL VyOS
#
# This attempts to encapsulate the README.md steps,
# except for the final writing to uSDcard.
#

# Quasi targets
CONT_TARG     = .cont.built
KERNEL_TARG   = .kernel.built
FS_TARG       = .filesystem.built
IMAGE_TARG    = .image.built

# A valid builds entry from builds.toml
BUILDTYPE = bookworm-am64xx-evm

# Base repository to use for all container build recipies.
REPO := https://github.com/psleng

.PHONY: help all sdcard clean

help:
	@echo 'Type "make all" to build an image.  This takes a very long time.'
	@echo 'You might want to do it in a "script" session to save output.'
	@echo 'Once complete, type "make sdcard" write to an sdcard.'
	@echo
	@echo 'Type "make clean" for a fresh start.'

all: $(IMAGE_TARG)

# Run a docker session.
define DOCKRUN
	@echo "### $$(date --iso-8601=s): Making $(1) using $(2) for target $@. Check $(1).ERR for status."
	./rundocker.sh script -e -c '$(2) --repo $(REPO)' $(1).ERR
	@echo "### $$(date --iso-8601=s): Making $(1) using $(2) for target $@ COMPLETED"
	@touch $@
endef

# Build the arm64 VyOS building container image
$(CONT_TARG):
	@echo ### Making build container image ($@)'
	./buildvyoscontainer.sh
	@touch $@

# Build the kernel
$(KERNEL_TARG): $(CONT_TARG)
	@$(call DOCKRUN,kernel,./build_iGOS_TMDS64EVM_kernel.sh)

# Build the root filesystem
$(FS_TARG): $(KERNEL_TARG)
	@$(call DOCKRUN,filesystem,./build_iGOS_TMDS64EVM_fs.sh)

# Create a uSDcard image
$(IMAGE_TARG): $(FS_TARG)
	@echo '### Making uSDcard image'
# This invalid directory sometimes appears breaking git ops on build
	@if [ -d ~root/.gitconfig ]; then sudo rm -rf ~root/.gitconfig; fi
	@$(call DOCKRUN,image,./buildiGOSti.sh $(BUILDTYPE))
	#script -e -c './buildiGOSti.sh $(BUILDTYPE)' buildiGOSti.ERR
	@ls -l build/$(BUILDTYPE)/tisdk*.tar.xz
	@echo '### Making uSDcard image COMPLETED'
	@echo '### Type "make sdcard" to write to an uSD card'
	@touch $@

# Write to a uSDcard.
sdcard: $(IMAGE_TARG)
	@echo '### Making $@'
	sudo ./create-sdcard.sh $(BUILDTYPE)
	@echo '### Making $@ COMPLETED'

# View state of build
status:
	@ls -ltr .*built

# Clean everything
clean: buildclean
	rm -f *.ERR .*.built
	docker image rm vyos/vyos-build:current-arm64v8 || true

# Clean build artifacts only
buildclean:
	sudo rm -rf vyos-build vyos-build-container build debian-repos drivers logs tools configs scripts builds.toml create-sdcard.sh

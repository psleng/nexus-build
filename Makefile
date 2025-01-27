#
# Make PSL VyOS
#
# This attempts to encapsulate the README.md steps,
# except for the final writing to uSDcard.
#

# Do not use implicit rules or variables to reduce confusion
MAKEFLAGS += -rR

# Build definitions.  Contents should be VAR=val format
# so that it can also be sourced by shell scripts.
DEFS := .defs.mk
-include $(DEFS)

# Quasi targets
CONT_TARG     = .cont.built
KERNEL_TARG   = .kernel.built
FS_TARG       = .filesystem.built
IMAGE_TARG    = .image.built

help:
	@echo First select a build type.  Valid types are:
	@echo
	@echo '    make targ-ti-evm # TI evaluation module (default)'
	@echo '    make targ-x86    # x86'
	@echo
	@echo Then type "make all".  Type "make clean" for a clean start.
	@echo You will have to reselect the build type after doing that.
	@echo
	@if [ -s "$(DEFS)" ]; then \
	    echo "The current build settings ($(DEFS)) are:"; \
	    cat $(DEFS); \
	fi

# target build: TI eval board (default)
# BUILDTYPE is a builds entry from ti-bdebstrap/builds.toml
$(DEFS) targ-ti-evm:
	@echo BUILDTARG=ti-evm > $(DEFS)
	@echo BUILDTYPE=bookworm-am64xx-evm >> $(DEFS)

# target build: x86_64
targ-x86:
	@echo BUILDTARG=x86_64 > $(DEFS)


# Base repository to use for all container build recipes.
REPO := https://github.com/psleng

ARCH := $(shell dpkg-architecture -qDEB_HOST_ARCH)
# Different image tag for docker vyos/vyos-build image
ifeq ($(ARCH),arm64)
	IMGTAG := current-arm64
else
	IMGTAG := latest
endif

.PHONY: help all sdcard status clean buildclean targ-ti-evm targ-x86

all: $(DEFS) $(IMAGE_TARG)

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
ifeq ($(BUILDTARG),x86_64)
	@echo "### Skipping $@ because BUILDTARG=$(BUILDTARG)"
	@echo "### The final .iso image should be here:"
	@ISO=vyos-build/build/live-image-$(ARCH).hybrid.iso; if [ -f $$ISO ]; then ls -l `realpath $$ISO`; else echo "Error: $$ISO not found!"; fi
else
	@echo '### Making uSDcard image'
# This invalid directory sometimes appears breaking git ops on build
	@if [ -d ~root/.gitconfig ]; then sudo rm -rf ~root/.gitconfig; fi
	@$(call DOCKRUN,image,./buildiGOSti.sh $(BUILDTYPE))
	@ls -l build/$(BUILDTYPE)/tisdk*.tar.xz
	@echo '### Making uSDcard image COMPLETED'
	@echo '### Type "make sdcard" to write to an uSD card'
	@touch $@
endif

# Write to a uSDcard.
sdcard: $(IMAGE_TARG)
ifeq ($(BUILDTARG),x86_64)
	@echo "### Skipping $@ because BUILDTARG=$(BUILDTARG)"
else
	@echo '### Making $@'
	sudo ti-bdebstrap/create-sdcardiGOS.sh $(BUILDTYPE)
	@echo '### Making $@ COMPLETED'
endif

# View state of build
status:
	@ls -ltr .*built

# Clean everything
clean: buildclean
	rm -f *.ERR .*.built $(DEFS)
	docker image rm vyos/vyos-build:$(IMGTAG) || true
	@echo 'Cleaning up docker garbage. This could take several minutes.'
	docker system prune -f

# Clean build artifacts only
buildclean:
	sudo rm -rf vyos-build build debian-repos ti-bdebstrap drivers logs tools configs scripts builds.toml

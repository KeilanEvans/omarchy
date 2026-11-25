.DEFAULT_GOAL := help

CHANNEL ?= edge
PROFILE ?=
ENGINE ?=
NO_AUR ?= 0
FORCE ?= 0
UNATTENDED ?= iso/unattended.env.example

ISO_FLAGS := --channel $(CHANNEL)
ifneq ($(ENGINE),)
  ISO_FLAGS += --engine $(ENGINE)
endif
ifeq ($(NO_AUR),1)
  ISO_FLAGS += --no-aur
endif

APPLY_FLAGS :=
ifneq ($(PROFILE),)
  APPLY_FLAGS += --profile $(PROFILE)
endif
ifeq ($(FORCE),1)
  APPLY_FLAGS += --force
endif

.PHONY: help iso iso-edge iso-fast iso-rebuild test-iso test-iso-unattended test-vm-boot \
        clean clean-all apply pull-upstream check packages check-themes

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

iso: ## Build offline x86_64 ISO (vars: CHANNEL=stable|rc|edge, NO_AUR=0|1, ENGINE=docker|podman)
	./iso/build $(ISO_FLAGS)

iso-edge: ## Build offline x86_64 ISO from Omarchy edge channel
	./iso/build --channel edge $(if $(ENGINE),--engine $(ENGINE),)

iso-fast: ## Build offline x86_64 ISO skipping AUR builds for fast iteration
	./iso/build --channel $(CHANNEL) --no-aur $(if $(ENGINE),--engine $(ENGINE),)

iso-rebuild: clean-all iso ## Wipe all caches/artifacts and rebuild the ISO from scratch

test-iso: ## Boot the newest built ISO in a fresh QEMU UEFI VM
	./iso/test-vm --fresh-disk

test-iso-unattended: ## Boot the newest ISO in QEMU using UNATTENDED=<env-file>
	./iso/test-vm --fresh-disk --unattended "$(UNATTENDED)"

test-vm-boot: ## Boot the already-installed QEMU VM disk without the ISO attached
	./iso/test-vm --boot-disk

clean: ## Remove built ISOs, working trees, and VM disks (keeps pacman/AUR cache)
	rm -rf iso/release iso/work iso/out iso/.cache/*.qcow2 iso/.cache/*.fd iso/.cache/cidata-*.img

clean-all: ## Remove ALL build files, ISOs, VM disks, and pacman/AUR caches
	rm -rf iso/release iso/work iso/out iso/.cache

apply: ## Apply Overlay to the current machine (vars: PROFILE=desktop|laptop, FORCE=0|1)
	./overlay/apply $(APPLY_FLAGS)

pull-upstream: ## Fetch and merge upstream Omarchy quattro into this fork
	git fetch upstream
	git merge upstream/quattro

check: ## Validate script syntax, Package Policy resolution, and gitignore hygiene
	@bash -n \
	  overlay/lib/packages.sh \
	  overlay/apply \
	  overlay/hooks/post-install.d/*.sh \
	  overlay/hooks/post-update.d/*.sh \
	  overlay/config/omarchy/hooks/theme-set.d/*.sh \
	  iso/build \
	  iso/builder/entrypoint.sh \
	  iso/test-vm \
	  iso/archiso/airootfs/usr/local/bin/omarchy-custom-install \
	  iso/archiso/airootfs/etc/profile.d/99-omarchy-installer.sh
	@bash -c 'set -euo pipefail; source overlay/lib/packages.sh; \
	  off=$$(overlay_resolved_install_packages "$$PWD" "$$PWD/overlay" "$(PROFILE)" | wc -l); \
	  aur=$$(overlay_aur_packages "$$PWD/overlay" "$(PROFILE)" | wc -l); \
	  fp=$$(overlay_read_list "$$PWD/overlay/packages/flatpak.txt" | wc -l); \
	  ex=$$(overlay_excluded_packages "$$PWD/overlay" "$(PROFILE)" | wc -l); \
	  echo "Syntax OK | Official: $$off | AUR: $$aur | Flatpak: $$fp | Excluded: $$ex"'
	@git check-ignore iso/release/test.iso iso/.cache/aur/test.pkg.tar.zst iso/.cache/vm-disk.qcow2 >/dev/null
	@echo "Gitignore OK (ISO build artifacts and caches are ignored)"

packages: ## Print resolved official, AUR, Flatpak, and excluded package lists (var: PROFILE=...)
	@bash -c 'set -euo pipefail; source overlay/lib/packages.sh; \
	  echo "=== Official / Omarchy packages (profile: $(or $(PROFILE),base)) ==="; \
	  overlay_resolved_install_packages "$$PWD" "$$PWD/overlay" "$(PROFILE)"; \
	  echo ""; echo "=== AUR packages ==="; \
	  overlay_aur_packages "$$PWD/overlay" "$(PROFILE)"; \
	  echo ""; echo "=== Flatpak entries ==="; \
	  overlay_read_list "$$PWD/overlay/packages/flatpak.txt"; \
	  echo ""; echo "=== Excluded packages ==="; \
	  overlay_excluded_packages "$$PWD/overlay" "$(PROFILE)"'

check-themes: ## Validate all Overlay themes with omarchy agent look theme
	@for t in overlay/themes/*/; do \
	  echo "=== $$(basename "$$t") ==="; \
	  OMARCHY_PATH="$$PWD" ./bin/omarchy-agent-look-theme "$$PWD/$$t"; \
	done

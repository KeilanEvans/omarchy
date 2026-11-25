# Custom Omarchy Overlay & ISO Runbook

This runbook documents every day-to-day workflow for maintaining this self-contained Omarchy Quattro fork: pulling upstream changes, customizing packages and Material UI v9 themes, building offline x86_64 ISOs, verifying them in QEMU, and syncing changes to already-installed machines.

See [GLOSSARY.md](../GLOSSARY.md) for canonical terminology and [docs/adr/](adr/) for the architectural decisions behind this layout.

## Quick Commands (`Makefile`)

Run `make` (or `make help`) at the repo root to see all shortcuts:

- `make iso` / `make iso-edge` / `make iso-fast` — build the offline ISO (or `make iso-rebuild` to wipe caches and rebuild from scratch)
- `make test-iso` / `make test-iso-unattended` / `make test-vm-boot` — test the ISO or installed disk in QEMU
- `make clean` / `make clean-all` — remove build outputs/VM disks, or wipe pacman/AUR caches too
- `make apply` (`PROFILE=desktop`) — sync Overlay configs, themes, and Package Policy on a live machine
- `make pull-upstream` — fetch and merge `upstream/quattro`
- `make check` / `make packages` / `make check-themes` — validate syntax, inspect resolved packages, and check all Material UI v9 themes

## Repository Layout

All customizations and ISO tooling live exclusively under `overlay/` and `iso/` so **Upstream** files stay untouched:

- `overlay/packages/` — **Package Policy** (`add.txt`, `exclude.txt`, `aur.txt`)
- `overlay/profiles/<name>/` — optional machine **Profiles** (`desktop`, `laptop`, etc.)
- `overlay/themes/` — static Material UI v9 themes (`colors.toml`, wallpapers, optional templates) and `default` theme name
- `overlay/config/` — user config/dotfile overrides mirroring `~/.config/`
- `overlay/etc/pacman-noextract.conf` — pacman `NoExtract` rules (suppresses built-in upstream themes)
- `overlay/hooks/` — `post-install.d/` and `post-update.d/` hooks
- `overlay/apply` — applies the **Overlay** at install time (`--install-mode`) or on a live system
- `iso/build` — containerized `archiso` + **Offline Mirror** builder (outputs to `iso/release/`)
- `iso/test-vm` — local QEMU UEFI VM runner
- `iso/.gitignore` — ignores all build artifacts, caches, ISOs, packages, and VM disks so they are never committed

## 1. Pulling Upstream Omarchy Changes

This repo tracks upstream `omacom/omarchy` (`quattro`) via the `upstream` git remote. Because upstream files are untouched, merges stay conflict-free:

```bash
git fetch upstream
git merge upstream/quattro
git push origin quattro
```

After merging upstream, review `git diff HEAD~1 -- install/omarchy-base.packages` to see if upstream added any new default packages you want to add to `overlay/packages/exclude.txt`.

## 2. Customizing Your Overlay

### Package Policy (Add, Exclude, AUR)

- Add extra official Arch or Omarchy packages in `overlay/packages/add.txt`
- Exclude unwanted upstream default packages in `overlay/packages/exclude.txt` (by default `omarchy-themes-backgrounds`, `omarchy-themes-intros`, and `omarchy-themes-loops` are excluded)
- Add AUR packages to pre-build and bundle into the **Offline Mirror** in `overlay/packages/aur.txt`
- Layer machine-specific packages in `overlay/profiles/<name>/packages/{add,exclude,aur}.txt`

### Material UI v9 Themes

Built-in upstream themes are permanently suppressed via `NoExtract = usr/share/omarchy/themes/*` in `overlay/etc/pacman-noextract.conf`.

- Edit or add static themes under `overlay/themes/<theme-slug>/` (each containing `colors.toml`, optional `backgrounds/`, and optional `*.tpl` overrides)
- Set the default theme name in `overlay/themes/default` (for example, `material-v9-dark`)

### Configs, Dotfiles, and Hooks

- Place user config overrides in `overlay/config/` mirroring `~/.config/` (for example, `overlay/config/hypr/hyprland.lua`)
- Place Profile-specific config overrides in `overlay/profiles/<name>/config/`
- Add custom install-time root scripts in `overlay/hooks/post-install.d/*.sh` (or per-Profile under `overlay/profiles/<name>/hooks/post-install.d/*.sh`)

## 3. Building an Offline ISO

Requirements on your Arch/Omarchy host: `docker` or `podman`.

```bash
./iso/build
```

Useful options:

- `./iso/build --channel edge` — build against Omarchy's `edge` channel instead of `stable`
- `./iso/build --no-aur` — skip AUR compilation for faster test builds
- `./iso/build --clean-cache` — wipe `iso/.cache/` and re-download/rebuild from scratch

Outputs are written to `iso/release/omarchy-custom-*.iso` (with `.sha256`), and downloads/AUR builds are cached in `iso/.cache/`. Both directories are ignored by `iso/.gitignore` and will never be committed.

## 4. Testing the ISO in a Local VM

Requirements on your host: `qemu-desktop` (or `qemu-full`), `edk2-ovmf`, and `mtools` (only if using `--unattended`).

Interactive install test:

```bash
./iso/test-vm --fresh-disk
```

Unattended install test (copy and edit `iso/unattended.env.example` first):

```bash
cp iso/unattended.env.example /tmp/vm-unattended.env
./iso/test-vm --fresh-disk --unattended /tmp/vm-unattended.env
```

Boot the installed VM disk afterward without the ISO attached:

```bash
./iso/test-vm --boot-disk
```

## 5. Flashing & Installing on Hardware

Write the ISO to a USB drive (replace `/dev/sdX` with your USB device):

```bash
sudo dd bs=4M if=iso/release/omarchy-custom-*.iso of=/dev/sdX status=progress oflag=sync
```

Boot from USB in UEFI mode. The interactive installer launches automatically on `tty1`, prompts for disk, **Profile**, user account, and LUKS passphrase, and installs 100% offline from the **Offline Mirror** with your **Overlay** applied last.

## 6. Updating & Syncing Installed Machines

- **Normal system updates**: Run `omarchy-update` as usual. It updates from upstream `pkgs.omarchy.org`, and the installed `post-update` hook (`~/.config/omarchy/hooks/post-update.d/10-overlay-policy.sh`) automatically re-enforces `NoExtract`, removes any restored upstream themes, and drops any excluded packages added by new upstream migrations without touching your live `~/.config/`.
- **Syncing new Overlay config/theme changes**: Pull your fork and run `overlay/apply`:

```bash
./overlay/apply --pull
```

By default, modified files in `~/.config/` are backed up to `<file>.bak.<timestamp>` before being replaced. Pass `--force` to overwrite without backups, or `--profile <name>` to switch the machine's active **Profile**.

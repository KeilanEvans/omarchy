#!/bin/bash

# Runs inside a privileged archlinux:latest container invoked by iso/build.
# Constructs the Offline Mirror (Arch + Omarchy + Overlay + pre-built AUR)
# and builds a bootable x86_64 archiso image into /release.

set -euo pipefail

CHANNEL=${OMARCHY_ISO_CHANNEL:-stable}
NO_AUR=${OMARCHY_ISO_NO_AUR:-0}
WORK_DIR="/work"
MIRROR_DIR="$WORK_DIR/offline-mirror"
PROFILE_DIR="$WORK_DIR/profile"
PACMAN_CACHE="/cache/pacman"
AUR_CACHE="/cache/aur"

mkdir -p "$WORK_DIR" "$MIRROR_DIR" "$PACMAN_CACHE" "$AUR_CACHE" /release

source /src/overlay/lib/packages.sh

echo "==> [1/6] Initializing build container keyring and tools..."
pacman-key --init
pacman-key --populate archlinux

for keyfile in /src/default/pacman/keys/*.asc; do
  [[ -f $keyfile ]] || continue
  pacman-key --add "$keyfile"
  fpr=$(gpg --homedir /etc/pacman.d/gnupg --with-colons --import-options show-only --import "$keyfile" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')
  if [[ -n $fpr ]]; then
    pacman-key --lsign-key "$fpr"
  fi
done

pacman -Sy --noconfirm --needed \
  archiso \
  arch-install-scripts \
  base-devel \
  dosfstools \
  erofs-utils \
  git \
  mtools \
  pacman-contrib \
  squashfs-tools \
  sudo

echo "==> [2/6] Preparing pacman configuration for channel '$CHANNEL'..."
BUILD_PACMAN_CONF="$WORK_DIR/build-pacman.conf"
BUILD_MIRRORLIST="$WORK_DIR/mirrorlist"
cp "/src/default/pacman/pacman-$CHANNEL.conf" "$BUILD_PACMAN_CONF"
cp "/src/default/pacman/mirrorlist-$CHANNEL" "$BUILD_MIRRORLIST"

# Point core/extra/multilib at Omarchy's pinned snapshot mirror so versioned
# Omarchy packages (e.g. hyprland, nvidia) match pkgs.omarchy.org exactly.
sed -i "s|^Include = /etc/pacman.d/mirrorlist|Include = $BUILD_MIRRORLIST|" "$BUILD_PACMAN_CONF"
mkdir -p "$WORK_DIR/empty-db"

echo "==> [3/6] Resolving and downloading Offline Mirror packages..."
mapfile -t mirror_pkgs < <(
  {
    printf '%s\n' \
      base \
      btrfs-progs \
      cryptsetup \
      dosfstools \
      efibootmgr \
      limine \
      limine-mkinitcpio-hook \
      limine-snapper-sync \
      linux-firmware \
      linux-omarchy \
      linux-omarchy-headers \
      snapper \
      zram-generator
    overlay_resolved_mirror_packages /src /src/overlay
  } | awk '!seen[$0]++'
)

pacman --config "$BUILD_PACMAN_CONF" --dbpath "$WORK_DIR/empty-db" -Sy --noconfirm

# Filter out any packages not present in configured sync repos (including virtual provides via -Sp)
valid_pkgs=()
for pkg in "${mirror_pkgs[@]}"; do
  if pacman --config "$BUILD_PACMAN_CONF" --dbpath "$WORK_DIR/empty-db" -Si -- "$pkg" &>/dev/null ||
     pacman --config "$BUILD_PACMAN_CONF" --dbpath "$WORK_DIR/empty-db" -Sg -- "$pkg" &>/dev/null ||
     pacman --config "$BUILD_PACMAN_CONF" --dbpath "$WORK_DIR/empty-db" -Sp -- "$pkg" &>/dev/null; then
    valid_pkgs+=("$pkg")
  else
    echo "Warning: package '$pkg' not found in sync repos; skipping from Offline Mirror." >&2
  fi
done

pacman --config "$BUILD_PACMAN_CONF" \
  --dbpath "$WORK_DIR/empty-db" \
  --cachedir "$PACMAN_CACHE" \
  -Sw --noconfirm --needed -- "${valid_pkgs[@]}"

# Download optional hardware packages individually so mutually-exclusive drivers
# (e.g. nvidia-open vs nvidia-580xx) do not conflict in one transaction.
while IFS= read -r hw_pkg; do
  pacman --config "$BUILD_PACMAN_CONF" \
    --dbpath "$WORK_DIR/empty-db" \
    --cachedir "$PACMAN_CACHE" \
    -Sw --noconfirm --needed -- "$hw_pkg" &>/dev/null || true
done < <(overlay_read_list /src/install/omarchy-other.packages)

cp -a "$PACMAN_CACHE"/*.pkg.tar.zst "$MIRROR_DIR/" 2>/dev/null || true

echo "==> [4/6] Pre-building AUR packages (if any)..."
if (( NO_AUR == 0 )); then
  mapfile -t aur_pkgs < <(overlay_all_aur_packages /src/overlay)
  if (( ${#aur_pkgs[@]} > 0 )); then
    id -u builder &>/dev/null || useradd -m -G wheel builder
    echo 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/builder
    mkdir -p "$WORK_DIR/aur-build"
    chown -R builder:builder "$WORK_DIR/aur-build" "$AUR_CACHE"

    for aur_pkg in "${aur_pkgs[@]}"; do
      if compgen -G "$AUR_CACHE/${aur_pkg}-*.pkg.tar.zst" >/dev/null; then
        echo "  Using cached AUR package for $aur_pkg"
      else
        echo "  Building AUR package: $aur_pkg"
        su - builder -c "
          set -euo pipefail
          cd '$WORK_DIR/aur-build'
          rm -rf '$aur_pkg'
          git clone --depth 1 'https://aur.archlinux.org/${aur_pkg}.git' '$aur_pkg'
          cd '$aur_pkg'
          PKGDEST='$AUR_CACHE' makepkg -s --noconfirm --needed
        "
      fi
    done

    cp -a "$AUR_CACHE"/*.pkg.tar.zst "$MIRROR_DIR/" 2>/dev/null || true
  fi
fi

echo "==> [5/6] Indexing Offline Mirror database..."
repo-add "$MIRROR_DIR/omarchy-offline.db.tar.gz" "$MIRROR_DIR"/*.pkg.tar.zst

echo "==> [6/6] Assembling archiso profile and building ISO..."
cp -r /usr/share/archiso/configs/releng "$PROFILE_DIR"

# Append live-installer packages to archiso package list
cat /src/iso/archiso/packages.x86_64 >>"$PROFILE_DIR/packages.x86_64"
sort -u -o "$PROFILE_DIR/packages.x86_64" "$PROFILE_DIR/packages.x86_64"

# Customize ISO naming in profiledef.sh
version=$(tr -d '[:space:]' </src/version)
sed -i \
  -e 's|^iso_name=.*|iso_name="omarchy-custom"|' \
  -e "s|^iso_label=.*|iso_label=\"OMARCHY_CUSTOM\"|" \
  -e "s|^iso_version=.*|iso_version=\"${version}-\$(date +%Y.%m.%d)\"|" \
  "$PROFILE_DIR/profiledef.sh"

# Stage Offline Mirror, Overlay, Upstream installer helpers, and live installer script
mkdir -p \
  "$PROFILE_DIR/airootfs/var/cache/omarchy/mirror" \
  "$PROFILE_DIR/airootfs/opt/omarchy-overlay" \
  "$PROFILE_DIR/airootfs/opt/omarchy-installer/provisioning" \
  "$PROFILE_DIR/airootfs/usr/local/bin" \
  "$PROFILE_DIR/airootfs/etc/profile.d"

cp -a "$MIRROR_DIR/." "$PROFILE_DIR/airootfs/var/cache/omarchy/mirror/"
cp -a /src/overlay/. "$PROFILE_DIR/airootfs/opt/omarchy-overlay/"
printf '%s\n' "$CHANNEL" >"$PROFILE_DIR/airootfs/opt/omarchy-installer/channel"
cp -a /src/install/omarchy-base.packages "$PROFILE_DIR/airootfs/opt/omarchy-installer/"
cp -a /src/install/provisioning/setup-form.sh "$PROFILE_DIR/airootfs/opt/omarchy-installer/provisioning/"
cp -a /src/install/provisioning/console-font.sh "$PROFILE_DIR/airootfs/opt/omarchy-installer/provisioning/"
install -m 0755 /src/iso/archiso/airootfs/usr/local/bin/omarchy-custom-install \
  "$PROFILE_DIR/airootfs/usr/local/bin/omarchy-custom-install"
install -m 0644 /src/iso/archiso/airootfs/etc/profile.d/99-omarchy-installer.sh \
  "$PROFILE_DIR/airootfs/etc/profile.d/99-omarchy-installer.sh"

mkarchiso -v -w "$WORK_DIR/archiso-work" -o /release "$PROFILE_DIR"

(
  cd /release
  for iso_file in omarchy-custom-*.iso; do
    [[ -f $iso_file ]] || continue
    sha256sum "$iso_file" >"$iso_file.sha256"
  done
)

if [[ -n ${HOST_UID:-} && -n ${HOST_GID:-} ]]; then
  chown -R "$HOST_UID:$HOST_GID" /release /cache 2>/dev/null || true
fi

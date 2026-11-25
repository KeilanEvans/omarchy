#!/bin/bash

# Installed to ~/.config/omarchy/hooks/post-update.d/10-overlay-policy.sh
# Runs automatically at the end of omarchy-update to enforce non-destructive
# Overlay invariants without touching live ~/.config/ edits.

set -euo pipefail

OVERLAY_DIR=${OVERLAY_DIR:-/usr/local/share/omarchy-overlay}
PROFILE_FILE="/etc/omarchy-overlay/profile"

if [[ ! -d $OVERLAY_DIR ]]; then
  exit 0
fi

source "$OVERLAY_DIR/lib/packages.sh"

active_profile=""
if [[ -f $PROFILE_FILE ]]; then
  active_profile=$(tr -d '[:space:]' <"$PROFILE_FILE")
fi

# 1. Re-enforce pacman NoExtract and clean any restored upstream themes
if [[ -f $OVERLAY_DIR/hooks/post-install.d/10-enforce-noextract.sh ]]; then
  OVERLAY_DIR="$OVERLAY_DIR" bash "$OVERLAY_DIR/hooks/post-install.d/10-enforce-noextract.sh"
fi

# 2. Drop any excluded packages installed by a new upstream migration
to_drop=()
while IFS= read -r pkg; do
  if pacman -Q -- "$pkg" &>/dev/null; then
    to_drop+=("$pkg")
  fi
done < <(overlay_excluded_packages "$OVERLAY_DIR" "$active_profile")

if (( ${#to_drop[@]} > 0 )); then
  echo "Overlay Package Policy: removing excluded packages: ${to_drop[*]}"
  omarchy-pkg-drop "${to_drop[@]}" || true
fi

# 3. Remove any excluded default desktop webapps
if [[ -f $OVERLAY_DIR/applications/exclude.txt && -d $HOME/.local/share/applications ]]; then
  while IFS= read -r desktop_file; do
    rm -f "$HOME/.local/share/applications/$desktop_file"
  done < <(overlay_read_list "$OVERLAY_DIR/applications/exclude.txt")
fi

# 4. Ensure configured Flatpak apps are installed (non-fatal if offline)
if [[ -f $OVERLAY_DIR/packages/flatpak.txt ]] && command -v flatpak &>/dev/null; then
  while IFS= read -r line; do
    IFS='|' read -r remote_name remote_url app_ref <<<"$line"
    [[ -n $app_ref ]] || continue
    if [[ -n $remote_name && -n $remote_url ]]; then
      flatpak remote-add --user --if-not-exists "$remote_name" "$remote_url" || true
    fi
    flatpak install --user --noninteractive -y "$app_ref" || true
  done < <(overlay_read_list "$OVERLAY_DIR/packages/flatpak.txt")
fi

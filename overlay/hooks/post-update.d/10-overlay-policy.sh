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

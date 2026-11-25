#!/bin/bash

# Enforce pacman NoExtract rules from overlay/etc/pacman-noextract.conf
# and remove any upstream built-in themes already on disk.

set -euo pipefail

OVERLAY_DIR=${OVERLAY_DIR:-/usr/local/share/omarchy-overlay}
NOEXTRACT_CONF="$OVERLAY_DIR/etc/pacman-noextract.conf"
PACMAN_CONF=${PACMAN_CONF:-/etc/pacman.conf}

if [[ ! -f $NOEXTRACT_CONF || ! -f $PACMAN_CONF ]]; then
  exit 0
fi

mapfile -t patterns < <(sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$NOEXTRACT_CONF")
if (( ${#patterns[@]} == 0 )); then
  exit 0
fi

run_as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

tmp_conf=$(mktemp)
trap 'rm -f "$tmp_conf"' EXIT

cp "$PACMAN_CONF" "$tmp_conf"
changed=0
for pattern in "${patterns[@]}"; do
  if ! grep -Eq "^[[:space:]]*NoExtract[[:space:]]*=.*(^|[[:space:]])${pattern//\*/\\*}($|[[:space:]])" "$tmp_conf"; then
    awk -v pat="$pattern" '
      BEGIN { inserted = 0 }
      /^\[options\]/ && !inserted {
        print
        print "NoExtract = " pat
        inserted = 1
        next
      }
      { print }
    ' "$tmp_conf" >"$tmp_conf.next"
    mv "$tmp_conf.next" "$tmp_conf"
    changed=1
  fi
done

if (( changed )); then
  run_as_root install -m 0644 "$tmp_conf" "$PACMAN_CONF"
fi

# Clean any upstream built-in themes already extracted before NoExtract was active
if [[ -d /usr/share/omarchy/themes ]]; then
  run_as_root find /usr/share/omarchy/themes -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

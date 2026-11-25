#!/bin/bash

# Enforce system-wide UK/GB locale (en_GB.UTF-8) and console keymap (uk).

set -euo pipefail

run_as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

if [[ -f /etc/locale.gen ]]; then
  if grep -q '^#en_GB.UTF-8 UTF-8' /etc/locale.gen; then
    run_as_root sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
  elif ! grep -q '^en_GB.UTF-8 UTF-8' /etc/locale.gen; then
    printf '%s\n' 'en_GB.UTF-8 UTF-8' | run_as_root tee -a /etc/locale.gen >/dev/null
  fi
  if ! locale -a 2>/dev/null | grep -qi 'en_GB\.utf-\?8'; then
    run_as_root locale-gen >/dev/null
  fi
fi

printf 'LANG=en_GB.UTF-8\n' | run_as_root tee /etc/locale.conf >/dev/null
printf 'KEYMAP=uk\n' | run_as_root tee /etc/vconsole.conf >/dev/null

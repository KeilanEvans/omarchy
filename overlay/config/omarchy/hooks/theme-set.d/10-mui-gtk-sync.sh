#!/bin/bash

# omarchy-hook theme-set script: propagates rendered MUI v9 GTK 3 and
# GTK 4 / libadwaita CSS from the active theme into ~/.config/gtk-{3,4}.0/
# and exposes them to Flatpak apps for full-distro UI consistency.

set -euo pipefail

THEME_DIR="$HOME/.local/state/omarchy/current/theme"
COLORS_FILE="$THEME_DIR/colors.toml"

[[ -d $THEME_DIR ]] || exit 0

mode="dark"
if [[ -f $COLORS_FILE ]] && command -v omarchy-theme-color &>/dev/null; then
  mode=$(omarchy-theme-color --file "$COLORS_FILE" mode 2>/dev/null || echo "dark")
fi

prefer_dark="1"
if [[ $mode == "light" ]]; then
  prefer_dark="0"
fi

write_gtk_settings() {
  local settings_file=$1
  mkdir -p "$(dirname "$settings_file")"
  if [[ -f $settings_file ]]; then
    if grep -q '^gtk-application-prefer-dark-theme=' "$settings_file"; then
      sed -i "s|^gtk-application-prefer-dark-theme=.*|gtk-application-prefer-dark-theme=$prefer_dark|" "$settings_file"
    else
      printf 'gtk-application-prefer-dark-theme=%s\n' "$prefer_dark" >>"$settings_file"
    fi
  else
    cat >"$settings_file" <<EOF
[Settings]
gtk-application-prefer-dark-theme=$prefer_dark
EOF
  fi
}

if [[ -f $THEME_DIR/gtk-3.0.css ]]; then
  mkdir -p "$HOME/.config/gtk-3.0"
  cp -f "$THEME_DIR/gtk-3.0.css" "$HOME/.config/gtk-3.0/gtk.css"
  write_gtk_settings "$HOME/.config/gtk-3.0/settings.ini"
fi

if [[ -f $THEME_DIR/gtk-4.0.css ]]; then
  mkdir -p "$HOME/.config/gtk-4.0"
  cp -f "$THEME_DIR/gtk-4.0.css" "$HOME/.config/gtk-4.0/gtk.css"
  write_gtk_settings "$HOME/.config/gtk-4.0/settings.ini"
fi

# Ensure Flatpak GTK apps inherit the active theme CSS
if command -v flatpak &>/dev/null; then
  flatpak override --user \
    --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
fi

# Nudge running GTK3/XSettings clients to reload updated gtk.css
pkill -HUP xsettingsd 2>/dev/null || true

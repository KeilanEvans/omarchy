# Launch the custom Omarchy installer automatically on tty1 of the live ISO.
if [[ -z ${SSH_CONNECTION:-} && $(tty 2>/dev/null || true) == "/dev/tty1" ]]; then
  if [[ -x /usr/local/bin/omarchy-custom-install ]]; then
    /usr/local/bin/omarchy-custom-install
  fi
fi

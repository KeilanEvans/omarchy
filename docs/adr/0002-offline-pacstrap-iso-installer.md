# Offline Pacstrap ISO Installer

status: accepted

Our integrated ISO builder uses `archiso` with a bundled **Offline Mirror** and runs offline `pacstrap` during installation, followed by **Upstream**'s `omarchy-apply-system` and `omarchy-provision-user`, and finally applies the **Overlay** and selected **Profile** so custom settings always take precedence.

## Considered Options

- **Pre-assembled compressed Btrfs root image (upstream `omarchy-iso` approach)**: Faster install time via `zstdcat | dd` and partition resize, but requires building and resizing a full Btrfs disk image inside the build container and bakes a single fixed package set into the image.
- **Thin netinstall ISO**: Smaller ISO and faster builds, but requires working Wi-Fi and live mirrors during installation.

## Consequences

- A single built ISO can install any **Profile** cleanly because `pacstrap` selects packages at install time from the **Offline Mirror**.
- Reusing `omarchy-apply-system` and `omarchy-provision-user` keeps disk layout (LUKS + Btrfs + Limine), hardware setup, and system defaults aligned with **Upstream**, while running the **Overlay** last guarantees customisations win.
- Installs take a couple of minutes longer than raw image `dd`, and the ISO builder must resolve and download all **Upstream**, hardware, and **Overlay** packages into the **Offline Mirror** at build time.

# Isolated Overlay with Upstream Package Updates

status: accepted

We keep **Upstream** Omarchy files untouched and place all customizations and ISO build tooling inside an isolated **Overlay** in this fork, while installed machines continue tracking upstream `pkgs.omarchy.org` for `omarchy-update`. Packages unwanted from upstream defaults are excluded at ISO build time, and an `omarchy-hook post-update` script enforces the **Package Policy** after future upstream updates.

## Considered Options

- **Direct edits to upstream files in the fork**: Simple initially, but causes recurring merge conflicts whenever pulling upstream Quattro changes.
- **Self-hosted custom `omarchy` / `omarchy-settings` pacman repo**: Gives preventive control over upstream migrations before pacman runs, but requires maintaining package builds, GPG signing keys, and hosted repository infrastructure.
- **Git-linked `dev` mode (`omarchy-dev-link`) on installed machines**: Useful for hacking on `bin/` and `shell/` QML, but still relies on upstream packages for `/etc/` and `/etc/skel/`.

## Consequences

- Merging upstream `quattro` into this fork stays low-conflict because upstream files are not modified.
- No custom pacman repository or package-signing infrastructure is needed.
- New packages introduced by future upstream migrations are removed reactively by the `post-update` hook rather than blocked pre-install, keeping upstream migrations from failing on `omarchy-pkg-add` checks.

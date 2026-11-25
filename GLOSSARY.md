# Custom Omarchy Fork

A self-contained fork of Omarchy Quattro that layers personal customizations and an integrated ISO builder on top of upstream Omarchy without linked repositories.

## Language

**Upstream**:
The `omacom/omarchy` Quattro codebase tracked by this fork, whose files remain untouched so upstream changes merge cleanly.
_Avoid_: base repo, original Omarchy

**Overlay**:
The isolated customization layer inside this fork that holds the **Package Policy**, config overrides, hooks, and ISO build configuration.
_Avoid_: custom folder, fork patches, dotfiles

**Package Policy**:
The declarative rules in the **Overlay** defining extra packages to install and **Upstream** default packages to exclude at ISO build time and remove after updates.
_Avoid_: package list, blacklist, whitelist

**Profile**:
An optional, named machine-specific layer inside the **Overlay** (such as `desktop` or `laptop`) that adds targeted package, config, or hook overrides on top of the shared base.
_Avoid_: host config, variant, preset

**Offline Mirror**:
The local pacman repository bundled inside the built ISO containing resolved **Upstream**, hardware, and **Overlay** packages so installation completes without network access.
_Avoid_: package cache, local repo, ISO cache

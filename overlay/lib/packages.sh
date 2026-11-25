# Shared Package Policy resolver for the Overlay and ISO builder.
# Sourced by overlay/apply, overlay/hooks/post-update.d/, and iso/build.

overlay_read_list() {
  local file
  for file in "$@"; do
    [[ -f $file ]] || continue
    sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$file"
  done | awk '!seen[$0]++'
}

overlay_list_profiles() {
  local overlay_dir=$1
  [[ -d $overlay_dir/profiles ]] || return 0
  find "$overlay_dir/profiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

overlay_excluded_packages() {
  local overlay_dir=$1
  local profile=${2:-}
  local files=("$overlay_dir/packages/exclude.txt")

  if [[ -n $profile && -f $overlay_dir/profiles/$profile/packages/exclude.txt ]]; then
    files+=("$overlay_dir/profiles/$profile/packages/exclude.txt")
  fi

  overlay_read_list "${files[@]}"
}

overlay_added_packages() {
  local overlay_dir=$1
  local profile=${2:-}
  local files=("$overlay_dir/packages/add.txt")

  if [[ -n $profile && -f $overlay_dir/profiles/$profile/packages/add.txt ]]; then
    files+=("$overlay_dir/profiles/$profile/packages/add.txt")
  fi

  overlay_read_list "${files[@]}"
}

overlay_aur_packages() {
  local overlay_dir=$1
  local profile=${2:-}
  local files=("$overlay_dir/packages/aur.txt")

  if [[ -n $profile && -f $overlay_dir/profiles/$profile/packages/aur.txt ]]; then
    files+=("$overlay_dir/profiles/$profile/packages/aur.txt")
  fi

  overlay_read_list "${files[@]}"
}

# Print the final x86 official package list for a target install:
# (Upstream base + omarchy + omarchy-settings + Overlay add) - Overlay exclude
overlay_resolved_install_packages() {
  local repo_root=$1
  local overlay_dir=$2
  local profile=${3:-}
  local exclude_file
  exclude_file=$(mktemp)
  overlay_excluded_packages "$overlay_dir" "$profile" >"$exclude_file"

  {
    printf '%s\n' omarchy omarchy-settings
    overlay_read_list "$repo_root/install/omarchy-base.packages"
    overlay_added_packages "$overlay_dir" "$profile"
  } | awk -v excludes="$exclude_file" '
    BEGIN { while ((getline pkg < excludes) > 0) drop[pkg] = 1 }
    !drop[$0] && !seen[$0]++'

  rm -f "$exclude_file"
}

# Print every official package needed in the Offline Mirror so any Profile can
# install offline from a single ISO (base + other + all Profiles' add lists,
# minus base-only exclusions).
overlay_resolved_mirror_packages() {
  local repo_root=$1
  local overlay_dir=$2
  local exclude_file
  exclude_file=$(mktemp)
  overlay_excluded_packages "$overlay_dir" "" >"$exclude_file"

  {
    printf '%s\n' omarchy omarchy-settings
    overlay_read_list "$repo_root/install/omarchy-base.packages" "$repo_root/install/omarchy-other.packages"
    overlay_added_packages "$overlay_dir" ""
    local profile
    while IFS= read -r profile; do
      overlay_read_list "$overlay_dir/profiles/$profile/packages/add.txt"
    done < <(overlay_list_profiles "$overlay_dir")
  } | awk -v excludes="$exclude_file" '
    BEGIN { while ((getline pkg < excludes) > 0) drop[pkg] = 1 }
    !drop[$0] && !seen[$0]++'

  rm -f "$exclude_file"
}

# Print every AUR package across the base Overlay and all Profiles.
overlay_all_aur_packages() {
  local overlay_dir=$1
  local files=("$overlay_dir/packages/aur.txt")
  local profile
  while IFS= read -r profile; do
    if [[ -f $overlay_dir/profiles/$profile/packages/aur.txt ]]; then
      files+=("$overlay_dir/profiles/$profile/packages/aur.txt")
    fi
  done < <(overlay_list_profiles "$overlay_dir")

  overlay_read_list "${files[@]}"
}

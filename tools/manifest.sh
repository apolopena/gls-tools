#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# manifest.sh
#
# Description:
# Generates a manifest of everything in the project root of the latest release of gitpod-laravel-starter.
# The manifest is saved to the file .latest_gls_manifest and relative to where this script was run from.
#
# Note:
# ../update.sh and ../install.sh rely on .latest_gls_manifest being up to date


# BEGIN: Globals

# manifest file to output to
manifest="$(pwd)/.latest_gls_manifest"
# working directory, set by download_latest()
tmp_dir=
# Latest version number of gitpod-laravel-starter, set by download_latest()
latest_version=

# END: Globals


### generate_manifest ###
# Description:
# Generates a manifest file at $(pwd)/.latest_gls_manifest that contains the following:
#     The [version] number for the latest release
#     All files and directories to [keep] 
#     All files and directories to [recommend-backup] for
generate_manifest() {
  local keep_file files directories

  [[ ! -d $tmp_dir ]] && echo "Could not find temp directory to work from" && return 1

  [[ -f $manifest ]] && rm "$manifest"
  
  [[ -n $latest_version ]] && echo -e "[version]\n$latest_version\n" >> "$manifest"

  # Move into the temp working directory and generate the manifest
  if ! cd "$tmp_dir"; then echo "Could not cd into: $(pwd)/$tmp_dir"; return 1; fi
  directories="$(find "$(pwd)" -maxdepth 1 -mindepth 1 -type d | grep -ve '.gp' -e '.theia')"

  files="$(find "$(pwd)" -maxdepth 1 -mindepth 1 -type f | \
  grep -ve "$manifest" -e LICENSE -e README -e CHANGELOG)"

  keep_file=".gp/bash/init-project.sh"
  if [[ -f $keep_file ]]; then
    echo -e "[keep]\n$keep_file\n" >> "$manifest"
  fi
  echo -e "[recommend-backup]" >> "$manifest"
  echo "$files" | while IFS= read -r line ; do printf '%s\n' "$(basename "$line")" >> "$manifest"; done
  echo "$directories" | while IFS= read -r line ; do echo "/$(basename "$line")" >> "$manifest"; done
  [[ -n $files || -n $directories ]] && echo -e "\n" >> "$manifest"

  # Move back up to where we started
  if ! cd ..; then echo "could not cd out of: $tmp_dir"; return 1; fi
}

### download_latest ###
# Description:
# Downloads and extracts the latest release version of gitpod-laravel-starter
# to a temporary working directory
# Sets the following global variables: $latest_version $tmp_dir
# Note:
# If this routine succeeds then the temporary working directory should be removed 
# by calling: cleanup "$tmp_dir"
download_latest() {
  local e_1 release_json release_url tarball_url chunk version_regex
  release_url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  version_regex='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  e_1="Could not download release data from: $release_url"

  # check that the release data is downloadable
  if ! curl --head --silent --fail "$release_url" &> /dev/null; then echo "$e_1" return 1; fi

  # Download release data
  release_json="$(curl -fsSL "$release_url")"

  # Parse release data for latest tarball url and the latest version
  chunk="$(echo "$release_json" | grep 'tarball_url')"
  tarball_url="$(echo "$chunk" | grep -oE 'https.*"')"
  tarball_url="${tarball_url::-1}"
  latest_version="$(echo "$chunk" | grep -oE "$version_regex")"

  # Create tmp dir to work from and move into it
  tmp_dir="tmp_gls_v$latest_version"
  [[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
  if ! mkdir "$tmp_dir"; then return 1; fi
  if ! cd "$tmp_dir"; then echo "could not cd into: $(pwd)/$tmp_dir"; return 1; fi
  
  # Download and extract latest release tarball
  e_1="Failed to download and extract latest release tarball to: $tmp_dir"
  if ! curl -sL "$tarball_url" | tar xz --strip=1; then echo "$e_1" return 1; fi

  # Move back up to where we started
  if ! cd ..; then echo "could not cd out of: $tmp_dir"; return 1; fi
}

### cleanup ###
# Description:
# Recursively removes a directory ($1) if it exists AND is a subpath of where this script is run from
# return 0  on success and 1 otherwise
cleanup() {
  local subpath
  subpath="$(pwd)/$1"
  [[ -d "$subpath" ]] && rm -rf "$subpath"  && return 0
}

### main ###
# Description:
# main routine
main() {
  if ! download_latest; then
    echo "Failed to download the latest release"
    cleanup "$tmp_dir"
    echo "Script aborted"
    exit 1
  fi

  if ! generate_manifest; then 
    echo "Failed to generate the manifest"
    cleanup "$tmp_dir"
    echo "Script aborted"
    exit 1
  fi
  
  if ! cleanup "$tmp_dir"; then echo "Unable to cleanup the temporary working directory: $tmp_dir"; fi

  echo -e "SUCCESS: manifest generated at:\n\t$(pwd)/$manifest"
}

main


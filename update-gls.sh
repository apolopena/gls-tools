#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# update-gls.sh
# Version: 1.0.0
#
# Description:
# Updates an existing project build on gitpod-laravel-starter to the latest version.
# Automated update with step by step merging of critical files in your existing project.
#
# Notes:
# Supports gitpod-laraver starter versions >= v1.0.0
# For specifics on what files are updated, replaced, left alone, etc.. see: up-manifest.yml @
# https://github.com/apolopena/gitpod-laravel-starter/tree/main/.gp/updater-manifest.yml

# TODOS
# verify gls verion (quit if there is no .gp directory)
# Warn users if there is no manifest (version is lower than 1.6)
# If version <= 1.5
#   warn user there is no manifest, inform them what will be changed
# If version > 1.5
#   check for yq binary
#   if yq binary exists check version, update if necessary
#   if yq binary does not exist download and install it
#   parse up-mainfest.yml
#   inform user of the changes to be made based on the manifest data
#   prompt to proceed

# Globals
target_version=
base_version=
d_keeps=() # Files to keep
d_merges=() # Files to merge
d_backups=() # Files to recommend backing up and hand merging
tmp_dir="$(pwd)/.tmp_gls_update" # Temporary working directory
release_json="$tmp_dir/latest_release.json" # Latest release data file

name() {
  printf '%s' "$(basename "${BASH_SOURCE[0]}")"
}

warn_msg() {
  echo -e "$(name) WARNING:\n\t$1"
}

err_msg() {
  echo -e "$(name) ERROR:\n\t$1"
}

abort_msg() {
  echo "$(name) ABORTED"
}

# split_ver
# Description:
# splits a version number ($1) into three numbers delimited by a space
#
# Notes:
# Assumes the format of the version number will be:
# <any # of digits>.<any # of digits>.<any # of digits>
#
# Usage:
# split_ver 6.31.140
# # outputs: 6 31 140 
split_ver() {
  local first mid last
  first=${1%%.*}; last=${1##*.}; mid=${1##$first.}; mid=${mid%%.$last}
  echo "$first $mid $last"
}


# comp_ver_lt
# Description:
# Compares version number ($1) to version number ($2)
# Echos 1 if version number ($1) is less than version number ($2)
# Echos 0 if version number ($1) is greater than or equal to version number ($2)
#
# Notes:
# Assumes the format of the version number will be:
# <any # of digits>.<any # of digits>.<any # of digits>
#
# Usage:
# comp_ver_lt 2.28.10 2.28.9
# # outputs: 1
# comp_ver_lt 0.0.1 0.0.0
# # outputs: 0
comp_ver_lt() {
  local v1=()
  local v2=()
  IFS=" " read -r -a v1 <<< "$(split_ver "$1")"
  IFS=" " read -r -a v2 <<< "$(split_ver "$2")"
  [[ ${v1[0]} -lt ${v2[0]} ]] && echo 1 && exit
  [[ ${v1[0]} -eq ${v2[0]} ]] && \
  [[ ${v1[1]} -lt ${v2[1]} ]] && echo 1 && exit
  [[ ${v1[0]} -eq ${v2[0]} ]] && \
  [[ ${v1[1]} -eq ${v2[1]} ]] && \
  [[ ${v1[2]} -lt ${v2[2]} ]] && echo 1 && exit
  echo 0
}

# gls_verion
# Description:
# Parses the first occurrence of a major.minor.patch version number from a file ($1)
gls_version() {
  local ver=
  ver="$(grep -oE "([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?" "$1" | head -n 1)"
  [[ -z $ver ]] && return 1
  echo "$ver"
  return 0
}

# default_manifest
# Description:
# The deafult manifest to use for the update
default_manifest() {
  echo "[keep]
.gp/bash/init-project.sh

[merge]
.gitattributes
.gitignore
.gitpod.Dockerfile
.gitpod.yml
.npmrc

[recommend-backup]
starter.ini"
}

set_base_version_unknown() {
  local unknown_msg="The current gls version has been set to 'unknown' but is assumed to be >= 1.0.0"
  base_version='unknown' && echo "$unknown_msg"
}

set_base_version() {
  local ver input ec gp_dir changelog err_p1 err_p2 err_p3
  gp_dir="$(pwd)/.gp"
  changelog="$gp_dir/CHANGELOG.md"
  err_p1="Undectable gls version"
  err_p2="Could not find required file: $changelog"
  err_p3="Could not parse version number from: $changelog"
  err_p4="Base version is too old, it must be >= 1.0.0\n\tYou will need to perform the update manaully."
  # Derive base version by other means if the CHANGELOG.md is not present or cannot be parsed
  if [[ ! -f $changelog ]]; then
    warn_msg "$err_p1\n\t$err_p2"
    echo -n "Enter the gls version you are updating from (y=skip): "
    read -r input
    [[ $input == y ]] && return 1
    # regexp match only: major.minor.patch with a range 0-999 for each one and no trailing zeros
    local regexp='^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$'
    if [[ $input =~ $regexp ]]; then
       [[ $(comp_ver_lt "$input" 1.0.0 ) == 1 ]] && err_msg "$err_p4" && abort_msg && exit 1
      base_version="$input" && echo "Base gls version set by user to: $input" && return 0
    else
      echo "Invalid version: $input" && return 1
    fi
  fi
  # Derive version from CHANGELOG.md
  ver="$(gls_version "$changelog")"
  ec=$?
  [[ $ec == 1 ]] && err_msg "$err_p3\n\tThis file should never be altered but it was." && return 1
  base_version="$ver"
  return 0
}

parse_manifest_chunk() {
  local chunk err_p err_1 err_2
  err_p="parse_manifest_chunk(): parse error"
  err_1="Exactly 2 arguments are required. Found $#"
  err_2="Invalid manifest:\n$2"
  err_3="Unable to find start marker: [$1]"

  # BEGIN: Error handling

  # Bad number of args
  [[ -z $1 || -z $2 ]] && err_msg "$err_p\n\t$err_1" && abort_msg && exit 1

  # Bad manifest


  # Bad start marker
  if ! echo "$2" | grep -oP "\[${1}\]"; then
    err_msg "$err_p\n\t$err_3" && abort_msg && exit 1
  fi

   # END: Error handling

  #[[ $1 =~ $valid_marker ]] && err_msg "$err_p\n\t$err_2" && abort_msg && exit 1
  #[[ $2 =~ $valid_marker ]] && err_msg "$err_p\n\t$err_3" && abort_msg && exit 1
  #chunk="$(awk -v _start="$1" -v _end="$2"  '/_start/{flag=1;next}/_end/{flag=0}flag' "$3")"
  # echo "$2" | sed '1,/\['"$1"'\]/d;/foo/,$d'
  chunk="$(echo "$2" | sed '/\['"$1"'\]/,/^END$/!d;//d')"


echo "$chunk" | grep -v "\[$1\]"

  #echo -e "parse_manifest_chunk(): TEST:\n$chunk"
}

parse_manifest_chunk2() {
  return 0
}


set_target_version() {
  local regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  local e1="Cannot set target version"
  [[ -z $release_json ]] && err_msg "$e1/n/tMissing required file $release_json" && return 1
  target_version="$(grep "tag_name" "$release_json" | grep -oE "$regexp")"
}

download_release_json() {
  local url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  if ! curl --silent "$url" -o "$release_json"; then
    err_msg "Could not download release data\n\tfrom $url"
    return 1
  fi
  return 0
}

set_directives() {
  local manifest file warn1 default
  file="$(pwd)/.gp/.updater_manifest"
  warn1="Could not find the updater manifest at $file"
  if [[ ! -f $file ]]; then
    default="$(default_manifest)"
    manifest="$default"
    warn_msg "$warn1\nUsing the default updater manifest:\n$default"
  else
    manifest="$(cat "$file")"
  fi
  # test in progress
  parse_manifest_chunk 'keep' "$manifest"
}

download_latest() {
  local e1 e2 url
  e1="Cannot download/extract latest gls tarball"
  e2="Unable to parse url from $release_json"
  [[ -z $release_json ]] && err_msg "$e1/n/tMissing required file $release_json" && return 1

  # parse json for tarball url
  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"

  [[ -z $url ]] && err_msg "$e1\n\t$e2" && return 1
  if ! cd "$tmp_dir"; then err_msg "$e1\n\tinternal error" && return 1; fi
  echo "Downloading and extracting $url"
  if ! curl -sL "$url" | tar xz --strip=1; then
    cd ..; err_msg "$e1\n\t curl failed $url"; return 1
  fi
}

cleanup() {
  [[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
}

update() {
  local e1 e2 update_msg
  e1="Version mismatch"
  
  # Handle dependencies 
  [[ ! -d $tmp_dir ]] && mkdir "$tmp_dir"
  if ! download_release_json; then abort_msg && return 1; fi

  # Derive base and target versions
  if ! set_target_version; then abort_msg && return 1; fi
  if ! set_base_version; then set_base_version_unknown; fi
  if [[ $(comp_ver_lt "$base_version" "$target_version") == 0 ]]; then
    e2="You current version v$base_version must be less than the latest version v$target_version"
    err_msg "$e1\n\t$e2" && a_msg && return 1
  fi

  # Update
  update_msg="Updating gls version $base_version to version $target_version"
  echo "BEGIN: $update_msg"
  if ! set_directives; then abort_msg && return 1; fi
  if ! download_latest; then abort_msg && return 1; fi


  echo "SUCCESS: $update_msg"
  return 0
}

main() {
  if ! update; then cleanup; exit 1; fi
}

main

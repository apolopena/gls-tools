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
target_dir=
data_keeps=() # Files or directories to keep
data_merges=() # Files to merge
data_backups=() # Files to recommend backing up and hand merging
data_deletes=() # Files or directories to delete (a directory will be rm -rf)
project_root="$(pwd)"
tmp_dir="$project_root/tmp_gls_update" # Temporary working directory

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

# is_subpath
# Description:
# returns 0 if ($2) is a subpath of ($1)
# return 1 otherwise
#
# Usage:
# base="/home/someusr"
# p1="/home/someusr/myproject"
# p2="/etc"
# if is_subpath "$base" "$p1";then
#    echo "$p1 is a subpath of $base"
# else
#   echo "$p1 is NOT a subpath of $base"
# fi
# # outputs: /home/someusr/myproject is a subpath of /home/someusr
# if is_subpath "$base" "$p2";then
#    echo "$p2 is a subpath of $base"
# else
#   echo "$p2 is NOT a subpath of $base"
# fi
# # outputs: /etc is NOT a subpath of /home/someusr
is_subpath() {
  if [[ $(realpath --relative-base="$1" -- "$2")  =~ ^/ ]]; then
    # $2 is NOT subpath of $1
    return 1
  else
    # $2 is subpath of $1
    return 0
  fi
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
  local err_p err_1 err_2 chunk ec
  err_p="parse_manifest_chunk(): parse error"

  # Error handling
  err_1="Exactly 2 arguments are required. Found $#"
  [[ -z $1 || -z $2 ]] && err_msg "$err_p\n\t$err_1" && return 1
  err_2="Invalid manifest:\n$2"
  # TODO verify header sections are delimited by an empty line
  err_3="Unable to find start marker: [$1]"
  if ! echo "$2" | grep -oP --silent "\[${1}\]"; then
    err_msg "$err_p\n\t$err_3" && return 1
  fi

  # If we got this far we can parse and return success no matter what
  echo "$2" | sed -n '/\['"$1"'\]/,/^$/p' | grep -v "\[$1\]"; return 0
}


# Sets target version and target directory
set_target_version() {
  local regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  local e1="Cannot set target version"
  [[ -z $release_json ]] && err_msg "$e1/n/tMissing required file $release_json" && return 1
  target_version="$(grep "tag_name" "$release_json" | grep -oE "$regexp")" && target_dir="$tmp_dir/$target_version"
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
  local chunk manifest file warn1 default ec
  file="$(pwd)/.gp/.updater_manifest"
  warn1="Could not find the updater manifest at $file"
  # Handle the manifest
  if [[ ! -f $file ]]; then
    default="$(default_manifest)"
    manifest="$default"
    warn_msg "$warn1\nUsing the default updater manifest:\n$default"
  else
    manifest="$(cat "$file")"
  fi
  # Parse files and directories to keep
  chunk="$(parse_manifest_chunk 'keep' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_keeps <<< "$chunk"
  # Parse files and directories to merge
  chunk="$(parse_manifest_chunk 'merge' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_merges <<< "$chunk"
  # Parse files and directories to recommend to backup
  chunk="$(parse_manifest_chunk 'recommend-backup' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_backups <<< "$chunk"
  # Parse files and directories to merge
  chunk="$(parse_manifest_chunk 'delete' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_deletes <<< "$chunk"
  # All good return success
  return 0
}

run_directives() {

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE KEEP:"
    [[ ${#data_keeps[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_keeps[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing ${data_keeps[$i]}"
    if ! keep "${data_keeps[$i]}"; then return 1; fi
  done

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE MERGE:"
    [[ ${#data_merges[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_merges[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${data_merges[$i]}"
  done

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE RECOMMEND TO BACKUP:"
    [[ ${#data_backups[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_backups[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${data_backups[$i]}"
  done

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE DELETE:"
    [[ ${#data_deletes[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_deletes[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${data_deletes[$i]}"
  done
}

# BEGIN: directives
keep() {
  local name loc err_pre e1_pre
  name="keep()"
  orig_loc=
  target_loc=
  err_pre="Failed to $name"
  e1_pre="Could not find"
  
  [[ -z $1 ]] && err_msg "$err_pre\n\t Missing argument. Nothing to keep." && return 1

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre directory $orig_loc" && return 1
    target_loc="$target_dir$1"

    # Ensure that is is safe to recursively delete the directory
    if is_subpath "$project_root" "$target_loc"; then
      echo "Keeping original directory $orig_loc"
      rm -rf "$target_loc" && cp -R "$orig_loc" "$target_loc"
      return 0
    fi
    return 1
  fi
  # Otherwise it must be a file
  orig_loc="$project_root/$1"
  [[ ! -f $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre file $orig_loc" && return 1
  target_loc="$target_dir/$1"
  # Ensure that is is safe to copy the file
  if is_subpath "$project_root" "$target_loc"; then
    echo "Keeping original file $orig_loc"
    cp "$orig_loc" "$target_loc"
    return 0
  fi
  return 1
}

merge() {
  return 0
}

recommend_backup() {
  return 0
}

delete() {
  return 0
}
# END: directives

download_latest() {
  local e1 e2 url
  e1="Cannot download/extract latest gls tarball"
  e2="Unable to parse url from $release_json"

  # Handle missing release data
  [[ -z $release_json ]] && err_msg "$e1/n/tMissing required file $release_json" && return 1
  # Parse tarball url from the release json
  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"
  # Handle a bad url
  [[ -z $url ]] && err_msg "$e1\n\t$e2" && return 1

  # Move into the target working directory
  if ! cd "$target_dir";then
    err_msg "$e1\n\tinternal error, bad target directory: $target_dir"
    return 1
  fi
  # Download
  echo "Downloading and extracting $url"
  if ! curl -sL "$url" | tar xz --strip=1; then
    err_msg "$e1\n\t curl failed $url"
    return 1
  fi
  # Cleanup
  cd "$project_root" || return 1
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
  [[ ! -d $target_dir ]] && mkdir "$target_dir"
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
  if ! run_directives; then abort_msg && return 1; fi

  echo "SUCCESS: $update_msg"
  return 0
}

main() {
  if ! update; then cleanup; exit 1; fi
}

main

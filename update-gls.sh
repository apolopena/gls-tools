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
# Supports gitpod-laraver starter versions > v0.0.4
# For specifics on what files are updated, replaced, left alone, etc.. see: up-manifest.yml @
# https://github.com/apolopena/gitpod-laravel-starter/tree/main/.gp/updater-manifest.yml

# TODOS
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

name() {
  printf '%s' "$(basename "${BASH_SOURCE[0]}")"
}

a_msg() {
  echo "$(name) ABORTED"
}

e_msg() {
  echo -e "$(name) ERROR:\n\t$1"
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
  local first=${1%%.*} # Delete first dot and what follows
  local last=${1##*.} # Delete up to last dot
  local mid=${1##$first.} # Delete first number and dot
  mid=${mid%%.$last} # Delete dot and last number
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

gls_version() {
  local ver=
  ver="$(grep -oE "([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?" "$1" | head -n 1)"
  [[ -z $ver ]] && return 1
  echo "$ver"
  return 0
}

set_base_version() {
  local ver ec hook1 hook2 err_p1 err_p2 err_p3
  hook1="$(pwd)/.gp"
  hook2="$hook1/CHANGELOG.md"
  err_p1="Undectable gls version"
  err_p2="Could not find required file: $hook2"
  err_p3="Could not parse version number from: $hook2"

  [[ ! -d $hook1 ]] && e_msg "$err_p1 Could not find $hook1" && return 1
  [[ ! -f $hook2 ]] && e_msg "$err_p1\n\t$err_p2" && return 1

  ver="$(gls_version "$hook2")"
  ec=$?
  [[ $ec == 1 ]] && e_msg "$err_p3\n\tThis file should never be altered but it was." && return 1
  base_version="$ver"
  return 0
}

set_target_version() {
 target_version=1.6.0
}

do_yq() {
  local min_ver=4.19.1
}

main() {
  local e1 e2
  e1="Version mismatch"
  if ! set_target_version; then a_msg && exit 1; fi
  if ! set_base_version; then a_msg && exit 1; fi
  if [[ $(comp_ver_lt "$base_version" "$target_version") == 0 ]]; then
    e2="You current version v$base_version must be less than the latest version v$target_version"
    e_msg "$e1\n\t$e2" && a_msg && exit 1
  fi
  echo "Updating gls v$base_version to v$target_version"
}

main

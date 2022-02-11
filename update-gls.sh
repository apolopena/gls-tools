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

e_msg() {
  echo -e "$(basename $BASH_SOURCE) ERROR:\n\t$1"
}

gls_version() {
  local v=
  v="$(grep -oE "([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?" "$1" | head -n 1)"
  echo "$v"
}

valid_version() {
  local hook1 hook2 err_p1 err_p2
  hook1="$(pwd)/.gp"
  hook2="$hook1/CHANGELOG.md"
  err_p1="Undectable gls version"
  err_p2="Could not parse required file: $hook2"
  [[ ! -d $hook1 ]] && e_msg "$err_p1 Could not find $hook1" && return 1
  [[ ! -f $hook2 ]] && e_msg "$err_p1\n\t$err_p2" && return 1
  gls_version "$hook2"
  return 0
}

do_yq() {
  local min_ver=4.19.1
}

main() {
 if ! valid_version; then exit 1; fi
}

main

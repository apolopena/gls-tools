#!/bin/bash
# shellcheck source=/dev/null # Ignore non constant sources
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# get-deps.sh
#
# Description:
# A single function for loading and sourcing gls-tool dependencies into the calling script via curl
# 
# Note:
# Only share functions from this script that really need to be shared
# Avoid the 'god object' even though the 'utils' pattern this script uses encourages it ;)

### get-dep.sh ###
# Description:
# Synchronously downloads dependencies ($@) via curl into memory and sources them into the calling script.
# Returns 0 if all dependencies are downloaded and sourced, return 1 otherwise.
# All dependencies passed in will use a base URL of:
#    https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib
# Unless this functions first argument contains the long option flag --load-deps-locally
# In the case of the --load-deps-locally long option flag, dependencies will be loaded relatively
# from the directory where this script resides on the local file system (./tools/lib/)
# Note:
# Requires at least one argument.
# Dependencies will be loaded in the order of the arguments given.
# Echos a 404 error message if the URL does not exist.
# Be aware not to accidentally source anything that will overwrite calling script's declarations.

_get_deps_name='lib/get-deps.sh'

get_deps() {
  local deps i ec url uri load_locally this_script_dir e_pre="$_get_deps_name failed:"
  local base_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib"

  [[ $# -eq 0 || $# -eq 1 && $1 =~ ^-- ]] && echo "$e_pre At least one argument is required" && return 1
  [[ $1 =~ ^- && $1 != --load-deps-locally ]] && echo "$e_pre Invalid option $1" && return 1

  if [[ $1 == --load-deps-locally ]]; then
    load_locally=yes
    this_script_dir="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
    shift
  fi

  deps=("$@")

  if [[ $load_locally == yes ]]; then
    for i in "${deps[@]}"; do
      uri="$this_script_dir/$i"
      if ! source "$uri"; then echo "$e_pre Unable source the required local dependency: $uri"; return 1; fi
    done
    return 0
  fi

  for i in "${deps[@]}"; do
    url="${base_url}/$i"
    if curl --head --silent --fail "$url" &> /dev/null; then
      source <(curl -fsSL "$url" &); ec=$?
      [[ $ec != 0 ]] && echo "$e_pre Unable to source the required dependency from: $url" && return 1
      wait;
    else
      echo "$e_pre 404 error at url: $url"
      return 1
    fi
  done
}


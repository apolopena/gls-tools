#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# get_deps.sh
#
# Description:
# A single function for loading and sourcing gls-tool dependencies into the calling script via curl
# 
# Note:
# Only share functions from this script that really need to be shared
# Avoid the 'god object' even though the 'utils' pattern this script uses encourages it ;)

### get_deps ###
# Description:
# Synchronously downloads dependencies ($@) via curl into memory and sources them into the calling script.
# Returns 0 if all dependencies are downloaded and sourced, return 1 otherwise.
# All dependencies pass in will use a base URL of:
#    https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib
#
# Note:
# Requires at least one argument.
# Dependencies will be loaded in the order of the arguments given.
# Echos a 404 error message if the URL does not exist.
# Be aware not to accidentally source anything that will overwrite calling script's declarations.
get_deps() {
  local deps=("$@")
  local i ec url load_locally base_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib"
  [[ $# -eq 0 || $# -eq 1 && $1 =~ ^-- ]] && echo "get_deps() failed: at least one argument is required" && return 1
  [[ $1 == --load-locally ]] && load_locally=yes && shift

  for i in "${deps[@]}"; do
    if [[ $load_locally == yes ]]; then
      # shellcheck source=/dev/null
      . "lib/$i"
      return 0
    fi
    url="${base_url}/$i"
    if curl --head --silent --fail "$url" &> /dev/null; then
      # shellcheck source=/dev/null
      source <(curl -fsSL "$url" &)
      ec=$?
      if [[ $ec != 0 ]] ; then echo "Unable to source $url"; return 1; fi
      wait;
    else
      echo "404 error at url: $url"
      return 1
    fi
  done
}


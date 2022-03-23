#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# manifest.sh
#
# Description:
# Utility library
# 
# Note:
# When adding to this file keep in mind the programming concept of 'god object' and avoid it ;) 
# In other words only share functions that really need to be shared


### url_exists ###
# Description:
# Essentially a 'dry run' for curl. Returns 1 if the url ($1) is a 404. Returns 0 otherwise.
url_exists() {
  [[ -z $1 ]] && echo "Internal error: No url argument" && return 1
  if ! curl --head --silent --fail "$1" &> /dev/null; then return 1; fi
}

### get_deps ###
# Description:
# Synchronously downloads dependencies ($@) via curl into memory and sources them into the calling script.
# Returns 0 if all dependencies are downloaded and sourced, return 1 otherwise.
# All dependencies pass in will use a base URL of:
#    https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib
#
# Note:
# Requires at least one argument
# Echos a 404 error message if the URL does not exist
# Be aware not to accidentally source anything that will overwrite this script declarations
get_deps() {
  local deps=("$@")
  local i ec url base_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib"
  [[ $# -eq 0 ]] && echo "get_deps() failed: at least one argument is required" && return 1

  for i in "${deps[@]}"; do
    url="${base_url}/$i"
    if url_exists "$url"; then
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
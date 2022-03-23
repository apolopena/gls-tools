#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# util.sh
#
# Description:
# Utility library
# 
# Note:
# Only share functions from this script that really need to be shared
# Avoid the 'god object' even though the 'utils' pattern this script uses encourages it ;)


### url_exists ###
# Description:
# Essentially a 'dry run' for curl. Returns 1 if the url ($1) is a 404. Returns 0 otherwise.
_url_exists() {
  [[ -z $1 ]] && echo "Internal error: No url argument" && return 1
  if ! curl --head --silent --fail "$1" &> /dev/null; then return 1; fi
}
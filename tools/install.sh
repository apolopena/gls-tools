#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# install-gls.sh
# Version: 0.0.1
#
# Description:
# Installs gitpod-laravel-starter.
# Interactive prompts with automated backup when existing project files will be overwritten.

# Globals
version=
tarball_url=

url_exists() {
  [[ -z $1 ]] && return 1
  if ! curl --head --silent --fail "$1" &> /dev/null; then return 1; fi
}

get_deps() {
  local url url_root="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib"
  url="$url_root/third-party/spinner.sh"
  if url_exists ""; then
    # shellcheck source=/dev/null
    if ! source <(curl -fsSL "$url"); then echo "Unable to source $url"; return 1; fi
  else
    echo "404 error at url: $url"
    return 1
  fi
}

spinner_task() {
  local e_pre msg command ec
  e_pre="Spinner task failed:"
  [[ -z $1 ]] && echo "$e_pre Missing message argument" && return 1
  [[ -z $2 ]] && echo "$e_pre Missing command argument" && return 1
  if ! msg="$1" && command="$2" && shift && shift; then
    echo "$e_pre Could not process arguments" && return 1
  fi
  command="$2 $@"
  echo "debug command=$command"
  start_spinner "$2" && eval "$command"
  ec=$?
  [[ $ec != 0 ]] && echo "ERROR: $msg" && stop_spinner 1 && return 1
  echo "SUCCESS: $msg"
  stop_spinner 0
}

test() {
  echo "1=$1, 2=$2"
}

init() {
  local msg
  if ! get_deps; then echo "Failed to download dependencies" && return 1; fi
  msg="Downloading latest release data from github"
  if ! spinner_task "test" "testing1" "testing2" "testing3"; then return 1; fi
}

main() {
  if ! init; then echo "Script aborted" && exit 1; fi
}

main


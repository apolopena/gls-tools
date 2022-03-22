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

get_deps() {
  local url="https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/lib"
  # shellcheck source=/dev/null
  source <(curl -fsSL "$url/third-party/spinner.sh")
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
  if ! get_deps; then echo "Failed to download dependencies from $url" && return 1; fi
  msg="Downloading latest release data from github"
  if ! spinner_task "test" "testing1" "testing2" "testing3"; then return 1; fi
}

main() {
  if ! init; then echo "Script aborted" && exit 1; fi
}

main


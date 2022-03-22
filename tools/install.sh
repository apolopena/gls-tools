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

# BEGIN: Globals

# Latest version number for gitpod.laravel-starter. Set via set_release_data()
latest_version=

# Latest tarball url for gitpod.laravel-starter. Set via set_release_data()
latest_tarball_url=

# END: GLobals

url_exists() {
  [[ -z $1 ]] && echo "Internal error: No url argument" && return 1
  if ! curl --head --silent --fail "$1" &> /dev/null; then return 1; fi
}

get_deps() {
  local url url_root="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib"
  url="$url_root/third-party/spinner.sh"
  if url_exists "$url"; then
    # shellcheck source=/dev/null
    if ! source <(curl -fsSL "$url"); then echo "Unable to source $url"; return 1; fi
  else
    echo "404 error at url: $url"
    return 1
  fi
}

spaces-to-dashes() {
  echo "$1" | tr ' ' '-'
}

dashes-to-spaces() {
  echo "$1" | tr '-' ' '
}

# Runs any function in this script with an number of args
# Uses a spinner to inform the user of the progress and tick while the task is performed
# First argument to this function must be the spinner(user) message
spinner_task() {
  local e_pre msg ec command
  e_pre="Spinner task failed:"
  [[ -z $1 ]] && echo "$e_pre Missing message argument" && return 1
  msg="$(spaces-to-dashes "$1")"
  [[ -z $2 ]] && echo "$e_pre Missing command argument" && return 1
  # For security only eval functions that exist in this script
  if ! declare -f "$2" > /dev/null; then echo "$e_pre function does not exist: $2" && return 1; fi
  command="$2"
  shift; shift
  start_spinner "$(dashes-to-spaces "$msg") " && eval "$command $*"
  ec=$?
  [[ $ec != 0 ]] && stop_spinner 1 && return 1
  stop_spinner 0
}

set_release_data() {
  local url msg release_json chunk version_regex
  version_regex='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"

  # Download
  if ! url_exists "$url"; then echo "404 error at url: $url" && return 1; fi
  release_json="$(curl -fsSL "$url")"

  # Parse and set globals
  chunk="$(echo "$release_json" | grep 'tarball_url')"
  latest_tarball_url="$(echo "$chunk" | grep -oE 'https.*"')"
  latest_tarball_url="${latest_tarball_url::-1}"
  latest_version="$(echo "$chunk" | grep -oE "$version_regex")"
  #[[ -z $latest_tarball_url ]] && echo "failed to parse the latest tarball_url" && return 1
  #[[ -z $latest_version ]] && echo "failed to parse the latest version" && return 1
}

install_latest() {
  if ! curl -sL "$latest_tarball_url" | tar xz --strip=1; then return 1; fi
}

test() {
  echo "1=$1, 2=$2"
}

init() {
  local msg
  if ! get_deps; then echo "Failed to download dependencies" && return 1; fi

  msg='Downloading latest release data from github'
  if ! spinner_task "$msg" "set_release_data"; then return 1; fi

  msg="Downloading and extracting the latest version of gitpod-laravel-starter v$latest_version\nfrom:"
  if ! spinner_task "$msg\n\t$latest_tarball_url\nto:\n\t$(pwd)" "install_latest"; then return 1; fi
}

main() {
  if ! init; then echo "Script aborted" && exit 1; fi
}

main


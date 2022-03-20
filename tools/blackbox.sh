#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# blackbox.sh
#
# Description:
# Installer and uninstaller for gitpod-laravel-starter
# Blackbox testing tool for installing, uninstalling and analyzing gitpod-laravel-starter projects
#
# Note:
# The script requires the first argument to be the 'gls' command and then any supported sub command
# routine will be called.
# Supported options should be last after the command and all other sub command
# Only long options are supported which are the following:
# --use-version-stub: stubs the tags json file 
# --treat-as-unbuilt:
#           Omits the moving of the below files to the .gp folder if they exist:
#           CHANGELOG.md, README.md, LICENSE


script="$(basename "${BASH_SOURCE[0]}")"
script_args=("$@")
github_api_url="https://api.github.com/repos/apolopena/gitpod-laravel-starter"

# Set by the init routine
declare -A tarball_urls=()
versions=()

has_option() {
  printf '%s\n' "${script_args[@]}" | grep -Fxq -- "$1"
}

init() {
  local version urls url ver_regex
  ver_regex='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'

  # Disable POSIX mode if enabled so we get the behavior we expect for builtins such as mapfile
  case :$SHELLOPTS: in
    *:posix:*) set +o posix; echo "POSIX mode was disabled" ;;
  esac
  
  # Populate the tarball_urls associative array with the tarball urls of all releases using the 
  # version number as the key. Assume that all releases are github tags with the pattern: vX+.X+.X+
  # where X+ is any number of digits.
  # If a --use-version-stub argument exists then use a hardcoded stub rather than downloading the tag data
  if ! has_option '--use-version-stub'; then
    mapfile -t urls < <(curl $github_api_url/tags 2>&1 | grep 'tarball_url')
  else
    echo "Using a hardcoded version stub, version data is NOT live."
    mapfile -t urls < <(version_stub)
  fi

  for (( i=0; i<${#urls[@]}; i++ )); do
    version="$(echo "${urls[$i]}" | grep -oE "$ver_regex")"
    versions[$i]="$version"
    url="$(echo "${urls[$i]}" | grep -oE 'https.*"')"
    url="${url::-1}"
    [[ $version =~ $ver_regex ]] && tarball_urls[$version]="$url"
  done
  # Uncomment to print the contents of the tarball_urls array
  #for x in "${!tarball_urls[@]}"; do printf "[%s]=%s\n" "$x" "${tarball_urls[$x]}" ; done
}

version_stub() {
  echo -e '\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.3.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.4",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.3",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.2",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.1a",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.0.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.1.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.5.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.4.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.2.0",'
}

version_exists() {
  [[ ${tarball_urls["$1"]+exists} ]] && return 0
  return 1
}

move_metafiles() {
  [[ ! -d .gp ]] && return 0
  for m in 'CHANGELOG.md' 'README.md' 'LICENSE'; do
    if ! mv "$m" ".gp/$m"; then echo "Failed to move metafile $m to .gp/$m"; fi
  done
  return 0
}

prompt_y_n() {
  local question="$1 (y/n)? "
    while true; do
      read -rp "$( echo -e "$question")" input
      case $input in
        [Yy]* ) break;;
        [Nn]* ) return 1;;
        * ) echo -e "Please answer y for yes or n for no.";;
      esac
    done
}

new_sandbox() {
  local s='sandbox'

  [[ $(basename "$(pwd)") == "$s" ]] \
  && echo "Cannot create a new sandbox from within the sandbox" \
  && echo "Move up a directory and run the script again" \
  && return 1

  if [[ -d $s ]]; then
    rm -rf $s
  fi
  mkdir $s
  if ! cd $s; then echo "could not cd into $(pwd)/$s" && return 1; fi
  install "$1"
}

install() {
  local msg

  [[ -z $1 ]] && echo "The install command requires a version number argument" && return 1
  if ! version_exists "$1"; then echo "gitpod-laravel-starter version $1 does not exist" && return 1; fi
  
  url="${tarball_urls[$1]}"
  msg="Downloading and extracting gitpod-laravel-starter release v$1"
  echo -e "$msg"

  if ! curl -sL "$url" | tar xz --strip=1; then
    echo -e "$script Error: $msg from $url"
    return 1
  fi

  # Moving the files that gitpod laravel starter would have moved if the project was already built
  if ! has_option '--treat-as-unbuilt'; then move_metafiles; fi

  echo -e "SUCCESS: gitpod-laravel-starter v$1 has been installed to $(pwd)"
}

new() {
  [[ -z $1 ]] && echo "The new subommand requires an additional subcommand argument" && return 1

  case $1 in 
    'sandbox')
      [[ -z $2 ]] && echo "The sandbox command requires a version argument" && return 1
      if ! version_exists "$2"; then 
        echo "sandbox command required a valid gitpod-laravel-starter version. Not $2"
        echo "To see a list of valid version run: gls version-list"
        return 1
      fi
      if prompt_y_n "Creating a new sandbox will delete any existing sandbox.\n\tProceed"; then
        if new_sandbox "$2"; then return 0; fi
      fi
      echo "Command 'new sandbox' aborted by user"
    ;;

    *)
      echo "unsupported new subcommand: $1"
    ;;
  esac
}


gls() {
  if ! init; then echo "$script Internal Error: Initialization failed"; exit 1; fi
  
  case "${script_args[1]}" in 
    'install')
      if ! install "${script_args[2]}"; then 
        echo "$script Error: failed to install gitpod-laravel-starter release version ${script_args[2]}"
      fi
    ;;

    'install-latest')
      if ! install "${versions[0]}"; then
        echo "$script Error: failed to install latest version of gitpod-laravel-starter ${versions[0]}"
      fi
    ;;

    'latest-version')
      echo "${versions[0]}"
    ;;

    'version-list')
      printf '%s\n' "${versions[@]}"
    ;;

    'new')
      if ! new "${script_args[2]}" "${script_args[3]}" ; then echo "Error: new subcommand failed"; fi
    ;;

    *)
      echo "gls subcommand not found: ${script_args[1]}"
    ;;
  esac
  
}

[[ -z $1 ]] && echo "$script cannot be run without a command" && exit 1
[[ $1 != 'gls' ]] && echo "$script only supports the gls command" && exit 1

# Call functions from this script gracefully
if declare -f "$1" > /dev/null; then
  # call arguments verbatim
  "$@"
else
  echo "$script: '$1' is not a known function name" >&2
  exit 1
fi

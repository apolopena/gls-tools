#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# blackbox.sh
#
# Description:
#
# Blackbox testing tool for installing, uninstalling and analyzing gitpod-laravel-starter projects
#
# Note:
# The script requires the first argument to be the 'gls' command and then any supported sub command
# routine will be called.
# Supported flags should be last after the command and sub command
# Only long options are supported such as: --use-version-stub


script="$(basename "${BASH_SOURCE[0]}")"
script_args=("$@")
github_api_url="https://api.github.com/repos/apolopena/gitpod-laravel-starter"

# Set by the init routine
declare -A tarball_urls=()

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
  if ! printf '%s\n' "${script_args[@]}" | grep -Fxq -- '--use-version-stub'; then
    mapfile -t urls < <(curl $github_api_url/tags 2>&1 | grep 'tarball_url')
    echo "${urls[@]}"
  else
    echo "Using a hardcoded version stub, version data is NOT live."
    mapfile -t urls < <(version_stub)
  fi

  for (( i=0; i<${#urls[@]}; i++ )); do
    version="$(echo "${urls[$i]}" | grep -oE "$ver_regex")"
    url="$(echo "${urls[$i]}" | grep -oE 'https.*"')"
    url="${url::-1}"
    [[ $version =~ $ver_regex ]] && tarball_urls[$version]="$url"
  done
  # Uncomment to print the contents of the tarball_urls array
  #for x in "${!tarball_urls[@]}"; do printf "[%s]=%s\n" "$x" "${tarball_urls[$x]}" ; done
}

in_array() {
  local arr match="$1"
  shift
  for arr; do [[ "$arr" == "$match" ]] && return 0; done
  return 1
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

test_version_exists() {
  if version_exists "$1"; then echo "v$1 exists"; else echo "v$1 does not exist"; fi
}

install() {
  local msg

  [[ -z $1 ]] && echo "The install command requires a version number argument" && return 1
  if ! version_exists "$1"; then echo "gitpod-laravel-starter version $1 does not exist" && return 1; fi
  
  url="${tarball_urls[$1]}"
  msg="Downloading and extracting gitpod-laravel-starter release v$1"
  echo -e "$msg"
  if ! curl -sL "$url" | tar xz --strip=1; then
    echo -e "Error: $msg from $url"
    return 1
  fi
  echo "gitpod-laravel-starter v$1 has been installed to $(pwd)"
}


gls() {
  if ! init; then echo "Internal Error: Initialization failed"; exit 1; fi
  case "${script_args[1]}" in 
    'install')
      if ! install "${script_args[2]}"; then echo "Error: failed to install gitpod-laravel-starter release version ${script_args[2]}"; fi
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
  echo "blackbox.sh: '$1' is not a known function name" >&2
  exit 1
fi

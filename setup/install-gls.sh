#!/bin/bash
# shellcheck disable=SC2016 # Allow expressions in single quotes (for sed)
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# install-gls.sh
#
# Description:
# Installs the lastest release of all the public gls-tools suite as a single executable to /usr/local/bin
#
# Usage example:
# curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/setup/install-gls.sh | sudo bash
#
# Note: 
# Requires bash >= 4 and must be run as root
# This is just as secure as any installer since all code in this script and the scripts it sources
# are encapsulated by functions 

download_latest_release() {
  local loc url tarball_url
  loc="$1"
  url="https://api.github.com/repos/apolopena/gls-tools/releases/latest"

  [[ -z $1 ]] && echo "missing argument" && return 1
  [[ ! -d ${loc%/*} ]] && echo "temporary installation directory does not exist: ${loc%/*}" && return 1

  if ! curl --silent "$url" -o "$loc"; then echo "bad curl" && return 1; fi
  [[ ! -f $loc ]] && echo "nothing at $loc"  return 1

  [[ "$(sed -n '/message/p' "$loc" | grep -o '"Not Found.*"' | tr -d '"')" == "Not Found" ]] \
    && echo "No releases available" && return 1

  tarball_url="$(sed -n '/tarball_url/p' "$loc" | grep -o '"https.*"' | tr -d '"')"
  [[ -z $tarball_url ]] && echo "parser failed" && return 1

  if ! curl -sL "$tarball_url" | tar xz --strip=1; then
    echo "Could not download and extract $tarball_url" && return 1
  fi
}

install() {
  local new_code='tools_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.gls-tools'
  local bin_file="gls.sh"
  local verb="installed"

  [[ -d /usr/local/bin/.gls-tools ]] && verb="updated"
  [[ ! -f $bin_file ]] && echo "tarball was missing required file: $bin_file" && return 1
  [[ ! -d tools ]] && echo "tarball was missing the required directory: tools"
  
  if [[ -f /usr/local/bin/gls && -d /usr/local/bin/.gls-tools ]]; then
    [[ $(bash gls.sh --version) == $(gls --version ) ]] && echo "gls is already up to date" && return 1
  fi

  # Remove tools/internal so users don't have access to internal tools.
  [[ -d tools/internal ]] && rm -rf tools/internal

  # Rename tools directory to .gls-tools to reduce the chances of it getting ovewritten by another process
  mv 'tools' '.gls-tools'

  # Parse gls.sh to properly handle tools being renamed .gls-tools, report if nothing was parsed
  sed -i.bak "/^tools_dir=\$(dirname/c $new_code" "$bin_file"
  if cmp -s  "$bin_file" "$bin_file.bak"; then echo "warning: nothing was parsed in $bin_file"; fi
  
  # Move the file gls.sh to usr/local/bin/gls
  mv "$bin_file" "/usr/local/bin/$(basename "$bin_file" .sh)"

  # Update/install the directory usr/local/bin/.gls-tools, use rsync if it's there
  if command -v rsync > /dev/null; then
    [[ ! -d /usr/local/bin/.gls-tools ]] && mkdir /usr/local/bin/.gls-tools
    rsync -avq --delete .gls-tools/ /usr/local/bin/.gls-tools/
  else
    [[ -d /usr/local/bin/.gls-tools ]] && rm -rf /usr/local/bin/.gls-tools 
    mv .gls-tools /usr/local/bin/.gls-tools
  fi

  echo "gls version $(gls --version) has been $verb in /usr/local/bin"
  echo "For more information run: gls --help"
}

main() {
  local tmp_dir e_fail_cd="install-to-bin.sh failed to cd into"
  
  [[ $(id -u) -ne 0 ]] && echo "must be run as root" && exit 1

  tmp_dir="/tmp/gls-install-as-bin-$(date +"%Y%m%d%H%M%S")"
  mkdir "$tmp_dir" && if ! cd "$tmp_dir"; then echo "$e_fail_cd $tmp_dir" && exit 1; fi

  if ! download_latest_release "$tmp_dir/latest_release.json"; then exit 1; fi
  if ! install; then exit 1; fi
}

main "$@"
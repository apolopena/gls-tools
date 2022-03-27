#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# install-to-bin.sh
#
# Description:
# Installs the lastest releast of gls-tools as a executable  /usr/local/bin
#
# Usage example:
# sudo bash <(curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/setup/install-to-bin.sh)
#
# Note: 
# Requires bash >= 4 and must be run as root

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
main() {
  local name="install-to-bin.sh"
  local tmp_dir e_fail_cd="$name failed to cd into"
  

  [[ $(id -u) -ne 0 ]] && echo "must be run as root" && exit 1
  tmp_dir="/tmp/gls-install-as-bin-$(date +"%Y%m%d%H%M%S")"
  mkdir "$tmp_dir" && if ! cd "$tmp_dir"; then echo "$e_fail_cd $tmp_dir" && exit 1; fi
  if ! download_latest_release "$tmp_dir/latest_release.json"; then exit 1; fi
}

main "$@"
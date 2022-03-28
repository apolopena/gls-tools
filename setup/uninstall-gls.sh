#!/bin/bash
# shellcheck disable=SC2016 # Allow expressions in single quotes (for sed)
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# uninstall-gls.sh
#
# Description:
# Uninstalls gls and its dependencies from /usr/local/bin
#
# Usage example:
# curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/setup/uninstall-gls.sh | sudo bash
#
# Note: 
# Must be run as root


main() {
  local file=/usr/local/bin/gls
  local dir=/usr/local/bin/.gls-tools
  [[ $(id -u) -ne 0 ]] && echo "uninstall-gls.sh must be run as root" && exit 1
  [[ ! -f $file  && ! -d $dir ]] && echo "gls is not installed, nothing to uninstall" && exit
  [[ -d "$dir" ]] && rm -rf "$dir"
  [[ -f $file ]] && if ! rm "$file"; then echo "failed to uninstall gls" && exit 1; fi
  echo "gls was uninstalled"
}

main
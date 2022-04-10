#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# gls.sh
#
# Description:
# Runs the gls tools as a single binary from somewhere like /usr/local/bin
# Passes the --load-deps-locally to each tools script it supports
# 
# Note:
# Do not run this script remotely. If you want gls tools to run remotely then run each tools individually
# For running the tools individually see: https://github.com/apolopena/gls-tools/blob/main/README.md
# To reduce the chances of the tools directory being overwritten in somewhere like /usr/local/bin
#
# Regarding installation of this script to somewhere like /usr/local/bin 
# All the steps below should be done as root.
# 1. Copy this file to somewhere like /usr/local/bin
# 2. Remove the file extension form this file by renaming /usr/local/bin/gls.sh to /usr/local/bin/gls
# 2. Parse the first line of code in the script where the tools_dir is set to:
#    tools_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.gls-tools
# 3. Recursively copy the tools directory to the same location where this script was copied to in step 1
# 4. Rename the tools directory to .gls-tools

gls_version() {
  echo "0.0.5
gls is command line utility that wraps the gls-tools suite
Copyright © 2022 Apolo Pena
License MIT <https://spdx.org/licenses/MIT.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Apolo Pena; see
<https://github.com/apolopena/gls-tools/graphs/contributors>"
}

gls_help() {
  echo -e "gls is a command line tool for gitpod-laravel-starter"
  echo -e "Usage:"
  echo -e "\tgls <command> [command options]"
  echo -e "\tgls list-options <command>"
  echo -e "\tgls [--help | --version]"
  echo
  echo -e "Example:"
  echo -e "\tgls update --help"
  echo
  echo -e "Commands:"
  echo -e "\tinstall       Installs the latest release of gitpod-laravel-starter"
  echo -e "\tuninstall     Uninstalls gitpod-laravel-starter"
  echo -e "\tupdate        Updates an existing installation of 
                           gitpod-laravel-starter to the latest release"
  echo
  echo -e "Options:"
  echo -e "\t--help        Output this help message and exit"
  echo -e "\t--version     Output version information and exit"
}

main() {
  local cmd tools_dir arg args tmp_args=()

  [[ -z $1 ]] && gls_help && exit;
  [[ $1 == --help ]] && gls_help && exit
  [[ $1 == --version ]] && gls_version && exit
  [[ $1 =~ ^- ]] && echo "unsupported option $1" && exit

  tools_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/tools
  args=("$@")
  cmd="$1"
  
  # Filter out arguments out that should not be passed to child scripts
  for arg in "${args[@]}"; do 
    case $arg in
      'install'                                      );;
      'uninstall'                                    );;
      'update'                                       );;
      '--load-deps-locally' | '-load-deps-locally'   );;
                                                    *) tmp_args+=("$arg");;
    esac
  done
  args=("${tmp_args[@]}"); unset tmp_args

  case $cmd in
    'install'     ) bash "$tools_dir/install.sh" --load-deps-locally "${args[@]}"; exit ;;
    'uninstall'   ) "$1 is not yet implemented"; exit ;;
    'update'      ) bash "$tools_dir/update.sh" --load-deps-locally "${args[@]}"; exit ;;
                 *) echo "not a valid command: $1"; exit ;;
  esac
}

main "$@"
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

tools_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/tools

supported_command() {
  local supported=('install' 'uninstall' 'update' 'list-options')
  printf '%s\n' "${supported[@]}" | grep -Fxq -- "$1"
}

gls_version() {
  echo "0.0.1"
}

gls_help() {
  echo -e "gls is a command line tool for gitpod-laravel-starter"
  echo -e "Usage:"
  echo -e "\tgls <command> [command options]"
  echo -e "\tgls list-options <command>"
  echo -e "\tgls [--help | --version]"
  echo
  echo -e "Commands:"
  echo -e "\tinstall       Installs gitpod-laravel-starter"
  echo -e "\tuninstall     Uninstalls gitpod-laravel-starter"
  echo -e "\tupdate        Updates an existing installation of gitpod-laravel-starter"
  echo -e "\tlist-options  List options for a command"
  echo
  echo -e "Options:"
  echo -e "\t--help        Output this help message and exit"
  echo -e "\t--version     Output version information and exit"
}

gls_install() {
  echo "The install command has not yet been implemented"
}

gls_uninstall() {
  echo "The uninstall command has not yet been implemented"
}

list_command_options() {
  [[ -z $1 ]] && echo "list-options requires an argument" && exit 1
  if ! supported_command "$1"; then echo "Cannot list options for unsupported command: $1" && exit 1; fi

   case $1 in
    'install'     )     echo "list-options for the 'install' command has not yet been implmented" ;;
    'uninstall'   )     echo "list-options for the 'uninstall' command has not yet been implmented" ;;
    'update'      )     bash "$tools_dir/update.sh" --help ;;
    'list-options')     echo "list-options has no options" ;;
                 *)     echo "list_command_options() internal error"; exit ;;
  esac 

}

gls_update() {
  shift
  # TODO: detect if $@ contains --load-deps-locally and remove it since it would be redundant and cause errors
  bash "$tools_dir/update.sh" --load-deps-locally "$@"
}

main() {
  [[ -z $1 ]] && gls_help && exit;
  [[ $1 == --help ]] && gls_help && exit
  [[ $1 == --version ]] && gls_version && exit
  [[ $1 =~ ^- ]] && echo "Unsupported option $1" && exit

  if ! supported_command "$1"; then echo "Unsupported command: $1" && exit; fi

  case $1 in
    'install'     )     gls_install "$@"; exit ;;
    'uninstall'   )     gls_uninstall "$@"; exit ;;
    'update'      )     gls_update "$@"; exit ;;
    'list-options')     list_command_options "$2"; exit ;;
                 *)     echo "internal error"; exit ;;
  esac
}

main "$@"
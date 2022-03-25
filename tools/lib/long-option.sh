#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# long-option.sh
#
# Description:
# Ultra simple long option support
#
# Note:
# All long options are treated as global flags

_long_option_name='lib/long-option.sh'
___long_options=()


### has_long_option  ###
# Description:
# Returns 0 if a long option has been set by via init_long_options()
# Returns 1 if a long option has not been set by via init_long_options()
# 
# Note:
# The one-time function set_long_options() must be called prior to calling this function
has_long_option() {
  printf '%s\n' "${___long_options[@]}" | grep -Fxq -- "$1"
}


### is_long_option ###
# Description:
# Validates  the structure of a long option
# Returns 0 if $1:
# Starts with double dashes followed by any number of uppercase or lowercase letters or integers
# optionally followed by zero or more sets of a single dash that must be accompanied 
# by any number uppercase or lowercase letters
# Returns 1 otherwise
is_long_option() {
  [[ $1 =~ ^--[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]] && return 0 || return 1
}

### set_long_options ###
# Description:
# One time operation to set the long options internal array
#
# Note:
# Make sure you pass in all the array elements calling script's script arguments ${@}
# See the usage example for more details
#
# Usage example:
#  #! /bin/bash
#  # example-script.sh
#  # Run: bash example-script.sh --foo --bar--baz foobarbaz
#  # Outputs:
#  # --foo
#  # --bar--baz
#  source lib/long-option.sh
#  main() {
#    set_long_options "$@"
#  }  
#  main
#
set_long_options() {
  local script_args=("$@")

  if [[ ${#___long_options[@]} -gt 0 ]]; then
    echo "$_long_option_name failed: internal error: long options can only be set once"
    return 1
  fi

  local arg i=0
  for arg in "${script_args[@]}"; do
    if is_long_option "$arg"; then
      ___long_options[$i]="$arg"
      (( i++ ))
    fi
  done
  return 0
}

### list_long_options ###
# Description:
# Prints a list of all long options passed a script that sources this script or this script
# 
# Note:
# The one-time function set_long_options() must be called prior to calling this function
list_long_options() {
  [[ ${#___long_options[@]} -gt 0 ]] && printf '%s\n' "${___long_options[@]}"
}
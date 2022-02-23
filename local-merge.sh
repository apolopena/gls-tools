#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# local-merge.sh
#
# Description:
# Merge, resolve any merge conflicts in two unstaged files and save that result to a target file
# The current file ($1) and a new file ($2) are merged into a target file ($3)  
# The target file can be either the original file, the new file or a file that does not yet exist
# Merge conflicts will automatically open as a temporary file in VSCode  and at that point the 
# merge conflicts must be resolved and the file closed before the script can continue
# Once the script continues it will save the temporary file as the target file and exit
#
# Notes:
# Wraps git merge-file


# BEGIN: Globals
# Errors
_E_NO_GIT=70
_E_GIT_CMD_FAILED=72
_E_NO_VSCODE=74
_E_OPT_ONE_ARG_ONLY=82
_E_THREE_ARGS_ONLY=84
_E_ORIG_FILE_NO_EXIST=86
_E_NEW_FILE_NO_EXIST=88
_E_FILE_DUPE=90
_E_ILLEGAL_TARGET_FILE=92
# Arguments passed to this script
script_args=("$@")
# File to save the results of the merge to
target_file=
# END: Globals

### _err_msg ###
# Description:
# Echoes an error message $1
# Echoes a multilined error message if the -m option is used as the first argument
_err_msg() {
  if [[ $1 == -m ]]; then 
    echo -e "local-merge ERROR:\n\t$1"
  else
    echo "local-merge ERROR: $1"
  fi
}

### _error_desc ###
# Description:
# Echoes an error message depending on the exit code
# Note:
# See the screaming snake case variables prefixed with _E_ in the Globals section for the integer values
_error_desc() {
  case "$1" in
    1)
      echo -n "generic"
      ;;

    "$_E_NO_GIT")
      echo -n "no git binary found"
      ;;

    "$_E_NO_VSCODE")
      echo -n "no vscode binary found"
      ;;

    "$_E_GIT_MERGE_FILE")
      echo -n "git merge-file command failed"
      ;;

    "$_E_OPT_ONE_ARG_ONLY")
      echo -n "option ${script_args[0]} requires exactly one value"
      ;;

    "$_E_THREE_ARGS_ONLY")
      echo -e "exactly three arguments are required"
      echo -e "\tthe orginal file: \$1"
      echo -e "\tthe new file: \$2"
      echo -e "\tthe target file to save the merged result to: \$3"
      ;;

    "$_E_ORIG_FILE_NO_EXIST")
      echo -n "original file does not exist: ${script_args[0]}"
      ;;

    "$_E_FILE_DUPE")
      echo -e "the original file cannot be the same as the new file"
      ;;

    "$_E_NEW_FILE_NO_EXIST")
      echo -n "new file does not exist: ${script_args[1]}"
      ;;

    "$_E_ILLEGAL_TARGET_FILE")
      echo -e "illegal target file: ${script_args[2]}"
      echo -e "\ttarget file cannot be an existing file unless it is"
      echo -e "\teither the original file (\$1), the new file (\$2)"
      ;;

    *)
      echo -n "Unknown"
      ;;
  esac
}

### _show_help ###
# Description:
# shows the help message
_show_help() {
  echo -e "\nA wrapper around git merge-file that merges two unstaged files
Requires git, VSCode is also required to resolve any merge conflicts.

Usage:

  local-merge [-h | --help | <orig_file new_file target_file> | --err-desc <error_code>]

  Options:
    -h  --help    Display this help and exit
    --err-desc    Pass in an error code integer and get a description of that errror
    orig_file     The original file to merge with the new file.
                  Must be the first argument.
    new_file      The new file to merge with the original file.
                  Must be the second argument.
    target_file   The target file to save results of merge to.
                  Must be the third argument.
                  Warning: Will overwrite any file!
  "
}

## _handle_args ###
# Description:
# Rudimentary argument and option handling
# A supported option must be the first argument if there are no files to be merge
# Otherwise the arguments are considered to be file arguments and must be exactly 3
# Original file ($1), New file ($2), and Target file ($3)
# If the file arguments are valid then $3 will be set as the valid for global variable: target_file
#
# Note:
# Unsupported options are considered to be a file arguments
# Options cannot stack: such as: --err-dec -h
# When coding more options:
#   Write a conditional for every possibility, exit on success
#   and return the proper error code on failure
_handle_args() {
  # Option: Help
  if [[ $# -eq 0 || $1 == -h || $1 == --help ]]; then
    _show_help
    exit
  fi
  # Option: error desciption
  if [[ $1 == --err-desc ]]; then
    [[ $# != 2 ]] && return $_E_OPT_ONE_ARG_ONLY
    error_desc "$2" && exit
  fi 
  # Validate arguments, if valid set target_file
  [[ $# -ne 3 ]] && return $_E_THREE_ARGS_ONLY
  if [[ -f $1 ]]; then
    [[ $1 == "$2" ]] && return $_E_FILE_DUPE
    if [[ -f $2 ]]; then
       [[ $2 == "$1" ]] && return $_E_FILE_DUPE
      if  [[ ! -f $3 ]]; then
        target_file="$3"
      else
        [[ $3 == "$1" ]] && target_file="$1" && return 0
        [[ $3 == "$2" ]] && target_file="$2" && return 0
        return $_E_ILLEGAL_TARGET_FILE
      fi # end check target file
    else
      return $_E_NEW_FILE_NO_EXIST
    fi # end check new file 
  else
    return $_E_ORIG_FILE_NO_EXIST
  fi # end check original file
}

### check_deps ###
# Description:
# returns an error code if any required binaries or commands are not installed or functioning
_check_deps() {
  if ! git --help &>/dev/null; then return $_E_NO_GIT; fi
  if ! git merge-file --help &>/dev/null; then return $_E_GIT_CMD_FAILED; fi
  if ! code --help &>/dev/null; then return $_E_NO_VSCODE; fi
}

### _main ###
# Description:
# Main routine
_main() {
  local ec

  _check_deps || ec=$? && [[ $ec -ne 0 ]] && _err_msg "$(_error_desc $ec)" && exit $ec
  _handle_args "$@" || ec=$? && [[ $ec -ne 0 ]] && _err_msg "$(_error_desc $ec)" && exit $ec
  # target_file is set, so do the merge
  echo "target file is: $target_file"
}

_main "$@"

#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# directives.sh
#
# Requires:
# utils.sh
#
# Description:
# Executes directives from a manifest to either keep or backup files or directories
# Files and driectories are recommended to be backed up if they have the potential to share project data
# such as .gitignore or even a hybrid setup where .gitpod.yml or .gitpod.Dockerfile has been altered
# Backed up files and directories can then be merged by hand back into the updated project.
#
# About the manifest:
# The manifest is loaded from
# https://raw.githubusercontent.com/apolopena/gls-tools/main/.latest_gls_manifest
# where it is dynamically generated each time gitpod-laravel-starter is released
# using: https://github.com/apolopena/gls-tools/blob/main/tools/manifest.sh
# If for some reason the manifest cannot be loaded then a hardcoded version will be used
# Supported directives in the manifest are:
#    [keep]
#    [recommend-backup]
#
# All unsupported directives in the manifest will be ignored
#
# Note:
# NOTE SURE WHAT TO DO ABOUT UTILITY FUNCTIONS, 
# SHARING THEM MAKES A MESSY PATTERN AND SO DOES DUPLICATING THEM



# NEW GLOBALS NEEDED
# ___manifest
#


# GLOBALS USED
# data_keeps=(), data_bakups=()

# FUNCTIONS TO BRING IN
# set_directives() # requires: $data_keeps, $data_backups
# parse_manifest_chunk()
# has_directive() # requires: The manifest file and default_manifest()
# execute_directives() # requires: $data_keeps, $data_backups, err_msg()
# keep() # requires: $project_root, $target_dir, $note_prefix, err_msg(), is_subpath(), yes_no()
# recommend_backup() # requires: $project_root, $backups_dir, err_msg(), is_subpath(), yes_no()


__data_keeps=()
__data_bakcups=()

### _directives_err_msg ###
# Description:
# Echos an error message ($1)
_directives_err_msg() {
  echo -e "lib/directives.sh ${c_fail}ERROR:${c_e}\n\t$1"
}

### default_manifest ###
# Description:
# The default manifest to use if the latest gls manifest cannot be downloaded
default_manifest() {
  echo "[version]
1.5.0

[keep]
.gp/bash/init-project.sh

[recommend-backup]
.gitignore
.gitattributes
starter.ini
.npmrc
.gitpod.yml
.gitpod.Dockerfile
/.github
/.vscode"
}

### set_directives ###
# Description:
# Parses a valid .updater_manifest into global arrays of directives
# if $1 is not passed in then  the global $tmp_dir will be used if it contains a valid directory
# $1 or $tmp_dir should be the temporary working direcotry for an update, install or uninstall
# $1 or $tmp_dir (depending on which is used) are not a valid directory exit code 1 will be returned
#
# Sets the following global arrays:
# $data_keeps $data_merges $data_backups $data_deletes
set_directives() {
  local err_pre="set_directives() internal error:"
  local manifest_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/.latest_gls_manifest"
  local chunk manifest manifest_file  ec

  [[ -n $1 ]] && [[ ! -d $1 ]] && echo -e "$err_pre bad temp directory argument" && return 1
  if [[ -n $1 && -d $1 ]]; then
    manifest_file="$1/$(basename $manifest_url)"
  else
    [[  -z $1 && -z $tmp_dir ]] && echo "$err_pre $tmp_dir must be set prior to calling this function" && return 1
    [[ ! -d $tmp_dir ]] && echo "$err_pre not a directory @ $tmp_dir" && return 1
    manifest_file="$tmp_dir/$(basename $manifest_url)"
  fi

  # Download the manifest as a file to the temp working directory
  if ! curl -sf "$manifest_url" -o "$manifest_file"; then
    echo -e "${c_norm_prob} Could not download the updater manifest at ${c_uri}$manifest_file${c_e}"
    manifest=$(default_manifest)
    echo -e "${c_norm_prob}Using the default manifest:\n${c_file}$manifest${c_e}"
  else
    manifest="$(cat "$manifest_file")"
  fi

  # Parse chunks and convert them to global directive arrays
  if has_directive 'keep' "$manifest_file"; then
    chunk="$(parse_manifest_chunk 'keep' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a __data_keeps <<< "$chunk"
  else
    echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_file}keep${c_e}"
  fi

  if has_directive 'recommend-backup' "$manifest_file"; then
    chunk="$(parse_manifest_chunk 'recommend-backup' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a __data_backups <<< "$chunk"
  else
    echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_file}recommend-backup${c_e}"
  fi

  echo "directives.sh successfull parsed the manifest into directive chunks"
  echo -e "keeps array is:\n${__data_keeps[*]}"
  echo -e "data_backups array is:\n${__data_backups[*]}"

  return 0
}

### has_directive ###
# Description:
# returns  0 if the updater manifest has the start marker ($1)
# returns 1 if the updater manifest does not contain the start marker ($1)
# Checks the default manifest if the updater manifest file is not found
has_directive() {
  local manifest err_pre="has_directive() error:"

  if [[ -z $2 ]]; then
    manifest="$(default_manifest)"
    echo -e "set_directive() is using the default manifest"
  else
    [[ ! -f $2 ]] && echo -e "$err_pre manifest file argument is not a file @ $2" && return 1
    manifest="$(cat "$2")"
  fi

  if echo "$manifest" | grep -oP --silent "\[${1}\]"; then
    return 0
  fi

  return 1
}

### parse_manifest_chunk ###
# Description:
# Parses a chunk (directive section) of the manifest
parse_manifest_chunk() {
  local err_p err_1 err_1b err_missing_marker chunk ec 
  err_p="${c_file_name}parse_manifest_chunk(): ${c_norm_prob}parse error${c_e}"
  err_missing_marker="${c_e}${c_file_name}[${c_e}${c_number}$1${c_e}${c_file_name}]${c_e}"

  # Error handling
  err_1="${c_norm_prob}Exactly ${c_number}2${c_e}"
  err_1b="${c_norm_prob}arguments are required. Found ${c_number}$#${c_e}"
  [[ $# -ne 2 ]] && _directives_err_msg "$err_p\n\t$err_1 $err_1b" && return 1
  [[ -z $1 || -z $2 ]] && _directives_err_msg "$err_pre\n\tBad data: an argument was empty. Check the calling function." && return 1
  # TODO verify the enitre manifest to ensure that header sections are delimited by an empty line
  err_3="${c_norm_prob}Unable to find start marker: ${err_missing_marker}"
  if ! echo "$2" | grep -oP --silent "\[${1}\]"; then
    _directives_err_msg "$err_p\n\t$err_3" && return 1
  fi

  # If we got this far we can parse and return success no matter what
  echo "$2" | sed -n '/\['"$1"'\]/,/^$/p' | grep -v "\[$1\]"; return 0
}

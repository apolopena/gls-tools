#!/bin/bash
# Allow backslash+linefeed in a literal (for eval), will go away when we start using shellcheck > 0.7.2 
# shellcheck disable=SC1004
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# directives.sh
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
# Output will be colorized if a script that sources this script implments lib/colors.sh
# Additional output for the --strict flag will occur if a script that sources this script
# implements lib/long-options.sh and has a warn_msg function

# BEGIN: Globals
# Satisfy shellcheck by defining the global variables this script requires but does not define
project_root=; tmp_dir=; target_dir=; backups_dir=; base_version=;
__data_keeps=(); __data_backups=()
# Flag for the edge case where only the cache buster has been changed in .gitpod.Dockerfile
gp_df_only_cache_buster_changed=no 
# Satisfy shellcheck since this is a variable that this script sets but does not use
: "$gp_df_only_cache_buster_changed"
# Satisfy shellcheck happy by predefining the colors we use here. See lib/colors.sh
c_e=; c_norm=; c_norm_prob=; c_pass=; c_fail=; c_file=;
c_file_name=; c_url=; c_uri=; c_number=; c_choice=; c_prompt=;
# END: Globals


### _directives_err_msg ###
# Description:
# Echos an error message ($1)
_directives_err_msg() {
  echo -e "${c_file_name}lib/directives.sh ${c_fail}ERROR:${c_e}\n\t$1"
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

### ___is_subpath ###
# Description:
# Internal function that returns 0 if ($2) is a subpath of ($1), returns 1 otherwise
___is_subpath() {
  if [[ $(realpath --relative-base="$1" -- "$2" 2>/dev/null)  =~ ^/ ]]; then
    return 1
  else
    return 0
  fi
}

### ___is_element ###
# Description:
# Internal function for checking if an array contains a value
# Returns 0 is an array ($1) contains a value ($2)
# returns 1 if an array ($1) does not contain a value ($2)
#
# Note:
# False positives will/can occur if:
#  The value contains line breaks like: "my\nvalue"
#  The array is associative
___is_element() {
  local args=("$@")
  local index="${args[-1]}"
  printf '%s\n' "${args[@]}" | grep -Fxq -- "$index"
}

### set_directives ###
# Description:
# Downloads and parses a valid manifest (to $1) into global directive arrays 
# If $1 is not passed in then the global $tmp_dir will be used if it is a valid directory
# $1 or $tmp_dir should be the temporary working direcotry for an update, install or uninstall
# If $1 or $tmp_dir (depending on which is used) are not a valid directory exit code 1 will be returned
# Can be used to set any number of directives contained in the manifest ($1) by passing in any number
# of supported long options as an arguments to this function ($2...$10) as long as they come after the
# manifest argument ($1). Supported long options are --keep-only and --recommend-backup-only
# If no supported long options arguments are passed into this function then all directives in the
# manifest will be set.
#
# Note:
# A hardcoded default manifest will be used if the manifest cannot be downloaded
# Will error out if an unsupported options are used. See the supported options variable in this function
# for more details.
# The following global array will be set if the manifest is successfully parsed:
# $__data_keeps$ $__data_backups
set_directives() {
  local err_pre="${c_norm_prob}set_directives() internal error:${c_e}"
  local e_short_opt="${c_norm_prob} short options are not allowed:"
  local manifest_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/.latest_gls_manifest"
  local note_prefix="${c_file_name}Notice:${c_e}"
  local long_opt_regexp='^--[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$'
  local chunk manifest manifest_file ec msg1 msg1 arg supported_opts opts=()

  supported_opts=(
    --only-keep
    --only-recommend-backup
  )

  # Handle any options passed into this function
  for arg in "$@"; do
    [[ $arg == '-' || $arg =~ ^-[^\--].* ]] && _directives_err_msg "$err_pre$e_short_opt $arg" && return 1
    if [[ $arg =~ $long_opt_regexp ]]; then
      if ___is_element "$arg" "${supported_opts[@]}"; then
        opts+=("$arg")
      else
        _directives_err_msg "$err_pre${c_norm_prob}unsupported long option: $arg"  && return 1
      fi
    fi
  done

  # Handle the optional $1 arg (alternate $tmp_dir location)
  if [[ -n $1 && ! $1 =~ $long_opt_regexp  && ! -d $1 ]]; then
    _directives_err_msg "$err_pre ${c_norm_prob}bad temp directory argument: ${c_uri}$1${c_e}"
    return 1
  fi

  # Set the manifest file path
  if [[ -n $1 && -d $1 ]]; then
    manifest_file="$1/$(basename $manifest_url)"
  else
    if [[  -z $1 && -z $tmp_dir ]]; then
      msg1="$err_pre ${c_url}$tmp_dir ${c_e}"
      msg2="${c_norm_prob}must be set prior to calling this function${c_e}"
      _directives_err_msg "$msg1 $msg2"
      return 1
    fi
    if [[ ! -d $tmp_dir ]]; then
      _directives_err_msg "$err_pre ${c_norm_prob}not a directory @ ${c_uri}$tmp_dir${c_e}"
      return 1
    fi
    manifest_file="$tmp_dir/$(basename $manifest_url)"
  fi

  # Download manifest file and set manifest data
  if ! curl -sf "$manifest_url" -o "$manifest_file"; then
    echo -e "${c_norm_prob} Could not download the updater manifest from ${c_uri}$manifest_url${c_e}"

    # clear manifest_file to keep _parse_manifest_chunk() satisfied
    manifest_file=

    manifest=$(default_manifest)
    echo -e "${c_norm_prob}Using the default manifest:\n${c_file}$manifest${c_e}\n"
  else
    manifest="$(cat "$manifest_file")"
  fi

  # Parse chunks and convert them to global directive arrays
  if ___is_element "${opts[@]}" --only-keep; then
    if has_directive 'keep' "$manifest_file"; then
      chunk="$(_parse_manifest_chunk 'keep' "$manifest")"
      ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
      IFS=$'\n' read -r -d '' -a __data_keeps <<< "$chunk"
    else
      echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_file}keep${c_e}"
    fi
  fi
  if ___is_element "${opts[@]}" --only-recommend-backup; then
    if has_directive 'recommend-backup' "$manifest_file"; then
      chunk="$(_parse_manifest_chunk 'recommend-backup' "$manifest")"
      ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
      IFS=$'\n' read -r -d '' -a __data_backups <<< "$chunk"
    else
      echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_file}recommend-backup${c_e}"
    fi
  fi

  return 0
}

### has_directive ###
# Description:
# returns 0 on the first occurrence of a start marker ($1) in a manifest file ($2)
# returns 1 if there are no occurrences of a start marker ($1) in a manifest file ($2)
# If the manifest argument ($2) is empty then the default manifest will be used
has_directive() {
  local manifest err_pre="has_directive() error:"

  if [[ -z $2 ]]; then
    manifest="$(default_manifest)"
  else
    [[ ! -f $2 ]] && echo -e "$err_pre manifest file argument is not a file @ $2" && return 1
    manifest="$(cat "$2")"
  fi

  if echo "$manifest" | grep -oP --silent "\[${1}\]"; then
    return 0
  fi

  return 1
}

### _parse_manifest_chunk ###
# Description:
# Internal function that parses a directive section (chunk) of the manifest
_parse_manifest_chunk() {
  local err_p err_1 err_1b err_missing_marker chunk ec 
  err_p="${c_file_name}_parse_manifest_chunk(): ${c_norm_prob}parse error${c_e}"
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

### execute_directives ###
# Description:
# Runs a function for each item in each global directive array
# Outputs debugging info if --debug is passed in ($1)
#
# Note: 
# Each function called will make system calls that affect the filesystem
# This function should be error handled by the caller
#
# Requires Global Arrays:
# $__data_keeps: calls the function: keep, for each item in the array
# $__data_backups: calls the function: recommend_backup, for each item in the array
execute_directives() {
  local e_pre="${c_norm_prob}execute_directives() internal error: Failed to"
  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE KEEP:"
    [[ ${#__data_keeps[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#__data_keeps[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing ${__data_keeps[$i]}"
    if ! ___keep "${__data_keeps[$i]}"; then
      _directives_err_msg "$e_pre keep ${c_uri}${__data_keeps[$i]}${c_e}"
      return 1
    fi
  done

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE RECOMMEND TO BACKUP:"
    [[ ${#__data_backups[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#__data_backups[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${__data_backups[$i]}"
    if ! ___recommend_backup "${__data_backups[$i]}"; then
      _directives_err_msg "$e_pre recommend-backup for ${c_uri}${__data_backups[$i]}${c_e}"
      return 1
    fi
  done
}

### ___keep ###
# Description:
# Internal function
# Persists a file ($1) or directory ($1) from the base (orig) version to the latest (target) version
# by copying a file or directory (recursively) from an original location ($project_root/$1)
# to a target location ($target_dir/$1).
# The target location will be deleted (recursively via rm -rf) prior to the copy.
# If ($1) starts with a / it is considered a directory
# If ($1) does not start with a / then it is considered a file
#
# Note:
# The keep operation will not occur if there are files or directories have no differences between them
# The keep operation will not occur if the file or directory for the original or the target does not exist
# If the calling script has implmented /lib/long-options.sh and has a warn_msg function and the 
# global option --strict has been passed in by the user then a warning will be printed about the missing
# file or directory
#
# Additional Note:
# This function should be error handled by the caller even though this function is robust
# This function will return an error if the target location is not a subpath of $project_root
# If the global variable $base_version is not set then it will be set locally to the string: unknown
# Exit code 1 is returned if any required global variables are not present or not valid files
# or directories
#
# Required Globals Variables:
# $project_root 
# $target_dir
___keep() {
  local name orig_loc target_loc err_pre e1_pre note1 note1b note1c orig_ver_text note_prefix
  local has_long_option_exists warn_msg_exists

  has_long_option_exists="$(declare -f "has_long_option" > /dev/null)"
  warn_msg_exists="$(declare -f "warn_msg" > /dev/null)"

  note_prefix="${c_file_name}Notice:${c_e}"
  name="${c_file_name}keep()${c_e}"
  err_pre="${c_norm_prob}Failed to ${c_e}$name"
  e1_pre="${c_norm_prob}Could not find${c_e}"

  if [[ -n $base_version ]]; then
    orig_ver_text="${c_number}v$base_version${c_e}"
  else
    orig_ver_text="${c_number}v unknown${c_e}"
  fi
  
  if [[ -z $project_root ]]; then
    _directives_err_msg "$name${c_norm_prob}: required global variable \$project_root${c_e}"
    return 1
  fi

  if [[ -z $target_dir ]]; then
    _directives_err_msg "$name${c_norm_prob}: required global variable \$target_dir${c_e}"
    return 1
  fi

  if [[ ! -d $project_root ]]; then
    _directives_err_msg "$name${c_norm_prob}: \$project_root is not a directory: ${c_uri} $project_root${c_e}"
    return 1
  fi

  if [[ ! -d $target_dir ]]; then
    _directives_err_msg "$name ${c_norm_prob}\$target_dir is not a valid directory: ${c_uri} $target_dir${c_e}"
    return 1
  fi

  if [[ -z $1 ]]; then
    _directives_err_msg "$err_pre\n\t${c_norm_prob}Missing argument. Nothing to keep.${c_e}"
    return 1
  fi

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    target_loc="$target_dir$1"
    
    # Return 0 if a directory is specified in the manifest but not present in the original or the latest
    # If the --strict option is used then output a warning about what was missing
    # Only do this a the script sourcing this script has the warn_msg and has_long_option functions
    # See lib/long-options.sh for more details about long option processing
    if [[ $has_long_option_exists -eq 0 && $warn_msg_exists -eq 0 ]]; then
      if has_long_option --strict; then
        if [[ ! -d $orig_loc ]]; then
          warn_msg "$err_pre\n\t$e1_pre directory ${c_uri}$orig_loc${c_e}"
          return 0
        fi
        if [[ ! -d "$target_dir/$1" ]]; then 
          warn_msg "$err_pre\n\t$e1_pre directory ${c_uri}${target_dir}/${1}${c_e}"
          return 0
        fi
      else
        [[ ! -d $orig_loc ]] && return 0
        [[ ! -d "$target_dir/$1" ]] && return 0
      fi
    else
      [[ ! -d $orig_loc ]] && return 0
      [[ ! -d "$target_dir/$1" ]] && return 0
    fi
    
    # Skip keeping the directory if the original and target exists and there are no differences
    [[ -d $orig_loc && -d $target_loc ]] && [[ -z $(diff -qr "$orig_loc" "$target_loc") ]] && return 0

    # For security $target_loc must be a subpath of $project_root
    if ___is_subpath "$project_root" "$target_loc"; then
      note1="$note_prefix ${c_file}Recursively kept original ($orig_ver_text${c_file}) directory${c_e}"
      note1b="${c_uri}$orig_loc${c_e}\n\t${c_file}as per the directive set in the updater manifest\n\t"
      note1c="This action will result in some of the latest changes being omitted${c_e}"
      echo -e "${note1} ${note1b}${note1c}"
      rm -rf "$target_loc" && cp -R "$orig_loc" "$target_loc"
      return $?
    fi
    echo -e "$name ${c_norm_prob}failed. Illegal target ${c_uri}$target_loc${c_e}"
    return 1
  fi

  # It's a file
  orig_loc="$project_root/$1"
  target_loc="$target_dir/$1"

  # Return 0 if a file is specified in the manifest but not present in the original or the latest
  # If the --strict option is used then output a warning about what was missing
  # Only do this a the script sourcing this script has the warn_msg and has_long_option functions
  # See lib/long-options.sh for more details about long option processing
  if [[ $has_long_option_exists -eq 0 && $warn_msg_exists -eq 0 ]]; then
    if has_long_option --strict; then
      if [[ ! -f $orig_loc ]]; then
        warn_msg "$err_pre\n\t$e1_pre file ${c_uri}$orig_loc${c_e}"
        return 0
      fi
      if [[ ! -f "$target_dir/$1" ]]; then 
        warn_msg "$err_pre\n\t$e1_pre file ${c_uri}${target_dir}/${1}${c_e}"
        return 0
      fi
    else
      [[ ! -f $orig_loc ]] && return 0
      [[ ! -f "$target_dir/$1" ]] && return 0
    fi
  else
    [[ ! -f $orig_loc ]] && return 0
    [[ ! -f "$target_dir/$1" ]] && return 0
  fi

  # Skip keeping the file if the original and target exists and there are no differences
  [[ -d $orig_loc && -d $target_loc ]] && [[ -z $(diff -qr "$orig_loc" "$target_loc") ]] && return 0

  # For security $target_loc must be a subpath of $project_root
  if ___is_subpath "$project_root" "$target_loc"; then
    note1="$note_prefix ${c_file}Kept original ($orig_ver_text${c_file}) file${c_e}"
    note1b="${c_uri}$orig_loc\n\t${c_file}as per the directive set in the updater manifest\n\t"
    note1c="This action will result in some of the latest changes being omitted${c_e}"
    if [[ $(basename "$orig_loc") == 'init-project.sh' ]]; then
      echo -e "${c_norm}Keeping project specific file:\n${c_uri}$orig_loc${c_e}"
    else
      echo -e "${note1} ${note1b}${note1c}"
    fi
    cp "$orig_loc" "$target_loc"
    return $?
  fi
  echo -e "$name ${c_norm_prob}failed. Illegal target ${c_uri}$target_loc${c_e}"
  return 1
}

### recommend_backup ###
# Description:
# 
# Requires Globals:
# $project_root $backups_dir
___recommend_backup() {
  local name orig_loc target_loc err_pre e1_pre msg cb
  local has_long_option_exists warn_msg_exists instr_file decor

  has_long_option_exists="$(declare -f "has_long_option" > /dev/null)"
  warn_msg_exists="$(declare -f "warn_msg" > /dev/null)"

  decor="----------------------------------------------"
  name="${c_file_name}recommend_backup()${c_e}"
  err_pre="${c_norm_prob}Failed to ${c_e}$name"
  e1_pre="${c_norm_prob}Could not find${c_e}"

  if [[ -z $project_root ]]; then
    _directives_err_msg "$name${c_norm_prob}: required global variable \$project_root${c_e}"
    return 1
  fi

  if [[ -z $backups_dir ]]; then
    _directives_err_msg "$name${c_norm_prob}: required global variable \$backups_dir${c_e}"
    return 1
  fi

  if [[ ! -d $project_root ]]; then
    _directives_err_msg "$name${c_norm_prob}: \$project_root is not a directory: ${c_uri} $project_root${c_e}"
    return 1
  fi

  if [[ ! -d $backups_dir ]]; then
    _directives_err_msg "$name ${c_norm_prob}\$backups_dir is not a valid directory: ${c_uri} $target_dir${c_e}"
    return 1
  fi

  if [[ -z $1 ]]; then
    _directives_err_msg "$name\n\t${c_norm_prob}Missing argument. Nothing to recommend a backup for.${c_e}"
    return 1
  fi

  target_loc="$backups_dir/$(basename "$1")"

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"

    # Return 0 if a directory is specified in the manifest but not present in the original or the latest
    # If the --strict option is used then output a warning about what was missing
    # Only do this a the script sourcing this script has the warn_msg and has_long_option functions
    # See lib/long-options.sh for more details about long option processing
    if [[ $has_long_option_exists -eq 0 && $warn_msg_exists -eq 0 ]]; then
      if has_long_option --strict; then
        if [[ ! -d $orig_loc ]]; then
          warn_msg "$err_pre\n\t$e1_pre directory ${c_uri}$orig_loc${c_e}"
          return 0
        fi
        if [[ ! -d "$target_dir/$1" ]]; then 
          warn_msg "$err_pre\n\t$e1_pre directory ${c_uri}${target_dir}/${1}${c_e}"
          return 0
        fi
      else
        [[ ! -d $orig_loc ]] && return 0
        [[ ! -d "$target_dir/$1" ]] && return 0
      fi
    else
      [[ ! -d $orig_loc ]] && return 0
      [[ ! -d "$target_dir/$1" ]] && return 0
    fi

    # Skip backing up the directory if there are no differences between the current and the latest
    [[ -d $orig_loc && -d "${target_dir}${1}" ]] \
    && [[ -z $(diff -qr "$orig_loc" "${target_dir}${1}") ]] && return 0

    # For security proceed with the backup only if the target is within the project root
    if ___is_subpath "$project_root" "$target_loc"; then

      if ! ___backup "directory" "$orig_loc" "$target_loc"; then return 1; fi

      # If there is no target directory then the backup was intentionally skipped
      [[ ! -d $target_loc ]] && return 0

      # Otherwise append merge instructions for each backup to file to locations_map.txt
      instr_file="$backups_dir/locations_map.txt"
      msg="Merge your backed up project specific data:\n\t$target_loc\ninto\n\t$orig_loc"
      if echo -e "${decor}\n$msg\n${decor}\n" >> "$instr_file"; then
        echo -e "${c_norm}Merge instructions for this file can be found at:\n${c_uri}$instr_file${c_e}"
      else
        echo -e "${c_norm_prob}Error could not create locations map file: ${c_uri}$instr_file${c_e}"
        echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_uri}$target_loc${c_e}"
      fi
      echo -e "${c_file}${decor}${decor}${c_e}"
      return 0
    fi
    echo -e "$name ${c_norm_prob}failed. Illegal target ${c_uri}$target_loc${c_e}"
    return 1
  fi

  # It's a file...
  orig_loc="$project_root/$1"

  # Return 0 if a file is specified in the manifest but not present in the original or the latest
  # If the --strict option is used then output a warning about what was missing
  # Only do this a the script sourcing this script has the warn_msg and has_long_option functions
  # See lib/long-options.sh for more details about long option processing
  if [[ $has_long_option_exists -eq 0 && $warn_msg_exists -eq 0 ]]; then
    if has_long_option --strict; then
      if [[ ! -f $orig_loc ]]; then
        warn_msg "$err_pre\n\t$e1_pre file ${c_uri}$orig_loc${c_e}"
        return 0
      fi
      if [[ ! -f "$target_dir/$1" ]]; then 
        warn_msg "$err_pre\n\t$e1_pre file ${c_uri}${target_dir}/${1}${c_e}"
        return 0
      fi
    else
      [[ ! -f $orig_loc ]] && return 0
      [[ ! -f "$target_dir/$1" ]] && return 0
    fi
  else
    [[ ! -f $orig_loc ]] && return 0
    [[ ! -f "$target_dir/$1" ]] && return 0
  fi

  # Skip backing up the file if there are no differences between the current and the latest
  [[ -z $(diff -q "$orig_loc" "$target_dir/$1") ]] && return 0
  
  # EDGE CASE: If the only change in .gitpod.Dockerfile is the cache buster value then
  # make that change in current (orig) version of the file instead of recommending the backup
  # Note: this will leave a changed file in the project root if the update fails further down the line.
  if [[ $(diff  --strip-trailing-cr "$target_dir/$1" "$orig_loc" | grep -cE "^(>|<)") == 2 ]]; then
    cb="$(diff "$target_dir/$1" "$orig_loc" | grep -m 1 "ENV INVALIDATE_CACHE" | cut -d"=" -f2- )"
    if [[ $cb =~ ^[0-9]+$ ]]; then
      if sed -i "s/ENV INVALIDATE_CACHE=.*/ENV INVALIDATE_CACHE=$cb/" "$orig_loc"; then
        gp_df_only_cache_buster_changed=yes
      fi
      return 0
    fi
  fi

  # For security proceed with the backup only if the target is within the project root
  if ___is_subpath "$project_root" "$target_loc"; then

    if ! ___backup "file" "$orig_loc" "$target_loc"; then return 1; fi

    # If there is no target file then the backup was intentionally skipped
    [[ ! -f $target_loc ]] && return 0

    # Otherwise append merge instructions for each backup to file to locations_map.txt
    instr_file="$backups_dir/locations_map.txt"
    msg="Merge your backed up project specific data:\n\t$target_loc\ninto\n\t$orig_loc"
    if echo -e "${decor}\n$msg\n${decor}\n" >> "$instr_file"; then
      echo -e "${c_norm}Merge instructions for the file can be found at:\n${c_uri}$instr_file${c_e}"
    else
      echo -e "${c_norm_prob}Error could not create locations map file ${c_uri}$instr_file${c_e}"
      echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_uri}$target_loc${c_e}"
    fi
    echo -e "${c_file}${decor}${decor}${c_e}"
    return 0
  fi
  echo -e "$name ${c_norm_prob}failed. Illegal target ${c_uri}$target_loc${c_e}"
  return 1
}

### ___backup ###
# Description:
# Internal function to perform an interactive backup of a file or directory
# Requires exactly three arguments
# $1 is the type, either: file or directory
# $2 is the source location, it must be a valid file or directory
# $3 is the destination location
#
# Note:
# Behavior of this function depends on if the calling script has certain functions from lib
# This function will not fail if the calling script is missing certain function from lib
# If the calling script uses lib\long-option.sh and the global long option --prompt-diffs is passed to
# the calling script then an additional prompt regarding viewing the differences between the source
# and the target will occur
___backup() {
  local e_pre e_cant_diff decor note_prefix yn question msg b_msg1 b_msg2 b_msg2b b_msg2c warn1 warn1b 
  local input prompt_again1 prompt_again1b success_msg1 success_msg1b ec
  e_pre="${c_norm_prob}___prompt_backup() internal error:"
  e_cant_diff="$e_pre can't diff. bad or missing \$target_dir"
  [[ $# -ne 3 ]] && _directives_err_msg "$e_pre required exactly 3 arguments, got $#${c_e}" && return 1
  if [[ -z $1 ]] || [[ $1 != 'file' && $1 != 'directory' ]]; then
    _directives_err_msg "$e_pre bad type arg: $1. \$1 can only be: file or directory${c_e}" && return 1
  fi

  # Clear out any possible dynamic scoping so this function does not rely on a callers scope
  local orig_loc="$2"
  local target_loc="$3"

  has_long_option_exists="$(declare -f "has_long_option" > /dev/null)"
  decor="----------------------------------------------"
  note_prefix="${c_file_name}Notice:${c_e}"
  yn="${c_e}${c_prompt}(${c_choice}y${c_e}${c_prompt}/${c_e}${c_choice}n${c_prompt})${c_e}"
  b_msg1="${c_file}There is probably project specific data in"
  question="${c_prompt}Would you like to perform the backup now ${yn}${c_prompt}? ${c_e}"
  warn1="$note_prefix ${c_norm}Answering no${c_e}"
  warn1b="${c_norm}will skip the backup which will most likely overwrite project specific data.${c_e}"
  prompt_again1="${c_norm}Please answer ${c_choice}y${c_e}"
  prompt_again1b="${c_norm}for yes or ${c_choice}n${c_e}${c_norm} for no.${c_e}"
  b_msg2="${c_norm}It is recommended that you back it up to:\n"
  b_msg2b="${c_uri}${3}${c_e}"
  b_msg2c="${c_norm}and merge it manually back into the project after the update has succeeded.${c_e}"
  success_msg1="${c_pass}SUCCESS: ${c_file}Backed up the file:\e[J\n${c_uri}$orig_loc${c_e}"
  success_msg1b="${c_norm}to${c_e}\n${c_uri}${target_loc}${c_e}"
  
  if [[ $1 == 'file' ]]; then
    [[ ! -f $2 ]] && _directives_err_msg "$e_pre bad source file arg: ${c_uri}${2}${c_e}" && return 1
    b_msg1="${b_msg1} the file:${c_e}"
  fi

  if [[ $1 == 'directory' ]]; then
    b_msg1="${b_msg1} the directory:${c_e}"
    success_msg1="${success_msg1//file/directory}"
  fi

  msg="$b_msg1\n${c_uri}$orig_loc\n$b_msg2$b_msg2b\n$b_msg2c"

  echo -e "${c_file}${decor}${decor}${c_e}"
  echo -e "$msg"

  if [[ $has_long_option_exists -eq 0 && $(has_long_option --prompt-diffs; echo $?) == 0 ]]; then
    [[ ! -d $target_dir ]] && _directives_err_msg "$e_cant_diff" && return 1
    ___prompt_diff "$orig_loc" "$target_dir/$(basename "$orig_loc")"
  fi
  
  while true; do
    read -rp "$( echo -e "$question\e[s\n$warn1 $warn1b\e[u\e[1A")" input
    case $input in
      [Yy]* ) if [[ $1 == 'file' ]]; then 
                cp "$orig_loc" "$target_loc"
              else
                cp -r "$orig_loc" "$target_loc"
              fi
              ec=$?
              if [[ $ec == 0 ]]; then
                echo -e "$success_msg1\n$success_msg1b"
                break
              else
                return 1
              fi;;

      [Nn]* ) echo -e "${note_prefix} ${c_norm_prob}Backup was skipped${c_e}\e[J"
              echo -e "${c_file}${decor}${decor}${c_e}"
              return 0;;
      
      * ) echo -e "$prompt_again1 $prompt_again1b\e[J";;
    esac
  done
}

### ___show_diff ###
# Description:
#
___show_diff() {
  local output l1 l2 has_long_option_exists
  has_long_option_exists="$(declare -f "has_long_option" > /dev/null)"
  l1="current version"; l2="target version" 
  [[ -z $target_version ]] && local target_version=
  if [[ -n $target_version ]]; then
    l2="${l2} v$target_version"
  fi

  output="$(diff -ur --minimal --label="$l1" --label="$l2" "$1" "$2")"
  
  if declare -f "use_color" > /dev/null; then
    if declare -f "colorudiff" > /dev/null; then
      if [[ $(use_color; echo $?) == 0 && $(has_long_option --no-colors; echo $?) -ne 0 ]]; then
        colorudiff "$output"
        return
      fi
    fi
  fi
  echo -e "$output"
}

### ___prompt_diff ###
# Description:
#
___prompt_diff() {
  local input question yn prompt_again1 prompt_again1b
  
  yn="${c_e}${c_prompt}(${c_choice}y${c_e}${c_prompt}/${c_e}${c_choice}n${c_prompt})${c_e}"
  question="${c_prompt}Would you like review the differences before deciding to backup ${yn}${c_prompt}? ${c_e}"
  prompt_again1="${c_norm}Please answer ${c_choice}y${c_e}"
  prompt_again1b="${c_norm}for yes or ${c_choice}n${c_e}${c_norm} for no.${c_e}"

  while true; do
    read -rp "$( echo -e "$question")" input
    case $input in
      [Yy]* )  ___show_diff "$1" "$2"
              return 0;;

      [Nn]* ) return 0;;

      * ) echo -e "$prompt_again1 $prompt_again1b";;
    esac
  done
}
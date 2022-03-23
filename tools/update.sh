#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# update-gls.sh
#
# Description:
# Updates an existing project build on gitpod-laravel-starter to the latest version.
# Automated update with step by step merging of critical files in your existing project.
#
# Notes:
# Supports gitpod-laraver starter versions >= v1.0.0
# For specifics on what files are updated, replaced, left alone, etc.. see: up-manifest.yml @
# https://github.com/apolopena/gitpod-laravel-starter/tree/main/.gp/updater-manifest.yml


# BEGIN: Globals

# This script arguments. Never mutate them.
script_args=("$@")

# The version to update to
target_version=

# The version to update from
base_version=

# target_dir conatins the download of latest version of gls to update the project to
# set in the update routine and deleted in the main routine
target_dir=

# Location for recommended backups (appended in the update routine)
backups_dir="$(pwd)"

# Project root. Never run this script from outside the project root!
project_root="$(pwd)"

# Temporary working directory for the update and is deleted after the script succeeds or fails
tmp_dir="$project_root/tmp_gls_update"

# Files or directories to keep.
data_keeps=()

# Files to recommend backing up so they can be merged manually after the update succeeds
data_backups=()

# Latest release data downloaded from github
release_json="$tmp_dir/latest_release.json"

# Flag for the edge case where only the cache buster has been changed in .gitpod.Dockerfile
gp_df_only_cache_buster_changed=no

# Global message prefixes are declared here but set in main so they can be conditionally colorized
note_prefix=;warn_prefix=

# Keep shellchack happy by predefining the colors set by lib/colors.sh
c_e=; c_s_bold=; c_norm=; c_norm_b=; c_norm_prob=; c_pass=; c_warn=; c_warn2=; c_fail=; c_file=;
c_file_name=; c_url=; c_uri=; c_number=; c_choice=; c_prompt=;

# END: Globals

# BEGIN: functions



### get_deps ###
# Description:
# Synchronously downloads dependencies ($@) via curl into memory and sources them into the calling script.
# Returns 0 if all dependencies are downloaded and sourced, return 1 otherwise.
# All dependencies pass in will use a base URL of:
#    https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib
#
# Note:
# Requires at least one argument
# Echos a 404 error message if the URL does not exist
# Be aware not to accidentally source anything that will overwrite this script declarations
get_deps() {
  local deps=("$@")
  local i ec url base_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib"
  [[ $# -eq 0 ]] && echo "get_deps() failed: at least one argument is required" && return 1

  for i in "${deps[@]}"; do
    url="${base_url}/$i"
    if url_exists "$url"; then
      # shellcheck source=/dev/null
      source <(curl -fsSL "$url" &)
      ec=$?
      if [[ $ec != 0 ]] ; then echo "Unable to source $url"; return 1; fi
      wait;
    else
      echo "404 error at url: $url"
      return 1
  fi
  done
}

### name ###
# Description:
# Prints the file name of this script
# This is hardcoded not done dynamically such as via $(basename ${BASH_SOURCE[0]}) because the
# result is a number rather than a name when the script is ran using process substitution
name() {
  printf '%s' "${c_file_name}update.sh${c_e}"
}

### warn_msg ###
# Description:
# Echos a warning message ($1)
warn_msg() {
  echo -e "$(name) ${c_warn}WARNING:${c_e}\n\t$1" 
}

### err_msg ###
# Description:
# Echos an error message ($1)
err_msg() {
  echo -e "$(name) ${c_fail}ERROR:${c_e}\n\t$1"
}

### abort_msg ###
# Description:
# Echos an abort message ($1) 
abort_msg() {
  echo -e "$(name) ${c_fail}ABORTED${c_e}"
}

### success_msg ###
# Description:
# Echos a success message ($1) 
success_msg() {
  echo -e "${c_pass}SUCCESS: ${c_norm}$1${c_e}"
}

failed_copy_to_root_msg() {
  echo -e "${c_norm_prob}Failed to copy target ${c_uri}$1${c_e}${c_norm_prob} to the project root"
}

### yes_no ###
# Description:
# Echos: (y/n) 
yes_no() {
  echo -e \
  "${c_e}${c_prompt}(${c_choice}y${c_e}${c_prompt}/${c_e}${c_choice}n${c_prompt})${c_e}"
}

### is_script_arg ###
# Description:
# returns 0 if the script arguments contain $1, returns 1 otherwise
# Globals:
# $script_args
is_script_arg() {
  printf '%s\n' "${script_args[@]}" | grep -Fxq -- "$1"
}
### is_subpath ###
# Description:
# returns 0 if ($2) is a subpath of ($1)
# return 1 otherwise
is_subpath() {
  if [[ $(realpath --relative-base="$1" -- "$2")  =~ ^/ ]]; then
    # $2 is NOT subpath of $1
    return 1
  else
    # $2 is subpath of $1
    return 0
  fi
}

### split_ver ###
# Description:
# splits a version number ($1) into three numbers delimited by a space
#
# Notes:
# Assumes the format of the version number will be:
# <any # of digits>.<any # of digits>.<any # of digits>
#
# Usage:
# split_ver 6.31.140
# # outputs: 6 31 140 
split_ver() {
  local first mid last
  first=${1%%.*}; last=${1##*.}; mid=${1##$first.}; mid=${mid%%.$last}
  echo "$first $mid $last"
}


### comp_ver_lt ###
# Description:
# Compares version number ($1) to version number ($2)
# Echos 1 if version number ($1) is less than version number ($2)
# Echos 0 if version number ($1) is greater than or equal to version number ($2)
#
# Notes:
# Assumes the format of the version number will be:
# <any # of digits>.<any # of digits>.<any # of digits>
#
# Usage:
# comp_ver_lt 2.28.10 2.28.9
# # outputs: 1
# comp_ver_lt 0.0.1 0.0.0
# # outputs: 0
comp_ver_lt() {
  local v1=()
  local v2=()
  IFS=" " read -r -a v1 <<< "$(split_ver "$1")"
  IFS=" " read -r -a v2 <<< "$(split_ver "$2")"
  [[ ${v1[0]} -lt ${v2[0]} ]] && echo 1 && exit
  [[ ${v1[0]} -eq ${v2[0]} ]] && \
  [[ ${v1[1]} -lt ${v2[1]} ]] && echo 1 && exit
  [[ ${v1[0]} -eq ${v2[0]} ]] && \
  [[ ${v1[1]} -eq ${v2[1]} ]] && \
  [[ ${v1[2]} -lt ${v2[2]} ]] && echo 1 && exit
  echo 0
}

### gls_verion ###
# Description:
# Parses the first occurrence of a major.minor.patch version number from a file ($1)
gls_version() {
  local ver=
  ver="$(grep -oE "([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?" "$1" | head -n 1)"
  [[ -z $ver ]] && return 1
  echo "$ver"
  return 0
}

### default_manifest ###
# Description:
# The default manifest to use for the update
default_manifest() {
  echo "[keep]
.gp/bash/init-project.sh

[recommend-backup]
starter.ini
.gitattributes
.gitignore
.gitpod.Dockerfile
.gitpod.yml
.npmrc"

}

### set_base_version_unknown ###
# Description:
# Sets the base version to the string: unknown
set_base_version_unknown() {
  local unknown_msg1 unknown_msg1b
  unknown_msg1="${c_norm}The current gls version has been set to '${c_file_name}unknown${c_e}"
  unknown_msg1b="${c_norm}' but is assumed to be ${c_file_name}>= ${c_e}${c_number}1.0.0${c_e}"
  base_version='unknown' && echo -e "$unknown_msg1$unknown_msg1b"
}

### set_base_version ###
# Description:
# Sets the base version to the first occurrence of a version number found in .gp/CHANGELOG.md
# Prompts the user to manually enter a base version if no version can be derived
# Validates the version number range x.x.x is >= 1.0.0 where x is equal to an integer between 0 and 999
set_base_version() {
  local ver input question1 question1b ec gp_dir changelog err_p1 err_p2 err_p3 err_p4 err_p4b err_p4c
  gp_dir="$(pwd)/.gp"
  changelog="$gp_dir/CHANGELOG.md"
  err_p1="${c_norm_prob}Undectable gls version${c_e}"
  err_p2="${c_norm_prob}Could not find required file: ${c_uri}$changelog${c_e}"
  err_p3="${c_norm_prob}Could not parse version number from: ${c_uri}$changelog${c_e}"
  err_p4="${c_norm_prob}Base version is too old, it must be ${c_e}"
  err_p4b="${c_file_name}>= ${c_number}1.0.0${c_e}"
  err_p4c="\n\t${c_norm_prob}You will need to perform the update manually.${c_e}"

  # Derive base version from user input if CHANGELOG.md is not present
  if [[ ! -f $changelog ]]; then
    warn_msg "$err_p1\n\t$err_p2"
    question1="${c_prompt}Enter the gls version you are updating from (hit "
    question1b="${c_choice}y${c_e}${c_prompt} or ${c_choice}enter${c_e}${c_prompt} to skip): ${c_e}"
    read -rp "$( echo -e "${question1}$question1b")" input

    [[ -z $input || $input == y ]] && return 1

    local regexp='^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$'

    if [[ $input =~ $regexp ]]; then
       [[ $(comp_ver_lt "$input" 1.0.0 ) == 1 ]] \
         && err_msg "$err_p4 $err_p4b $err_p4c" \
         && abort_msg \
         && exit 1
      base_version="$input" \
      && echo -e "${c_norm}Base gls version set by user to: ${c_number}$input${c_e}" \
      && return 0
    else
      warn_msg "${c_norm_prob}Invalid gls base version: ${c_number}$input${c_e}" \
      && return 1
    fi
  fi

  # Derive version from CHANGELOG.md
  ver="$(gls_version "$changelog")"
  ec=$?
  [[ $ec == 1 ]] \
    && err_msg "$err_p3\n\t${c_norm_prob}This file should never be altered but it was.${c_e}" \
    && return 1
  base_version="$ver"
  return 0
}

###   ###
# Description:
# 
parse_manifest_chunk() {
  local err_p err_1 err_1b err_missing_marker chunk ec 
  err_p="${c_file_name}parse_manifest_chunk(): ${c_norm_prob}parse error${c_e}"
  err_missing_marker="${c_e}${c_file_name}[${c_e}${c_number}$1${c_e}${c_file_name}]${c_e}"

  # Error handling
  err_1="${c_norm_prob}Exactly ${c_number}2 ${c_e}"
  err_1b="${c_norm_prob}arguments are required. Found ${c_number}$#${c_e}"
  [[ -z $1 || -z $2 ]] && err_msg "$err_p\n\t$err_1 $err_1b" && return 1
  # TODO verify the enitre manifest to ensure that header sections are delimited by an empty line
  err_3="${c_norm_prob}Unable to find start marker: ${err_missing_marker}"
  if ! echo "$2" | grep -oP --silent "\[${1}\]"; then
    err_msg "$err_p\n\t$err_3" && return 1
  fi

  # If we got this far we can parse and return success no matter what
  echo "$2" | sed -n '/\['"$1"'\]/,/^$/p' | grep -v "\[$1\]"; return 0
}


### set_target_version ###
# Description:
# Sets target version and target directory
# Requires Global:
# $release_json (a valid github latest release json file)
set_target_version() {
  local regexp e1 e1b e2
  regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  e1="${c_norm_prob}Cannot set target version"
  e1b="Missing required file ${c_uri}$release_json${c_e}"
  e2="${c_norm_prob}Failed to parse target version from:\n\t${c_uri}$release_json${c_e}"

  [[ ! -f $release_json ]] && err_msg "$e1\n\t$e1b" && return 1
  
  target_version="$(grep "tag_name" "$release_json" | grep -oE "$regexp")"

  [[ -z $target_version ]] && err_msg "$e2" && return 1

  target_dir="$tmp_dir/$target_version"
}

### download_release_json ###
# Description:
# Downloads the latest gitpod-laravel-starter release json data from github
# Requires Global:
# $release_json (a valid github latest release json file)
download_release_json() {
  local url msg
  url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  msg="${c_norm}Downloading release data"
  echo -e "$msg from:\n\t${c_url}$url${c_e}"
  if ! curl --silent "$url" -o "$release_json"; then
    err_msg "${c_norm_prob}Could not download release data from\n\t ${c_url}$url${c_e}"
    return 1
  fi
  return 0
}

### has_directive ###
# Description:
# returns  0 if the updater manifest has the start marker ($1)
# return2 1 if the updater manifest does not contain the start marker ($1)
# Checks the default manifest if the updater manifest file is not found
has_directive() {
  local file manifest
  file="$(pwd)/.gp/.updater_manifest"
  if [[ ! -f $file ]]; then
    manifest="$(default_manifest)"
  else
    manifest="$(cat "$file")"
  fi
  if echo "$manifest" | grep -oP --silent "\[${1}\]"; then
    return 0
  fi
  return 1
}

### set_directives ###
# Description:
# Parses a valid .updater_manifest into global arrays of directives
# Looks for .gp/.updater_manifest and if that doesn't exist then default_manifest is used
# Sets the following global arrays:
# $data_keeps $data_merges $data_backups $data_deletes
set_directives() {
  local chunk manifest file warn1 default ec
  file="$(pwd)/.gp/.updater_manifest"
  warn1="${c_norm_prob} Could not find the updater manifest at ${c_uri}$file${c_e}"
  
  # Get the manifest
  if [[ ! -f $file ]]; then
    default="$(default_manifest)"
    manifest="$default"
    warn_msg "$warn1\n${c_norm_prob} Using the default updater manifest:\n${c_file}$default${c_e}\n"
  else
    manifest="$(cat "$file")"
  fi

  # Parse chunks and convert them to global directive arrays
  if has_directive 'keep'; then
    chunk="$(parse_manifest_chunk 'keep' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a data_keeps <<< "$chunk"
  else
    echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_file}keep${c_e}"
  fi

  if has_directive 'recommend-backup'; then
    chunk="$(parse_manifest_chunk 'recommend-backup' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a data_backups <<< "$chunk"
  else
    echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_file}recommend-backup${c_e}"
  fi

  return 0
}

### execute_directives ###
# Description:
# Runs a function for each item in each global directive array
# Outputs debugging info if --debug is passed in ($1)
#
# Note: 
# Each function called will make system calls that affect the filesystem
# This function should be error handled
#
# Requires Global Arrays:
# $data_keeps: calls the function: keep, for each item in the array
# $data_merges: calls the function: merge, for each item in the array
# $data_recommend_backup: calls the function: recommend_backup, for each item in the array
# $data_deletes: calls the function: delete, for each item in the array
execute_directives() {
  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE KEEP:"
    [[ ${#data_keeps[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_keeps[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing ${data_keeps[$i]}"
    if ! keep "${data_keeps[$i]}"; then return 1; fi
  done

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE RECOMMEND TO BACKUP:"
    [[ ${#data_backups[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_backups[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${data_backups[$i]}"
    if ! recommend_backup "${data_backups[$i]}"; then return 1; fi
  done
}

### keep ###
# Description:
# Persists a file ($1) or directory ($1) from the original (base) version to the updated (target) version
# by copying a file or directory (recursively) from an original location ($project_root/$1)
# to a target location ($target_dir/$1).
# The target location will be deleted (recursively via rm -rf) prior to the copy.
# If ($1) starts with a / it is considered a directory
# If ($1) does not start with a / then it is considered a file
#
# Note:
# This function should be error handled
# This function will return an error if the target location is not a subpath of $project_root
#
# Requires Globals:
# $project_root $target_dir $note_prefix
keep() {
  local name orig_loc target_loc err_pre e1_pre note1 note1b note1c orig_ver_text
  name="${c_file_name}keep()${c_e}"
  err_pre="${c_norm_prob}Failed to ${c_e}$name"
  e1_pre="${c_norm_prob}Could not find${c_e}"
  orig_ver_text="${c_number}v$base_version${c_e}"
  
  [[ -z $1 ]] \
    && err_msg "$err_pre\n\t${c_norm_prob}Missing argument. Nothing to keep.${c_e}" \
    && return 1

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] \
      && err_msg "$err_pre\n\t$e1_pre ${c_norm_prob}directory ${c_uri}$orig_loc${c_e}" \
      && return 1
    target_loc="$target_dir$1"
    
    # Skip keeping the directory if the original and target exists and there are no differences
    [[ -d $orig_loc && -d $target_loc ]] && [[ -z $(diff -qr "$orig_loc" "$target_loc") ]] && return 0

    # For security $target_loc must be a subpath of $project_root
    if is_subpath "$project_root" "$target_loc"; then
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
  [[ ! -f $orig_loc ]] \
    && err_msg "$err_pre\n\t$e1_pre${c_norm_prob} file ${c_uri}$orig_loc${c_e}" \
    && return 1
  target_loc="$target_dir/$1"

  # Skip keeping the file if the original and target exists and there are no differences
  [[ -d $orig_loc && -d $target_loc ]] && [[ -z $(diff -qr "$orig_loc" "$target_loc") ]] && return 0

  # For security $target_loc must be a subpath of $project_root
  if is_subpath "$project_root" "$target_loc"; then
    note1="$note_prefix ${c_file}Kept original ($orig_ver_text${c_file}) file${c_e}"
    note1b="${c_uri}$orig_loc\n\t${c_file}as per the directive set in the updater manifest\n\t"
    note1c="This action will result in some of the latest changes being omitted${c_e}"
    if [[ $(basename "$orig_loc") == 'init-project.sh' ]]; then
      echo -e "${c_norm}Keeping project specific file ${c_uri}$orig_loc${c_e}"
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
# $project_root $backups_dir $warn_prefix
recommend_backup() {
  local name orig_loc target_loc err_pre e1_pre msg b_msg1 b_msg2 b_msg2b b_msg3 msg warn1 warn1b cb
  local question instr_file input decor="----------------------------------------------"
  name="${c_file_name}recommend_backup()${c_e}"
  err_pre="${c_norm_prob}Failed to ${c_e}$name"
  e1_pre="${c_norm_prob}Could not find${c_e}"
  b_msg1="\n${c_file}There is probably project specific data in"
  question="${c_prompt}Would you like perform the backup now $(yes_no)${c_prompt}? ${c_e}"
  warn1="$note_prefix ${c_norm}Answering no to the question below${c_e}"
  warn1b="${c_norm}will most likely result in the loss of project specific data.${c_e}"
  
  [[ ! -d $backups_dir ]] \
    && err_msg " ${c_norm_prob}Missing the recommended backups directory${c_e}" \
    && return 1
  [[ -z $1 ]] \
    && err_msg "$name\n\t${c_norm_prob}Missing argument. Nothing to recommend a backup for.${c_e}" \
    && return 1

  target_loc="$backups_dir/$(basename "$1")"

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] && warn_msg "$err_pre\n\t$e1_pre ${c_uri}$orig_loc${c_e}" && return 0

    # Skip backing up the directory if the original and the target exist and 
    # there are no differences between them
    [[ -d $orig_loc && -d "${target_dir}${1}" ]] \
    && [[ -z $(diff -qr "$orig_loc" "${target_dir}${1}") ]] && return 0

    # For security proceed only if the target is within the project root
    if is_subpath "$project_root" "$target_loc"; then
      b_msg2="${c_norm}It is recommended that you backup the directory:\n\t"
      b_msg2b="${c_e}${c_uri}$orig_loc${c_e}\n${c_norm}to\n\t${c_e}${c_uri}$target_loc${c_e}"
      b_msg3="${c_norm}and merge the contents manually back into the project after the update has succeeded.${c_e}"
      msg="$b_msg1 ${c_e}${c_uri}$orig_loc${c_e}\n$b_msg2$b_msg2b\n$b_msg3\n$warn1 $warn1b"

      echo -e "$msg"

      while true; do
        read -rp "$( echo -e "$question")" input
        case $input in
          [Yy]* ) if cp -R "$orig_loc" "$target_loc"; then echo -e "${c_pass}SUCCESS${c_e}"; break; else return 1; fi;;
          [Nn]* ) return 0;;
          * ) echo -e "${c_norm}Please answer ${c_choice}y${c_e}${c_norm} for yes or ${c_choice}n${c_e}${c_norm} for no.${c_e}";;
        esac
      done

      # Append merge instructions file for each backup made
      instr_file="$backups_dir/locations_map.txt"
      msg="Merge your backed up project specific data:\n\t$target_loc\ninto\n\t$orig_loc"
      if echo -e "${decor}\n$msg\n${decor}\n" >> "$instr_file"; then
        echo -e "${c_norm}Merge instructions for this file can be found at ${c_uri}$instr_file${c_e}"
      else
        echo -e "${c_norm_prob}Error could not create locations map file: ${c_uri}$instr_file${c_e}"
        echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_uri}$target_loc${c_e}"
      fi
      return 0
    fi
    echo -e "$name ${c_norm_prob}failed. Illegal target ${c_uri}$target_loc${c_e}"
    return 1
  fi

  # It's a file...
  orig_loc="$project_root/$1"

  # Exit gracefully if file is specificed in the manifest but not present in the original or the latest
  # Also output a warning if the --strict option is used.
  if is_script_arg '--strict'; then
    echo "--strict used and should be aborting the backup with a warning"
    [[ ! -f $orig_loc ]] && warn_msg "$err_pre\n\t$e1_pre ${c_uri}$orig_loc${c_uri}"
    [[ ! -f "$target_dir/$1" ]] && warn_msg "$err_pre\n\t$e1_pre ${c_uri}${target_dir}/${1}${c_uri}"
    return 0
  else
    [[ ! -f $orig_loc ]] && return 0
    [[ ! -f "$target_dir/$1" ]] && return 0
  fi
  
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

  # Skip backing up the files if there are no differences between them
  # the current and the latest
  [[ -z $(diff -q "$orig_loc" "$target_dir/$1") ]] && return 0

  # For security proceed only if the target is within the project root
  if is_subpath "$project_root" "$target_loc"; then
    b_msg2="${c_norm}It is recommended that you backup the file:\n\t"
    b_msg2b="${c_e}${c_uri}$orig_loc\n${c_norm}to\n\t${c_e}${c_uri}$target_loc${c_e}"
    b_msg3="${c_norm}and merge the contents manually back into the project after the update has succeeded.${c_e}"
    msg="$b_msg1 ${c_e}${c_uri}$orig_loc\n$b_msg2$b_msg2b\n$b_msg3\n$warn1 $warn1b"

    echo -e "$msg"

    while true; do
      read -rp "$( echo -e "$question")" input
      case $input in
        [Yy]* ) if cp "$orig_loc" "$target_loc"; then success_msg "${c_file}Backed up ${c_uri}$orig_loc${c_e}"; break; else return 1; fi;;
        [Nn]* ) return 0;;
        * ) echo -e "${c_norm}Please answer ${c_choice}y${c_e}${c_norm} for yes or ${c_choice}n${c_e}${c_norm} for no.${c_e}";;
      esac
    done

    # Append merge instructions for each backup to file
    instr_file="$backups_dir/locations_map.txt"
    msg="Merge your backed up project specific data:\n\t$target_loc\ninto\n\t$orig_loc"
    if echo -e "${decor}\n$msg\n${decor}\n" >> "$instr_file"; then
      echo -e "${c_norm}Merge instructions for this file can be found at ${c_uri}$instr_file${c_e}"
    else
      echo -e "${c_norm_prob}Error could not create locations map file ${c_uri}$instr_file${c_e}"
      echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_uri}$target_loc${c_e}"
    fi
    return 0
  fi
  echo -e "$name ${c_norm_prob}failed. Illegal target ${c_uri}$target_loc${c_e}"
  return 1
}

### download_latest ###
# Description:
# Downloads the .tar.gz of the latest release of gitpod-laravel-starter and extracts it to $target_dir
# Requires Globals
# $release_json
# $target_dir
download_latest() {

  #echo -e "${c_norm}TESTING MOCK: Downloading and extracting ${c_e}${c_url}https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/v1.5.0${c_e}" # temp testing
  #return 0 # temp testing, must download once first though
  local files_to_move=("CHANGELOG.md" "LICENSE" "README.md")
  local e1 e2 url loc msg
  e1="${c_norm_prob}Cannot download/extract latest gls tarball${c_e}"
  e2="${c_norm_prob}Unable to parse url from ${c_uri}$release_json${c_e}"

  [[ -z $release_json ]] \
    && err_msg "$e1/n/t${c_norm_prob}Missing required file ${c_uri}$release_json${c_e}" \
    && return 1

  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"
  [[ -z $url ]] && err_msg "$e1\n\t$e2" && return 1

  if ! cd "$target_dir";then
    err_msg "$e1\n\t${c_norm_prob}internal error, bad target directory: ${c_uri}$target_dir${c_e}"
    return 1
  fi

  echo -e "${c_norm}Downloading and extracting ${c_url}$url${c_e}"
  if ! curl -sL "$url" | tar xz --strip=1; then
    err_msg "$e1\n\t ${c_norm}curl failed ${c_url}$url${c_e}"
    return 1
  fi
  
  for i in "${!files_to_move[@]}"; do
   loc="$target_dir/${files_to_move[$i]}"
   loc2="$target_dir/.gp/${files_to_move[$i]}"
    if [[ -f $loc ]]; then
      if ! mv "$loc" "$loc2"; then
        msg="${c_norm_prob}Could not move the file\n\t${c_uri}${loc}${c_e}\n${c_norm_prob}to\n\t"
        warn_msg "$msg${c_uri}${loc2}${c_e}"
      fi
    fi
  done

  cd "$project_root" || return 1
}

### cleanup ###
# Description:
# Clean up after the update
cleanup() {
  return 0
  #[[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
}

### update ###
# Description:
# Performs the update by calling all the proper routines in the proper order
# Creates any necessary files or directories any routine might need
# Handles errors for each routine called or action made
update() {
  local ec e1 e2 e2b update_msg1 update_msg2 warn_msg1 warn_msg1b warn_msg1b warn_msg1c
  local base_ver_txt target_ver_txt file same_ver1 same_ver1b same_ver1c gls_url loc
  e1="${c_norm_prob}Version mismatch${c_e}"
  warn_msg1="${c_norm_prob}Could not delete the directory ${c_uri}.gp${c_e}"
  warn_msg1b="${c_norm_prob}Some old files may remain but should not cause any issues${c_e}"
  warn_msg1c="${c_norm_prob}The old file may remain but should not cause any issues${c_e}"
  warn_msg1d="${c_norm_prob}Try manually copying this file from the repo to the project root${c_e}"
  gls_url="https://github.com/apolopena/gitpod-laravel-starter"

  # Create working directory
  if ! mkdir -p "$tmp_dir"; then
    err_msg "${c_norm_prob}Unable to create required directory ${c_uri}$tmp_dir${c_e}"
    abort_msg
    return 1
  fi

  # Download release data
  if ! download_release_json; then abort_msg && return 1; fi

  # Set base and target versions, identical version message and required global directories 
  if ! set_target_version; then abort_msg && return 1; fi
  [[ ! -d $target_dir ]] && mkdir "$target_dir"
  if ! set_base_version; then set_base_version_unknown; fi
  base_ver_txt="${c_number}$base_version${c_e}"
  target_ver_txt="${c_number}$target_version${c_e}"
  same_ver1="$note_prefix ${c_norm_prob}Your current version $base_ver_txt"
  same_ver1b="${c_norm_prob}and the latest version $target_ver_txt ${c_norm_prob}are the same${c_e}"
  same_ver1c="${c_norm}${c_s_bold}gitpod-laravel-starter${c_e}${c_norm} is already up to date${c_e}"
  if [[ $backups_dir == $(pwd) ]]; then
    backups_dir="${backups_dir}/GLS_BACKUPS_v$base_version"
    [[ -d $backups_dir ]] && rm -rf "$backups_dir"
    mkdir "$backups_dir"
  fi

  # Validate base and target versions
  if [[ $base_version == "$target_version" ]]; then
    echo -e "$same_ver1 $same_ver1b\n$same_ver1c" && return 1
  fi
  if [[ $(comp_ver_lt "$base_version" "$target_version") == 0 ]]; then
    e2="${c_norm_prob}Your current version v${c_e}$base_ver_txt "
    e2b="${c_norm_prob}must be less than the latest version v${c_e}$target_ver_txt"
    err_msg "$e1\n\t$e2$e2b" && abort_msg && return 1
  fi

  # Set directives, download and extract latest release and execute directives
  update_msg1="${c_norm_b}Updating gitpod-laravel-starter version${c_e}"
  update_msg2="$base_ver_txt ${c_norm_b}to version ${c_e}$target_ver_txt"
  echo -e "${c_s_bold}${c_pass}START: ${c_e}$update_msg1 $update_msg2"
  if ! set_directives; then abort_msg && return 1; fi
  if ! download_latest; then abort_msg && return 1; fi
  if ! execute_directives; then abort_msg && return 1; fi

  # BEGIN: update by deleting the old and copying over the new
  local root_files=(".gitpod.yml" ".gitattributes" ".npmrc" ".gitignore") # TODO: rsync this since cp cant do a dry run
  local root_dirs=(".gp" ".vscode" ".theia") # TODO: rsync this since cp cant do a dry run

  for i in "${!root_files[@]}"; do
    if [[ -f ${root_files[$i]} ]]; then
      if ! rm "${root_files[$i]}"; then
        warn_msg "${c_norm_prob}Could not delete the file ${c_uri}.gp${c_e}\n\t$warn_msg1c"
      fi
    fi
  done

  [[ $gp_df_only_cache_buster_changed == no && -f .gitpod.Dockerfile ]] && rm .gitpod.Dockerfile

  if ! rm -rf .gp; then
    warn_msg "$warn_msg1\n\t$warn_msg1b"
  fi

  e1="${c_norm_prob}You will need to manually copy it from  the repository: ${c_url}$gls_url${c_e}"

  for i in "${!root_dirs[@]}"; do
    loc="$target_dir/${root_dirs[$1]}"
    if ! cp -r "$loc" "$project_root"; then
      err_msg "$(failed_copy_to_root_msg "$loc")/t$e1" && abort_msg && return 1
    fi
  done

  for i in "${!root_files[@]}"; do
    loc="$target_dir/${root_files[$i]}"
    if ! cp "$loc" "$project_root/${root_files[$i]}"; then
      err_msg "${c_norm_prob}Could not copy the file ${c_uri}${loc}{c_e}\n\t$warn_msg1d"
    fi
  done

  if [[ $gp_df_only_cache_buster_changed == no ]]; then
    file="$target_dir/.gitpod.Dockerfile"
    if ! cp "$file" "$project_root"; then
      err_msg "$(failed_copy_to_root_msg "${c_uri}$file${c_e}")/t$e1"
    fi
  fi
  echo -e "${c_s_bold}${c_pass}DONE:${c_norm_b} $update_msg1 $update_msg2"
  return 0
  # END: update by deleting the old and copying over the new
}

### init ###
# Description:
# Validates an existing installation of gls and initializes
# the project so the update routine can be called
init() {
  handle_colors

  local gls e_not_installed
  gls="${c_norm_prob}${c_s_bold}gitpod-laravel-starter${c_e}${c_norm_prob}"
  e_not_installed="${c_norm_prob}An existing installation of $gls is required but was not found${c_e}"
  warn_prefix="${c_warn2}Warning:${c_e}"
  note_prefix="${c_file_name}Notice:${c_e}"

  [[ ! -d '.gp' ]] && err_msg "$e_not_installed" && abort_msg && return 1

  gls_header 'updater'
}

### main ###
# Description:
# Main routine
# Order specific:
#   1. Pre check the url for loading get_deps.sh, abort if the check fails
#   2. Load get_deps.sh as it contains get_deps() which is used to load the rest of the dependencies
#   3. Load the rest of the dependencies using get_deps()
#   4. Initialize
#   5. Update. Clean up if the update fails
#
# Note:
# Dependency loading is synchronous and happens on every invocation of the script.
main() {
  local ec dependencies=('util.sh' 'color.sh' 'header.sh' 'third-party/spinner.sh')
  local get_deps_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/get_deps.shh"

  if ! curl --head --silent --fail "$get_deps_url" &> /dev/null; then
    err_msg "Cannot load the loader" && exit 1
  fi
  # shellcheck source=/dev/null
  source \
  <(curl -fsSL "" &)
  ec=$?; if [[ $ec != 0 ]] ; then echo "Unable to source $url"; exit 1; fi; wait;

  if ! get_deps "${dependencies[@]}"; then exit 1; fi
  if ! init; then exit 1; fi
  if ! update; then cleanup && exit 1; fi
}
# END: functions

main

#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# update-gls.sh
# Version: 1.0.0
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

# Files to merge
data_merges=()

# Files to recommend backing up so they can be merged manually after the update succeeds
data_backups=()

# Files or directories to delete
data_deletes=()

# Latest release data downloaded from github
release_json="$tmp_dir/latest_release.json"

# END: Globals

# BEGIN: functions

### name ###
# Description:
# Prints the file name of this script
name() {
  printf '%s' "$(basename "${BASH_SOURCE[0]}")"
}

### warn_msg ###
# Description:
# Echos a warning message ($1)
warn_msg() {
  echo -e "$(name) WARNING:\n\t$1"
}

### err_msg ###
# Description:
# Echos an error message ($1)
err_msg() {
  echo -e "$(name) ERROR:\n\t$1"
}

### abort_msg ###
# Description:
# Echos an abort message ($1) 
abort_msg() {
  echo "$(name) ABORTED"
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

[merge]
.gitattributes
.gitignore
.gitpod.Dockerfile
.gitpod.yml
.npmrc

[recommend-backup]
starter.ini
/test_directory/bar
/foobarbaz

[delete]"

}

### set_base_version_unknown ###
# Description:
# Sets the base version to the string: unknown
set_base_version_unknown() {
  local unknown_msg="The current gls version has been set to 'unknown' but is assumed to be >= 1.0.0"
  base_version='unknown' && echo "$unknown_msg"
}

### set_base_version ###
# Description:
# Sets the base version to the first occurrence of a version number found in .gp/CHANGELOG.md
# Prompts the user to manually enter a base version if no version can be derived
# Validates the version number range x.x.x is >= 1.0.0 where x is equal to an integer between 0 and 999
set_base_version() {
  local ver input ec gp_dir changelog err_p1 err_p2 err_p3
  gp_dir="$(pwd)/.gp"
  changelog="$gp_dir/CHANGELOG.md"
  err_p1="Undectable gls version"
  err_p2="Could not find required file: $changelog"
  err_p3="Could not parse version number from: $changelog"
  err_p4="Base version is too old, it must be >= 1.0.0\n\tYou will need to perform the update manaully."

  # Derive base version from user input if CHANGELOG.md is not present
  if [[ ! -f $changelog ]]; then
    warn_msg "$err_p1\n\t$err_p2"
    echo -n "Enter the gls version you are updating from (y=skip): "
    read -r input
    [[ $input == y ]] && return 1

    local regexp='^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$'

    if [[ $input =~ $regexp ]]; then
       [[ $(comp_ver_lt "$input" 1.0.0 ) == 1 ]] && err_msg "$err_p4" && abort_msg && exit 1
      base_version="$input" && echo "Base gls version set by user to: $input" && return 0
    else
      echo "Invalid version: $input" && return 1
    fi
  fi

  # Derive version from CHANGELOG.md
  ver="$(gls_version "$changelog")"
  ec=$?
  [[ $ec == 1 ]] && err_msg "$err_p3\n\tThis file should never be altered but it was." && return 1
  base_version="$ver"
  return 0
}

###   ###
# Description:
# 
parse_manifest_chunk() {
  local err_p err_1 chunk ec
  err_p="parse_manifest_chunk(): parse error"

  # Error handling
  err_1="Exactly 2 arguments are required. Found $#"
  [[ -z $1 || -z $2 ]] && err_msg "$err_p\n\t$err_1" && return 1
  # TODO verify the enitre manifest to ensure that header sections are delimited by an empty line
  err_3="Unable to find start marker: [$1]"
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
  local regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  local e1="Cannot set target version"
  [[ -z $release_json ]] && err_msg "$e1/n/tMissing required file $release_json" && return 1
  target_version="$(grep "tag_name" "$release_json" | grep -oE "$regexp")" &&
  target_dir="$tmp_dir/$target_version"
}

### download_release_json ###
# Description:
# Downloads the latest gitpod-laravel-starter release json data from github
# Requires Global:
# $release_json (a valid github latest release json file)
download_release_json() {
  local url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  if ! curl --silent "$url" -o "$release_json"; then
    err_msg "Could not download release data\n\tfrom $url"
    return 1
  fi
  return 0
}

### has_directive ###
# Description:
# returns exit code 0 if the updater manifest has the start marker ($1)
# return exit code 1 if the updater manifest does not contain the start marker ($1)
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
  warn1="Could not find the updater manifest at $file"
  
  # Get the manifest
  if [[ ! -f $file ]]; then
    default="$(default_manifest)"
    manifest="$default"
    warn_msg "$warn1\nUsing the default updater manifest:\n$default\n"
  else
    manifest="$(cat "$file")"
  fi

  # Parse chunks and convert them to global directive arrays
  chunk="$(parse_manifest_chunk 'keep' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_keeps <<< "$chunk"

  chunk="$(parse_manifest_chunk 'merge' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_merges <<< "$chunk"

  chunk="$(parse_manifest_chunk 'recommend-backup' "$manifest")"
  ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
  IFS=$'\n' read -r -d '' -a data_backups <<< "$chunk"
  
  # Optional directives are checked with the has_directive routine
  if has_directive 'delete'; then
    chunk="$(parse_manifest_chunk 'delete' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a data_deletes <<< "$chunk"
  else
    echo "skipping optional directive: delete"
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
    echo "DIRECTIVE MERGE:"
    [[ ${#data_merges[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_merges[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${data_merges[$i]}"
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

  if [[ $1 == '--debug' ]]; then
    echo "DIRECTIVE DELETE:"
    [[ ${#data_deletes[@]} == 0 ]] && echo -e "\tnothing to process"
  fi
  for (( i=0; i<${#data_deletes[@]}; i++ ))
  do
    [[ $1 == '--debug' ]] && echo -e "\tprocessing: ${data_deletes[$i]}"
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
# $project_root
# $target_dir
keep() {
  local name orig_loc target_loc err_pre e1_pre
  name="keep()"
  err_pre="Failed to $name"
  e1_pre="Could not find"
  
  [[ -z $1 ]] && err_msg "$err_pre\n\t Missing argument. Nothing to keep." && return 1

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre directory $orig_loc" && return 1
    target_loc="$target_dir$1"

    # For security $target_loc must be a subpath of $project_root
    if is_subpath "$project_root" "$target_loc"; then
      echo "Keeping original directory $orig_loc"
      rm -rf "$target_loc" && cp -R "$orig_loc" "$target_loc"
      return 0
    fi
    echo "$name failed. Illegal target $target_loc"
    return 1
  fi

  # It's a file
  orig_loc="$project_root/$1"
  [[ ! -f $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre file $orig_loc" && return 1
  target_loc="$target_dir/$1"

  # For security $target_loc must be a subpath of $project_root
  if is_subpath "$project_root" "$target_loc"; then
    echo "Keeping original file $orig_loc"
    cp "$orig_loc" "$target_loc"
    return 0
  fi
  echo "$name failed. Illegal target $target_loc"
  return 1
}

### merge ###
# Description:
# TBD
merge() {
  return 0
}

### recommend_backup ###
# Description:
# 
# Requires Globals:
# $project_root
# $backups_dir
recommend_backup() {
  local name orig_loc target_loc err_pre e1_pre b_msg1 b_msg2 b_msg3 msg warning question instr_file input
  name="recommend_backup()"
  err_pre="Failed to $name"
  e1_pre="Could not find"
  b_msg1="\nProject senstive data found"
  question="Would you like perform the backup now (y/n)?"
  warning="Warning: Answering no (n) will most likely overwrite important project specific data."
  
  [[ ! -d $backups_dir ]] && err_msg "Missing the recommended backups directory" && return 1
  [[ -z $1 ]] && err_msg "$err_pre\n\t Missing argument. Nothing to recommend a backup for." && return 1

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre directory $orig_loc" && return 1
    target_loc="$backups_dir/$(basename "$1")"
    # Proceed with the recommended backup if the path does not appear to be malicious
    if is_subpath "$project_root" "$target_loc"; then
      b_msg2="It is recommended that you backup the directory:\n\t$orig_loc\nto\n\t$target_loc"
      b_msg3="and merge the contents manually back into the project after the update has succeeded."
      msg="$b_msg1 in $orig_loc\n$b_msg2\n$b_msg3\n$warning"

      # sleep 1 is required after the echo if you pipe the output of this script through grc
      # otherwise the prompt text shows up before the echo -e "$msg"
      echo -e "$msg"

      while true; do
        read -rp "$question" input
        case $input in
          [Yy]* ) if cp -R "$orig_loc" "$target_loc"; then echo "SUCCESS"; break; else return 1; fi;;
          [Nn]* ) return 0;;
          * ) echo "Please answer y for yes or n for no.";;
        esac
      done
      # Log the original location of backed up directory in a file next to the backed up directory
      instr_file="$target_loc"_original_location.txt
      if echo "$orig_loc" > "$instr_file"; then
        echo "The original location of this directory can be found at $instr_file"
      else
        echo "Error could not create original location file map $instr_file"
        echo "Refer back to this log when manually merging $target_loc back into the project."
      fi
      return 0
    fi
    echo "$name failed. Illegal target $target_loc"
    return 1
  fi
  # Otherwise it must be a file
  #orig_loc="$project_root/$1"
  #[[ ! -f $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre file $orig_loc" && return 1
  #target_loc="$target_dir/$1"
  # Proceed with the recommended backup if the path is not malicious
  #if is_subpath "$project_root" "$target_loc"; then
    #echo "Recommending back for file $orig_loc"
    #cp "$orig_loc" "$target_loc"
  # return 0
  #fi
  #echo "$name failed. Illegal target $target_loc"
  #return 1
}

### delete ###
# Description:
# TBD
delete() {
  return 0
}

### download_latest ###
# Description:
# Downloads the .tar.gz of the latest release of gitpod-laravel-starter and extracts it to $target_dir
# Requires Globals
# $release_json
# $target_dir
download_latest() {
  local e1 e2 url
  e1="Cannot download/extract latest gls tarball"
  e2="Unable to parse url from $release_json"

  # Handle missing release data
  [[ -z $release_json ]] && err_msg "$e1/n/tMissing required file $release_json" && return 1
  # Parse tarball url from the release json
  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"
  # Handle a bad url
  [[ -z $url ]] && err_msg "$e1\n\t$e2" && return 1

  # Move into the target working directory
  if ! cd "$target_dir";then
    err_msg "$e1\n\tinternal error, bad target directory: $target_dir"
    return 1
  fi
  # Download
  echo "Downloading and extracting $url"
  if ! curl -sL "$url" | tar xz --strip=1; then
    err_msg "$e1\n\t curl failed $url"
    return 1
  fi
  # Cleanup
  cd "$project_root" || return 1
}

### cleanup ###
# Description:
# Clean up after the update
cleanup() {
  [[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
}

### update ###
# Description:
# Performs the update by calling all the proper routines in the proper order
# Creates any necessary files or directories any routine might need
# Handles errors for each routine called or action made
update() {
  local e1 e2 update_msg
  e1="Version mismatch"
  
  # Handle dependencies 
  [[ ! -d $tmp_dir ]] && mkdir "$tmp_dir"
  if ! download_release_json; then abort_msg && return 1; fi

  # Set base and target versions and any directories that other routines require
  if ! set_target_version; then abort_msg && return 1; fi
  [[ ! -d $target_dir ]] && mkdir "$target_dir"
  if ! set_base_version; then set_base_version_unknown; fi
  [[ $backups_dir == $(pwd) ]] &&
    backups_dir="${backups_dir}/gls_BACKUPS_$base_version" &&
    mkdir -p "$backups_dir"
  
  # Validate base and target versions
  if [[ $(comp_ver_lt "$base_version" "$target_version") == 0 ]]; then
    e2="You current version v$base_version must be less than the latest version v$target_version"
    err_msg "$e1\n\t$e2" && a_msg && return 1
  fi

  # Update
  update_msg="Updating gls version $base_version to version $target_version"
  echo "BEGIN: $update_msg"
  if ! set_directives; then abort_msg && return 1; fi
  if ! download_latest; then abort_msg && return 1; fi
  if ! execute_directives; then abort_msg && return 1; fi

  echo "SUCCESS: $update_msg"
  return 0
}

### main ###
# Description:
# Main routine
# Calls the update routine with error handling and cleans up if necessary
main() {
  if ! update; then cleanup; exit 1; fi
}
# END: functions

main

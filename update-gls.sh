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

### supports_truecolor ###
# Desciption:
# returns 0 if the terminal supports truecolor and retuns 1 if not
# Source: https://gist.github.com/XVilka/8346728
supports_truecolor() {
  case "$COLORTERM" in
  truecolor|24bit) return 0 ;;
  esac

  case "$TERM" in
  iterm           |\
  tmux-truecolor  |\
  linux-truecolor |\
  xterm-truecolor |\
  screen-truecolor) return 0 ;;
  esac

  return 1
}

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

#testing
c_e='\e[0m' # Reset 
c_s_bold='\033[1m' # Bold style
# c_1: RGB Bright Red or fallback to ANSI 256 Red (Red3)
if supports_truecolor; then c_1="\e[38;2;255;25;38m"; else c_1='\e[38;5;160m'; fi
c_2='\e[38;5;208m' # Bright Orange (DarkOrange)
c_3='\e[38;5;76m' # Army Green (Chartreuse3)
c_4='\e[38;5;147m' # Lavendar (LightSteelBlue)
c_5='\e[38;5;213m' # Hot Pink (Orchid1)#
# c_6: RGB Cornflower Lime or fallback to ANSI 256 Yellow3
if supports_truecolor; then c_6="\e[38;2;206;224;102m"; else c_6='\e[38;5;148m'; fi
c_7='\e[38;5;45m' # Turquoise (Turquoise2)
c_8='\e[38;5;39m' # Blue (DeepSkyBlue31)
c_9='\e[38;5;34m' # Green (Green3) 
c_10='\e[38;5;118m' # Chartreuse (Chartreuse1)
c_11='\e[38;5;178m' # Gold (Gold3)
c_12='\e[38;5;184m' # Yellow3
c_13='\e[38;5;185m' # Khaki (Khaki3)
c_14='\e[38;5;119m' # Light Green (LightGreen)
c_15='\e[38;5;190m' # Yellow Chartreuse (Yellow3)
c_16='\e[38;5;154m' # Ultrabrite Green (GreenYellow)


# END: Globals

# BEGIN: functions

# Set is_tty to the top level
if [[ -t 1 ]]; then
  is_tty() {
    true
  }
else
  is_tty() {
    false
  }
fi

# Quick and dirty color flag taking up the $1 spot for now
# dont use color if the flag says so or we are not a tty (such as a pipe)
if [[ $1 == '--no-color'|| ! -t 1 ]]; then
  use_color() {
    false
  }
else
  use_color() {
    true
  }
fi

handle_colors() {
  if use_color; then set_colors; else remove_colors; fi
}

remove_colors() {
  c_1=;c_2=;c_3=;c_4=;c_5=;c_6=;c_7=;c_8=;c_9=;c_e=;
  c_norm=; c_warn=; c_fail=; c_pass=; c_file=;
}

set_colors() {
  c_norm="$c_10"
  c_norm_b="${c_s_bold}${c_norm}"
  c_norm_prob="$c_14"
  c_pass="${c_s_bold}$c_16"
  c_warn="${c_s_bold}$c_2"
  c_warn2="${c_15}"
  c_fail="${c_s_bold}$c_1"

  c_file="$c_7"
  c_file_name="${c_s_bold}$c_9"
  c_url="$c_11"
  c_uri="$c_12"
  c_number="$c_13"
  c_choice="$c_5"
  c_prompt="$c_4"
}

### show_logo ##
# Description:
# Echoes either a plain or 256 colorized GLS logo banner
handle_logo() {
  if use_color; then
  echo -e "[38;5;118m [0m[38;5;118m [0m[38;5;118m_[0m[38;5;118m_[0m[38;5;118m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m.[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;148m_[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;178m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m
[38;5;118m [0m[38;5;118m/[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m/[0m[38;5;154m|[0m[38;5;148m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m/[0m[38;5;184m [0m[38;5;184m [0m[38;5;178m [0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m/[0m
[38;5;154m/[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m [0m[38;5;154m\[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m_[0m[38;5;148m_[0m[38;5;184m_[0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;178m\[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;214m [0m[38;5;214m\[0m[38;5;214m [0m
[38;5;154m\[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m [0m[38;5;154m [0m[38;5;148m\[0m[38;5;184m_[0m[38;5;184m\[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m_[0m[38;5;178m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;214m/[0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m\[0m
[38;5;154m [0m[38;5;154m\[0m[38;5;148m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;178m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;214m/[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;208m_[0m[38;5;208m_[0m[38;5;208m_[0m[38;5;208m [0m[38;5;208m [0m[38;5;208m/[0m
[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m\[0m[38;5;184m/[0m[38;5;184m [0m[38;5;178m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m\[0m[38;5;214m/[0m[38;5;214m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m\[0m[38;5;208m/[0m[38;5;208m [0m
           [38;5;118mU[0m[38;5;154mP[0m[38;5;148mD[0m[38;5;184mA[0m[38;5;178mT[0m[38;5;214mE[0m[38;5;208mR[0m
"
  else
    # shellcheck disable=SC1004 # Allow backslashes in a literal
    echo '
  ________.____      _________
 /  _____/|    |    /   _____/
/   \  ___|    |    \_____  \ 
\    \_\  |    |___ /        \
 \______  |_______ /_______  /
        \/        \/       \/ 
           UPDATER
'
  fi
}

### name ###
# Description:
# Prints the file name of this script
name() {
  printf '%s' "${c_file_name}$(basename "${BASH_SOURCE[0]}")${c_e}"
}

### warn_msg ###
# Description:
# Echos a warning message ($1)
warn_msg() {
  echo 
  #_out "$c_blue" "$(echo -e "$(name) $(_out "$c_orange" WARNING):\n\t$1")"
  #_out "$c_blue" "$(name) " && _out "$c_orange" "WARNING:" && _out "$c_blue \n\t$1"
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

### yes_no ###
# Description:
# Echos: (y/n) 
yes_no() {
  echo -e \
  "${c_e}${c_prompt}(${c_e}${c_choice}y${c_e}${c_prompt}/${c_e}${c_choice}n${c_e}${c_prompt})${c_e}"
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
  local unknown_msg1 unknown_msg1b
  unknown_msg1="${c_norm}The current gls version has been set to '${c_e}${c_file_name}unknown${c_e}"
  unknown_msg1b="${c_norm}' but is assumed to be ${c_e}${c_file_name}>= ${c_e}${c_number}1.0.0${c_e}"
  base_version='unknown' && echo "$unknown_msg1$unknown_msg1b"
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
  err_p2="${c_norm_prob}Could not find required file: ${c_e}${c_uri}$changelog${c_e}"
  err_p3="${c_norm_prob}Could not parse version number from: ${c_e}${c_uri}$changelog${c_e}"
  err_p4="${c_norm_prob}Base version is too old, it must be ${c_e}"
  err_p4b="${c_file_name}>= ${c_e}${c_number}1.0.0${c_e}"
  err_p4c="\n\t${c_norm_prob}You will need to perform the update manually.${c_e}"

  # Derive base version from user input if CHANGELOG.md is not present
  if [[ ! -f $changelog ]]; then
    warn_msg "$err_p1\n\t$err_p2"
    question="${c_prompt}Enter the gls version you are updating from (${c_e}"
    question1b="${c_choice}y${c_e}${c_prompt}=skip): ${c_e}"
    read -rp "$( echo -e "$question1 $question1b")" input

    [[ $input == y ]] && return 1

    local regexp='^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$'

    if [[ $input =~ $regexp ]]; then
       [[ $(comp_ver_lt "$input" 1.0.0 ) == 1 ]] \
         && err_msg "$err_p4 $err_p4b $err_p4c" \
         && abort_msg \
         && exit 1
      base_version="$input" \
      && echo -e "${c_norm}Base gls version set by user to: ${c_norm}${c_number}$input${c_e}" \
      && return 0
    else
      echo -e "${c_norm_prob}Invalid version: ${c_e}${c_number}$input${c_e}" \
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
  err_p="${c_file_name}parse_manifest_chunk():${c_e} ${c_norm_prob}parse error${c_e}"
  err_missing_marker="${c_e}${c_file_name}[${c_e}${c_number}$1${c_e}${c_file_name}]${c_e}"

  # Error handling
  err_1="${c_norm_prob}Exactly ${c_e}${c_number}2 ${c_e}"
  err_1b="${c_norm_prob}arguments are required. Found ${c_e}${c_number}$#${c_e}"
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
  local regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  local e1="${c_norm_prob}Cannot set target version"
  [[ ! -f $release_json ]] && err_msg "$e1\n\tMissing required file ${c_e}${c_uri}$release_json${c_e}" \
    && return 1
  target_version="$(grep "tag_name" "$release_json" | grep -oE "$regexp")" \
  && target_dir="$tmp_dir/$target_version"
}

### download_release_json ###
# Description:
# Downloads the latest gitpod-laravel-starter release json data from github
# Requires Global:
# $release_json (a valid github latest release json file)
download_release_json() {

  #return 0 # temp testing

  local url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  if ! curl --silent "$url" -o "$release_json"; then
    err_msg "${c_norm_prob}Could not download release data\n\tfrom${c_e} ${c_url}$url${c_e}"
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
  warn1="${c_norm_prob} Could not find the updater manifest at ${c_e}${c_uri}$file${c_e}"
  
  # Get the manifest
  if [[ ! -f $file ]]; then
    default="${c_file}$(default_manifest)${c_e}"
    manifest="$default"
    warn_msg "$warn1\n${c_norm_prob} Using the default updater manifest:${c_e}\n$default\n"
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
  name="${c_file_name}keep()${c_e}"
  err_pre="${c_norm_prob}Failed to ${c_e}$name"
  e1_pre="${c_norm_prob}Could not find${c_e}"
  
  [[ -z $1 ]] && err_msg "$err_pre\n\t${c_norm_prob}Missing argument. Nothing to keep.${c_e}" && return 1

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] \
      && err_msg "$err_pre\n\t$e1_pre ${c_norm_prob}directory${c_e} ${c_uri}$orig_loc${c_e}" \
      && return 1
    target_loc="$target_dir$1"

    # For security $target_loc must be a subpath of $project_root
    if is_subpath "$project_root" "$target_loc"; then
      echo -e "${c_norm}Keeping original directory ${c_e}${c_uri}$orig_loc${c_e}"
      rm -rf "$target_loc" && cp -R "$orig_loc" "$target_loc"
      return 0
    fi
    echo -e "$name ${c_norm_prob}failed. Illegal target ${c_e}${c_uri}$target_loc${c_e}"
    return 1
  fi

  # It's a file
  orig_loc="$project_root/$1"
  [[ ! -f $orig_loc ]] \
    && err_msg "$err_pre\n\t$e1_pre${c_norm_prob} file ${c_e}${c_uri}$orig_loc${c_e}" \
    && return 1
  target_loc="$target_dir/$1"

  # For security $target_loc must be a subpath of $project_root
  if is_subpath "$project_root" "$target_loc"; then
    echo -e "${c_norm}Keeping original file ${c_e}${c_uri}$orig_loc${c_e}"
    cp "$orig_loc" "$target_loc"
    return 0
  fi
  echo -e "$name ${c_norm_prob}failed. Illegal target ${c_e}${c_uri}$target_loc${c_e}"
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
  local name orig_loc target_loc err_pre e1_pre b_msg1 b_msg2 b_msg2b b_msg3 msg warning
  local question instr_file input
  name="${c_file_name}recommend_backup()${c_e}"
  err_pre="${c_norm_prob}Failed to ${c_e}$name"
  e1_pre="${c_norm_prob}Could not find${c_e}"
  b_msg1="\n${c_norm}Project senstive data found"
  question="${c_prompt}Would you like perform the backup now $(yes_no)${c_prompt}?${c_e}"
  warning="${c_warn2}Warning: ${c_e}${c_norm}Answering no will most likely result in the loss of project specific data.${c_e}"
  
  [[ ! -d $backups_dir ]] && err_msg " ${c_norm_prob}Missing the recommended backups directory${c_e}" && return 1
  [[ -z $1 ]] && err_msg "$err_pre\n\t${c_norm_prob}Missing argument. Nothing to recommend a backup for.${c_e}" && return 1

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] && err_msg "$err_pre\n\t$e1_pre directory $orig_loc" && return 1
    target_loc="$backups_dir/$(basename "$1")"
    # Proceed with the recommended backup if the path does not appear to be malicious
    if is_subpath "$project_root" "$target_loc"; then
      b_msg2="${c_norm}It is recommended that you backup the directory:\n\t"
      b_msg2b="${c_e}${c_uri}$orig_loc${c_e}\n${c_norm}to\n\t${c_e}${c_uri}$target_loc${c_e}"
      b_msg3="${c_norm}and merge the contents manually back into the project after the update has succeeded.${c_e}"
      msg="$b_msg1 in ${c_e}${c_uri}$orig_loc${c_e}\n$b_msg2$b_msg2b\n$b_msg3\n$warning"

      # sleep .2 is required after the echo if you pipe the output of this script through grc
      # otherwise the prompt text shows up before the echo -e "$msg"
      echo -e "$msg" && sleep .2

      while true; do
        read -rp "$( echo -e "$question")" input
        case $input in
          [Yy]* ) if cp -R "$orig_loc" "$target_loc"; then echo -e "${c_pass}SUCCESS${c_e}"; break; else return 1; fi;;
          [Nn]* ) return 0;;
          * ) echo -e "${c_norm}Please answer ${c_choice}y${c_e}${c_norm} for yes or ${c_choice}n${c_e}${c_norm} for no.${c_e}";;
        esac
      done
      # Log the original location of backed up directory in a file next to the backed up directory
      instr_file="$target_loc"_original_location.txt
      if echo "$orig_loc" > "$instr_file"; then
        echo -e "${c_norm}The original location of this directory can be found at ${c_e}${c_uri}$instr_file${c_e}"
      else
        echo -e "${c_norm_prob}Error could not create original location file map ${c_e}${c_uri}$instr_file${c_e}"
        echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_e}${c_uri}$target_loc${c_e}"
      fi
      return 0
    fi
    echo -e "$name ${c_norm_prob}failed. Illegal target ${c_e}${c_uri}$target_loc${c_e}"
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

  echo -e "${c_norm}Downloading and extracting ${c_e}${c_url}https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/v1.5.0${c_e}" # temp testing
  return 0 # temp testing, must download once first though

  local e1 e2 url
  e1="${c_norm_prob}Cannot download/extract latest gls tarball${c_e}"
  e2="${c_norm_prob}Unable to parse url from ${c_e}${c_uri}$release_json${c_e}"

  # Handle missing release data
  [[ -z $release_json ]] \
    && err_msg "$e1/n/t${c_norm_prob}Missing required file ${c_e}${c_uri}$release_json${c_e}" \
    && return 1

  # Parse tarball url from the release json
  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"
  # Handle a bad url
  [[ -z $url ]] && err_msg "$e1\n\t$e2" && return 1

  # Move into the target working directory
  if ! cd "$target_dir";then
    err_msg "$e1\n\t${c_norm_prob}internal error, bad target directory: ${c_e}${c_uri}$target_dir${c_e}"
    return 1
  fi
  # Download
  echo -e "${c_norm}Downloading and extracting ${c_e}${c_url}$url${c_e}"
  if ! curl -sL "$url" | tar xz --strip=1; then
    err_msg "$e1\n\t ${c_norm}curl failed ${c_e}${c_url}$url${c_e}"
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
  local e1 e2 e2b update_msg1 update_msg2 
  local base_ver_txt="${c_number}$base_version${c_e}${c_norm}"
  local target_ver_txt="${c_number}$base_version${c_e}${c_norm}"
  e1="${c_norm_prob}Version mismatch${c_e}"
  
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
    e2="$c_norm_prob}Your current version v${c_e}$base_ver_txt "
    e2b="${c_norm_prob}must be less than the latest version v${c_e}$target_ver_txt"
    err_msg "$e1\n\t$e2$e2b" && a_msg && return 1
  fi

  # Update
  update_msg1="${c_norm}Updating gitpod-laravel-starter version${c_e}"
  update_msg2="$base_ver_txt ${c_norm}to version ${c_e}$target_ver_txt"
  echo -e "${c_norm_b}BEGIN:${c_e} $update_msg1 $update_msg2"
  if ! set_directives; then abort_msg && return 1; fi
  if ! download_latest; then abort_msg && return 1; fi
  if ! execute_directives; then abort_msg && return 1; fi

  echo "${c_pass}SUCCESS:${c_e} $update_msg1 $update_msg2"
  return 0
}

# Internal function
_out() {
  local end='\e[0m'
  if [[ -n $useColor ]]; then
    echo -en "$1$2$end"
  fi
}

### main ###
# Description:
# Main routine
# Calls the update routine with error handling and cleans up if necessary
main() {
  handle_colors; handle_logo
  if ! update; then cleanup; exit 1; fi
}
# END: functions

main

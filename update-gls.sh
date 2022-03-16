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

# Files to recommend backing up so they can be merged manually after the update succeeds
data_backups=()

# Latest release data downloaded from github
release_json="$tmp_dir/latest_release.json"

# Global message prefixes are declared here but set in main so they can be conditionally colorized
note_prefix=;warn_prefix=

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
  c_url="$c_12"
  c_uri="$c_11"
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
  echo -e "${c_pass}SUCCESS:${c_e} ${c_norm}$1${c_e}"
}

### yes_no ###
# Description:
# Echos: (y/n) 
yes_no() {
  echo -e \
  "${c_e}${c_prompt}(${c_choice}y${c_e}${c_prompt}/${c_e}${c_choice}n${c_prompt})${c_e}"
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
  unknown_msg1="${c_norm}The current gls version has been set to '${c_e}${c_file_name}unknown${c_e}"
  unknown_msg1b="${c_norm}' but is assumed to be ${c_e}${c_file_name}>= ${c_e}${c_number}1.0.0${c_e}"
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
  err_p2="${c_norm_prob}Could not find required file: ${c_e}${c_uri}$changelog${c_e}"
  err_p3="${c_norm_prob}Could not parse version number from: ${c_e}${c_uri}$changelog${c_e}"
  err_p4="${c_norm_prob}Base version is too old, it must be ${c_e}"
  err_p4b="${c_file_name}>= ${c_e}${c_number}1.0.0${c_e}"
  err_p4c="\n\t${c_norm_prob}You will need to perform the update manually.${c_e}"

  # Derive base version from user input if CHANGELOG.md is not present
  if [[ ! -f $changelog ]]; then
    warn_msg "$err_p1\n\t$err_p2"
    question1="${c_prompt}Enter the gls version you are updating from (${c_e}"
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
      warn_msg "${c_norm_prob}Invalid gls base version: ${c_e}${c_number}$input${c_e}" \
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
  local regexp e1 e1b e2
  regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  e1="${c_norm_prob}Cannot set target version"
  e1b="$e1\n\tMissing required file ${c_e}${c_uri}$release_json${c_e}"
  e2="${c_norm_prob}Failed to parse target version from:${c_e}\n\t${c_uri}$release_json${c_e}"

  [[ ! -f $release_json ]] && err_msg "$e1$e1b" && return 1
  
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
  return 0 # temp testing
  local url msg
  url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  msg="${c_norm}Downloading release data"
  echo -e "$msg from:\n\t${c_e}${c_url}$url${c_e}"
  if ! curl --silent "$url" -o "$release_json"; then
    err_msg "${c_norm_prob}Could not download release data from\n\t${c_e} ${c_url}$url${c_e}"
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
  if has_directive 'keep'; then
    chunk="$(parse_manifest_chunk 'keep' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a data_keeps <<< "$chunk"
  else
    echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_e}${c_file}keep${c_e}"
  fi

  if has_directive 'recommend-backup'; then
    chunk="$(parse_manifest_chunk 'recommend-backup' "$manifest")"
    ec=$? && [[ $ec != 0 ]] && echo "$chunk" && return 1
    IFS=$'\n' read -r -d '' -a data_backups <<< "$chunk"
  else
    echo -e "${note_prefix}${c_norm}skipping optional directive: ${c_e}${c_file}recommend-backup${c_e}"
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
      && err_msg "$err_pre\n\t$e1_pre ${c_norm_prob}directory${c_e} ${c_uri}$orig_loc${c_e}" \
      && return 1
    target_loc="$target_dir$1"
    
    # Skip keeping the directory if there are no differences
    [[ -z $(diff -qr "$orig_loc" "$target_loc") ]] && return 0

    # For security $target_loc must be a subpath of $project_root
    if is_subpath "$project_root" "$target_loc"; then
      note1="$note_prefix ${c_file}Recursively kept original ($orig_ver_text${c_file}) directory${c_e}"
      note1b="${c_uri}$orig_loc${c_e}\n\t${c_file}as per the directive set in the updater manifest\n\t"
      note1c="This action will result in some of the latest changes being omitted${c_e}"
      echo -e "${note1} ${note1b}${note1c}"
      rm -rf "$target_loc" && cp -R "$orig_loc" "$target_loc"
      return $?
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

  # Skip keeping the file if there are no differences
  [[ -z $(diff -qr "$orig_loc" "$target_loc") ]] && return 0

  # For security $target_loc must be a subpath of $project_root
  if is_subpath "$project_root" "$target_loc"; then
    note1="$note_prefix ${c_file}Kept original ($orig_ver_text${c_file}) file${c_e}"
    note1b="${c_uri}$orig_loc${c_e}\n\t${c_file}as per the directive set in the updater manifest\n\t"
    note1c="This action will result in some of the latest changes being omitted${c_e}"
    if [[ $(basename "$orig_loc") == 'init-project.sh' ]]; then
      echo -e "${c_norm}Keeping project specific file ${c_uri}$orig_loc${c_e}"
    else
      echo -e "${note1} ${note1b}${note1c}"
    fi
    cp "$orig_loc" "$target_loc"
    return $?
  fi
  echo -e "$name ${c_norm_prob}failed. Illegal target ${c_e}${c_uri}$target_loc${c_e}"
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
  question="${c_prompt}Would you like perform the backup now $(yes_no)${c_prompt}?${c_e}"
  warn1="$warn_prefix ${c_norm}Answering no to the question below${c_e}"
  warn1b="${c_norm}will most likely result in the loss of project specific data.${c_e}"
  
  [[ ! -d $backups_dir ]] \
    && err_msg " ${c_norm_prob}Missing the recommended backups directory${c_e}" \
    && return 1
  [[ -z $1 ]] \
    && err_msg "$err_pre\n\t${c_norm_prob}Missing argument. Nothing to recommend a backup for.${c_e}" \
    && return 1

  target_loc="$backups_dir/$(basename "$1")"

  # It's a directory
  if [[ $1 =~ ^\/ ]]; then
    orig_loc="$project_root$1"
    [[ ! -d $orig_loc ]] && warn_msg "$err_pre\n\t$e1_pre ${c_uri}$orig_loc${c_uri}" && return 0

    # Skip backing up the directory if there are no differences between the current and the latest
    [[ -z $(diff -qr "$orig_loc" "${target_dir}${1}") ]] && return 0

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

      # Append merge instructions for each backup to file
      instr_file="$backups_dir/locations_map.txt"
      msg="Merge your backed up project specific data:\n\t$target_loc\ninto\n\t$orig_loc"
      if echo -e "${decor}\n$msg\n${decor}\n" >> "$instr_file"; then
        echo -e "${c_norm}Merge instructions for this file can be found at ${c_e}${c_uri}$instr_file${c_e}"
      else
        echo -e "${c_norm_prob}Error could not create locations map file: ${c_e}${c_uri}$instr_file${c_e}"
        echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_e}${c_uri}$target_loc${c_e}"
      fi
      return 0
    fi
    echo -e "$name ${c_norm_prob}failed. Illegal target ${c_e}${c_uri}$target_loc${c_e}"
    return 1
  fi

  # It's a file
  orig_loc="$project_root/$1"
  [[ ! -f $orig_loc ]] && warn_msg "$err_pre\n\t$e1_pre ${c_uri}$orig_loc${c_uri}" && return 0

  # Skip backing up the file if there are no differences between the current and the latest
  [[ -z $(diff -q "$orig_loc" "$target_dir/$1") ]] && return 0

  # EDGE CASE: If the only change in .gitpod.Dockerfile is the cache buster value then
  # make that change in current (orig) version of the file instead of recommending the backup
  if [[ $(diff  --strip-trailing-cr "$target_dir/$1" "$orig_loc" | grep -cE "^(>|<)") == 2 ]]; then
    cb="$(diff "$target_dir/$1" "$orig_loc" | grep -m 1 "ENV INVALIDATE_CACHE" | cut -d"=" -f2- )"
    if [[ $cb =~ ^[0-9]+$ ]]; then
      sed -i "s/ENV INVALIDATE_CACHE=.*/ENV INVALIDATE_CACHE=$cb/" "$orig_loc"
    fi
  fi

  # For security proceed only if the target is within the project root
  if is_subpath "$project_root" "$target_loc"; then
    b_msg2="${c_norm}It is recommended that you backup the file:\n\t"
    b_msg2b="${c_e}${c_uri}$orig_loc${c_e}\n${c_norm}to\n\t${c_e}${c_uri}$target_loc${c_e}"
    b_msg3="${c_norm}and merge the contents manually back into the project after the update has succeeded.${c_e}"
    msg="$b_msg1 ${c_e}${c_uri}$orig_loc${c_e}\n$b_msg2$b_msg2b\n$b_msg3\n$warn1 $warn1b"

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
      echo -e "${c_norm}Merge instructions for this file can be found at ${c_e}${c_uri}$instr_file${c_e}"
    else
      echo -e "${c_norm_prob}Error could not create locations map file ${c_e}${c_uri}$instr_file${c_e}"
      echo -e "${c_norm_prob}Refer back to this log to manually back up and merge ${c_e}${c_uri}$target_loc${c_e}"
    fi
    return 0
  fi
  echo -e "$name ${c_norm_prob}failed. Illegal target ${c_e}${c_uri}$target_loc${c_e}"
  return 1
}

### download_latest ###
# Description:
# Downloads the .tar.gz of the latest release of gitpod-laravel-starter and extracts it to $target_dir
# Requires Globals
# $release_json
# $target_dir
download_latest() {

  echo -e "${c_norm}TESTING MOCK: Downloading and extracting ${c_e}${c_url}https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/v1.5.0${c_e}" # temp testing
  return 0 # temp testing, must download once first though

  local e1 e2 url
  e1="${c_norm_prob}Cannot download/extract latest gls tarball${c_e}"
  e2="${c_norm_prob}Unable to parse url from ${c_e}${c_uri}$release_json${c_e}"

  [[ -z $release_json ]] \
    && err_msg "$e1/n/t${c_norm_prob}Missing required file ${c_e}${c_uri}$release_json${c_e}" \
    && return 1

  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"
  [[ -z $url ]] && err_msg "$e1\n\t$e2" && return 1

  if ! cd "$target_dir";then
    err_msg "$e1\n\t${c_norm_prob}internal error, bad target directory: ${c_e}${c_uri}$target_dir${c_e}"
    return 1
  fi

  echo -e "${c_norm}Downloading and extracting ${c_e}${c_url}$url${c_e}"
  if ! curl -sL "$url" | tar xz --strip=1; then
    err_msg "$e1\n\t ${c_norm}curl failed ${c_e}${c_url}$url${c_e}"
    return 1
  fi

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
  local e1 e2 e2b update_msg1 update_msg2 base_ver_txt target_ver_txt
  e1="${c_norm_prob}Version mismatch${c_e}"
  
  # Create working directory
  if ! mkdir -p "$tmp_dir"; then
    err_msg "${c_norm_prob}Unable to create required directory ${c_uri}$tmp_dir${c_e}"
    abort_msg
    return 1
  fi

  # Download release data
  if ! download_release_json; then abort_msg && return 1; fi

  # Set base and target versions required global directories 
  if ! set_target_version; then abort_msg && return 1; fi
  [[ ! -d $target_dir ]] && mkdir "$target_dir"
  if ! set_base_version; then set_base_version_unknown; fi
  base_ver_txt="${c_number}$base_version${c_e}"
  target_ver_txt="${c_number}$target_version${c_e}"
  [[ $backups_dir == $(pwd) ]] &&
    backups_dir="${backups_dir}/GLS_BACKUPS_v$base_version" &&
    mkdir -p "$backups_dir"
  
  # Validate base and target versions
  if [[ $(comp_ver_lt "$base_version" "$target_version") == 0 ]]; then
    e2="$c_norm_prob}Your current version v${c_e}$base_ver_txt "
    e2b="${c_norm_prob}must be less than the latest version v${c_e}$target_ver_txt"
    err_msg "$e1\n\t$e2$e2b" && abort_msg && return 1
  fi

  # Set directives, download and extract latest release and execute directives
  update_msg1="${c_s_bold}${c_pass}BEGIN: ${c_e}${c_norm_b}Updating gitpod-laravel-starter version${c_e}"
  update_msg2="$base_ver_txt ${c_norm_b}to version ${c_e}$target_ver_txt"
  echo -e "$update_msg1 $update_msg2"
  if ! set_directives; then abort_msg && return 1; fi
  if ! download_latest; then abort_msg && return 1; fi
  if ! execute_directives; then abort_msg && return 1; fi

  echo -e "${c_pass}SUCCESS:${c_e} $update_msg1 $update_msg2"
  return 0
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

  handle_logo
}

### main ###
# Description:
# Main routine
main() {
  if ! init; then exit 1; fi
  if ! update; then cleanup && exit 1; fi
}
# END: functions

main

#!/bin/bash
# shellcheck source=/dev/null # Allow dynamic source paths
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# update.sh
#
# Description:
# Command line tool for updating a project built on gitpod-laravel-starter to the latest version
#
# Notes:
# Supports gitpod-laraver starter versions >= v1.0.0
# Update is interactive. Interactivity can be skipped by piping yes | or yes n | into this script 
# or by using the -f or --force option. Do so at your own risk.
# For specifics on what files are kept and recommended to be backed up, see the .latest_gls_manifest @
# https://github.com/apolopena/gls-tools/blob/main/.latest_gls_manifest


# BEGIN: Globals
# Note: Never mutate globals once they are set unless they are a flag/toggle

# The arguments passed to this script. Set by main().
script_args=()

# Options this script supports. Set by main()
global_supported_options=()

# Project root. Never run this script from outside the project root. Set by init()
project_root=

# Temporary working directory for the update. Set by init()
tmp_dir=

# Location for the download of latest version of gls to update the project to. Set by set_target_version()
target_dir=

# Location for recommended backups. Set by init(). Appended by update().
backups_dir=

# Latest release data downloaded from github. Set by init()
release_json=

# The version to update to. Set by init()
target_version=

# The version to update from Set by init()
base_version=

# Flag for the edge case where only the cache buster has been changed in .gitpod.Dockerfile. Set by init()
gp_df_only_cache_buster_changed=no

# Satisfy shellcheck by predefining the colors we use from lib/colors.sh
c_e=; c_s_bold=; c_norm=; c_norm_b=; c_norm_prob=; c_pass=; c_warn=; c_file=;
c_file_name=; c_url=; c_uri=; c_number=; c_choice=; c_prompt=;
# END: Globals

# BEGIN: functions

### version ###
# Description:
# Outputs this scripts version information
# See https://github.com/apolopena/gls-tools/releases
version() {
  echo "update is a tool from the gls-tools suite v0.0.5
Copyright © 2022 Apolo Pena
License MIT <https://spdx.org/licenses/MIT.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Apolo Pena; see
<https://github.com/apolopena/gls-tools/graphs/contributors>"
}

### name ###
# Description:
# Prints the file name of this script. Hardcoded so it works with process substitution.
name() {
  printf '%s' "${c_file_name}update.sh${c_e}"
}

### help ###
# Description:
# Outputs help text
help() {
  echo -e "Usage: update [-option | --option]...
Update a project built on apolopena/gitpod-laravel-starter to the latest version
Example: update --no-colors

-F, --force                 force overwrite all files and skip all interactivity
    --help                  display this help and exit
-l, --load-deps-locally     load tool dependencies from the local filesystem 
-n, --no-colors             omit colors from terminal output
-p, --prompt-diffs          prompt to show differences when overwriting anything
-q, --quiet                 reduce output messages
-s, --strict                show additional warnings
-V, --version               output version information and exit"
}

### load_get_deps ###
# Description:
# Downloads and sources the dependency loader library (lib/get-deps.sh) from
# https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/get-deps.sh
load_get_deps() {
  local get_deps_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/get-deps.sh"

  if ! curl --head --silent --fail "$get_deps_url" &> /dev/null; then
    echo -e "failed to load the loader from:\n\t$get_deps_url" && exit 1
  fi
  source <(curl -fsSL "$get_deps_url" &)
  ec=$?;
  if [[ $ec != 0 ]] ; then echo -e "failed to source the loader from:\n\t$get_deps_url"; exit 1; fi; wait;
}

### load_get_deps_locally ###
# Description:
# Sources the dependency loader library (lib/get-deps.sh) from the local filesystem
load_get_deps_locally() {
  local this_script_dir

  this_script_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
  if ! source "$this_script_dir/lib/get-deps.sh"; then
    echo -e "failed to source the loader from the local file system:\n\t$get_deps_url"
    exit 1
  fi
}

### validate_long_options ###
# Description:
# Checks 'set' long options against the global_supported_options array
#
# Returns 0 if all 'set' long options are in the global_supported_options array
# Return 1 if a 'set' long option is not in the global_supported_options array
# Returns 1 if the list_long_options function is not sourced
#
# Note:
# This function relies on lib/long-option.sh and the global variable global_supported_options
# For more details see: https://github.com/apolopena/gls-tools/blob/main/tools/lib/long-option.sh
validate_long_options() {
  local failed options;

  if ! declare -f "list_long_options" > /dev/null; then
    echo -e "${c_norm_prob}failed to validate options: list_long_options() does not exist${c_e}"
    return 1
  fi

  options="$(list_long_options)"

  for option in $options; do
    option=" ${option} "
    if [[ ! " ${global_supported_options[*]} " =~ $option ]]; then
        echo -e "${c_norm_prob}unsupported long option: ${c_pass}$option${c_e}"
        failed=1
    fi
  done

  [[ -n $failed ]] && return 1 || return 0
}

### validate_arguments ###
# Description:
# Validate the scripts arguments
#
# Note:
# Commands and bare double dashes are illegal. This functions handles them quick and dirty
# @@@@@@@INITIALIZED@@@@@@@ is a lock flag set one-time in init_script_args()
validate_arguments() {
  local e_bad_opt e_command

  e_command="${c_norm_prob}unsupported Command:${c_e}"
  e_bad_opt="${c_norm_prob}illegal option:${c_e}"

  for arg in "${script_args[@]}"; do
    if [[ $arg != '@@@@@@@INITIALIZED@@@@@@@' ]]; then
      # Regex: Commands do not start with a dash
      [[ $arg =~ ^[^\-] ]] && err_msg "$e_command ${c_pass}$arg${c_e}" && return 1
      # A bare double dash is also an illegal option
      [[ $arg == '--' ]] && err_msg "$e_bad_opt ${c_pass}$arg${c_e}" && return 1
    fi
  done
  return 0
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

### set_target_version ###
# Description:
# Sets target version and target directory
# Requires Global:
# $release_json (a valid github latest release json file)
set_target_version() {
  local regexp e1 e1b e2 rle

  regexp='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'
  e1="${c_norm_prob}cannot set target version"
  e1b="missing required file ${c_uri}$release_json${c_e}"
  e2="${c_norm_prob}failed to parse target version from:\n\t${c_uri}$release_json${c_e}"

  [[ ! -f $release_json ]] && err_msg "$e1\n\t$e1b" && return 1
  
  target_version="$(grep "tag_name" "$release_json" | grep -oE "$regexp")"

  if [[ -z $target_version ]]; then
    rle="rate limit exceeded"
    if [[ $(grep "message" "$release_json" | grep -o "$rle") == "$rle" ]]; then
      err_msg "$e2\n\t${c_warn}github hourly $rle${c_e}" && return 1
    fi
    err_msg "$e2" && return 1
  fi

  target_dir="$tmp_dir/$target_version"
}

### load_deps_locally_option_looks_mispelled ###
# Description:
# Searches the global $script_args array for a possible typo in the --load-deps-locally option
# Returns 1 and outputs a message showing what was matched if a possible typo is found
# Returns 0 if no typo is found or if the global $script_args array has no elements in it
# 
# Usage example:
# script_args=("$@"); if load_deps_locally_option_looks_mispelled; then exit 1; fi
#
# Note:
# Be aware that the exit codes for this function are intentionally reversed
load_deps_locally_option_looks_mispelled() {
  local script_args_flat

  [[ ${#script_args[@]} -eq 0 ]] && return 1
  script_args_flat="$(printf '%s\n' "${script_args[@]}")"
  if [[ $script_args_flat =~ [-]{0,3}lo[a|o]?[a-z]?d[a-z]?[-_]deps?[-_]local?ly ]]; then
    echo -e "invalid option: ${BASH_REMATCH[0]}\ndid you mean? --load-deps-locally"
    return 0
  fi
  return 1
}

### init ###
# Description:
# Handles colors, sets and validates all arguments and long options passed to this script
# Sets long options and sets global variables other functions will depnd on
# An optional fancy header is written to stdout if this function succeeds
#
# Returns 0 if successful, returns 1 if there are any errors
# Also returns 1 if an existing installation of gitpod-laravel-starter is not detected
#
# Note:
# This function can only be called once and prior to calling update()
# Subsequent attempts to call this function will result in an error
init() {
  local arg gls e_not_installed e_long_options nothing_m run_r_m
  
  # Handle color support first and foremost
  if ! printf '%s\n' "${script_args[@]}" | grep -Fxq -- "--no-colors"; then
   handle_colors
  fi

  gls="${c_pass}gitpod-laravel-starter${c_e}${c_norm_prob}"
  e_not_installed="${c_norm_prob}An existing installation of $gls is required but was not detected${c_e}"
  curl_m="bash <(curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/install.sh)"
  nothing_m="${c_norm_prob}Nothing to update\n\tTry installing $gls instead"
  run_r_m="Run the installer remotely:\n\t${c_uri}$curl_m${c_e}"
  run_b_m="${c_norm_prob}or if you have the gls binary installed run: ${c_file}gls install${c_e}"
  e_long_options="${c_norm_prob}failed to set global long options${c_e}"

  if ! gls_installation_exists; then 
    warn_msg "$e_not_installed\n\t$nothing_m\n\t$run_r_m\n\t$run_b_m"
    abort_msg
    return 1; 
  fi
  
  # Set globals that other functions will rely on
  project_root="$(pwd)"
  backups_dir="$project_root"; # Will be mutated intentionally by update()
  tmp_dir="$project_root/tmp_gls_update"
  release_json="$tmp_dir/latest_release.json"

  # Create the temporary working directory that other functions will rely on
  if ! mkdir -p "$tmp_dir"; then
    err_msg "${c_norm_prob}unable to create required directory ${c_uri}$tmp_dir${c_e}"
    abort_msg
    return 1
  fi
  
  # Validate options and arguments
  if ! set_long_options "${script_args[@]}"; then err_msg "$e_long_options" && abort_msg && return 1; fi
  if ! validate_long_options; then abort_msg && return 1; fi
  if ! validate_arguments; then abort_msg && return 1; fi
  
  # Success. It is now safe to call update()
  if ! has_long_option --quiet; then gls_header 'updater'; fi
}

### update ###
# Description:
# Performs the update in a specific order of execution
# Creates any necessary global files and directories any function might need
# Handles errors for each function called
#
# Note:
# main() and then init() must be called prior to calling this function
update() {
  local ec e1 e2 e2b update_msg1 update_msg2 warn_msg1 warn_msg1b warn_msg1b warn_msg1c fin_msg1 fin_msg1b
  local base_ver_txt target_ver_txt file same_ver1 same_ver1b same_ver1c gls_url loc e_fail_prefix

  e_fail_prefix="${c_norm_prob}update() internal error: Failed to"
  e1="${c_norm_prob}Version mismatch${c_e}"
  warn_msg1="${c_norm_prob}Could not delete the directory ${c_uri}.gp${c_e}"
  warn_msg1b="${c_norm_prob}Some old files may remain but should not cause any issues${c_e}"
  warn_msg1c="${c_norm_prob}The old file may remain but should not cause any issues${c_e}"
  warn_msg1d="${c_norm_prob}Try manually copying this file from the repo to the project root${c_e}"
  gls_url="https://github.com/apolopena/gitpod-laravel-starter"

  # Download release data
  if ! download_release_json "$release_json"; then abort_msg && return 1; fi

  # Set base and target versions and messages
  if ! set_target_version; then abort_msg && return 1; fi
  [[ ! -d $target_dir ]] && mkdir "$target_dir"
  if ! set_base_version; then set_base_version_unknown; fi
  base_ver_txt="${c_number}$base_version${c_e}"
  target_ver_txt="${c_number}$target_version${c_e}"
  fin_msg1="${c_norm_b}gitpod-laravel-starter has been updated to the latest version"
  fin_msg1b="${c_number}v$target_ver_txt${c_e}"
  same_ver1="${c_file_name}Notice:${c_e} ${c_norm_prob}Your current version $base_ver_txt"
  same_ver1b="${c_norm_prob}and the latest version $target_ver_txt ${c_norm_prob}are the same${c_e}"
  same_ver1c="${c_norm}${c_s_bold}gitpod-laravel-starter${c_e}${c_norm} is already up to date${c_e}"
  update_msg1="${c_norm_b}Updating gitpod-laravel-starter version${c_e}"
  update_msg2="$base_ver_txt ${c_norm_b}to version ${c_e}$target_ver_txt"

  # Create the global backups dir (required by lib/directives.sh)
  if [[ $backups_dir == "$project_root" ]]; then
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
  
  if ! has_long_option --quiet; then
    echo -e "${c_s_bold}$update_msg1 $update_msg2${c_norm} ...\n${c_e}";
  fi

  # Set directives, download/extract latest release and execute directives
  if has_long_option --force; then
      if ! install_latest_tarball "$release_json"; then abort_msg && return 1; fi
  else 
    if ! set_directives; then err_msg "$e_fail_prefix set a directive" && abort_msg && return 1; fi
    if ! install_latest_tarball "$release_json"; then abort_msg && return 1; fi
    if ! execute_directives; then abort_msg && return 1; fi
  fi

  # BEGIN: Update by deleting the old (orig) and coping over the new (target)

  # Latest files to copy from target (latest) to orig (current)
  local root_files=(".gitpod.yml" ".gitattributes" ".npmrc" ".gitignore")

  # Latest directories to copy from target (latest) to orig (current)
  local root_dirs=(".gp" ".vscode" ".github")

  # Remove files before copying just in case they are in the current (orig) but not the latest (target)
  for i in "${!root_files[@]}"; do
    if [[ -f ${root_files[$i]} ]]; then
      if ! rm "${root_files[$i]}"; then
        warn_msg "${c_norm_prob}Could not delete the file ${c_uri}${root_files[$i]}${c_e}\n\t$warn_msg1c"
      fi
    fi
  done

  # Remove .gp to ensure that no old files remain since we are using cp instead of rsync
  if ! rm -rf .gp; then
    warn_msg "$warn_msg1\n\t$warn_msg1b"
  fi

  # Remove the Theia configurations, see https://github.com/apolopena/gitpod-laravel-starter/issues/216
  [[ -d .theia ]] && rm -rf .theia

  e1="${c_norm_prob}You will need to manually copy it from the repository: ${c_url}$gls_url${c_e}"

  for i in "${!root_dirs[@]}"; do
    loc="$target_dir/${root_dirs[$i]}"
    if ! cp -r "$loc" "$project_root"; then
      warn_msg "$(failed_copy_to_root_msg "$loc" "d")\n\t$e1/tree/main/${c_url}${root_dirs[$i]}${c_e}"
    fi
  done

  for i in "${!root_files[@]}"; do
    loc="$target_dir/${root_files[$i]}"
    if ! cp "$loc" "$project_root/${root_files[$i]}"; then
      warn_msg "${c_norm_prob}Could not copy the file ${c_uri}${loc}${c_e}\n\t$warn_msg1d"
    fi
  done

  if [[ $gp_df_only_cache_buster_changed == no ]]; then
    file="$target_dir/.gitpod.Dockerfile"
    if ! cp "$file" "$project_root"; then
      warn_msg "$(failed_copy_to_root_msg "${c_uri}$file${c_e}" "f")/t$e1/tree/main/${c_url}.gitpod.Dockerfile${c_e}"
    fi
  fi
  # END: Update by deleting the old (orig) and coping over the new (target)
  
  # Success
  if ! has_long_option --quiet; then 
    gls_header success
    echo -e "$fin_msg1 $fin_msg1b"
  else
    echo -e "$fin_msg1 $fin_msg1b"
  fi
}

### cleanup ###
# Description:
# Recursively removes any temporary directories this script may have created
#
# WARNING:
# This function assumes that this script will be run from the project root
# If this script is not run from the project root then any directories 
# outside the project root that have the same name as the temporary directories
# that this script creates will most likely be deleted
cleanup() {
  local e_msg1 e_msg1b

  e_msg1="${c_norm_prob}cleanup() failed:\n\t${c_uri}$tmp_dir${c_e}"
  e_msg1b="\n\t${c_norm_prob}is not a sub directory of:\n\t${c_uri}$project_root${c_e}"

  if is_subpath "$project_root" "$tmp_dir"; then
    [[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
  else
    warn_msg "${e_msg1}${e_msg1b}" && exit 1
  fi
  
  find . -maxdepth 1 -type d -name "GLS_BACKUPS_v*" | \
  while read -r dir; do
    [[ $(find "$dir" -mindepth 1 -maxdepth 1 | wc -l) -eq 0 ]] && rm -rf "$dir"
  done 
}

### init_script_args ###
# Description:
# One-time function to convert supported short options ($1) to long options and 
# append them to the global $script_args array
# Returns 0 on success
# Returns 1 on failure or if this function is called more than once
init_script_args() {
  local OPTIND opt lock='@@@@@@@INITIALIZED@@@@@@@'

  if printf '%s\n' "${script_args[@]}" | grep -Fxq -- "$lock"; then
    echo -e "${c_norm_prob}init_script_args() internal error: this function can only be called once${c_e}"
    return 1
  fi
  while getopts ":Flnpqs" opt; do
    case $opt in
      F) script_args+=( --force ) ;;
      l) script_args+=( --load-deps-locally );;
      n) script_args+=( --no-colors ) ;;
      p) script_args+=( --prompt-diffs ) ;;
      q) script_args+=( --quiet ) ;;
      s) script_args+=( --strict) ;;
      \?) echo "illegal option: -$OPTARG"; exit 1
    esac
  done
  shift $((OPTIND - 1 ))
  script_args+=("$lock")
}

### main ###
# Description:
# Main routine
# This function must follow a very specific order of execution:
#   1. Set local values, global values and process the --help option
#   2. Harvest short options from argv and append them to the global script args array
#   3. Load lib/get-deps.sh and use it's function get_deps() to load the rest of the dependencies
#   4. Load the rest of the dependencies using get_deps()
#   5. init() --> update() --> cleanup()
#
# Note:
# Dependency loading is synchronous and happens on every invocation of the script
# unless the global option --load-deps-locally is in argv
main() {
  local dependencies=(
                       'util.sh'
                       'color.sh'
                       'header.sh'
                       'spinner.sh'
                       'long-option.sh'
                       'directives.sh'
                       'download.sh'
                       )
  local possible_option=()
  local short_options=()
  local ec arg abort="aborted"

  # Set globally supported long options
  global_supported_options=(
    --force
    --help
    --load-deps-locally
    --no-colors
    --prompt-diffs
    --quiet
    --strict
    --version
  )

  [[ " $* " =~ " --help " ]] && help && exit 1
  [[  " $* " =~ " --version " || " $* " =~ " -V " ]] && version && exit 1
  

  # Harvest short options from argv
  for arg in "$@"; do
    [[ $arg =~ ^-[^\--].* ]] && short_options+=("$arg")
  done

  # Set the global $script_args array
  script_args=("$@")

  # Append the global $script_args array with the long option equivalents of the short options in argv
  if ! init_script_args "${short_options[@]}"; then echo "$abort"; exit 1; fi

  # Load the loader (lib/get-deps.sh)
  if printf '%s\n' "${script_args[@]}" | grep -Fxq -- "--load-deps-locally"; then
    possible_option=(--load-deps-locally)
    load_get_deps_locally
  else
    if load_deps_locally_option_looks_mispelled; then exit 1; fi
    load_get_deps
  fi

  # Use the loaded loader to load the rest of the dependencies
  if ! get_deps "${possible_option[@]}" "${dependencies[@]}"; then echo "$abort"; exit 1; fi

  # Initialize, update and finally cleanup
  if ! init; then cleanup; exit 1; fi
  if ! update; then cleanup; exit 1; fi
  cleanup
}
# END: functions

main "$@"
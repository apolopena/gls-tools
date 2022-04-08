#!/bin/bash
# shellcheck source=/dev/null # Allow dynamic source paths
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# install.sh
#
# Description:
# Installs the latest release version of apolopena/gitpod-laravel-starter
#
# Notes:
# Install is interactive when it needs to be
# Interactivity can be skipped by piping yes | or yes n | into this script 
# or by using the -f or --force option. Do so at your own risk
# For specifics on what files are kept and recommended to be backed up, see the .latest_gls_manifest @
# https://github.com/apolopena/gls-tools/blob/main/.latest_gls_manifest


# BEGIN: Globals
# Note: Never mutate globals once they are set unless they are a flag/toggle

# The arguments passed to this script. Set from main().
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

# Satisfy shellcheck by predefining the colors we use from lib/colors.sh
c_norm_b=; c_norm_prob=; c_number=; c_uri=; c_warn=; c_pass=; c_file_name=; c_file=; c_e=;
# END: Globals

# BEGIN: functions

### version ###
# Description:
# Outputs this tools version information
version() {
  echo "v0.0.5
install is a gitpod-larvel-starter tool from the gls-tools suite
Copyright © 2022 Apolo Pena
License MIT <https://spdx.org/licenses/MIT.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Apolo Pena; see
<https://github.com/apolopena/gls-tools/graphs/contributors>"
}

### help ###
# Description:
# Outputs help text
help() {
  echo -e "Usage: install [-option | --option]...
Install the latest version of apolopena/gitpod-laravel-starter
Example: install -s

-F, --force                 force overwrite all files and skip all interactivity
    --help                  display this help and exit
-l, --load-deps-locally     load tool dependencies from the local filesystem 
-n, --no-colors             omit colors from terminal output
-p, --prompt-diffs          prompt to show differences before overwriting
                              this option is set by default
-q, --quiet                 reduce output messages
-s, --skip-diff-prompts     skip prompts to show differences before overwriting
-S, --strict                show additional warnings
-V, --version               output version information and exit"
}

### name ###
# Description:
# Prints the file name of this script. Hardcoded so it works with process substitution
name() {
  printf '%s' "${c_file_name}install.sh${c_e}"
}

### load_get_deps ###
# Description:
# Synchronously downloads and sources the dependency loader library (lib/get-deps.sh) from
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
  local arg e_bad_opt e_command

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
  local arg gls e_installed e_long_options cannot_m run_r_m
  
  # Handle color support first and foremost
  if ! printf '%s\n' "${script_args[@]}" | grep -Fxq -- "--no-colors"; then
   handle_colors
  fi

  gls="${c_pass}gitpod-laravel-starter${c_e}${c_norm_prob}"
  e_installed="${c_norm_prob}An existing installation of $gls was detected${c_e}"
  curl_m="bash <(curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh)"
  cannot_m="${c_norm_prob}Cannot install on an existing installation\n\tTry updating $gls instead"
  run_r_m="Run the updater remotely:\n\t${c_uri}$curl_m${c_e}"
  run_b_m="${c_norm_prob}or if you have the gls binary installed run: ${c_file}gls update${c_e}"
  e_long_options="${c_norm_prob}failed to set global long options${c_e}"

  if gls_installation_exists; then 
    warn_msg "$e_installed\n\t$cannot_m\n\t$run_r_m\n\t$run_b_m"
    abort_msg
    return 1; 
  fi
  
  # Set globals that other functions will depend on
  project_root="$(pwd)"
  backups_dir="$project_root"; # Will be mutated intentionally by update()
  tmp_dir="$project_root/tmp_gls_update"
  release_json="$tmp_dir/latest_release.json"

  # Create the temporary working directory that other functions will depend on
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
  if ! has_long_option --quiet; then gls_header 'installer'; fi
}

### install ###
# Description:
# Interactively installs the latest release version of apolopena/gitpod-laravel-starter
#
# Note:
# main() and then init() must be called prior to calling this function
install() {
  local e_fail_prefix target_ver_txt fin_msg1 fin_msg1b warn_msg1 warn_msg1b

  e_fail_prefix="${c_norm_prob}install() internal error: Failed to"
  warn_msg1="${c_norm_prob}Could not delete the directory ${c_uri}.gp${c_e}"
  warn_msg1b="${c_norm_prob}Some old files may remain but should not cause any issues${c_e}"

  # Download release data
  if ! download_release_json "$release_json"; then abort_msg && return 1; fi

  # Set target_version including $target_dir
  if ! set_target_version; then abort_msg && return 1; fi

  # Set messages
  target_ver_txt="${c_number}v$target_version${c_e}"
  fin_msg1="${c_norm_b}gitpod-laravel-starter ${c_e}$target_ver_txt"
  fin_msg1b="${c_norm_b}has been installed to:\n${c_e}${c_uri}$project_root${c_e}"

  # Create target_dir
  [[ ! -d $target_dir ]] && mkdir "$target_dir"

  # Create backups_dir
  if [[ $backups_dir == "$project_root" ]]; then
    backups_dir="${backups_dir}/GLS_BACKUPS_project_data"
    [[ -d $backups_dir ]] && rm -rf "$backups_dir"
    mkdir "$backups_dir"
  fi

  # Set directives, download/extract latest release and execute directives
  if has_long_option --force; then
      if ! install_latest_tarball "$release_json" --treat-as-unbuilt; then abort_msg && return 1; fi
  else
    if ! set_directives --only-recommend-backup; then
      err_msg "$e_fail_prefix set a directive" && abort_msg && return 1
    fi
    if ! install_latest_tarball "$release_json" --treat-as-unbuilt; then abort_msg && return 1; fi
    if ! execute_directives; then abort_msg && return 1; fi
  fi

  # Purge originals first to ensure nothing old remains since we are using cp instead of rsync
  if ! rm -rf .gp; then warn_msg "$warn_msg1\n\t$warn_msg1b"; fi
  if ! rm -rf .vscode; then warn_msg "$warn_msg1\n\t$warn_msg1b"; fi
  if ! rm -rf .github; then warn_msg "$warn_msg1\n\t$warn_msg1b"; fi

  # Install
  if ! cp -a "$target_dir/." "$project_root"; then return 1; fi

  # Success
  if ! has_long_option --quiet; then 
    gls_header success
    echo -e "$fin_msg1 $fin_msg1b"
  else
    echo -e "$fin_msg1 ${c_norm_b}has been installed${c_e}"
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
  
  find . -maxdepth 1 -type d -name "GLS_BACKUPS_*" | \
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
  while getopts ":FlnpqsS" opt; do
    case $opt in
      F) script_args+=( --force ) ;;
      l) script_args+=( --load-deps-locally );;
      n) script_args+=( --no-colors ) ;;
      p) script_args+=( --prompt-diffs ) ;;
      q) script_args+=( --quiet ) ;;
      s) script_args+=( --skip-diff-prompts) ;;
      S) script_args+=( --strict) ;;
      \?) echo "illegal option: -$OPTARG"; exit 1 ;;
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
#   5. init() --> install() --> cleanup()
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
  local ec arg abort="aborted"

  # Set globally supported long options
  global_supported_options=(
    --force
    --help
    --load-deps-locally
    --no-colors
    --prompt-diffs
    --quiet
    --skip-diff-prompts
    --strict
  )

  [[ " $* " =~ " --help " ]] && help && exit 1
  [[  " $* " =~ " --version " || " $* " =~ " -V " ]] && version && exit 1

  # Harvest short options from argv
  for arg in "$@"; do
    [[ $arg =~ ^-[^\--].* ]] && short_options+=("$arg")
  done

  # Set the global $script_args array
  if printf '%s\n' "$@" | grep -Fxq -- "--skip-diff-prompts"; then
    script_args=("$@");
  else
    script_args=("$@" "--prompt-diffs");
  fi

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
  if ! install; then cleanup; exit 1; fi
  cleanup
}
# END: functions

main "$@"

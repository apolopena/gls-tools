#!/bin/bash
# shellcheck source=/dev/null # Allow dynamic source paths
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# change-version.sh
#
# Description:
# Changes the version number in any gls-tool that has changed since the latest release
# A diff of the changes the script makes will be shown and then the code files will be parsed
# to update the version numbers either by patch, minor, or major version
#
# Note: This tool will only work in a clone of a gls-tools repository
# Calling and invoking this script via curl is not supported

# BEGIN: Globals
# Note: Never mutate globals once they are set unless they are a flag/toggle

# The arguments passed to this script. Set from main().
script_args=()

# Options this script supports. Set by main()
global_supported_options=()

# Type of version to bump up, set by init_script_args if the -b option is used
# or set interactively via a prompt
# can be: major, minor, patch
bump_type=

# Project root. Never run this script from outside the project root. Set by init()
project_root=

# Temporary working directory for the change-version. Set by init()
tmp_dir=

# Location for the download of latest version of gls to change-version the project to. Set by set_target_version()
target_dir=

# Location for recommended backups. Set by init(). Appended by change-version().
backups_dir=

# Latest release data downloaded from github. Set by init()
release_json=

# The version to change-version to. Set by init()
target_version=

# Satisfy shellcheck by predefining the colors we use from lib/colors.sh
c_norm_b=; c_norm_prob=; c_number=; c_uri=; c_warn=; c_pass=; c_file_name=; c_file=; c_e=;
# END: Globals

# BEGIN: functions

### version ###
# Description:
# Outputs version information
version() {
  echo "v1.0.0
change-version is a gitpod-larvel-starter tool from the gls-tools suite
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
  echo -e "Usage: change-version [-option | --option]...
Install the latest version of apolopena/gitpod-laravel-starter
Example: change-version -s
-b                          -b=STRING bump up version type by STRING
                              valid values for STRING sre: major, minor, patch
    --help                  display this help and exit
-n, --no-colors             omit colors from terminal output
-s, --skip-diff-prompts     skip prompts to show differences before overwriting
-V, --version               output version information and exit"
}

### name ###
# Description:
# Prints the file name of this script
# Hardcoded so it works with process substitution
name() {
  printf '%s' "${c_file_name}change-version.sh${c_e}"
}

### load_get_deps_locally ###
# Description:
# Sources the dependency loader library (lib/get-deps.sh) from the local filesystem
load_get_deps_locally() {
  local this_script_dir

  this_script_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
  if ! source "$this_script_dir/../lib/get-deps.sh"; then
    echo -e "failed to source the loader from the local file system:\n\t$this_script_dir/lib/get-deps.sh"
    exit 1
  fi
}

### validate_long_options ###
# Description:
# Checks long options that have been set against the global_supported_options array
#
# Returns 0 if all long options that have been set are in the $global_supported_options array
# Return 1 if a long option that has been set is not in the $global_supported_options array
# Returns 1 if the list_long_options function is not sourced
#
# Note:
# This function relies on lib/long-option.sh and the global variable $global_supported_options
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
# Validates the global scripts arguments array
#
# Note:
# Commands and bare double dashes are illegal
# @@@@@@@INITIALIZED@@@@@@@ is a lock flag set one-time in init_script_args()
validate_arguments() {
  local arg e_bad_opt e_command

  e_command="${c_norm_prob}unsupported Command:${c_e}"
  e_bad_opt="${c_norm_prob}illegal option:${c_e}"

  for arg in "${script_args[@]}"; do
    if [[ $arg != '@@@@@@@INITIALIZED@@@@@@@' ]]; then
      # Commands do not start with a dash
      [[ $arg =~ ^[^\-] ]] && err_msg "$e_command ${c_pass}$arg${c_e}" && return 1
      # A bare double dash is illegal
      [[ $arg == '--' ]] && err_msg "$e_bad_opt ${c_pass}$arg${c_e}" && return 1
    fi
  done
  return 0
}

### set_target_version ###
# Description:
# Parses github release data and sets the global variables for target version and target directory
# Requires the global variable $release_json (a valid github latest release json file)
# Returns and error exit code in the following situations:
#   The global $release_json is not a file
#   The global $release_json file contains a message that the rate limit has been exceeded
#   The parse for the target version results in an empty string
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
# This function can only be called once and prior to calling change-version()
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
  backups_dir="$project_root"; # Will be mutated intentionally by change-version()
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
  
  # Success. It is now safe to call change-version()
  #if ! has_long_option --quiet; then gls_header 'installer'; fi
}

### change-version ###
# Description:
# Description goes here
#
# Note:
# main() and then init() must be called prior to calling this function
change-version() {
  local e_fail_prefix target_ver_txt fin_msg1 fin_msg1b warn_msg1 warn_msg1b

  e_fail_prefix="${c_norm_prob}change-version() internal error: Failed to"
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
  if ! install_latest_tarball "$release_json" --treat-as-unbuilt; then abort_msg && return 1; fi

  echo "verify valid bump from $target_version type here for: $bump_type"

  # Success
  echo -e "$fin_msg1 ${c_norm_b}has been installed${c_e}"
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

valid_bump_type() {
  [[ $1 != 'major' && $1 != 'minor' && $1 != 'patch' ]] && return 1 || return 0
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
  while getopts ":b:nps" opt; do
    case $opt in
      b) if valid_bump_type "${OPTARG:1}"; then 
           bump_type="${OPTARG:1}"
         else
           echo "invalid -b (bump type) value: ${OPTARG:1}"; exit 1;
         fi ;; 
      n) script_args+=( --no-colors ) ;;
      p) script_args+=( --prompt-diffs ) ;;
      s) script_args+=( --skip-diff-prompts) ;;
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
#   5. init() --> change-version() --> cleanup()
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
  local arg abort="aborted"

  # Set globally supported long options
  global_supported_options=(
    --bump
    --help
    --no-colors
    --prompt-diffs
    --skip-diff-prompts
  )

  # Handle options that have no dependencies and should exit when completed
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
  load_get_deps_locally

  # Use the loaded loader to load the rest of the dependencies
  if ! get_deps "${possible_option[@]}" "${dependencies[@]}"; then echo "$abort"; exit 1; fi

  # Initialize, change-version and finally cleanup
  if ! init; then cleanup; exit 1; fi
  if ! change-version; then cleanup; exit 1; fi
  #cleanup
}
# END: functions

main "$@"
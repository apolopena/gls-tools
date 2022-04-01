#!/bin/bash
# shellcheck source=/dev/null # Allow dynamic source paths
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# REPLACE_WITH_SCRIPT_NAME (and file extension) BOILERPLATE gls-tools SCRIPT
#
# Description:
# DESCRIPTION GOES HERE
# Boiler plate code for creating a gls-tool script in tools
# Just make a few replacements in the obvious places to get started
# The code runs as-is. It will download the latest release version of gitpod laravel starter
# to tmp_gls_update/x.x.x where x is an integer
# That directory will be created relative to where this script is run from


# BEGIN: Globals
# Never mutate globals them once they are set unless they are a flag

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

### name ###
# Description:
# Prints the file name of this script. Hardcoded so it works with process substitution
name() {
  printf '%s' "${c_file_name}boilerplate.sh${c_e}"
}

### help ###
# Description:
help() {
  echo "help text goes here"
}

### load_get_deps ###
# Description:
# Downloads and sources dependencies $@ in parallel
# using the base url: https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/
load_get_deps() {
  local get_deps_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/get-deps.sh"

  if ! curl --head --silent --fail "$get_deps_url" &> /dev/null; then
    err_msg "failed to load the loader from:\n\t$get_deps_url" && exit 1
  fi
  source <(curl -fsSL "$get_deps_url" &)
  ec=$?;
  if [[ $ec != 0 ]] ; then echo -e "failed to source the loader from:n\t$get_deps_url"; exit 1; fi; wait;
}

### load_get_deps_locally ###
# Description:
# Sources dependencies $@ from the local file system relative to tools/lib
load_get_deps_locally() {
  local this_script_dir

  this_script_dir="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"

  # Boilerplate Note: The script directory is parsed so that this script actually works as-is 
  # remove this entire code block once your script lives in tools rather than here in tools/internal
  # shellcheck disable=SC2001
  this_script_dir=$(echo "$this_script_dir" | sed 's@/internal@@g')


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
# Commands and short options are illegal. This functions handles them quick and dirty
validate_arguments() {
  local e_bad_opt e_bad_short_opt e_command

  e_command="${c_norm_prob}unsupported Command:${c_e}"
  e_bad_short_opt="${c_norm_prob}illegal short option:${c_e}"
  e_bad_opt="${c_norm_prob}illegal option:${c_e}"

  for arg in "${script_args[@]}"; do
    # Regex: Short options are a single dash or start with a single dash but not a double dash
    [[ $arg == '-' || $arg =~ ^-[^\--].* ]] && err_msg "$e_bad_short_opt ${c_pass}$arg${c_e}" && return 1

    # Regex: Commands do not start with a dash
    [[ $arg =~ ^[^\-] ]] && err_msg "$e_command ${c_pass}$arg${c_e}" && return 1

    # A bare double dash is also an illegal option
    [[ $arg == '--' ]] && err_msg "$e_bad_opt ${c_pass}$arg${c_e}" && return 1
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

### init ###
# Description:
# Enables colors, validates all arguments passed to this script,
# sets long options and sets any global variables
# A fancy header is written to stdout if this function succeeds ;)
#
# Returns 0 if successful, returns 1 if there are any errors
# Also returns 1 if an existing installation of gitpod-laravel-starter is not detected
#
# Note:
# This function can only be called once and prior to calling update()
# Subsequent attempts to call this function will result in an error
init() {
  local arg gls e_installed e_long_options cannot_m run_r_m
  
  # Handle color support first
  if ! printf '%s\n' "${script_args[@]}" | grep -Fxq -- "--no-colors"; then
   handle_colors
  fi

  gls="${c_pass}gitpod-laravel-starter${c_e}${c_norm_prob}"
  e_installed="${c_norm_prob}an existing installation of $gls was not detected${c_e}"
  curl_m="bash <(curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh)"
  cannot_m="${c_norm_prob}cannot install\n\tTry updating $gls instead either"
  run_r_m="run remotely: ${c_uri}$curl_m${c_e}"
  run_b_m="${c_norm_prob}or if you have the gls binary installed run: ${c_file}gls update${c_e}"
  e_long_options="${c_norm_prob}failed to set global long options${c_e}"

  if gls_installation_exists; then 
    err_msg "$e_installed\n\t$cannot_m\n\t$run_r_m\n\t$run_b_m"
    abort_msg
    return 1; 
  fi
  
  # Set globals that other functions will depend on
  project_root="$(pwd)"
  backups_dir="$project_root"; # Will be mutated intentionally by update()
  tmp_dir="$project_root/tmp_gls_update"
  release_json="$tmp_dir/latest_release.json"

  # Create a temporary working directory that other functions will depend on
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
  gls_header 'installer'
}

### REPLACE_WITH_SCRIPT_NAME ###
# Description:
# DESCRIPTION GOES HERE
REPLACE_WITH_SCRIPT_NAME() {
  local target_ver_txt fin_msg1 fin_msg1b

  # Download release data
  if ! download_release_json "$release_json"; then abort_msg && return 1; fi

  # Set target_version
  if ! set_target_version; then abort_msg && return 1; fi

  # Set messages
  target_ver_txt="${c_number}v$target_version${c_e}"
  fin_msg1="${c_norm_b}gitpod-laravel-starter ${c_e}$target_ver_txt"
  fin_msg1b="${c_norm_b}has been PLACEHOLDER TEXT to:\n\t${c_e}${c_uri}$project_root${c_e}"

  # Create target_dir
  [[ ! -d $target_dir ]] && mkdir "$target_dir"

  # Create backups_dir, alter this as needed
  if [[ $backups_dir == "$project_root" ]]; then
    backups_dir="${backups_dir}/GLS_BACKUPS_project_data"
    [[ -d $backups_dir ]] && rm -rf "$backups_dir"
    mkdir "$backups_dir"
  fi

  # Set directives, download/extract latest release and execute directives
  #if ! set_directives; then err_msg "$e_fail_prefix set a directive" && abort_msg && return 1; fi
  if ! install_latest_tarball "$release_json" --treat-as-unbuilt; then abort_msg && return 1; fi
  #if ! execute_directives; then abort_msg && return 1; fi

  # TODO: MAIN LOGIC GOES HERE

  # Success
  gls_header success
  echo -e "$fin_msg1 $fin_msg1b"
  return 0
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
  
  # Satisfy shellcheck, remove this once the code block below this one is uncommented
  echo "$e_msg1" > /dev/null; echo "$e_msg1b" > /dev/null

  # Delete the temporary working directory, comment this out for testing
  #if is_subpath "$project_root" "$tmp_dir"; then
  #  [[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
  #else
  #  warn_msg "${e_msg1}${e_msg1b}" && exit 1
  #fi
  
  # Delete all empty backup directories, alter as needed
  find . -maxdepth 1 -type d -name "GLS_BACKUPS_*" | \
  while read -r dir; do
    [[ $(find "$dir" -mindepth 1 -maxdepth 1 | wc -l) -eq 0 ]] && rm -rf "$dir"
  done 
}

### main ###
# Description:
# Main routine
# Order specific:
#   1. Set local and global values
#   2. Load lib/get-deps.sh, it contains get_deps() which is used to load the rest of the dependencies
#   3. Load the rest of the dependencies using get_deps()
#   3. Initialize by calling init()
#   4. Update by calling update(). Clean up if the update fails
#
# Note:
# Dependency loading is synchronous and happens on every invocation of the script
# unless the global option --load-deps-locally is used
# init() and update() cleanup after themselves
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
  local abort="update aborted"
  local ec

  # Set globals once and never touch them again
  script_args=("$@");
  # Alter as needed but do not remove --load-deps-locally
  global_supported_options=(
    --help
    --load-deps-locally
    --move-meta-files
    --force
    --no-colors
    --strict
  )

  # Process the --help directive first since it requires no dependencies to do so
  [[ " ${script_args[*]} " =~ " --help " ]] && help && exit 1

  # Load the loader (get-deps.sh)
  if printf '%s\n' "${script_args[@]}" | grep -Fxq -- "--load-deps-locally"; then
    possible_option=(--load-deps-locally)
    load_get_deps_locally
  else
    load_get_deps
  fi

  # Use the loaded loader it to load the rest of the dependencies
  if ! get_deps "${possible_option[@]}" "${dependencies[@]}"; then echo "$abort"; exit 1; fi

  # Initialize, update and cleanup
  if ! init; then exit 1; fi
  if ! REPLACE_WITH_SCRIPT_NAME; then cleanup; exit 1; fi
  cleanup
}
# END: functions

main "$@"

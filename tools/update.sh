#!/bin/bash
# shellcheck source=/dev/null
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# update.sh
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
# Never mutate globals them once they are set unless they are a flag

# The arguments passed to this script. Set from main().
script_args=()

# Supported options.
global_supported_options=(
  --help
  --debug 
  --load-deps-locally
  --manifest
  --strict
)

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

# Global message prefixes are declared here but set in init() so they can be conditionally colorized
note_prefix=

# Keep shellchack happy by predefining the colors set by lib/colors.sh
c_e=; c_s_bold=; c_norm=; c_norm_b=; c_norm_prob=; c_pass=; c_warn=; c_fail=; c_file=;
c_file_name=; c_url=; c_uri=; c_number=; c_choice=; c_prompt=;

# END: Globals

# BEGIN: functions


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
  spinner_task "$msg from:\n\t${c_url}$url${c_e}" 'curl' --silent "$url" -o "$release_json"
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

### update ###
# Description:
# Performs the update by calling all the proper routines in the proper order
# Creates any necessary files or directories any routine might need
# Handles errors for each routine called or action made
update() {
  local ec e1 e2 e2b update_msg1 update_msg2 warn_msg1 warn_msg1b warn_msg1b warn_msg1c
  local base_ver_txt target_ver_txt file same_ver1 same_ver1b same_ver1c gls_url loc e_fail_prefix

  e_fail_prefix="${c_norm_prob}update() internal error: Failed to"
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
  if ! set_directives; then err_msg "$e_fail_prefix set a directive" && abort_msg && return 1; fi
  if ! download_latest; then abort_msg && return 1; fi
  if ! execute_directives; then abort_msg && return 1; fi

  # BEGIN: Update by deleting the old (orig) and coping over the new (target)

  # Latest files to copy from target (latest) to orig (current)
  local root_files=(".gitpod.yml" ".gitattributes" ".npmrc" ".gitignore")

  # Latest directories to copy from target (latest) to orig (current)
  local root_dirs=(".gp" ".vscode" ".github")

  for i in "${!root_files[@]}"; do
    if [[ -f ${root_files[$i]} ]]; then
      if ! rm "${root_files[$i]}"; then
        warn_msg "${c_norm_prob}Could not delete the file ${c_uri}.gp${c_e}\n\t$warn_msg1c"
      fi
    fi
  done

  [[ $gp_df_only_cache_buster_changed == no && -f .gitpod.Dockerfile ]] && rm .gitpod.Dockerfile

  # Remove the Theia configurations, see https://github.com/apolopena/gitpod-laravel-starter/issues/216
  [[ -d .theia ]] && rm -rf .theia

  if ! rm -rf .gp; then
    warn_msg "$warn_msg1\n\t$warn_msg1b"
  fi

  e1="${c_norm_prob}You will need to manually copy it from the repository: ${c_url}$gls_url${c_e}"

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

  echo -e "${c_s_bold}${c_pass}FINISHED:${c_norm_b} $update_msg1 $update_msg2"
  # END: Update by deleting the old (orig) and coping over the new (target)

  return 0
}

### load_get_deps ###
# Description:
# Downloads and sources dependencies $@
# using the base url: https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/
load_get_deps() {
  local get_deps_url="https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/get-deps.sh"

  if ! curl --head --silent --fail "$get_deps_url" &> /dev/null; then
    err_msg "Failed to load the loader from:\n\t$get_deps_url" && exit 1
  fi

  source \
  <(curl -fsSL "$get_deps_url" &)
  ec=$?;
  if [[ $ec != 0 ]] ; then echo -e "Failed to source the loader from:\n\t$get_deps_url"; exit 1; fi; wait;
}

### load_get_deps_locally ###
# Description:
# Sources dependencies $@ from the local file system relative to tools/lib
load_get_deps_locally() {
  local this_script_dir

  this_script_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
  if ! source "$this_script_dir/lib/get-deps.sh"; then
    "Failed to source the loader from the local file system:\n\t$get_deps_url"
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
# This function relies on lib/long-option.sh
# For more details see: https://github.com/apolopena/gls-tools/blob/main/tools/lib/long-option.sh
validate_long_options() {
  local failed options;

  if ! declare -f "list_long_options" > /dev/null; then
    echo -e "${c_norm_prob}Failed to validate options: list_long_options() does not exist${c_e}"
    return 1
  fi

  options="$(list_long_options)"

  for option in $options; do
    option=" ${option} "
    if [[ ! " ${global_supported_options[*]} " =~ $option ]]; then
        echo -e "${c_norm_prob}Unsupported long option: ${c_pass}$option${c_e}"
        failed=1
    fi
  done

  [[ -n $failed ]] && return 1 || return 0
}

### validate_arguments ###
# Description:
# Validate the scripts arguments
#
# NOte:
# Commands and short options are illegal. This functions handles them quick and dirty
validate_arguments() {
  local e_bad_opt e_bad_short_opt

  e_bad_short_opt="${c_norm_prob}Illegal short option:${c_e}"
  e_bad_opt="${c_norm_prob}Illegal option:${c_e}"

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

gls_installation_exists() {
  # v0.0.1 to v0.0.4 See: https://github.com/apolopena/gls-tools/issues/4
  [[ -d .theia && -d bash && -f .gitpod.yml && -f .gitpod.Dockerfile ]] && return 0

  # v1.0.0 - latest
  [[ -d .gp/bash && -f .gitpod.yml && -f .gitpod.Dockerfile ]] && return 0

  return 1
}

### help ###
# Description:
# Echoes the help text to stdout 
help() {
  echo -e "update-gls command line tool\n\t help TBD GOES HERE"
}

### init ###
# Description:
# Enables colors, validates all arguments passed to this script,
# sets long options and sets any global strings that need to be colorized
# A fancy header is written to stdout if this function succeeds ;)
#
# Returns 0 if successful, returns 1 if there are any errors
# Also returns 1 if an existing installation of gitpod-laravel-starter is not detected
#
# Note:
# This function can only be called once.
# Subsequent attempts to call this function will result in an error
init() {
  local arg gls e_not_installed e_long_options e_command nothing_m run_r_m run_l_m
  
  handle_colors

  gls="${c_pass}gitpod-laravel-starter${c_e}${c_norm_prob}"
  e_not_installed="${c_norm_prob}An existing installation of $gls is required but was not detected${c_e}"
  curl_m="bash <(curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/install.sh)"
  nothing_m="${c_norm_prob}Nothing to update\n\tTry installing $gls instead either"
  run_r_m="Run remotely: ${c_uri}$curl_m${c_e}"
  run_b_m="${c_norm_prob}Or if you have the gls binary installed run: ${c_file}gls install${c_e}"
  e_long_options="${c_norm_prob}Failed to set global long options${c_e}"
  e_command="${c_norm_prob}Unsupported Command:${c_e}"
  note_prefix="${c_file_name}Notice:${c_e}"

  if ! gls_installation_exists; then 
    err_msg "$e_not_installed\n\t$nothing_m\n\t$run_r_m\n\t$run_b_m"
    abort_msg
    return 1; 
  fi

  if ! set_long_options "${script_args[@]}"; then err_msg "$e_long_options" && abort_msg && return 1; fi
  if ! validate_long_options; then echo bad long options; abort_msg && return 1; fi
  if ! validate_arguments; then echo bad arguments; abort_msg && return 1; fi

  gls_header 'updater'
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
  while read -r dir_to_delete; do
    : "$dir_to_delete"
    #[[ -d $dir_to_delete ]] && rm -rf "$dir_to_delete"
  done 
}

### main ###
# Description:
# Main routine
# Order specific:
#   1. Set local aand global values
#   2. Load get-deps.sh, it contains get_deps() which is used to load the rest of the dependencies
#   3. Load the rest of the dependencies using get_deps()
#   3. Initialize: call init()
#   4. Update: call update(). Clean up if the update fails
#
# Note:
# Dependency loading is synchronous and happens on every invocation of the script.
# init() and update() cleanup after themselves
main() {
  local dependencies=('util.sh' 'color.sh' 'header.sh' 'spinner.sh' 'long-option.sh' 'directives.sh')
  local possible_option=() 
  local abort="update aborted"
  local ec

  # Set this global once and never touch it again
  script_args=("$@");

  # Process the --help directive first since it requires no dependencies to do so
  [[ " ${script_args[*]} " =~ " --help " ]] && help && exit 1

  # Load the loader (get-deps.sh)
  if printf '%s\n' "${script_args[@]}" | grep -Fxq -- "--load-deps-locally"; then
    possible_option=(--load-deps-locally)
    load_get_deps_locally
  else
    load_get_deps
  fi

  # Now that the loader is loader use it to load the rest of the dependencies
  if ! get_deps "${possible_option[@]}" "${dependencies[@]}"; then echo "$abort"; exit 1; fi

  # Initialize, update and cleanup
  if ! init; then exit 1; fi
  if ! update; then cleanup; exit 1; fi
  cleanup
}
# END: functions

main "$@"
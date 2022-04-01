#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# download.sh
#
# Description:
# Library for downloading apolopena/gitpod-laravel-starter data
#
# Required globals:
# The functions in this library require valid directories to work from
# See the Globals section and the comment header for each function for what is required

# BEGIN: Globals
# Satisfy shellcheck by defining the global variables this script requires but does not define
project_root=; target_dir=;
# Satisfy shellcheck by predefining the colors we use here. See lib/colors.sh
c_e=; c_norm=; c_norm_prob=; c_fail=; c_file_name=; c_url=; c_uri=; c_file=;


### download_release_json ###
# Description:
# Downloads the latest gitpod-laravel-starter release json data from github to a file ($1)
download_release_json() {
  local url="https://api.github.com/repos/apolopena/gitpod-laravel-starter/releases/latest"
  local err_pre="${c_file_name}lib/download.sh download_release_json() ${c_fail}error:${c_e}${c_norm_prob}"
  local msg="${c_norm}Downloading release data from:\n\t${c_url}$url${c_e}"

  [[ -z $1 ]] && echo -e "$err_pre missing required file argument" && return 1

  if declare -f "spinner_task" > /dev/null; then
    spinner_task "$msg" 'curl' --silent "$url" -o "$1" && echo
  else
    echo -e "$msg"
    if ! curl --silent "$url" -o "$1"; then
      echo -e "$err_pre failed to curl from\n\t${c_url}$url${c_norm_prob}\nto\n\t${c_uri}$1${c_e}"
      return 1
    fi
  fi
}

### install_latest_tarball ###
# Description:
# Downloads the tarball of the latest release of gitpod-laravel-starter and extracts it to $target_dir
# The download url is parsed from github latest release json data ($1)
# ($1) Should be the file downloaded by this libraries download_release_json() function
# If the optional argument --treat-as-unbuilt ($2) is passed in then $files_to_move will not be moved
# See the first line of this function for more details about the files moved
# Returns 0 if the parse, download and tar extraction were successful
# Returns 1 on any error and also returns 1 if:
#  The release json argument ($1) is empty or not a file
#  The global variable $target_dir is empty or not a directory
#  The global variable $project_root is empty or not a directory
#  A warn_msg() or err_msg() function does not exist
#  Cannot cd into $target_dir
#  Cannot cd from $target_dir to $project_root
#  
#
# Requires Globals
# $target_dir
# $project_root
#
# Note:
# It is assumed that this function is called from $project_root and that $target_dir is relative to it
# otherwise the cd commands will fail
# lib/spinner.sh will be used for downloads if a script the sources this script has sourced lib/spinner.sh
#
# Usage example:
#   #!/bin/bash
#   project_root="$(pwd)"
#   target_dir="$project_root/test_tmp_dir/latest"
#   json_file="$project_root/test_tmp_dir/latest_release.json"
#   mkdir -p "$target_dir"
#   if ! download_release_json "$json_file"; then exit; fi
#   if ! install_latest_tarball "$json_file"; then exit; fi
install_latest_tarball() {
  local files_to_move=("CHANGELOG.md" "LICENSE" "README.md")
  local start_spinner_exists stop_spinner_exists
  local e_pre e1 e2 e3 e4 e5 e6 e7 e8 e9 e10 e10b e11 url loc msg ec
  local release_json="$1"
  
  e_pre="${c_file_name}lib/download.sh install_latest_tarball() ${c_fail}error:${c_e}"
  w_pre="${c_file_name}lib/download.sh install_latest_tarball() ${c_fail}warning:${c_e}"
  e1="${c_norm_prob}cannot download/extract latest gls tarball${c_e}"
  e2="${c_norm_prob}unable to parse the tarball url from\n\t${c_uri}$release_json${c_e}"
  e3="${c_norm_prob}missing required file argument${c_e}"
  e4="${c_norm_prob}missing required global variable \$project_root${c_e}"
  e5="${c_norm_prob}required global variable \$project_root is not a directory:${c_e}"
  e6="${c_norm_prob}missing required global variable \$target_dir${c_e}"
  e7="${c_norm_prob}required global variable \$target_dir is not a directory:${c_e}"
  e8="${c_norm_prob}failed to ${c_file}cd${c_e}${c_norm_prob} into ${c_uri}$target_dir${c_e}"
  e9="${c_norm_prob}failed to ${c_file}cd${c_e}${c_norm_prob} from \$target_dir to \$project_root${c_e}"
  e10="${c_norm_prob}either the ${c_file}curl${c_e}${c_norm_prob} or the"
  e10b="${c_file}cd${c_e}${c_norm_prob} command failed${c_e}"
  e11="${c_norm_prob}illegal option ${c_file}$2${c_e}"

  [[ -n $2 && $2 != '--treat-as-unbuilt' ]] && echo -e "$e_pre\n\t$e1\n\t$e11" && return 1
  [[ -z $release_json ]] && echo -e "$e_pre\n\t$e1\n\t$e3" && return 1
  [[ -z ${project_root} ]] && echo -e "$e_pre\n\t$e1\n\t$e4" && return 1
  [[ ! -d ${project_root} ]] && echo -e "$e_pre\n\t$e1\n\t$e5" && return 1
  [[ -z ${target_dir} ]] && echo -e "$e_pre\n\t$e1\n\t$e6" && return 1
  [[ ! -d ${target_dir} ]] && echo -e "$e_pre\n\t$e1\n\t$e7" && return 1
  
  url="$(sed -n '/tarball_url/p' "$release_json" | grep -o '"https.*"' | tr -d '"')"
  [[ -z $url ]] && echo -e "$e_pre\n\t$e1\n\t$e2" && return 1
  
  if ! cd "$target_dir";then
    echo -e "$e_pre\n\t$e1\n\t$e8"
    return 1
  fi

  # Download and extract the latest release tarball
  start_spinner_exists="$(declare -f "start_spinner_exists" > /dev/null)"
  stop_spinner_exists="$(declare -f "stop_spinner_exists" > /dev/null)"
  msg="${c_norm}Downloading and extracting latest release tarball from:\n\t${c_url}$url${c_e}"
  if [[ $start_spinner_exists -eq 0 && $stop_spinner_exists -eq 0 ]]; then
    start_spinner "$msg" && curl -sL "$url" | tar xz --strip=1
    ec=$?
    if [[ $ec -eq 0 ]]; then
      stop_spinner 0
      echo
    else
      stop_spinner 1
      echo -e "$e_pre\n\t$e1\n\t$e10 $e10b"
      return 1
    fi
  else
    if ! curl -sL "$url" | tar xz --strip=1; then
      echo -e "$e_pre\n\t$e1\n\t$e10 $e10b"
      return 1
    fi
  fi
  
  # Move the files that gitpod laravel starter moves once a project is built
  # Only do this if the --treat-as-unbuilt option is passed to this function as $2
  if [[ -z $2 ]]; then
    for i in "${!files_to_move[@]}"; do
    loc="$target_dir/${files_to_move[$i]}"
    loc2="$target_dir/.gp/${files_to_move[$i]}"
      if [[ -f $loc ]]; then
        if ! mv "$loc" "$loc2"; then
          msg="${c_norm_prob}Could not move the file\n\t${c_uri}${loc}${c_e}\n\t${c_norm_prob}to"
          echo -e "$w_pre\n\t$msg\n\t${c_uri}${loc2}${c_e}"
        fi
      fi
    done
  fi

  if ! cd "$project_root"; then
    echo -e "$e_pre\n\t$e1\n\t$e9"
    return 1
  fi
}
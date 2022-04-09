#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# download.sh
#
# Description:
# Recursively finds all .sh files from the current working directory, runs them through shellcheck
# and outputs a simple success summary or just the standard output if shellcheck finds anything 
# that needs attention. 
#
# Note:
# If you run this script outside of Gitpod:
# To ensure all .sh files in the project are linted, make sure you run this script from the project root


path() {
  [[ -z $GITPOD_REPO_ROOT ]] && GITPOD_REPO_ROOT="$(pwd)"
  echo "$GITPOD_REPO_ROOT"
}

list_all_scripts() {
  find "$(path)" -type d \( -name node_modules \) -prune -false -o -name "*.sh"
}

script_total() {
  list_all_scripts | wc -l
}

main() {
  local total result exclude_msg exclude=(-e SC2119)
  if ! command -v rsync > /dev/null; then
    echo "lint.sh requires shellcheck. Install it and try again."
    return 1
  fi
  
  total=$(script_total)

  if [[ $1 == '-V' || $1 == '--verbose' ]]; then
    echo -e "\e[38;5;76mFound\e[0;36m $total\e[0m\e[38;5;40m scripts relative to $(pwd).\nRunning them through shellcheck now\e[0m"
    echo -ne "\e[38;5;45m"
    list_all_scripts;  echo -ne "\e[0m"
  fi

  (( total == 0 )) && echo -e "\e[38;5;124mInternal Error:\e[0m no scripts found to lint" && exit 1
  if [[ ! -e $(pwd)/tools ]]; then
    exclude_msg="\e[38;5;208mWARNING: You did not lint the starter scripts from the project root so the shellcheck error \e[0mSC1091\e[38;5;208m was excluded.\e[0m"
    exclude+=(-e SC1091)
  fi
  result=$(find "$(path)" -type d \( -name node_modules \) -prune -false -o -name "*.sh" -exec shellcheck -x -P "$(path)" "${exclude[@]}" {} \; | tee >(wc -l))
  if [[ $result == 0 ]]; then
    [[ -n $exclude_msg ]] && echo -e "$exclude_msg"
    echo -e "\e[38;5;76mSUCCESS:\e[0m \e[38;5;40mall \e[0;36m$total\e[0m \e[38;5;40mscripts in the system passed the shellcheck.\e[0m"
    exit
  fi
  find "$(path)" -type d \( -name node_modules \) -prune -false -o -name "*.sh" -exec shellcheck -x -P "$(path)" "${exclude[@]}" {} \;
  [[ -n $exclude_msg ]] && echo -e "$exclude_msg"
}

main "$1"
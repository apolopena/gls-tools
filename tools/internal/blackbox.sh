#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# blackbox.sh
#
# Description:
# Installer and uninstaller for gitpod-laravel-starter
# Blackbox testing tool for installing, uninstalling and analyzing gitpod-laravel-starter projects
#
# Note:
# The script requires the first argument to be the 'gls' command and then any supported sub command
# routine will be called.
# Supported options should be last after the command and all other sub command
# Only long options are supported which are the following:
# --use-version-stub: stubs the tags json file 
# --treat-as-unbuilt:
#           Omits the moving of the below files to the .gp folder if they exist:
#           CHANGELOG.md, README.md, LICENSE

script="$(basename "${BASH_SOURCE[0]}")"
script_args=("$@")
long_options=()
github_api_url="https://api.github.com/repos/apolopena/gitpod-laravel-starter"

# Set by the init routine
declare -A tarball_urls=()
versions=()

has_script_arg() {
  printf '%s\n' "${script_args[@]}" | grep -Fxq -- "$1"
}

has_option() {
  printf '%s\n' "${long_options[@]}" | grep -Fxq -- "$1"
}

### is_long_option ###
# Returns 0 if $1:
# Starts with double dashes followed by any number of uppercase or lowercase letters or integers
# optionally followed by zero or more sets of a single dash that must be accompanied 
# by any number uppercase or lowercase letters
# Returns 1 otherwise
is_long_option() {
  [[ $1 =~ ^--[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]] && return 0 || return 1
}

init() {
  local supported_options=(
    --use-version-stub
    --treat-as-unbuilt
    --strict
    --load-deps-locally
    --no-colors
  )
  local version urls url ver_regex arg
  ver_regex='([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)?'

  # Disable POSIX mode if enabled so we get the behavior we expect for builtins such as mapfile
  case :$SHELLOPTS: in
    *:posix:*) set +o posix; echo "POSIX mode was disabled" ;;
  esac
  
  # Gather options from the script arguments
  # if it is not a valid long option or a supported option then exit with error
  for (( i=0; i<${#script_args[@]}; i++ )); do
    arg="${script_args[i]}"
    if [[ $arg =~ ^- ]]; then 
      if ! is_long_option "$arg"; then echo "invalid long option: $arg" && return 1; fi
      if ! printf '%s\n' "${supported_options[@]}" | grep -Fxq -- "$arg"; then
        echo "unsupported option: $arg" && return 1
      fi 
      long_options[$i]="$arg"
    fi
    done

  # Populate the tarball_urls associative array with the tarball urls of all releases using the 
  # version number as the key. Assume that all releases are github tags with the pattern: vX+.X+.X+
  # where X+ is any number of digits.
  # If a --use-version-stub argument exists then use a hardcoded stub rather than downloading the tag data
  if ! has_option '--use-version-stub'; then
    mapfile -t urls < <(curl $github_api_url/tags 2>&1 | grep 'tarball_url')
  else
    echo "Using a hardcoded version stub, version data is NOT live."
    mapfile -t urls < <(version_stub)
  fi
  for (( i=0; i<${#urls[@]}; i++ )); do
    version="$(echo "${urls[$i]}" | grep -oE "$ver_regex")"
    versions[$i]="$version"
    url="$(echo "${urls[$i]}" | grep -oE 'https.*"')"
    url="${url::-1}"
    [[ $version =~ $ver_regex ]] && tarball_urls[$version]="$url"
  done
  # Uncomment to print the contents of the tarball_urls array
  #for x in "${!tarball_urls[@]}"; do printf "[%s]=%s\n" "$x" "${tarball_urls[$x]}" ; done
}

version_stub() {
  echo -e '\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.3.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.4",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.3",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.2",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v0.0.1a",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.0.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.1.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.5.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.4.0",
\t"tarball_url": "https://api.github.com/repos/apolopena/gitpod-laravel-starter/tarball/refs/tags/v1.2.0",'
}

version_exists() {
  [[ ${tarball_urls["$1"]+exists} ]] && return 0
  return 1
}

move_metafiles() {
  [[ ! -d .gp ]] && return 0
  for m in 'CHANGELOG.md' 'README.md' 'LICENSE'; do
    if ! mv "$m" ".gp/$m"; then echo "Failed to move metafile $m to .gp/$m"; fi
  done
  return 0
}

prompt_y_n() {
  local question="$1 (y/n)? "
    while true; do
      read -rp "$( echo -e "$question")" input
      case $input in
        [Yy]* ) break;;
        [Nn]* ) return 1;;
        * ) echo -e "Please answer y for yes or n for no.";;
      esac
    done
}

new_sandbox() {
  local s

  if [[ -z $2 ]]; then s='sandbox'; else s="$2"; fi

  [[ $(basename "$(pwd)") == "$s" ]] \
  && echo "cannot create a new sandbox from within the sandbox" \
  && echo "move up a directory and run the script again" \
  && return 1

  if [[ -d $s ]]; then
    rm -rf "$s"
  fi

  mkdir "$s"

  if ! cd "$s"; then echo "could not cd into $(pwd)/$s" && return 1; fi
  
  install "$1"
}

install() {
  local msg

  [[ -z $1 ]] && echo "the install command requires a version number argument" && return 1
  if ! version_exists "$1"; then echo "gitpod-laravel-starter version $1 does not exist" && return 1; fi
  
  url="${tarball_urls[$1]}"
  msg="Downloading and extracting gitpod-laravel-starter release v$1"
  echo -e "$msg"

  if ! curl -sL "$url" | tar xz --strip=1; then
    echo -e "$script Error: $msg from $url"
    return 1
  fi

  # Moving the files that gitpod laravel starter would have moved if the project was already built
  if ! has_option '--treat-as-unbuilt'; then move_metafiles; fi

  echo -e "SUCCESS: gitpod-laravel-starter v$1 has been installed to $(pwd)"
}

new_tool_boilerplate() {
  local input dest src="tools/internal/boilerplate.sh"

  if [[ ! -d tools && ! -d tools/internal && ! -f $src ]]; then
    echo "this script can only be run from the root of the gls-tools repository"
    echo "could not find the required file $src"
    return 1
  fi

  if [[ -z $1 ]]; then
    while true; do
      read -rp "$( echo -en "Enter the name of tool you want to create boilerplate code for or Q to quit: ")" input
      dest="$(pwd)/tools/$input.sh"
      if [[ -f $dest ]]; then
        echo "The tool $input.sh already exists at: $dest"
      elif [[ $input == 'q' || $input == 'Q' ]]; then
        echo "command aborted by user";
        exit
      else
       break;
      fi
    done
  else
    dest="$(pwd)/tools/$1.sh"
    [[ -f $dest ]] && echo "The tool $1.sh already exists at: $dest" && exit 1
    input="$1"
  fi

  if sed "s/REPLACE_WITH_SCRIPT_NAME/$input/" "$src" > "$dest"; then
    echo -e "SUCCESS: Boilerplate code for the new tool $input.sh has been created at:\n$dest"
    exit
  fi

  echo "failed to parse $src"
  return 1
}

new() {
  local msg1 msg2 msg3="To see a list of valid gls versions run: gls version-list"

  [[ -z $1 ]] && echo "the new subommand requires an additional subcommand argument" && return 1

  case $1 in 
    sandbox | control-sandbox)
      [[ -z $2 ]] && echo "the $1 command requires a version argument" && return 1
      if ! version_exists "$2"; then 
        echo "$1 command requires a valid gls version. Not $2"
        echo "$msg3"
        return 1
      fi
      if prompt_y_n "Creating a new $1 will delete any existing $1.\n\tProceed"; then
        [[ $1 == 'sandbox' ]] && if new_sandbox "$2"; then return 0; else return 1; fi
        if new_sandbox "$2" "control_sandbox_v$2"; then return 0; fi
      fi
      echo "Command '$1' aborted by user" && exit 1
    ;;

    'double-sandbox')
      msg1="the $1 command requires two version arguments,"
      msg2="\$1: sandbox version, \$2: control sandbox version"
      [[ -z $2 || -z $3 ]] && echo -e "$msg1\n\t$msg2" && return 1
      if is_long_option "$2"; then echo -e "$msg1\n\t$msg2" && return 1; fi
      if is_long_option "$3"; then echo -e "$msg1\n\t$msg2" && return 1; fi

      msg1="the $1 command requires a valid gls version for the sandbox. Not $2"
      msg2="the $1 command requires a valid gls version for the control sandbox. Not $2"
      if ! version_exists "$2"; then echo -e "$msg1\n$msg3"; return 1; fi
      if ! version_exists "$3"; then echo -e "$msg2\n$msg3"; return 1; fi

      msg1="creating a new $1 will delete any existing sandbox and the control sandbox for v$3."
      if prompt_y_n "$msg1\n\tProceed"; then
        if new_sandbox "$2"; then
          cd .. || return 1
          if new_sandbox "$3" "control_sandbox_v$3"; then return 0; fi
          echo "failed to create control sandbox for v$3"
          return 1
        fi
        echo "failed to create sandbox for v$2"
        return 1
      fi
      echo "Command '$1' aborted by user"
    ;;

    'tool')
      [[ -n $3 ]] && echo "invalid command chain: $*" && exit 1
      if ! new_tool_boilerplate "$2"; then return 1; fi
    ;;

    *)
      echo "unsupported new sub command: $1"
    ;;
  esac
}


gls() {
  if ! init; then echo "$script internal error: Initialization failed"; exit 1; fi
  
  case "${script_args[1]}" in 
    'install')
      if ! install "${script_args[2]}"; then 
        echo "$script error: failed to install gitpod-laravel-starter release version ${script_args[2]}"
      fi
    ;;

    'install-latest')
      if ! install "${versions[0]}"; then
        echo "$script error: failed to install latest version of gitpod-laravel-starter ${versions[0]}"
      fi
    ;;

    'latest-version')
      echo "${versions[0]}"
    ;;

    'version-list')
      printf '%s\n' "${versions[@]}"
    ;;

    'new')
      if ! new "${script_args[2]}" "${script_args[3]}" "${script_args[4]}"; then 
        echo "error: new subcommand failed";
      fi
    ;;

    'test-update')
      local ver_regex='^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$'
      [[ $(basename "$(pwd)") == 'sandbox' ]] && echo "You cannot be in the sandbox. Try cd .. first." && exit 1
      [[ -z $2 ]] && echo "test-update-locally requires a version argument" && exit 1
      [[ ! $2 =~ $ver_regex ]] && echo -e "bad version arg: $2\nverion argument must be first" && exit 1
      local ver="$2"; shift; shift
      bash tools/internal/blackbox.sh gls new sandbox "$ver" && cd sandbox && bash ../tools/update.sh "$@"
    ;;

    *)
      echo "gls sub command not found: ${script_args[1]}"
    ;;
  esac
  
}

[[ -z $1 ]] && echo "$script cannot be run without a command" && exit 1
[[ $1 != 'gls' ]] && echo "$script only supports the gls command" && exit 1

# Call functions from this script gracefully
if declare -f "$1" > /dev/null; then
  # call arguments verbatim
  "$@"
else
  echo "$script: '$1' is not a known function name" >&2
  exit 1
fi

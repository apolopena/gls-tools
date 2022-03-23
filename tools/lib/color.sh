#!/bin/bash
# shellcheck disable=SC2034 # Ignore all unused variables
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# color.sh
#
# Description:
# Barebones, opinionated color support for shellscripts.
#
# Example usage:
# 
# init() {
#   source <(curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/lib/colors.sh)
#   if ! handle_colors; then echo "Failed to implement terminal colors"; fi
# }
# if ! init; then exit 1; fi
# echo -e "${c_pass}SUCCESS: ${c_norm}colors.sh implemented${c_e}"


### supports_truecolor ###
# Description:
# returns 0 if the terminal supports truecolor and retuns 1 otherwise
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

c_e='\e[0m' # Reset 
c_s_bold='\033[1m' # Bold style
# c_1 --> RGB Bright Red or fallback to ANSI 256 Red (Red3)
if supports_truecolor; then c_1="\e[38;2;255;25;38m"; else c_1='\e[38;5;160m'; fi
c_2='\e[38;5;208m' # Bright Orange (DarkOrange)
c_3='\e[38;5;76m' # Army Green (Chartreuse3)
c_4='\e[38;5;147m' # Lavendar (LightSteelBlue)
c_5='\e[38;5;213m' # Hot Pink (Orchid1)#
# c_6 --> RGB Cornflower Lime or fallback to ANSI 256 Yellow3
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

# BEGIN: Functions

### use_color ###
# Description: Flag function for determining when to use colors.
# returns 0 if stdout is a terminal, returns 1 otherwise
if [[ ! -t 1 ]]; then
  use_color() {
    false
  }
else
  use_color() {
    true
  }
fi

###  ###
# Description:
# Sets the global colors
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

###  ###
# Description:
# Clears all color values
remove_colors() {
  # clear all global colors
  for i in {1..16}; do eval "c_$i="; done

  # Clear all set colors
  c_e=; c_s_bold=; c_norm=; c_norm_b=; c_norm_prob=; c_pass=; c_warn=; c_warn2=; c_fail=; c_file=;
  c_file_name=; c_url=; c_uri=; c_number=; c_choice=; c_prompt=;
}

###  ###
# Description:
# Sets color values if stdout is a terminal.
# Color values are cleared out if this script is piped or redirected
handle_colors() {
  if use_color; then set_colors; else remove_colors; fi
}


# END: Functions
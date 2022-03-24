#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# header.sh
#
# Requires:
# Bash version >= 4
#
# Description:
# Fancy ANSI 256 colorized headers for gls tools with matching footer ($1)
# Supported footers are: installer, uninstaller and updater
# Unsupported footers will not display when stdin is a terminal (color)
#
# Note:
# Colors are omitted if stdin is not a terminal 
# All footers will be bumped to uppercase
# Pass no arguments if you want ensure that in all situations you get a header with no footer in it
#
# Example usage:
# . header.sh && gls_header 'installer'


### no_color ###
# Description: Internal Flag function for determining when to use colors.
# returns 0 if stdout is a terminal, returns 1 otherwise
if [[ ! -t 1 ]]; then
  _use_color() {
    false
  }
else
  _use_color() {
    true
  }
fi

### gls_label ###
# Description:
# Echoes: gitpod-laravel-starter ($1)
# Either ANSI 256 colors are used if stdin is a terminal or plain text otherwise
# ($1) is displayed only if it is supported or stdin is not a terminal
gls_label() {
  local label="    [38;5;83mg[0m[38;5;83mi[0m[38;5;83mt[0m[38;5;118mp[0m[38;5;118mo[0m[38;5;118md[0m[38;5;118m-[0m[38;5;118ml[0m[38;5;118ma[0m[38;5;118mr[0m[38;5;154ma[0m[38;5;154mv[0m[38;5;154me[0m[38;5;154ml[0m[38;5;154m-[0m[38;5;154ms[0m[38;5;148mt[0m[38;5;184ma[0m[38;5;184mr[0m[38;5;184mt[0m[38;5;184me[0m[38;5;184mr[0m"
  if ! _use_color; then echo -n "gitpod-laravel-starter ${1^^}"; return 0; fi
  [[ $1 == installer ]] && label="[38;5;83mg[0m[38;5;83mi[0m[38;5;83mt[0m[38;5;118mp[0m[38;5;118mo[0m[38;5;118md[0m[38;5;118m-[0m[38;5;118ml[0m[38;5;118ma[0m[38;5;118mr[0m[38;5;154ma[0m[38;5;154mv[0m[38;5;154me[0m[38;5;154ml[0m[38;5;154m-[0m[38;5;154ms[0m[38;5;148mt[0m[38;5;184ma[0m[38;5;184mr[0m[38;5;184mt[0m[38;5;184me[0m[38;5;184mr[0m[38;5;184m [0m[38;5;184mI[0m[38;5;184mN[0m[38;5;214mS[0m[38;5;214mT[0m[38;5;214mA[0m[38;5;214mL[0m[38;5;214mL[0m[38;5;214mE[0m[38;5;214mR[0m"
  [[ $1 == uninstaller ]] && label="[38;5;83mg[0m[38;5;83mi[0m[38;5;83mt[0m[38;5;118mp[0m[38;5;118mo[0m[38;5;118md[0m[38;5;118m-[0m[38;5;118ml[0m[38;5;118ma[0m[38;5;118mr[0m[38;5;154ma[0m[38;5;154mv[0m[38;5;154me[0m[38;5;154ml[0m[38;5;154m-[0m[38;5;154ms[0m[38;5;148mt[0m[38;5;184ma[0m[38;5;184mr[0m[38;5;184mt[0m[38;5;184me[0m[38;5;184mr[0m[38;5;184m [0m[38;5;184mU[0m[38;5;184mN[0m[38;5;214mI[0m[38;5;214mN[0m[38;5;214mS[0m[38;5;214mT[0m[38;5;214mA[0m[38;5;214mL[0m[38;5;214mL[0m[38;5;208mE[0m[38;5;208mR[0m"
  [[ $1 == updater ]] && label="[38;5;83mg[0m[38;5;83mi[0m[38;5;83mt[0m[38;5;118mp[0m[38;5;118mo[0m[38;5;118md[0m[38;5;118m-[0m[38;5;118ml[0m[38;5;118ma[0m[38;5;118mr[0m[38;5;154ma[0m[38;5;154mv[0m[38;5;154me[0m[38;5;154ml[0m[38;5;154m-[0m[38;5;154ms[0m[38;5;148mt[0m[38;5;184ma[0m[38;5;184mr[0m[38;5;184mt[0m[38;5;184me[0m[38;5;184mr[0m[38;5;184m [0m[38;5;184mU[0m[38;5;184mP[0m[38;5;214mD[0m[38;5;214mA[0m[38;5;214mT[0m[38;5;214mE[0m[38;5;214mR[0m"
  echo -en "$label"
}

### gls_header ###
# Description:
# Echoes a fancy header with a footer ($1) if the footer is supported.
# See the gls_header() function for supported footers.
# Either ANSI 256 colors are used if stdin is a terminal or plain text otherwise
# The footer ($1) is displayed only if stdin is not a terminal
gls_header() {
  local header footer
  footer="$(gls_label "$1")"

  if _use_color; then
    header="[38;5;118m [0m[38;5;118m [0m[38;5;118m_[0m[38;5;118m_[0m[38;5;118m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m.[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;148m_[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;178m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m
[38;5;118m [0m[38;5;118m/[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m/[0m[38;5;154m|[0m[38;5;148m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m/[0m[38;5;184m [0m[38;5;184m [0m[38;5;178m [0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m/[0m
[38;5;154m/[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m [0m[38;5;154m\[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m_[0m[38;5;148m_[0m[38;5;184m_[0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;178m\[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;214m [0m[38;5;214m\[0m[38;5;214m [0m
[38;5;154m\[0m[38;5;154m [0m[38;5;154m [0m[38;5;154m [0m[38;5;154m [0m[38;5;148m\[0m[38;5;184m_[0m[38;5;184m\[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m_[0m[38;5;178m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;214m/[0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m\[0m
[38;5;154m [0m[38;5;154m\[0m[38;5;148m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m|[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;178m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;214m/[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;208m_[0m[38;5;208m_[0m[38;5;208m_[0m[38;5;208m [0m[38;5;208m [0m[38;5;208m/[0m
[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;184m\[0m[38;5;184m/[0m[38;5;184m [0m[38;5;178m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m\[0m[38;5;214m/[0m[38;5;214m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m\[0m[38;5;208m/[0m[38;5;208m [0m
"
  else
    # shellcheck disable=SC1004 # Allow backslashes in a literal
    header='
  ________.____      _________
 /  _____/|    |    /   _____/
/   \  ___|    |    \_____  \ 
\    \_\  |    |___ /        \
 \______  |_______ /_______  /
        \/        \/       \/ 
'
  fi

  echo -e "$header\n$footer\n"
}
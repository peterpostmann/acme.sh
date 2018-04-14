#!/usr/bin/env sh

#
# Hosteurope API
#
# Author: Peter Postmann
# Report Bugs here: https://github.com/peterpostmann/acme.sh
# --
#
# Pass credentials before "acme.sh --issue --dns dns_hosteurope ..."
# --
# export HOSTEUROPE_Username="username"
# export HOSTEUROPE_Password="password"
# --

HOSTEUROPE_Api="https://kis.hosteurope.de/administration/domainservices/index.php?menu=2&mode=autodns"

########  Public functions #####################

# Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_hosteurope_add() {
  fulldomain="$1"
  txtvalue="$2"

  HOSTEUROPE_Username="${HOSTEUROPE_Username:-$(_readaccountconf_mutable HOSTEUROPE_Username)}"
  HOSTEUROPE_Password="${HOSTEUROPE_Password:-$(_readaccountconf_mutable HOSTEUROPE_Password)}"
  if [ -z "$HOSTEUROPE_Username" ] || [ -z "$HOSTEUROPE_Password" ]; then
    HOSTEUROPE_Username=""
    HOSTEUROPE_Password=""
    _err "You don't specify hosteurope username and password."
    return 1
  fi

  #save the credentials to the account conf file.
  _saveaccountconf_mutable HOSTEUROPE_Username  "$HOSTEUROPE_Username"
  _saveaccountconf_mutable HOSTEUROPE_Password  "$HOSTEUROPE_Password"
  
  _debug "detect the root zone"
  if ! _get_root "$fulldomain"; then
    return 1
  fi

  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _debug "add txt record"
  _hosteurope_get "&submode=edit&domain=$_domain&hostadd=$_sub_domain&record=11&pointeradd=$txtvalue&truemode=host&action=add&submit=Neu+anlegen&dubnachfrage=1"
}

# Usage: fulldomain txtvalue
dns_hosteurope_rm() {
  fulldomain="$1"
  txtvalue="$2"

  HOSTEUROPE_Username="${HOSTEUROPE_Username:-$(_readaccountconf_mutable HOSTEUROPE_Username)}"
  HOSTEUROPE_Password="${HOSTEUROPE_Password:-$(_readaccountconf_mutable HOSTEUROPE_Password)}"
  if [ -z "$HOSTEUROPE_Username" ] || [ -z "$HOSTEUROPE_Password" ]; then
    HOSTEUROPE_Username=""
    HOSTEUROPE_Password=""
    _err "You don't specify hosteurope username and password."
    return 1
  fi

  _debug "detect the root zone"
  if ! _get_root "$fulldomain"; then
    return 1
  fi

  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _debug "get records"    
  
  _hosteurope_get "&submode=edit&domain=$_domain"
  _hostid="$(echo "$response" | grep -a -A 50 "$txtvalue" | grep -m 1 "hostid" | grep -o 'value="[^"]*' | grep -o '[^"]*$')"
  _debug _hostid "$_hostid"

  if [ -z "$_hostid" ] ; then
    _err "record not found"
    return 1
  fi

  _debug "rm txt record"
  _hosteurope_get "&submode=edit&domain=$_domain&hostadd=$_sub_domain&record=11&pointer=$txtvalue&submit=L%F6schen&truemode=host&hostid=$_hostid&nachfrage=1"
}

####################  Private functions below ##################################

#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
_get_root() {
  domain=$1

  if ! _hosteurope_get ''; then
    return 1
  fi

  _domains=$(echo "$response" | grep -a -o 'value="edit"><input type="hidden" name="domain" value="[^"]*' | grep -o '[^"]*$')
  _debug2 domains "$_domains"

  for _d in $_domains; do
    if echo "$domain" | grep "$_d$" > /dev/null; then
        _domain="$_d"
        _sub_domain="$(echo "$domain" | sed "s/$_d$//g" | sed "s/\\.$//g")"
        return 0
    fi
  done

  _err "invalid domain"

  return 1
}

_hosteurope_get() {
  ep="$1"
  _debug "$ep"

  kdnummer="$(printf '%s' "$HOSTEUROPE_Username" | _url_encode)"
  passwd="$(printf '%s' "$HOSTEUROPE_Password" | _url_encode)"
  url="$HOSTEUROPE_Api&kdnummer=$kdnummer&passwd=$passwd"

  response="$(_get "${url}${ep}")"
  res="$?"
  _debug2 response "$response"

  if [ "$res" != "0" ]; then
    _err "error $ep"
    return 1
  fi

  if echo "$response" | grep "<title>KIS Login</title>" > /dev/null; then
    _err "Invalid Credentials"
    return 1
  fi

  if echo "$response" | grep "FEHLER" > /dev/null; then
    _err "$(_hosteurope_result "$response" "FEHLER")"
    return 1
  fi

  if echo "$response" | grep "INFO" > /dev/null; then
    _info "$(_hosteurope_result "$response" "INFO")"
  fi

  return 0
}

_hosteurope_result() {
    echo "$1" |  grep -a -A 10 "$2" | grep -a "<li>" | sed 's/^\s*<li>//g' | sed 's/<\/li>*$//g'
}
#!/bin/sh
# Cowboy Bebop branding; only print on interactive shells.
[ -n "${COWBOY_BEBOP_NO_BRAND:-}" ] && return 0
[ -t 0 ] || return 0
[ -t 1 ] || return 0
case "${-}" in *i*) ;; *) return 0 ;; esac
[ -r /etc/config/cowboy-bebop ] || return 0

_cb_enabled="$(uci -q get cowboy-bebop.main.enabled 2>/dev/null)"
_cb_tun="down"
[ -d /sys/class/net/tun0 ] && _cb_tun="up"

case "$_cb_enabled" in
  1|yes|true) _cb_proxy="ON" ;;
  *) _cb_proxy="OFF" ;;
esac

# Starting sing-box just to read its version is slow on a router; cache it
# in RAM until the binary changes.
_cb_version="unknown"
_cb_bin="$(command -v sing-box 2>/dev/null)"
if [ -n "$_cb_bin" ]; then
	_cb_cache=/tmp/run/cowboy-bebop-singbox-version
	if [ -s "$_cb_cache" ] && [ "$_cb_cache" -nt "$_cb_bin" ]; then
		read -r _cb_version < "$_cb_cache"
	else
		_cb_version="$(sing-box version 2>/dev/null | sed -n '1s/.*version[[:space:]]*//p')"
		[ -n "$_cb_version" ] || _cb_version="unknown"
		mkdir -p /tmp/run 2>/dev/null && printf '%s\n' "$_cb_version" > "$_cb_cache" 2>/dev/null
	fi
	unset _cb_cache
fi
unset _cb_bin

if [ -n "${NO_COLOR:-}" ]; then
  printf 'Cowboy Bebop | proxy: %s | TUN: %s | sing-box: %s\n' "$_cb_proxy" "$_cb_tun" "$_cb_version"
  PS1='\u@cowboy-bebop:\w# '
else
  printf '\033[1;33mCowboy Bebop\033[0m | proxy: %s | TUN: %s | sing-box: %s\n' "$_cb_proxy" "$_cb_tun" "$_cb_version"
  _cb_yellow="$(printf '\033[1;33m')"
  _cb_cyan="$(printf '\033[1;36m')"
  _cb_reset="$(printf '\033[0m')"
  PS1="${_cb_yellow}\u@cowboy-bebop${_cb_reset}:${_cb_cyan}\w${_cb_reset}# "
  unset _cb_yellow _cb_cyan _cb_reset
fi
unset _cb_enabled _cb_tun _cb_proxy _cb_version

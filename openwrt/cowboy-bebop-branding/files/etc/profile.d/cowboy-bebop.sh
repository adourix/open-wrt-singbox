#!/bin/sh
# Cowboy Bebop branding; only print on interactive shells.
[ -n "${COWBOY_BEBOP_NO_BRAND:-}" ] && return 0
[ -t 0 ] || return 0
[ -t 1 ] || return 0
case "${-}" in *i*) ;; *) return 0 ;; esac
[ -r /etc/config/cowboy-bebop ] || return 0

_cb_enabled="$(uci -q get cowboy-bebop.main.enabled 2>/dev/null)"
_cb_tun="down"
[ -d /sys/class/net/singtun0 ] && _cb_tun="up"

case "$_cb_enabled" in
  1|yes|true) _cb_proxy="ON" ;;
  *) _cb_proxy="OFF" ;;
esac

_cb_version="unknown"
if command -v sing-box >/dev/null 2>&1; then
	_cb_version="$(sing-box version 2>/dev/null | sed -n '1s/.*version[[:space:]]*//p')"
	[ -n "$_cb_version" ] || _cb_version="unknown"
fi

if [ -n "${NO_COLOR:-}" ]; then
  printf 'Cowboy Bebop | proxy: %s | TUN: %s | sing-box: %s\n' "$_cb_proxy" "$_cb_tun" "$_cb_version"
else
  printf '\033[1;33mCowboy Bebop\033[0m | proxy: %s | TUN: %s | sing-box: %s\n' "$_cb_proxy" "$_cb_tun" "$_cb_version"
fi
unset _cb_enabled _cb_tun _cb_proxy _cb_version

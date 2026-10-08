#!/bin/sh
# Cowboy Bebop branding; only print on interactive shells.
[ -n "${COWBOY_BEBOP_NO_BRAND:-}" ] && return 0
[ -n "${NO_COLOR:-}" ] && _cb_plain=1
[ -t 1 ] || return 0
case "${-}" in *i*) ;; *) return 0 ;; esac
[ -r /etc/config/cowboy-bebop ] || return 0

_cb_enabled="$(uci -q get cowboy-bebop.main.enabled 2>/dev/null)"
_cb_tun="down"
[ -d /sys/class/net/singtun0 ] && _cb_tun="up"

case "$_cb_enabled" in
  1|yes|true) _cb_proxy="enabled" ;;
  *) _cb_proxy="disabled" ;;
esac

if [ -n "${_cb_plain:-}" ]; then
  printf 'Cowboy Bebop | proxy: %s | TUN: %s\n' "$_cb_proxy" "$_cb_tun"
else
  printf '\033[1;33mCowboy Bebop\033[0m | proxy: %s | TUN: %s\n' "$_cb_proxy" "$_cb_tun"
fi
unset _cb_enabled _cb_tun _cb_proxy _cb_plain

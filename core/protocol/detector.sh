#!/bin/sh

# Detect a supported proxy URL scheme.
# stdout: vmess | vless
# exit 0 on supported protocol, 1 on unsupported/invalid input.

detect_protocol() {
    url=$1

    case "$url" in
        vmess://*) printf '%s\n' "vmess" ;;
        vless://*) printf '%s\n' "vless" ;;
        *) return 1 ;;
    esac
}

if [ "${0##*/}" = "detector.sh" ] && [ "$#" -gt 0 ]; then
    detect_protocol "$1" || {
        printf '%s\n' "unsupported" >&2
        exit 1
    }
fi

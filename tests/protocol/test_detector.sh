#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=../../../core/protocol/detector.sh
. "$ROOT/core/protocol/detector.sh"

[ "$(detect_protocol 'vless://uuid@example.com:443')" = "vless" ]
[ "$(detect_protocol 'vmess://YWJj')" = "vmess" ]

if detect_protocol 'trojan://example' >/dev/null 2>&1; then
    echo "unsupported protocol was accepted" >&2
    exit 1
fi

echo "detector: ok"

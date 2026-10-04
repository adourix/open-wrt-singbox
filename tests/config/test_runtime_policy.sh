#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

for file in     "$ROOT/core/protocol/detector.sh"     "$ROOT/core/protocol/vmess/parser.sh"     "$ROOT/core/protocol/vless/parser.sh"     "$ROOT/core/config/generator.sh"     "$ROOT/core/config/validator.sh"     "$ROOT/core/service/manager.sh"     "$ROOT/core/network/firewall.sh"; do
    sh -n "$file"
done

grep -R -nE 'echo .*proxy_url|printf .*proxy_url|logger .*proxy_url|echo .*uuid|logger .*uuid'     "$ROOT/core" >/dev/null 2>&1 && {
    echo "possible secret logging found" >&2
    exit 1
} || true

echo "runtime policy tests: PASS"

#!/bin/sh
# Every generated profile shape must pass the real pinned sing-box `check`.
# Set SINGBOX_BIN to a sing-box 1.13.21 binary; skipped when it is absent.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SB=${SINGBOX_BIN:-sing-box}
command -v "$SB" >/dev/null 2>&1 || { echo "sing-box check tests: SKIP (no sing-box)"; exit 0; }
"$SB" version | grep -q 'version 1\.13\.21' || { echo "FAIL: sing-box 1.13.21 required" >&2; exit 1; }

. "$ROOT/core/protocol/vless/parser.sh"
. "$ROOT/core/protocol/vmess/parser.sh"
. "$ROOT/core/config/generator.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
uuid=550e8400-e29b-41d4-a716-446655440000
n=0
check() {
    n=$((n + 1))
    generate_config "$1" > "$TMP/c.json" || { echo "FAIL: generate $2" >&2; exit 1; }
    "$SB" check -c "$TMP/c.json" || { echo "FAIL: sing-box check $2" >&2; exit 1; }
}

check "$(vless_parse "vless://$uuid@front.example.net:443?alpn=http%2F1.1&encryption=none&fp=ios&host=www.app.example.org&path=%2Fsecret-path&security=tls&sni=www.app.example.org&type=ws#WS")" "ws cdn"
pinned=$(vless_parse "vless://$uuid@192.0.2.10:17943?encryption=none&security=tls&sni=decoy.example&fp=chrome&alpn=http%2F1.1&vcn=real.example.org&pcs=$(printf '%064d' 7)&type=tcp&headerType=none#P")
check "$(printf '%s' "$pinned" | jq -c '.tls.certificate_public_key_sha256=["nEjF/gqqkyltAfqfikO4tefssJbkJimrWK78b8ULnH8="]')" "tcp public-key pin"
check "$(printf '%s' "$pinned" | jq -c '.tls.insecure=true')" "tcp insecure fallback"
check "$(vless_parse "vless://$uuid@example.com:443?type=grpc&security=tls&sni=example.com&serviceName=svc")" "grpc"
check "$(vless_parse "vless://$uuid@example.com:443?security=reality&sni=example.com&fp=chrome&pbk=jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0&sid=0123&flow=xtls-rprx-vision")" "reality vision"
vm=$(printf '{"v":"2","ps":"t","add":"example.com","port":"443","id":"%s","aid":"0","net":"ws","path":"/ws","host":"example.com","tls":"tls","sni":"example.com"}' "$uuid" | base64 | tr -d '\n')
check "$(vmess_parse "vmess://$vm")" "vmess ws tls"

echo "sing-box check tests: PASS ($n configs)"

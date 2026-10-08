#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/core/protocol/vless/parser.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

expect_error() {
    input=$1; expected=$2
    if vless_parse "$input" >/dev/null 2>"$TMPDIR/vless.err"; then fail "expected: $expected"; fi
    grep -F "$expected" "$TMPDIR/vless.err" >/dev/null || fail "wrong error: $expected"
}

TMPDIR=${TMPDIR:-/tmp}
umask 077
uuid=550e8400-e29b-41d4-a716-446655440000

profile=$(vless_parse "vless://$uuid@example.com:443?type=ws&security=tls&sni=example.com&path=%2F&fp=ios&alpn=http%2F1.1&allowInsecure=1&encryption=none#My%20Server")
printf '%s\n' "$profile" | jq -e '
 .schema_version == 1 and .protocol == "vless"
 and .server == "example.com" and .server_port == 443 and .uuid == "550e8400-e29b-41d4-a716-446655440000"
 and .tls.enabled == true and .tls.server_name == "example.com" and .tls.insecure == true
 and .tls.utls.enabled == true and .tls.utls.fingerprint == "ios" and .tls.alpn[0] == "http/1.1"
 and .transport.type == "ws" and .transport.path == "/"
 and .transport.headers == {} and .metadata.name == "My Server"
' >/dev/null || fail "TLS WebSocket profile"

vless_parse "vless://$uuid@[2001:db8::1]:443?type=tcp&security=tls&sni=example.com" |
 jq -e '.server == "2001:db8::1" and .server_port == 443 and .transport.type == "tcp"' >/dev/null ||
 fail "IPv6 profile"

vless_parse "vless://$uuid@example.com:443?type=grpc&security=tls&sni=example.com&serviceName=my-service" |
 jq -e '.transport.type == "grpc" and .transport.service_name == "my-service"' >/dev/null ||
 fail "gRPC profile"

vless_parse "vless://$uuid@example.com:443?security=reality&sni=example.com&fp=chrome&pbk=PUBLIC&sid=0123" |
 jq -e '.tls.reality.enabled == true and .tls.reality.public_key == "PUBLIC" and .tls.utls.fingerprint == "chrome"' >/dev/null ||
 fail "Reality profile"

vless_parse "vless://$uuid@example.com:443?type=ws&security=tls&allowInsecure=0" |
 jq -e '.tls.insecure == false' >/dev/null || fail "allowInsecure=0"

expect_error "vless://bad@example.com:443" "Invalid VLESS UUID"
expect_error "vless://$uuid@example.com" "Invalid VLESS port"
expect_error "vless://$uuid@example.com:70000" "Invalid VLESS port"
expect_error "vless://$uuid@example.com:443?encryption=aes" "Unsupported VLESS encryption"
expect_error "vless://$uuid@example.com:443?type=xhttp" "Unsupported transport"
expect_error "vless://$uuid@example.com:443?security=xtls" "Unsupported VLESS security mode"
expect_error "vless://$uuid@example.com:443?type=grpc" "Missing gRPC serviceName"
expect_error "vless://$uuid@example.com:443?security=reality&sni=example.com" "Missing Reality public key"
expect_error "vless://$uuid@example.com:443?security=reality&sni=example.com&pbk=PUBLIC&sid=0123456789abcdef0" "Invalid Reality short ID"
expect_error "vless://$uuid@example.com:443?security=reality&sni=example.com&pbk=bad%2Akey&sid=0123" "Invalid Reality public key"
expect_error "vless://$uuid@example.com:443?insecure=1" "Insecure TLS requires explicit opt-in"
expect_error "vless://$uuid@example.com:443?security=none&insecure=1" "Insecure TLS requires TLS or Reality"

VLESS_ALLOW_INSECURE=1 vless_parse "vless://$uuid@example.com:443?security=tls&insecure=1" |
 jq -e '.tls.insecure == true' >/dev/null || fail "explicit insecure opt-in"

# Query parsing must not perform pathname expansion on untrusted values.
glob_dir="$TMPDIR/vless-glob.$$"
mkdir -p "$glob_dir"
(
    cd "$glob_dir"
    : > 'host=evil'
    out=$(vless_parse "vless://$uuid@example.com:443?type=ws&host=*")
    printf '%s\n' "$out" | jq -e '.transport.headers.Host == "*"' >/dev/null
) || fail "query pathname expansion"
rm -rf "$glob_dir"

name='vless://'$uuid'@example.com:443?type=ws#hello%0A$(touch%20/tmp/pwned)'
out=$(vless_parse "$name")
printf '%s\n' "$out" | jq -e '.metadata.name == "hello$(touch /tmp/pwned)"' >/dev/null ||
 fail "fragment sanitization"

long=$(awk 'BEGIN { for (i=0;i<8200;i++) printf "A" }')
expect_error "$long" "VLESS URL is too long"

rm -f "$TMPDIR/vless.err"
printf '%s\n' "VLESS parser tests: PASS"

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

vless_parse "vless://$uuid@example.com:443?security=tls&insecure=1" |
 jq -e '.tls.insecure == true' >/dev/null || fail "fixed insecure TLS policy"

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
expect_error "vless://$uuid@example.com:443?security=none&insecure=1" "Insecure TLS requires TLS or Reality"

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


# --- Real-world link shapes (placeholders only; never commit real links) ---

# WebSocket + TLS + Host header + path + uTLS ios + ALPN, CDN front.
ws_link="vless://$uuid@front.example.net:443?alpn=http%2F1.1&encryption=none&fp=ios&host=www.app.example.org&path=%2Fsecret-path&security=tls&sni=www.app.example.org&type=ws#WS-Example"
vless_parse "$ws_link" | jq -e '
  .server=="front.example.net" and .server_port==443
  and .tls.enabled and .tls.server_name=="www.app.example.org" and .tls.insecure==false
  and .tls.utls.fingerprint=="ios" and .tls.alpn==["http/1.1"]
  and .transport=={type:"ws",path:"/secret-path",headers:{Host:"www.app.example.org"}}
  and .tls.pinned_cert_sha256==null and .tls.verify_names==null
  and .metadata.name=="WS-Example"' >/dev/null || fail "WebSocket CDN link"

# TCP + TLS with a decoy SNI, Xray certificate pin (pcs) and verify name (vcn).
pin=A1B2C3D4E5F60718293A4B5C6D7E8F90A1B2C3D4E5F60718293A4B5C6D7E8F90
tcp_link="vless://$uuid@192.0.2.10:17943?encryption=none&security=tls&sni=decoy.example&fp=chrome&alpn=http%2F1.1&vcn=real.example.org&pcs=$pin&type=tcp&headerType=none#Pinned%20-%20Example%20-%20100GB"
vless_parse "$tcp_link" | jq -e '
  .server=="192.0.2.10" and .server_port==17943
  and .tls.server_name=="decoy.example" and .tls.utls.fingerprint=="chrome"
  and .transport.type=="tcp"
  and .tls.pinned_cert_sha256==["a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"]
  and .tls.verify_names==["real.example.org"]
  and .metadata.name=="Pinned - Example - 100GB"' >/dev/null || fail "pinned TCP link"

# Colon-separated and multiple pins are accepted.
vless_parse "vless://$uuid@example.com:443?security=tls&sni=a.example&pcs=$(printf '%s' "$pin" | sed 's/../&:/g;s/:$//'),$(printf '%064d' 1)" |
  jq -e '.tls.pinned_cert_sha256|length==2' >/dev/null || fail "pin list"

expect_error "vless://$uuid@example.com:443?security=tls&pcs=abc" "Invalid certificate pin"
expect_error "vless://$uuid@example.com:443?security=tls&vcn=bad%20name%3B" "Invalid certificate name"
expect_error "vless://$uuid@example.com:443?type=tcp&headerType=http" "Unsupported transport"
# Pins have no meaning without plain TLS and are ignored for Reality.
vless_parse "vless://$uuid@example.com:443?security=reality&sni=example.com&pbk=PUBLIC&sid=01&pcs=$pin" |
  jq -e '.tls.pinned_cert_sha256==null' >/dev/null || fail "pcs ignored with reality"

# allow_insecure policy is enforced.
if VLESS_ALLOW_INSECURE=0 vless_parse "vless://$uuid@example.com:443?security=tls&insecure=1" >/dev/null 2>"$TMPDIR/vless.err"; then
    fail "insecure must be refused when policy is off"
fi
grep -F "Insecure TLS is disabled by policy" "$TMPDIR/vless.err" >/dev/null || fail "policy error text"

rm -f "$TMPDIR/vless.err"
printf '%s\n' "VLESS parser tests: PASS"

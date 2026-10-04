#!/bin/sh
set -eu

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=../../core/protocol/vmess/parser.sh
. "$ROOT/core/protocol/vmess/parser.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

expect_error() {
    input=$1
    expected=$2
    if vmess_parse "$input" >/dev/null 2>"$TMPDIR/vmess.err"; then
        fail "expected error: $expected"
    fi
    grep -F "$expected" "$TMPDIR/vmess.err" >/dev/null ||
        fail "wrong error for: $expected"
}

TMPDIR=${TMPDIR:-/tmp}
umask 077

json='{"v":"2","ps":"Test VMess","add":"example.test","port":"443","id":"550e8400-e29b-41d4-a716-446655440000","aid":"0","scy":"","net":"ws","type":"none","host":"example.test","path":"/ws","tls":"tls","sni":"example.test"}'
payload=$(printf '%s' "$json" | base64 | tr -d '\r\n')
url="vmess://$payload"

profile=$(vmess_parse "$url")
printf '%s\n' "$profile" | jq -e '
    .schema_version == 1
    and .protocol == "vmess"
    and .server == "example.test"
    and .server_port == 443
    and .uuid == "550e8400-e29b-41d4-a716-446655440000"
    and .alter_id == 0
    and .security == "auto"
    and .tls.enabled == true
    and .tls.server_name == "example.test"
    and .transport.type == "ws"
    and .transport.path == "/ws"
    and .transport.headers.Host == "example.test"
    and .metadata.name == "Test VMess"
' >/dev/null || fail "valid VMess was not normalized"

payload_urlsafe=$(printf '%s' "$json" | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\r\n')
vmess_parse "vmess://$payload_urlsafe" | jq -e '.protocol == "vmess"' >/dev/null ||
    fail "URL-safe/missing-padding VMess failed"

json_numeric='{"add":"example.test","port":443,"id":"550e8400-e29b-41d4-a716-446655440000","aid":4,"net":"tcp","tls":""}'
payload_numeric=$(printf '%s' "$json_numeric" | base64 | tr -d '\r\n')
vmess_parse "vmess://$payload_numeric" | jq -e '.server_port == 443 and .alter_id == 4 and .transport.type == "tcp"' >/dev/null ||
    fail "numeric fields failed"

expect_error "vless://not-vmess" "Invalid VMess URL"
expect_error "vmess://%%%" "Invalid VMess Base64"

bad_json=$(printf '%s' '{"add":"example.test"' | base64 | tr -d '\r\n')
expect_error "vmess://$bad_json" "Invalid VMess JSON"

bad_uuid=$(printf '%s' '{"add":"example.test","port":443,"id":"not-a-uuid"}' | base64 | tr -d '\r\n')
expect_error "vmess://$bad_uuid" "Invalid VMess UUID"

bad_port=$(printf '%s' '{"add":"example.test","port":70000,"id":"550e8400-e29b-41d4-a716-446655440000"}' | base64 | tr -d '\r\n')
expect_error "vmess://$bad_port" "Invalid VMess port"

bad_transport=$(printf '%s' '{"add":"example.test","port":443,"id":"550e8400-e29b-41d4-a716-446655440000","net":"xhttp"}' | base64 | tr -d '\r\n')
expect_error "vmess://$bad_transport" "Unsupported transport"

long_payload=$(awk 'BEGIN { for (i=0;i<8200;i++) printf "A" }')
expect_error "vmess://$long_payload" "VMess URL is too long"

rm -f "$TMPDIR/vmess.err"
printf '%s\n' "VMess parser tests: PASS"

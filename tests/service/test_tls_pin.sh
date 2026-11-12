#!/bin/sh
# Apply-time translation of an Xray certificate pin (pcs) into the sing-box
# public-key pin, against a throw-away local TLS server.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "TLS pin tests: SKIP (no openssl)"; exit 0; }

TMP=$(mktemp -d)
SERVER_PID=
cleanup() { [ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "$TMP/k.pem" -out "$TMP/c.pem" -days 2 -subj "/CN=real.example.org" >/dev/null 2>&1
PORT=$(awk 'BEGIN { srand(); print 20000 + int(rand() * 20000) }')
openssl s_server -accept "$PORT" -cert "$TMP/c.pem" -key "$TMP/k.pem" -quiet </dev/null >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1

PCS=$(openssl x509 -in "$TMP/c.pem" -outform der | openssl dgst -sha256 -r | awk '{print $1}')
SPKI=$(openssl x509 -in "$TMP/c.pem" -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl base64 -A)

export MANAGER_LIB="$ROOT/core" CONFIG_DIR="$TMP/cfg" COWBOY_BEBOP_SOURCE_ONLY=1
# shellcheck disable=SC1091
. "$ROOT/core/service/manager.sh"
load_core
logger() { :; }

uuid=550e8400-e29b-41d4-a716-446655440000
link() { printf 'vless://%s@127.0.0.1:%s?encryption=none&security=tls&sni=decoy.example&fp=chrome&alpn=http%%2F1.1&vcn=real.example.org&pcs=%s&type=tcp&headerType=none#t' "$uuid" "$PORT" "$1"; }

# Matching pin -> public-key pin, verification stays on.
p=$(vless_parse "$(link "$PCS")")
r=$(resolve_tls_verification "$p" 0) || fail "matching pin rejected"
printf '%s' "$r" | jq -e --arg k "$SPKI" '.tls.certificate_public_key_sha256==[$k] and .tls.insecure==false' >/dev/null || fail "public-key pin"
generate_config "$r" | jq -e --arg k "$SPKI" '.outbounds[1].tls.certificate_public_key_sha256==[$k]' >/dev/null || fail "generated pin"

# Wrong pin -> refused even when allow_insecure is on.
p=$(vless_parse "$(link "$(printf '%064d' 0)")")
if resolve_tls_verification "$p" 1 >/dev/null 2>"$TMP/err"; then fail "mismatched pin accepted"; fi
grep -F 'does not match the pinned certificate' "$TMP/err" >/dev/null || fail "mismatch message"

# openssl unavailable -> insecure only by policy.
p=$(vless_parse "$(link "$PCS")")
OPENSSL_BIN=/nonexistent
r=$(resolve_tls_verification "$p" 1) || fail "policy fallback"
printf '%s' "$r" | jq -e '.tls.insecure==true and .tls.certificate_public_key_sha256==null' >/dev/null || fail "fallback profile"
if resolve_tls_verification "$p" 0 >/dev/null 2>&1; then fail "fallback without policy"; fi

# Profiles without pins pass through untouched.
plain=$(vless_parse "vless://$uuid@example.com:443?security=tls&sni=example.com")
[ "$(resolve_tls_verification "$plain" 0)" = "$plain" ] || fail "plain profile changed"

echo "TLS pin tests: PASS"

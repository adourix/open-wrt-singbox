#!/bin/sh
set -eu

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/core/config/generator.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
TMPDIR=${TMPDIR:-/tmp}
export TMPDIR
uuid=550e8400-e29b-41d4-a716-446655440000
profile=$(jq -cn --arg uuid "$uuid" '{schema_version:1,protocol:"vless",server:"example.com",server_port:443,uuid:$uuid,flow:null,tls:{enabled:true,server_name:"example.com",insecure:true,utls:{enabled:true,fingerprint:"ios"},reality:null,alpn:["http/1.1"]},transport:{type:"ws",path:"/",headers:{}},metadata:{name:"test"}}')
out=$(generate_config "$profile")
printf '%s\n' "$out" | jq -e '
  .log.level=="warn"
  and .outbounds[0].type=="direct"
  and .outbounds[0].tag=="direct"
  and .outbounds[1].type=="vless"
  and .outbounds[1].tag=="proxy-out"
  and .outbounds[1].server=="example.com"
  and .outbounds[1].server_port==443
  and .outbounds[1].uuid=="550e8400-e29b-41d4-a716-446655440000"
  and .outbounds[1].domain_resolver.server=="dns-1"
  and .outbounds[1].domain_resolver.strategy=="ipv4_only"
  and .outbounds[1].tls.enabled==true
  and .outbounds[1].tls.server_name=="example.com"
  and .outbounds[1].tls.insecure==true
  and .outbounds[1].tls.utls.fingerprint=="ios"
  and .outbounds[1].tls.alpn[0]=="http/1.1"
  and .outbounds[1].transport.type=="ws"
  and .outbounds[1].transport.path=="/"
  and .inbounds[0].type=="tun"
  and .inbounds[0].interface_name=="tun0"
  and .inbounds[0].auto_route==true
  and .inbounds[0].auto_redirect==true
  and .inbounds[0].strict_route==true
  and .dns.strategy=="ipv4_only"
  and .dns.final=="dns-1"
  and .dns.servers[0].tag=="dns-1"
  and .dns.servers[0].server=="1.1.1.1"
  and .dns.servers[0].detour=="direct"
  and .dns.servers[1].server=="8.8.8.8"
  and .route.auto_detect_interface==true
  and .route.default_domain_resolver.server=="dns-1"
  and (.route.rules|length)==3
  and .route.rules[0].ip_cidr[0]=="1.1.1.1/32"
  and .route.rules[0].outbound=="direct"
  and .route.rules[1].ip_is_private==true
  and .route.rules[1].outbound=="direct"
  and .route.rules[2].action=="hijack-dns"
  and .route.rules[2].port==53
  and .route.final=="proxy-out"
' >/dev/null || fail "VLESS generation"

# TCP VLESS should omit transport; DNS/routing policy remains shared.
tcp_profile=$(printf '%s' "$profile" | jq '.transport.type="tcp"')
tcp_out=$(generate_config "$tcp_profile")
printf '%s\n' "$tcp_out" | jq -e '(.outbounds[1].transport|not) and .dns.final=="dns-1" and .route.final=="proxy-out"' >/dev/null || fail "TCP VLESS generation"

bad='{"schema_version":1,"protocol":"trojan"}'
if generate_config "$bad" >/dev/null 2>/dev/null; then fail "invalid protocol accepted"; fi
bad_transport=$(printf '%s' "$profile" | jq '.transport.type="xhttp"')
if generate_config "$bad_transport" >/dev/null 2>/dev/null; then fail "invalid transport accepted"; fi

malicious=$(
printf '%s' "$profile" | jq --arg s '$(touch /tmp/pwned)' '.server=$s')
rm -f /tmp/pwned
if generate_config "$malicious" >/dev/null 2>"$TMPDIR/generator.err"; then :; fi
if [ -e /tmp/pwned ]; then fail "generator executed shell input"; fi
rm -f "$TMPDIR/generator.err"

# --- Certificate pin handling ---
base=$(jq -cn --arg uuid "$uuid" '{schema_version:1,protocol:"vless",server:"192.0.2.10",server_port:17943,uuid:$uuid,flow:null,tls:{enabled:true,server_name:"decoy.example",insecure:false,utls:{enabled:true,fingerprint:"chrome"},reality:null,alpn:["http/1.1"],pinned_cert_sha256:["a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"],verify_names:["real.example.org"]},transport:{type:"tcp"},metadata:{name:null}}')

# An unresolved Xray pin must never be silently dropped.
if generate_config "$base" >/dev/null 2>&1; then fail "unresolved pin accepted"; fi

# Resolved public-key pin is emitted and wins over insecure.
spki='nEjF/gqqkyltAfqfikO4tefssJbkJimrWK78b8ULnH8='
out=$(generate_config "$(printf '%s' "$base" | jq -c --arg k "$spki" '.tls.certificate_public_key_sha256=[$k] | .tls.insecure=true')")
printf '%s\n' "$out" | jq -e --arg k "$spki" '
  .outbounds[1].tls.certificate_public_key_sha256==[$k]
  and (.outbounds[1].tls|has("insecure")|not)
  and .outbounds[1].tls.server_name=="decoy.example"
  and (.outbounds[1]|has("transport")|not)' >/dev/null || fail "public-key pin"

# Policy fallback: insecure explicitly set by the manager.
generate_config "$(printf '%s' "$base" | jq -c '.tls.insecure=true')" |
  jq -e '.outbounds[1].tls.insecure==true' >/dev/null || fail "insecure fallback"

# A verify name equal to the SNI needs nothing special.
generate_config "$(printf '%s' "$base" | jq -c '.tls.pinned_cert_sha256=null | .tls.verify_names=["decoy.example"]')" >/dev/null ||
  fail "vcn equal to sni"
if generate_config "$(printf '%s' "$base" | jq -c '.tls.pinned_cert_sha256=null')" >/dev/null 2>&1; then
  fail "differing vcn without policy accepted"
fi
# Malformed public-key pin is rejected.
if generate_config "$(printf '%s' "$base" | jq -c '.tls.certificate_public_key_sha256=["not-base64"]')" >/dev/null 2>&1; then
  fail "bad public-key pin accepted"
fi

printf '%s\n' "Config generator tests: PASS"

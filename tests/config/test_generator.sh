#!/bin/sh
set -eu

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=../../core/config/generator.sh
. "$ROOT/core/config/generator.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
TMPDIR=${TMPDIR:-/tmp}
export TMPDIR
uuid=550e8400-e29b-41d4-a716-446655440000
profile=$(jq -cn --arg uuid "$uuid" '{schema_version:1,protocol:"vless",server:"example.com",server_port:443,uuid:$uuid,flow:null,tls:{enabled:true,server_name:"example.com",insecure:true,utls:{enabled:true,fingerprint:"ios"},reality:null,alpn:["http/1.1"]},transport:{type:"ws",path:"/",headers:{}},metadata:{name:"test"}}')
out=$(generate_config "$profile")
printf '%s\n' "$out" | jq -e '
  .log.level=="info"
  and .outbounds[0].type=="direct"
  and .outbounds[0].tag=="direct"
  and .outbounds[1].type=="vless"
  and .outbounds[1].tag=="proxy-out"
  and .outbounds[1].server=="example.com"
  and .outbounds[1].server_port==443
  and .outbounds[1].uuid=="550e8400-e29b-41d4-a716-446655440000"
  and .outbounds[1].domain_resolver.server=="configured-dns-0"
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
  and .dns.servers[0].type=="udp"
  and .dns.servers[0].server=="1.1.1.1"
  and .dns.servers[1].server=="8.8.8.8"
  and .dns.final=="configured-dns-0"
  and .dns.strategy=="ipv4_only"
  and .route.auto_detect_interface==true
  and .route.rules[0].ip_cidr[0]=="1.1.1.1/32"
  and .route.rules[0].ip_cidr[1]=="8.8.8.8/32"
  and .route.rules[0].outbound=="direct"
  and .route.default_domain_resolver.server=="configured-dns-0"
  and .route.default_domain_resolver.strategy=="ipv4_only"
  and .route.final=="proxy-out"
' >/dev/null || fail "VLESS generation"
bad='{"schema_version":1,"protocol":"trojan"}'
if generate_config "$bad" >/dev/null 2>/dev/null; then fail "invalid protocol accepted"; fi
bad_transport=$(printf '%s' "$profile" | jq '.transport.type="xhttp"')
if generate_config "$bad_transport" >/dev/null 2>/dev/null; then fail "invalid transport accepted"; fi
printf '%s\n' "Config generator tests: PASS"
malicious=$(printf '%s' "$profile" | jq --arg s '$(touch /tmp/pwned)' '.server=$s')
rm -f /tmp/pwned
if generate_config "$malicious" >/dev/null 2>"$TMPDIR/generator.err"; then :; fi
if [ -e /tmp/pwned ]; then fail "generator executed shell input"; fi
rm -f "$TMPDIR/generator.err"

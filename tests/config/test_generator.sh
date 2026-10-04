#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=../../core/config/generator.sh
. "$ROOT/core/config/generator.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

TMPDIR=${TMPDIR:-/tmp}
export TMPDIR

uuid=550e8400-e29b-41d4-a716-446655440000

profile=$(jq -cn --arg uuid "$uuid" '{
 schema_version:1, protocol:"vless", server:"example.com", server_port:443, uuid:$uuid,
 flow:null,
 tls:{enabled:true,server_name:"example.com",insecure:false,utls:null,reality:null,alpn:["h2","http/1.1"]},
 transport:{type:"ws",path:"/ws",headers:{Host:"example.com"}},
 metadata:{name:"test"}
}')

out=$(generate_config "$profile")
printf '%s\n' "$out" | jq -e '
 .outbounds[0].type=="vless"
 and .outbounds[0].server=="example.com"
 and .outbounds[0].server_port==443
 and .outbounds[0].uuid=="550e8400-e29b-41d4-a716-446655440000"
 and .outbounds[0].tls.enabled==true
 and .outbounds[0].transport.type=="ws"
 and .inbounds[0].type=="tun"
 and .inbounds[0].auto_route==true
 and .inbounds[0].auto_redirect==true
 and .inbounds[0].strict_route==false
 and .route.rules[0].action=="sniff"
 and .route.rules[1].action=="hijack-dns"
 and .dns.strategy=="ipv4_only"
' >/dev/null || fail "VLESS generation"

bad='{"schema_version":1,"protocol":"trojan"}'
if generate_config "$bad" >/dev/null 2>/dev/null; then
    fail "invalid protocol accepted"
fi

bad_transport=$(printf '%s' "$profile" | jq '.transport.type="xhttp"')
if generate_config "$bad_transport" >/dev/null 2>/dev/null; then
    fail "invalid transport accepted"
fi

printf '%s\n' "Config generator tests: PASS"

# Sensitive input must not be emitted into diagnostics by the generator.
malicious=$(printf '%s' "$profile" | jq --arg s '$(touch /tmp/pwned)' '.server=$s')
if generate_config "$malicious" >/dev/null 2>"$TMPDIR/generator.err"; then
    :
fi
if [ -e /tmp/pwned ]; then
    fail "generator executed shell input"
fi
rm -f "$TMPDIR/generator.err"

#!/bin/sh
# Parse a VMess share URL into normalized profile v1.
# Input is untrusted. Decoded data is parsed as JSON and never executed.

VMESS_MAX_INPUT=8192

vmess_error() { printf '%s\n' "$1" >&2; return 1; }

_vmess_decode_base64() {
    payload=$1
    payload=$(printf '%s' "$payload" | tr -- '_-' '/+')
    payload=$(printf '%s' "$payload" | tr -d ' \t\r\n')
    case "$payload" in *[!A-Za-z0-9+/=]*|'') return 1;; esac
    case "$payload" in *=*) case "$payload" in *[!]=*|*==*=*) return 1;; esac;; esac
    len=${#payload}
    rem=$((len % 4))
    [ "$rem" -ne 1 ] || return 1
    [ "$rem" -ne 2 ] || payload=$payload==
    [ "$rem" -ne 3 ] || payload=$payload=
    printf '%s' "$payload" | base64 -d 2>/dev/null
}

vmess_parse() {
    url=$1
    [ -n "$url" ] || { vmess_error "Invalid VMess URL"; return 1; }
    [ ${#url} -le "$VMESS_MAX_INPUT" ] || { vmess_error "VMess URL is too long"; return 1; }
    url=$(printf '%s' "$url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case "$url" in vmess://*) ;; *) vmess_error "Invalid VMess URL"; return 1;; esac

    payload=${url#vmess://}
    [ -n "$payload" ] || { vmess_error "Invalid VMess Base64"; return 1; }
    decoded=$(_vmess_decode_base64 "$payload") || { vmess_error "Invalid VMess Base64"; return 1; }
    printf '%s' "$decoded" | jq -e 'type=="object"' >/dev/null 2>&1 ||
        { vmess_error "Invalid VMess JSON"; return 1; }

    printf '%s' "$decoded" | jq -e '
      ((.add|type)=="string") and ((.port|type)=="number" or (.port|type)=="string")
      and ((.id|type)=="string")
      and ((.aid|type)=="number" or (.aid|type)=="string" or (.aid|type)=="null")
      and ((.scy|type)=="string" or (.scy|type)=="null")
      and ((.net|type)=="string" or (.net|type)=="null")
      and ((.host|type)=="string" or (.host|type)=="null")
      and ((.path|type)=="string" or (.path|type)=="null")
      and ((.tls|type)=="string" or (.tls|type)=="null")
      and ((.sni|type)=="string" or (.sni|type)=="null")
      and ((.ps|type)=="string" or (.ps|type)=="null")
      and ((.fp|type)=="string" or (.fp|type)=="null")
      and ((.serviceName|type)=="string" or (.serviceName|type)=="null")
    ' >/dev/null 2>&1 || { vmess_error "Invalid VMess JSON"; return 1; }

    server=$(printf '%s' "$decoded" | jq -er '.add') || { vmess_error "Missing VMess server"; return 1; }
    [ -n "$server" ] || { vmess_error "Missing VMess server"; return 1; }
    printf '%s' "$server" | grep -Eq '^[A-Za-z0-9._:-]+$' ||
        { vmess_error "Invalid VMess server"; return 1; }

    uuid=$(printf '%s' "$decoded" | jq -er '.id') || { vmess_error "Invalid VMess UUID"; return 1; }
    printf '%s' "$uuid" | grep -Eq '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89AaBb][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$' ||
        { vmess_error "Invalid VMess UUID"; return 1; }

    port=$(printf '%s' "$decoded" | jq -er 'if (.port|type)=="number" then tostring elif (.port|type)=="string" then . else error end') ||
        { vmess_error "Invalid VMess port"; return 1; }
    printf '%s' "$port" | grep -Eq '^[0-9]+$' ||
        { vmess_error "Invalid VMess port"; return 1; }
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null ||
        { vmess_error "Invalid VMess port"; return 1; }

    aid=$(printf '%s' "$decoded" | jq -er 'if .aid==null then 0 elif (.aid|type)=="number" and ((.aid|floor)==.aid) then .aid elif (.aid|type)=="string" and (.aid|test("^[0-9]+$")) then (.aid|tonumber) else error end') ||
        { vmess_error "Invalid VMess alter_id"; return 1; }

    security=$(printf '%s' "$decoded" | jq -er 'if .scy==null or .scy=="" then "auto" elif (.scy|type)=="string" then ascii_downcase else error end') ||
        { vmess_error "Invalid VMess security"; return 1; }
    case "$security" in auto|none|zero|aes-128-gcm|chacha20-poly1305|aes-128-ctr) ;; *) vmess_error "Unsupported VMess security"; return 1;; esac

    network=$(printf '%s' "$decoded" | jq -er 'if .net==null or .net=="" then "tcp" elif (.net|type)=="string" then ascii_downcase else error end') ||
        { vmess_error "Invalid VMess transport"; return 1; }
    case "$network" in tcp|ws|grpc) ;; *) vmess_error "Unsupported transport"; return 1;; esac

    tls=$(printf '%s' "$decoded" | jq -er 'if .tls==null or .tls=="" then false elif (.tls|type)=="string" then ((.tls|ascii_downcase)=="tls" or (.tls|ascii_downcase)=="1" or (.tls|ascii_downcase)=="true") else error end') ||
        { vmess_error "Invalid VMess TLS configuration"; return 1; }
    sni=$(printf '%s' "$decoded" | jq -er 'if .sni==null then "" else .sni end') || { vmess_error "Invalid VMess SNI"; return 1; }
    host=$(printf '%s' "$decoded" | jq -er 'if .host==null then "" else .host end') || { vmess_error "Invalid VMess host"; return 1; }
    path=$(printf '%s' "$decoded" | jq -er 'if .path==null then "" else .path end') || { vmess_error "Invalid VMess path"; return 1; }
    name=$(printf '%s' "$decoded" | jq -er 'if .ps==null then "" else .ps end') || { vmess_error "Invalid VMess name"; return 1; }
    fp=$(printf '%s' "$decoded" | jq -er 'if .fp==null then "" else .fp end') || { vmess_error "Invalid VMess fingerprint"; return 1; }
    service_name=$(printf '%s' "$decoded" | jq -er 'if .serviceName==null then "" else .serviceName end') || { vmess_error "Invalid VMess serviceName"; return 1; }

    [ "$network" != "grpc" ] || [ -n "$service_name" ] ||
        { vmess_error "Missing gRPC serviceName"; return 1; }
    [ "$network" != "ws" ] || [ -n "$path" ] || path="/"

    jq -cn \
      --arg protocol vmess --arg server "$server" --argjson server_port "$port" --arg uuid "$uuid" \
      --argjson alter_id "$aid" --arg security "$security" --arg network "$network" --argjson tls "$tls" \
      --arg sni "$sni" --arg host "$host" --arg path "$path" --arg name "$name" --arg fp "$fp" --arg service_name "$service_name" '
      {
        schema_version:1, protocol:$protocol, server:$server, server_port:$server_port, uuid:$uuid,
        alter_id:$alter_id, security:$security,
        tls:{
          enabled:$tls,
          server_name:(if $sni!="" then $sni else null end),
          insecure:false,
          utls:(if $fp!="" then {enabled:true,fingerprint:$fp} else null end),
          reality:null,
          alpn:null
        },
        transport:(
          if $network=="ws" then {type:"ws",path:$path,headers:(if $host!="" then {Host:$host} else {} end)}
          elif $network=="grpc" then {type:"grpc",service_name:$service_name}
          else {type:"tcp"} end
        ),
        metadata:{name:(if $name!="" then $name else null end)}
      }'
}

if [ "${0##*/}" = "parser.sh" ] && [ "$#" -gt 0 ]; then vmess_parse "$1"; fi

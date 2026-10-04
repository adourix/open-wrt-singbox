#!/bin/sh
# VMess share-link parser.
# Input is untrusted. Decoded data is parsed as JSON and is never executed.

VMESS_MAX_INPUT=8192

vmess_error() {
    printf '%s\n' "$1" >&2
    return 1
}

_vmess_decode_base64() {
    payload=$1
    payload=$(printf '%s' "$payload" | tr -- '_-' '/+')
    payload=$(printf '%s' "$payload" | tr -d ' \t\r\n')

    case "$payload" in
        *[!A-Za-z0-9+/=]*|'') return 1 ;;
    esac

    case "$payload" in
        *=*) case "$payload" in *[!]=*|*==*=*) return 1 ;; esac ;;
    esac

    len=\${#payload}
    rem=$((len % 4))
    if [ "$rem" -eq 1 ]; then
        return 1
    elif [ "$rem" -eq 2 ]; then
        payload=$payload==
    elif [ "$rem" -eq 3 ]; then
        payload=$payload=
    fi

    printf '%s' "$payload" | base64 -d 2>/dev/null
}

vmess_parse() {
    url=$1

    [ -n "$url" ] || { vmess_error "Invalid VMess URL"; return 1; }
    [ \${#url} -le "$VMESS_MAX_INPUT" ] || { vmess_error "VMess URL is too long"; return 1; }

    case "$url" in
        vmess://*) ;;
        *) vmess_error "Invalid VMess URL"; return 1 ;;
    esac

    payload=\${url#vmess://}
    [ -n "$payload" ] || { vmess_error "Invalid VMess Base64"; return 1; }

    decoded=$(_vmess_decode_base64 "$payload") ||
        { vmess_error "Invalid VMess Base64"; return 1; }

    printf '%s' "$decoded" | jq -e . >/dev/null 2>&1 ||
        { vmess_error "Invalid VMess JSON"; return 1; }

    if ! printf '%s' "$decoded" | jq -e '
        type == "object"
        and ((.add | type) == "string" or (.add | type) == "null")
        and ((.port | type) == "number" or (.port | type) == "string" or (.port | type) == "null")
        and ((.id | type) == "string" or (.id | type) == "null")
        and ((.aid | type) == "number" or (.aid | type) == "string" or (.aid | type) == "null")
        and ((.scy | type) == "string" or (.scy | type) == "null")
        and ((.net | type) == "string" or (.net | type) == "null")
        and ((.host | type) == "string" or (.host | type) == "null")
        and ((.path | type) == "string" or (.path | type) == "null")
        and ((.tls | type) == "string" or (.tls | type) == "null")
        and ((.sni | type) == "string" or (.sni | type) == "null")
        and ((.ps | type) == "string" or (.ps | type) == "null")
    ' >/dev/null 2>&1; then
        vmess_error "Invalid VMess JSON"
        return 1
    fi

    server=$(printf '%s' "$decoded" | jq -er 'if (.add|type) == "string" then .add else error end') ||
        { vmess_error "Missing VMess server"; return 1; }
    [ -n "$server" ] || { vmess_error "Missing VMess server"; return 1; }

    uuid=$(printf '%s' "$decoded" | jq -er 'if (.id|type) == "string" then .id else error end') ||
        { vmess_error "Invalid VMess UUID"; return 1; }
    printf '%s' "$uuid" | grep -Eq '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89AaBb][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$' ||
        { vmess_error "Invalid VMess UUID"; return 1; }

    port=$(printf '%s' "$decoded" | jq -er 'if (.port|type) == "number" then (.port|tostring) elif (.port|type) == "string" then .port else error end') ||
        { vmess_error "Invalid VMess port"; return 1; }
    printf '%s' "$port" | grep -Eq '^[0-9]+$' ||
        { vmess_error "Invalid VMess port"; return 1; }
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null ||
        { vmess_error "Invalid VMess port"; return 1; }

    aid=$(printf '%s' "$decoded" | jq -er '
        if .aid == null then 0
        elif (.aid|type) == "number" and ((.aid|floor) == .aid) then .aid
        elif (.aid|type) == "string" and test("^[0-9]+$") then tonumber
        else error end
    ') || { vmess_error "Invalid VMess alter_id"; return 1; }

    security=$(printf '%s' "$decoded" | jq -er '
        if .scy == null or .scy == "" then "auto"
        elif (.scy|type) == "string" then .scy
        else error end
    ') || { vmess_error "Invalid VMess security"; return 1; }

    network=$(printf '%s' "$decoded" | jq -er '
        if .net == null or .net == "" then "tcp"
        elif (.net|type) == "string" then ascii_downcase
        else error end
    ') || { vmess_error "Invalid VMess transport"; return 1; }

    case "$network" in
        tcp|ws|grpc) ;;
        *) vmess_error "Unsupported transport"; return 1 ;;
    esac

    tls=$(printf '%s' "$decoded" | jq -er '
        if .tls == null or .tls == "" then false
        elif (.tls|type) == "string" then ((ascii_downcase == "tls") or (ascii_downcase == "1") or (ascii_downcase == "true"))
        else error end
    ') || { vmess_error "Invalid VMess TLS configuration"; return 1; }

    sni=$(printf '%s' "$decoded" | jq -er 'if .sni == null then "" elif (.sni|type) == "string" then . else error end') ||
        { vmess_error "Invalid VMess SNI"; return 1; }

    host=$(printf '%s' "$decoded" | jq -er 'if .host == null then "" elif (.host|type) == "string" then . else error end') ||
        { vmess_error "Invalid VMess host"; return 1; }

    path=$(printf '%s' "$decoded" | jq -er 'if .path == null then "" elif (.path|type) == "string" then . else error end') ||
        { vmess_error "Invalid VMess path"; return 1; }

    name=$(printf '%s' "$decoded" | jq -er 'if .ps == null then "" elif (.ps|type) == "string" then . else error end') ||
        { vmess_error "Invalid VMess name"; return 1; }

    jq -cn \
        --arg protocol "vmess" \
        --arg server "$server" \
        --argjson server_port "$port" \
        --arg uuid "$uuid" \
        --argjson alter_id "$aid" \
        --arg security "$security" \
        --arg network "$network" \
        --argjson tls "$tls" \
        --arg sni "$sni" \
        --arg host "$host" \
        --arg path "$path" \
        --arg name "$name" '
        {
          schema_version: 1,
          protocol: $protocol,
          server: $server,
          server_port: $server_port,
          uuid: $uuid,
          alter_id: $alter_id,
          security: $security,
          tls: {
            enabled: $tls,
            server_name: (if $sni != "" then $sni else null end)
          },
          transport: (
            if $network == "ws" then
              {type:"ws", path:(if $path != "" then $path else "/" end),
               headers:(if $host != "" then {Host:$host} else {} end)}
            elif $network == "grpc" then
              {type:"grpc"}
            else
              {type:"tcp"}
            end
          ),
          metadata: {
            name: (if $name != "" then $name else null end)
          }
        }'
}

if [ "\${0##*/}" = "parser.sh" ] && [ "$#" -gt 0 ]; then
    vmess_parse "$1"
fi

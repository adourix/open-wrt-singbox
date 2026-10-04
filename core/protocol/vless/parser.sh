#!/bin/sh
# Parse a VLESS share URL into normalized profile v1.
# Input is untrusted and is never evaluated.

VLESS_MAX_INPUT=8192

vless_error() { printf '%s\n' "$1" >&2; return 1; }

_vless_urldecode() {
    LC_ALL=C printf '%s\n' "$1" | awk '
    function hv(c) { return index("0123456789abcdef",tolower(c))-1 }
    {
        s=$0; out=""
        for (i=1;i<=length(s);i++) {
            c=substr(s,i,1)
            if (c=="%") {
                if (i+2>length(s)) exit 2
                a=substr(s,i+1,1); b=substr(s,i+2,1)
                if (a !~ /^[0-9A-Fa-f]$/ || b !~ /^[0-9A-Fa-f]$/) exit 2
                out=out sprintf("%c",hv(a)*16+hv(b)); i+=2
            } else if (c=="+") out=out " "
            else out=out c
        }
        printf "%s",out
    }' 2>/dev/null
}

_vless_param() {
    key=$1
    query=$2
    old_ifs=$IFS
    IFS='&'
    for item in $query; do
        IFS=$old_ifs
        case "$item" in
            "$key"=*) printf '%s' "${item#*=}"; IFS=$old_ifs; return 0 ;;
        esac
        IFS='&'
    done
    IFS=$old_ifs
    return 1
}

vless_parse() {
    url=$1
    [ -n "$url" ] || { vless_error "Invalid VLESS URL"; return 1; }
    [ ${#url} -le "$VLESS_MAX_INPUT" ] || { vless_error "VLESS URL is too long"; return 1; }
    case "$url" in vless://*) ;; *) vless_error "Invalid VLESS URL"; return 1;; esac

    rest=${url#vless://}
    fragment=
    case "$rest" in *\#*) fragment=${rest#*\#}; rest=${rest%%\#*};; esac
    query=
    case "$rest" in *\?*) query=${rest#*\?}; rest=${rest%%\?*};; esac

    case "$rest" in
        *@*) userinfo=${rest%%@*}; authority=${rest#*@};;
        *) vless_error "Missing VLESS UUID"; return 1;;
    esac
    [ -n "$userinfo" ] || { vless_error "Invalid VLESS UUID"; return 1; }
    [ -n "$authority" ] || { vless_error "Missing VLESS server"; return 1; }

    uuid=$( _vless_urldecode "$userinfo" ) || { vless_error "Invalid VLESS UUID"; return 1; }
    printf '%s' "$uuid" | grep -Eq '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89AaBb][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$' ||
        { vless_error "Invalid VLESS UUID"; return 1; }

    case "$authority" in
        \[*\]:*) server=${authority#\[}; server=${server%%\]}; port=${authority##*\]:};;
        *:*) server=${authority%:*}; port=${authority##*:};;
        *) vless_error "Invalid VLESS port"; return 1;;
    esac
    case "$server" in *:*) ;; esac
    case "$authority" in *:*:* ) case "$authority" in \[*\]:*) ;; *) vless_error "IPv6 server must use brackets"; return 1;; esac;; esac
    [ -n "$server" ] || { vless_error "Missing VLESS server"; return 1; }
    printf '%s' "$server" | grep -Eq '^[A-Za-z0-9._:-]+$' ||
        { vless_error "Invalid VLESS server"; return 1; }
    printf '%s' "$port" | grep -Eq '^[0-9]+$' ||
        { vless_error "Invalid VLESS port"; return 1; }
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null ||
        { vless_error "Invalid VLESS port"; return 1; }

    type= security= sni= host= path= service_name= flow= fp= pbk= sid= alpn= encryption= insecure=
    for key in type security sni host path serviceName flow fp pbk sid alpn encryption allowInsecure insecure; do
        raw=$( _vless_param "$key" "$query" 2>/dev/null ) || continue
        value=$( _vless_urldecode "$raw" ) || { vless_error "Invalid URL encoding"; return 1; }
        case "$key" in
            type) type=$value;; security) security=$value;; sni) sni=$value;; host) host=$value;;
            path) path=$value;; serviceName) service_name=$value;; flow) flow=$value;; fp) fp=$value;;
            pbk) pbk=$value;; sid) sid=$value;; alpn) alpn=$value;; encryption) encryption=$value;;
            allowInsecure|insecure) insecure=$value;;
        esac
    done

    name=$( _vless_urldecode "$fragment" ) || { vless_error "Invalid URL encoding"; return 1; }
    name=$(printf '%s' "$name" | LC_ALL=C tr -d '[:cntrl:]')

    [ -z "$encryption" ] || [ "$encryption" = "none" ] ||
        { vless_error "Unsupported VLESS encryption"; return 1; }
    case "$security" in ""|none|tls|reality) ;; *) vless_error "Unsupported VLESS security mode"; return 1;; esac

    insecure_json=false
    case "$insecure" in
        1|true|yes)
            [ "${VLESS_ALLOW_INSECURE:-0}" = "1" ] ||
                { vless_error "Insecure TLS requires explicit opt-in"; return 1; }
            insecure_json=true ;;
        "") ;;
        *) vless_error "Invalid insecure option"; return 1;;
    esac

    case "$type" in ""|tcp|ws|grpc) ;; *) vless_error "Unsupported transport"; return 1;; esac
    if [ "$security" = "reality" ]; then
        [ -n "$pbk" ] || { vless_error "Missing Reality public key"; return 1; }
        [ -n "$sid" ] || { vless_error "Missing Reality short ID"; return 1; }
        [ -n "$sni" ] || { vless_error "Missing Reality SNI"; return 1; }
    fi
    [ "$type" != "grpc" ] || [ -n "$service_name" ] ||
        { vless_error "Missing gRPC serviceName"; return 1; }
    [ "$type" != "ws" ] || [ -n "$path" ] || path="/"

    [ -z "$flow" ] || [ "$flow" = "xtls-rprx-vision" ] ||
        { vless_error "Unsupported VLESS flow"; return 1; }

    tls_enabled=false
    if [ "$security" = "tls" ] || [ "$security" = "reality" ]; then tls_enabled=true; fi

    jq -cn \
      --arg protocol vless --arg server "$server" --argjson server_port "$port" --arg uuid "$uuid" \
      --arg flow "$flow" --arg security "$security" --arg sni "$sni" --arg type "$type" \
      --arg path "$path" --arg host "$host" --arg service_name "$service_name" --arg fp "$fp" \
      --arg pbk "$pbk" --arg sid "$sid" --arg alpn "$alpn" --arg name "$name" \
      --argjson tls_enabled "$tls_enabled" --argjson insecure "$insecure_json" '
      {
        schema_version:1, protocol:$protocol, server:$server, server_port:$server_port, uuid:$uuid,
        flow:(if $flow!="" then $flow else null end),
        tls:{
          enabled:$tls_enabled,
          server_name:(if $sni!="" then $sni else null end),
          insecure:$insecure,
          utls:(if $fp!="" then {enabled:true,fingerprint:$fp} else null end),
          reality:(if $security=="reality" then {enabled:true,public_key:$pbk,short_id:$sid} else null end),
          alpn:(if $alpn!="" then ($alpn|split(",")) else null end)
        },
        transport:(
          if $type=="ws" then {type:"ws",path:$path,headers:(if $host!="" then {Host:$host} else {} end)}
          elif $type=="grpc" then {type:"grpc",service_name:$service_name}
          else {type:"tcp"} end
        ),
        metadata:{name:(if $name!="" then $name else null end)
      }'
}

if [ "${0##*/}" = "parser.sh" ] && [ "$#" -gt 0 ]; then vless_parse "$1"; fi

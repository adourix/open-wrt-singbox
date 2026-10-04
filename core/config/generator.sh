#!/bin/sh
# Generate a deterministic sing-box outbound from a normalized profile.
# This layer intentionally does not accept VMess/VLESS URLs.

generate_config() {
    profile=$1
    [ -n "$profile" ] || { printf '%s\n' "Missing normalized profile" >&2; return 1; }

    printf '%s' "$profile" | jq -e '
      type=="object"
      and .schema_version==1
      and (.protocol=="vmess" or .protocol=="vless")
      and (.server|type)=="string"
      and (.server_port|type)=="number"
      and (.uuid|type)=="string"
      and (.tls|type)=="object"
      and (.transport|type)=="object"
    ' >/dev/null 2>&1 || {
        printf '%s\n' "Invalid normalized profile" >&2
        return 1
    }

    printf '%s' "$profile" | jq -e '
      if .transport.type=="ws" then
        (.transport.path|type)=="string" and (.transport.headers|type)=="object"
      elif .transport.type=="grpc" then
        (.transport.service_name|type)=="string"
      elif .transport.type=="tcp" then true
      else false end
    ' >/dev/null 2>&1 || {
        printf '%s\n' "Invalid normalized transport" >&2
        return 1
    }

    printf '%s' "$profile" | jq -e '
      if .protocol=="vmess" then
        (.alter_id|type)=="number" and (.security|type)=="string"
      else true end
    ' >/dev/null 2>&1 || {
        printf '%s\n' "Invalid VMess profile" >&2
        return 1
    }

    printf '%s' "$profile" | jq -e '
      if .protocol=="vless" and .flow != null then (.flow|type)=="string" else true end
    ' >/dev/null 2>&1 || {
        printf '%s\n' "Invalid VLESS profile" >&2
        return 1
    }

    # The output below is the project's internal generation boundary.
    # Exact sing-box fields are kept here, not in protocol parsers.
    printf '%s' "$profile" | jq -c '
      . as $p |
      {
        log: {level:"warn"},
        outbounds: [
          (
            {
              type: $p.protocol,
              tag: "proxy",
              server: $p.server,
              server_port: $p.server_port,
              uuid: $p.uuid
            }
            + (if $p.protocol == "vmess" then
                {alter_id:$p.alter_id, security:$p.security}
               else
                (if $p.flow != null then {flow:$p.flow} else {} end)
               end)
            + (if $p.tls.enabled then
                {tls:({
                  enabled:true
                }
                + (if $p.tls.server_name != null then {server_name:$p.tls.server_name} else {} end)
                + (if $p.tls.insecure then {insecure:true} else {} end)
                + (if $p.tls.alpn != null then {alpn:$p.tls.alpn} else {} end)
                + (if $p.tls.utls != null then {utls:$p.tls.utls} else {} end)
                + (if $p.tls.reality != null then {reality:$p.tls.reality} else {} end))}
               else {} end)
            + (if $p.transport.type == "ws" then
                {transport:{type:"ws",path:$p.transport.path,headers:$p.transport.headers}}
               elif $p.transport.type == "grpc" then
                {transport:{type:"grpc",service_name:$p.transport.service_name}}
               else {} end)
          )
        ]
      }'
}

if [ "\${0##*/}" = "generator.sh" ] && [ "$#" -gt 0 ]; then
    generate_config "$1"
fi

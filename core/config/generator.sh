#!/bin/sh
# Generate deterministic sing-box 1.13.x configuration from a normalized profile.

generate_config() {
    profile=$1
    [ -n "$profile" ] || { printf '%s\n' 'Missing normalized profile' >&2; return 1; }

    printf '%s' "$profile" | jq -e '
      type=="object" and .schema_version==1
      and (.protocol=="vmess" or .protocol=="vless")
      and (.server|type)=="string" and (.server|length)>0
      and (.server_port|type)=="number" and (.server_port>=1 and .server_port<=65535)
      and (.uuid|type)=="string"
      and (.tls|type)=="object"
      and (.transport|type)=="object"
      and (.metadata|type)=="object"
    ' >/dev/null 2>&1 || { printf '%s\n' 'Invalid normalized profile' >&2; return 1; }

    printf '%s' "$profile" | jq -e '
      (.tls.enabled|type)=="boolean" and (.tls.insecure|type)=="boolean"
      and ((.tls.server_name==null) or (.tls.server_name|type)=="string")
      and ((.tls.utls==null) or (.tls.utls|type)=="object")
      and ((.tls.reality==null) or (.tls.reality|type)=="object")
      and ((.tls.alpn==null) or (.tls.alpn|type)=="array")
      and (.transport.type=="tcp" or .transport.type=="ws" or .transport.type=="grpc")
    ' >/dev/null 2>&1 || { printf '%s\n' 'Invalid normalized TLS/transport' >&2; return 1; }

    printf '%s' "$profile" | jq -e '
      if .transport.type=="ws" then (.transport.path|type)=="string" and (.transport.headers|type)=="object"
      elif .transport.type=="grpc" then (.transport.service_name|type)=="string" and (.transport.service_name|length)>0
      else true end
    ' >/dev/null 2>&1 || { printf '%s\n' 'Invalid normalized transport' >&2; return 1; }

    printf '%s' "$profile" | jq -e '
      if .protocol=="vmess" then (.alter_id|type)=="number" and (.alter_id>=0) and (.security|type)=="string" else true end
    ' >/dev/null 2>&1 || { printf '%s\n' 'Invalid VMess profile' >&2; return 1; }

    printf '%s' "$profile" | jq -e '
      if .protocol=="vless" and .flow != null then (.flow|type)=="string" else true end
    ' >/dev/null 2>&1 || { printf '%s\n' 'Invalid VLESS flow' >&2; return 1; }

    printf '%s' "$profile" | jq -c '
      . as $p |
      def tls:
        if $p.tls.enabled then
          {enabled:true}
          + (if $p.tls.server_name != null then {server_name:$p.tls.server_name} else {} end)
          + (if $p.tls.insecure then {insecure:true} else {} end)
          + (if $p.tls.alpn != null then {alpn:$p.tls.alpn} else {} end)
          + (if $p.tls.utls != null then {utls:$p.tls.utls} else {} end)
          + (if $p.tls.reality != null then {reality:$p.tls.reality} else {} end)
        else null end;
      def transport:
        if $p.transport.type=="ws" then {type:"ws",path:$p.transport.path,headers:$p.transport.headers}
        elif $p.transport.type=="grpc" then {type:"grpc",service_name:$p.transport.service_name}
        else null end;
      def proxy_outbound:
        ({type:$p.protocol,tag:"proxy",server:$p.server,server_port:$p.server_port,uuid:$p.uuid}
        + (if $p.protocol=="vmess" then {alter_id:$p.alter_id,security:$p.security}
           elif $p.flow != null then {flow:$p.flow} else {} end)
        + (if tls != null then {tls:tls} else {} end)
        + (if transport != null then {transport:transport} else {} end));
      {
        log:{level:"warn"},
        dns:{
          servers:[{type:"local",tag:"local"}],
          final:"local",
          strategy:"ipv4_only"
        },
        inbounds:[{
          type:"tun", tag:"tun-in", interface_name:"singtun0",
          address:["172.19.0.1/30"], auto_route:true, auto_redirect:true,
          strict_route:false
        }],
        outbounds:[proxy_outbound,{type:"direct",tag:"direct"}],
        route:{
          auto_detect_interface:true,
          default_domain_resolver:"local",
          rules:[
            {action:"sniff"},
            {protocol:"dns",action:"hijack-dns"},
            {ip_is_private:true,outbound:"direct"}
          ],
          final:"proxy"
        }
      }'
}

if [ "${0##*/}" = "generator.sh" ] && [ "$#" -gt 0 ]; then
    generate_config "$1"
fi

# Normalized Profile v1

The protocol parsers produce this JSON contract. The config generator consumes this contract and must not parse VMess/VLESS share URLs itself.

## Required top-level fields
- schema_version: integer, currently 1
- protocol: vmess or vless
- server: hostname or IP literal
- server_port: integer 1..65535
- uuid: validated UUID string
- tls: object
- transport: object
- metadata: object

## VMess-only
- alter_id: non-negative integer
- security: VMess cipher/security string

## VLESS-only
- flow: string or null

## TLS
- enabled: boolean
- server_name: string or null
- insecure: boolean
- utls: object or null
- reality: object or null
- alpn: array of strings or null

## Transport
- TCP: {type: tcp}
- WebSocket: {type: ws, path: /, headers: {Host: example.com}}
- gRPC: {type: grpc, service_name: name}

The normalized profile is an internal contract. It is not itself a sing-box configuration. The generator maps it to the exact sing-box schema supported by the pinned engine version.
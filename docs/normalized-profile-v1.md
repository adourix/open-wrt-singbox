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
- pinned_cert_sha256: array of lowercase 64-hex strings or null. Xray
  certificate pin from the share-link `pcs` parameter: SHA-256 of the whole
  leaf certificate. Plain TLS only (ignored for Reality).
- verify_names: array of names or null. From the share-link `vcn` parameter:
  the name the certificate must be valid for when it differs from the SNI.
- certificate_public_key_sha256: array of base64 SHA-256 public-key hashes, or
  absent. Never produced by a parser; added by the manager at apply time.

### Certificate pin / verification name mapping

sing-box 1.13 cannot consume an Xray certificate pin (it pins the public key,
not the certificate) and cannot verify a name other than the SNI. At apply time
`cowboy-bebop-manager`:

1. Fetches the server's leaf certificate with `openssl s_client` (when
   `openssl` is installed), checks its SHA-256 against `pinned_cert_sha256`
   and, on a match, writes the public-key hash to
   `certificate_public_key_sha256`. sing-box then verifies only that key.
2. Rejects the profile when the fetched certificate does not match the pin.
3. When the pin cannot be checked (no `openssl`, server unreachable) or only a
   differing `vcn` is present, sets `insecure: true` only if the UCI
   `allow_insecure` policy is `1`; otherwise the apply fails.

The generator refuses a profile that still carries an unresolved pin or a
differing verification name, so a requested check is never silently dropped.

## Transport
- TCP: {type: tcp}
- WebSocket: {type: ws, path: /, headers: {Host: example.com}}
- gRPC: {type: grpc, service_name: name}

The normalized profile is an internal contract. It is not itself a sing-box configuration. The generator maps it to the exact sing-box schema supported by the pinned engine version.
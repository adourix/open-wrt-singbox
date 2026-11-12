# VMess share links

Format: `vmess://BASE64(JSON)` (max 8192 bytes, untrusted input, never evaluated).

Base64: standard or URL-safe alphabet, with 0, 1 or 2 `=` padding characters or
none, surrounding whitespace ignored.

| JSON key | Meaning | Handling |
|---|---|---|
| `add`, `port`, `id` | server, port, UUID | required; port may be a number or string |
| `aid` | alter ID | number or string, default 0 |
| `scy` | cipher | default `auto` |
| `net` | transport | `tcp` (default), `ws`, `grpc` |
| `host`, `path` | WebSocket Host header / path | path defaults to `/` |
| `serviceName` | gRPC service | required for `grpc` |
| `tls` | `tls` / empty | enables TLS |
| `sni`, `fp` | server name, uTLS fingerprint | optional |
| `pcs`, `vcn` | Xray certificate pin / verify name | same handling as VLESS |
| `ps` | display name | metadata only |

Errors: `Invalid VMess Base64`, `Invalid VMess JSON`, `Invalid VMess UUID`,
`Missing VMess server`, `Invalid VMess port`, `Unsupported transport`.

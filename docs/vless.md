# VLESS share links

Format: `vless://UUID@HOST:PORT?PARAMETERS#NAME` (max 8192 bytes, untrusted input, never evaluated).

| Parameter | Meaning | Handling |
|---|---|---|
| `type` | transport | `tcp` (default), `ws`, `grpc`; anything else → `Unsupported transport` |
| `headerType` | Xray TCP header | empty/`none` only; `http` → `Unsupported transport` |
| `security` | `none`, `tls`, `reality` | anything else → `Unsupported VLESS security mode` |
| `encryption` | must be `none` or absent | otherwise `Unsupported VLESS encryption` |
| `sni` | TLS server name | `tls.server_name` |
| `host`, `path` | WebSocket Host header / path | path defaults to `/` |
| `serviceName` | gRPC service | required for `grpc` |
| `flow` | only `xtls-rprx-vision` | otherwise `Unsupported VLESS flow` |
| `fp` | uTLS fingerprint | `tls.utls.fingerprint` |
| `alpn` | comma-separated list | `tls.alpn` |
| `pbk`, `sid` | Reality public key / short ID | required and validated for `reality` |
| `allowInsecure`, `insecure` | skip verification | only with the `allow_insecure` policy |
| `pcs` | Xray pinned certificate SHA-256 (hex, optional colons, comma list) | `tls.pinned_cert_sha256`, plain TLS only |
| `vcn` | Xray verify-certificate-by-name | `tls.verify_names`, plain TLS only |

Unknown parameters are ignored and never passed to sing-box. IPv6 servers must
use brackets. The `#NAME` fragment is URL-decoded and stripped of control
characters.

`pcs`/`vcn` have no direct sing-box equivalent; see
[normalized-profile-v1.md](normalized-profile-v1.md) for how they are enforced.

Example shapes (placeholders):

```text
vless://<UUID>@<FRONT_HOST>:443?type=ws&security=tls&sni=<SNI>&host=<SNI>&path=%2F<PATH>&fp=ios&alpn=http%2F1.1&encryption=none#Name
vless://<UUID>@<IP>:<PORT>?type=tcp&headerType=none&security=tls&sni=<DECOY_SNI>&vcn=<CERT_NAME>&pcs=<CERT_SHA256>&fp=chrome&alpn=http%2F1.1&encryption=none#Name
```

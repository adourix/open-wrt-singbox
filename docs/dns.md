# DNS

```json
"dns": {
  "servers": [
    {"type": "udp", "tag": "configured-dns-0", "server": "1.1.1.1", "server_port": 53},
    {"type": "udp", "tag": "configured-dns-1", "server": "8.8.8.8", "server_port": 53}
  ],
  "final": "configured-dns-0",
  "strategy": "ipv4_only"
}
```

- The proxy outbound and `route.default_domain_resolver` use
  `configured-dns-0` with `ipv4_only`, so a hostname proxy endpoint resolves
  without going through the proxy.
- Both resolver addresses are routed `direct` (see [routing.md](routing.md)).
- Do **not** add `"detour": "direct"` to the DNS servers. sing-box accepts it in
  `check` but refuses to start: `detour to an empty direct outbound makes no
  sense`. The integration test starts every generated config to catch this.
- LAN clients keep using dnsmasq on the router; sing-box does not bind port 53.
  DNS that enters the TUN on port 53 is answered through `hijack-dns`.
- No fake-IP in the MVP.

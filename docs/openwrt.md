# OpenWrt Compatibility

## Pinned development target

- OpenWrt: 25.12.5
- Target: x86_64
- sing-box: 1.13.21
- Firewall: fw4/nftables
- Shell: BusyBox ash
- Required runtime tools: jq, nft, ip, uci, procd

The installed sing-box version is the source of truth for generated syntax. The
manager refuses to rely on deprecated pre-1.13 route syntax and the generator
targets the pinned 1.13 configuration model.

## Runtime architecture

```text
LuCI
  |
  v
rpcd -> singbox-manager
          |
          +-- parser / normalized profile
          +-- generator
          +-- validator
          +-- procd service
          +-- nftables safety policy
          |
          v
      sing-box 1.13.21
          |
       singtun0
```

Project-specific paths:

- UCI: `/etc/config/singbox`
- Generated config: `/etc/singbox/config.json`
- Candidate: `/etc/singbox/config.json.new`
- Backup: `/etc/singbox/config.json.bak`
- Pending confirmation: `/etc/singbox/config.pending`
- Init: `/etc/init.d/singbox`
- Manager: `/usr/bin/singbox-manager`
- Runtime library: `/usr/lib/singbox-manager/`

## TUN policy

The generator uses:

- `auto_route: true`
- `auto_redirect: true`
- `strict_route: false`

`auto_redirect` is the router-oriented Linux mechanism for sing-box 1.13.x.
It integrates with OpenWrt fw4 without the project editing fw4-owned tables.

The project-owned nftables table is `inet singbox`. It contains only safety
policy owned by this application. It currently blocks IPv6 forwarding from
`br-lan` because the MVP TUN is IPv4-only. Router input/management is not
blocked by this rule.

## DNS

OpenWrt/dnsmasq remains the LAN DNS service. sing-box does not bind port 53.

The generated sing-box config uses a local DNS server and the route actions:

```json
[
  { "action": "sniff" },
  { "protocol": "dns", "action": "hijack-dns" },
  { "ip_is_private": true, "outbound": "direct" }
]
```

The DNS strategy is IPv4-only for the MVP so IPv6 cannot bypass the proxy.

## Safety / recovery

Every apply:

1. parses the URL;
2. generates a candidate;
3. validates with `sing-box check`;
4. backs up the current config;
5. atomically installs the candidate;
6. restarts the service;
7. verifies process, TUN, routing and connectivity;
8. starts a 60-second commit-confirm timer.

Run:

```sh
singbox-manager confirm
```

to commit the new configuration. If confirmation is not received, the previous
valid configuration is restored. A reboot while confirmation is pending also
causes the init script to restore the backup before starting the service.

Recovery is:

```sh
singbox-manager recovery
```

Recovery is idempotent and removes the project-owned nftables table.

## Important separation

The OpenWrt feed may provide its own sing-box package and integration. This
project does not modify or co-enable that integration. The project service is
named `singbox` and owns only its documented paths.

The `tests/` directory is development/CI only and is never installed into the
runtime packages.

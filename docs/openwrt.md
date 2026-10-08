# OpenWrt Compatibility

## Pinned development target

- OpenWrt: 25.12.5
- Target: x86_64
- sing-box: 1.13.21
- Firewall: fw4/nftables
- Shell: BusyBox ash
- Required runtime tools: jq, nft, ip, uci, procd, uclient-fetch
- Required kernel capabilities: TUN and nfnetlink queue for sing-box `auto_redirect`

The installed sing-box version is the source of truth for generated syntax. The
manager refuses to rely on deprecated pre-1.13 route syntax and the generator
targets the pinned 1.13 configuration model.

## Runtime architecture

```text
LuCI
  |
  v
rpcd -> cowboy-bebop
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

- UCI: `/etc/config/cowboy-bebop`
- Generated config: `/etc/cowboy-bebop/config.json`
- Candidate: `/etc/cowboy-bebop/config.json.new`
- Backup: `/etc/cowboy-bebop/config.json.bak`
- Pending confirmation: `/etc/cowboy-bebop/config.pending`
- Pending desired-state backup: `/etc/cowboy-bebop/state.pending.json`
- Init: `/etc/init.d/cowboy-bebop`
- Manager: `/usr/bin/cowboy-bebop`
- Runtime library: `/usr/lib/cowboy-bebop/`

## Runtime architecture and state

The UCI configuration is desired state. The running sing-box process, TUN
interface, routing state and firewall state are actual state. `cowboy-bebop`
reconciles them and never lets LuCI edit Linux networking directly.

## TUN policy

The generator uses:

- `auto_route: true`
- `auto_redirect: true`
- `strict_route: false`

`auto_redirect` is the router-oriented Linux mechanism for sing-box 1.13.x.
It integrates with OpenWrt fw4 without the project editing fw4-owned tables.

The project-owned nftables table is `inet singbox`. It contains only safety
policy owned by this application. It blocks IPv6 forwarding from `br-lan`
because the MVP TUN is IPv4-only. Router input/management is not blocked by
this rule. The safety rule intentionally has no nft comment so it remains
portable across OpenWrt nft CLI parsers.

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

## Explicit insecure TLS opt-in

VLESS links containing `allowInsecure=1` or `insecure=1` are rejected by
default. LuCI exposes an explicit `Allow insecure TLS` control. The setting is
stored as `allow_insecure` in UCI and is only passed to the VLESS parser during
an apply/preview operation when enabled.

## Save & Apply and desired-state safety

LuCI's `Save & Apply` is one transactional operation. The new URL and settings
are not committed to UCI until parsing, generation, `sing-box check`, service
restart, TUN/routing checks and connectivity verification all succeed. A
failed apply therefore leaves both the previous runtime configuration and the
previous desired UCI state intact.

The browser never receives the stored proxy URL back. After a successful save,
the input is cleared and LuCI displays `Saved - hidden` plus non-sensitive
profile information.

## Safety / recovery

Every apply:

1. reads the requested URL and settings;
2. detects the protocol;
3. parses and normalizes the profile;
4. generates a candidate;
5. validates with `sing-box check`;
6. backs up the current config;
7. atomically installs the candidate;
8. restarts the service;
9. verifies process, TUN, routing and connectivity;
10. creates a root-only pending desired-state backup;
11. starts a 60-second commit-confirm timer;
12. commits the new desired UCI state.

Run:

```sh
cowboy-bebop confirm
```

to commit the new configuration. If confirmation is not received, the previous
valid configuration and previous desired UCI state are restored. A reboot while
confirmation is pending also restores both before the service is started.

Recovery is:

```sh
cowboy-bebop recovery
```

Recovery is idempotent and removes the project-owned nftables table.

## Important separation

The OpenWrt feed may provide its own sing-box package and integration. This
project does not modify or co-enable that integration. The project service is
named `singbox` and owns only its documented paths.

The `tests/` directory is development/CI only and is never installed into the
runtime packages.

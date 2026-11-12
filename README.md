# Cowboy Bebop Manager

A lightweight OpenWrt management application for configuring and controlling sing-box through LuCI.

The project accepts VMess and VLESS share URLs, detects the protocol automatically, parses them into a normalized profile, generates a sing-box configuration, validates it, and manages the service.

## MVP

The intended MVP flow is:

1. Install `cowboy-bebop-manager` and `luci-app-cowboy-bebop` on supported OpenWrt.
2. Open **LuCI → Services → Cowboy Bebop**.
3. Paste a `vmess://` or `vless://` URL.
4. Preview the detected protocol/profile.
5. Save & Apply.
6. Validate the generated configuration with `sing-box check`.
7. Start the TUN service and verify process, TUN, routing and connectivity.
8. Confirm the configuration or let the safety rollback restore the previous state.

The core manager also works without LuCI through `cowboy-bebop-manager`.

## Pinned runtime

- OpenWrt 25.12.5
- sing-box 1.13.21
- BusyBox ash + jq + UCI + procd + nftables/fw4
- `sing-box-tiny` package on the target router
- TUN with `auto_route` + `auto_redirect`
- IPv4-only MVP with explicit IPv6 bypass blocking

## Packages

This repository builds exactly three packages:

- `cowboy-bebop-manager` — core CLI, parser, generator, procd service (no LuCI dependency)
- `luci-app-cowboy-bebop` — LuCI page under **Services → Cowboy Bebop**; works with any stock LuCI theme
- `cowboy-bebop-branding` — optional SSH banner/status line and removal of third-party reseller
  identity (board model text, reseller LuCI theme) from the UI

Runtime dependency: `sing-box-tiny` from the matching OpenWrt feed. Do not install the full
`sing-box` package next to it. Optional: `openssl-util` (see below).

The former `luci-theme-cowboy-bebop` package was removed. Installing the new LuCI app or
branding package switches LuCI back to the bootstrap theme if it still points at it.

## Supported share links

`vmess://` (Base64 JSON) and `vless://` with TCP, WebSocket or gRPC transports and
none/TLS/Reality security, including `fp`, `alpn`, `host`, `path`, `flow`, `pbk`/`sid`.

Xray certificate options are supported:

- `pcs` (pinned certificate SHA-256) and `vcn` (verify certificate by name) are parsed.
- sing-box only pins public keys, so on apply the manager fetches the server certificate,
  checks it against `pcs` and enforces the matching public-key pin. This needs `openssl`
  (`apk add openssl-util`).
- A certificate that does not match the pin is always rejected.
- Without `openssl`, or for a `vcn` that differs from the SNI, verification is disabled
  only if UCI `cowboy-bebop.main.allow_insecure` is `1` (the default); otherwise apply fails.
- `headerType=http` (Xray TCP HTTP obfuscation) has no sing-box equivalent and is rejected.

The runtime does not require Node.js, Docker, Python, React, Vue, or a permanent backend process.

The user-facing OpenWrt service is `cowboy-bebop`, and the LuCI page is available at
`/admin/services/cowboy-bebop`.

Auto Start and insecure-TLS policy are fixed by the current MVP policy and are intentionally not exposed as primary UI controls.

## Test order

1. Run the shell/parser/generator tests.
2. Build the three OpenWrt packages with the 25.12.5 SDK.
3. Install them on the OpenWrt x86_64 VM or KT-708 target.
4. Configure one VLESS or VMess URL.
5. Run `cowboy-bebop-manager apply` or use **Save & Apply** in LuCI.
6. Verify `cowboy-bebop-manager health`, TUN, routing, DNS, LAN forwarding and connectivity.
7. Test OFF, ON, recovery, reboot and failed-server rollback.
8. Build the final image with `openwrt/imagebuilder` after package-level validation.

## Important

The project is designed as an OpenWrt package, not as a web application. Production routers should not need Node.js, Docker or a permanent application server.

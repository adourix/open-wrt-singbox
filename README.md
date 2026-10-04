# OpenWrt Sing-box Manager

A lightweight OpenWrt management application for configuring and controlling sing-box through LuCI.

The project accepts VMess and VLESS share URLs, detects the protocol automatically, parses them into a normalized profile, generates a sing-box configuration, validates it, and manages the service.

## Development

Phase 1 starts with protocol detection and parsers. The core is designed to run without LuCI and without a permanent application server.

See the project specification supplied with this repository, and `docs/openwrt.md` for the pinned OpenWrt/sing-box runtime contract.


## Pinned runtime

- OpenWrt 25.12.5 x86_64
- sing-box 1.13.21
- BusyBox ash + jq + UCI + procd + nftables/fw4
- TUN with `auto_route` + `auto_redirect`
- IPv4-only MVP with explicit IPv6 leak blocking

## Runtime packages

- `singbox-manager`
- `luci-app-singbox`
- `sing-box` from the matching OpenWrt feed

The runtime does not require Node.js, Docker, Python, React, Vue, or a permanent
backend process.

## Test order

1. Run the shell/parser/generator tests.
2. Build the two OpenWrt packages with the 25.12.5 SDK.
3. Install them on the OpenWrt x86_64 VM.
4. Configure one VLESS or VMess URL.
5. Run `singbox-manager apply`.
6. Verify `sing-box health`, TUN, routing, DNS, LAN forwarding and connectivity.
7. Test OFF, ON, recovery, reboot and failed-server rollback.
8. Build the final combined-efi image with `openwrt/imagebuilder`.

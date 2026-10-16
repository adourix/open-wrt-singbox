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

## Runtime packages

- `cowboy-bebop-manager`
- `luci-app-cowboy-bebop`
- `sing-box-tiny` from the matching OpenWrt feed

The runtime does not require Node.js, Docker, Python, React, Vue, or a permanent backend process.

The user-facing OpenWrt service is `cowboy-bebop`, and the LuCI page is available at
`/admin/services/cowboy-bebop`.

Auto Start and insecure-TLS policy are fixed by the current MVP policy and are intentionally not exposed as primary UI controls.

## Test order

1. Run the shell/parser/generator tests.
2. Build the two OpenWrt packages with the 25.12.5 SDK.
3. Install them on the OpenWrt x86_64 VM or KT-708 target.
4. Configure one VLESS or VMess URL.
5. Run `cowboy-bebop-manager apply` or use **Save & Apply** in LuCI.
6. Verify `cowboy-bebop-manager health`, TUN, routing, DNS, LAN forwarding and connectivity.
7. Test OFF, ON, recovery, reboot and failed-server rollback.
8. Build the final image with `openwrt/imagebuilder` after package-level validation.

## Important

The project is designed as an OpenWrt package, not as a web application. Production routers should not need Node.js, Docker or a permanent application server.

# OpenWrt Sing-box Manager

A lightweight OpenWrt management application for configuring and controlling sing-box through LuCI.

The project accepts VMess and VLESS share URLs, detects the protocol automatically, parses them into a normalized profile, generates a sing-box configuration, validates it, and manages the service.

## Development

Phase 1 starts with protocol detection and parsers. The core is designed to run without LuCI and without a permanent application server.

See the project specification supplied with this repository, and `docs/openwrt.md` for the pinned OpenWrt/sing-box runtime contract.

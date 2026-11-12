# Image Builder

Targets:

- OpenWrt 25.12.5
- x86_64 generic EFI (`PROFILE=generic`) and ipq40xx/generic KT-708 (`PROFILE=mercury_ti04-708h`)
- sing-box-tiny 1.13.21 (pulled in by `cowboy-bebop-manager`)
- cowboy-bebop-manager
- luci-app-cowboy-bebop
- cowboy-bebop-branding
- jq, nftables/fw4, Tailscale
- openssl-util (optional, enables real certificate pinning for `pcs` links)

The image uses the stock LuCI bootstrap theme. The underlying platform remains
the pinned OpenWrt release.

Secrets are never embedded in the image. Add the proxy URL after first boot
through LuCI or UCI. Add the Tailscale authentication key separately.

## Build flow

1. Build the manager, LuCI app and branding packages with the matching OpenWrt SDK.
2. Set `IMAGEBUILDER`, `MANAGER_PKG`, `LUCI_PKG` and `BRANDING_PKG`.
3. Run `./build.sh` (uses this `files/` directory as custom files).

The x86 output is a combined EFI disk image, not an ISO. It can be converted to
qcow2/vmdk with `qemu-img`.

Do not add the full `sing-box` package: it conflicts with `sing-box-tiny`. The
feed's own sing-box init script and config are never enabled by this project.

# x86_64 Image Builder

Target:

- OpenWrt 25.12.5
- x86_64 generic EFI
- sing-box 1.13.21 package
- cowboy-bebop-manager
- luci-app-cowboy-bebop
- luci-theme-cowboy-bebop
- cowboy-bebop-branding
- jq
- nftables/fw4
- Tailscale

The image presents a private management interface and does not use the default LuCI visual identity. The underlying platform remains the pinned runtime target.

Secrets are never embedded in the image. Add the proxy URL after first boot through the management interface or UCI. Add the Tailscale authentication key separately.

## Build flow

1. Build the manager, LuCI app, private theme and branding packages with the matching OpenWrt SDK.
2. Place the resulting `.apk` packages in an ImageBuilder package directory.
3. Set `MANAGER_PKG`, `LUCI_PKG`, `THEME_PKG` and `BRANDING_PKG`.
4. Use this `files/` directory as custom files.
5. Run the ImageBuilder with the generic x86_64 EFI profile.

The output is a combined EFI disk image, not an ISO. It can be converted to qcow2/vmdk with `qemu-img`.

The package feed's sing-box package remains the engine dependency; this project does not overwrite its files or enable its separate integration.

# x86_64 Image Builder

Target:

- OpenWrt 25.12.5
- x86_64 generic EFI
- sing-box 1.13.21 package
- cowboy-bebop
- luci-app-cowboy-bebop
- jq
- nftables/fw4
- Tailscale

Secrets are never embedded in the image. Add the proxy URL after first boot
through LuCI or UCI. Add the Tailscale authentication key separately.

## Build flow

1. Build `cowboy-bebop` and `luci-app-cowboy-bebop` with the matching OpenWrt SDK.
2. Place the resulting packages in an ImageBuilder package directory.
3. Use this `files/` directory as custom files.
4. Run the ImageBuilder with the generic x86_64 EFI profile.

OpenWrt produces a combined EFI disk image, not an ISO. The output can be
converted to qcow2/vmdk with `qemu-img`.

The package feed's sing-box package remains the engine dependency; this project
does not overwrite its files or enable its separate integration.

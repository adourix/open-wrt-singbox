include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for sing-box
LUCI_DEPENDS:=+singbox-manager +rpcd +luci-base
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

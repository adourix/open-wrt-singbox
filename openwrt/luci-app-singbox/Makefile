include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for sing-box manager
LUCI_DEPENDS:=+luci-base +rpcd +singbox-manager
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad

define Package/luci-app-singbox/postinst
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
    chmod 0755 /usr/libexec/rpcd/luci.singbox 2>/dev/null || true
    /etc/init.d/rpcd reload 2>/dev/null || true
    rm -f /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
}
exit 0
endef

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature

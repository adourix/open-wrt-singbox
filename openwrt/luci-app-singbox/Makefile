include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox
PKG_RELEASE:=4
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-singbox
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for sing-box manager
  DEPENDS:=+luci-base +rpcd +singbox-manager
  PKGARCH:=all
endef

define Package/luci-app-singbox/description
LuCI interface for the lightweight sing-box manager.
endef

define Package/luci-app-singbox/postinst
#!/bin/sh
[ -n "$(IPKG_INSTROOT)" ] || {
    chmod 0755 /usr/libexec/rpcd/luci.singbox 2>/dev/null || true
    /etc/init.d/rpcd reload 2>/dev/null || true
    rm -f /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
}
exit 0
endef

define Build/Compile
endef

define Package/luci-app-singbox/install
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/. $(1)/www/
	$(INSTALL_DIR) $(1)/
	$(CP) ./root/. $(1)/
endef

$(eval $(call BuildPackage,luci-app-singbox))

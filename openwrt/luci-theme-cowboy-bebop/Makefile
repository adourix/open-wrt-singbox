include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-cowboy-bebop
PKG_RELEASE:=2
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-cowboy-bebop
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=4. Themes
  TITLE:=Cowboy Bebop Manager Private Theme
  DEPENDS:=+luci-base
  PKGARCH:=all
endef

define Package/luci-theme-cowboy-bebop/description
Private, self-contained LuCI theme for Cowboy Bebop Manager.
endef

define Package/luci-theme-cowboy-bebop/postinst
#!/bin/sh
[ -n "$(IPKG_INSTROOT)" ] || {
    /etc/init.d/rpcd reload 2>/dev/null || true
    rm -f /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
}
exit 0
endef

define Build/Compile
endef

define Package/luci-theme-cowboy-bebop/install
	$(INSTALL_DIR) $(1)/www/luci-static/cowboy-bebop
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/cascade.css $(1)/www/luci-static/cowboy-bebop/cascade.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/mobile.css $(1)/www/luci-static/cowboy-bebop/mobile.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/logo.svg $(1)/www/luci-static/cowboy-bebop/logo.svg

	$(INSTALL_DIR) $(1)/www/luci-static/resources
	$(INSTALL_DATA) ./htdocs/luci-static/resources/menu-cowboy-bebop.js $(1)/www/luci-static/resources/menu-cowboy-bebop.js

	$(INSTALL_DIR) $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop
	$(INSTALL_DATA) ./ucode/template/themes/cowboy-bebop/header.ut $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop/header.ut
	$(INSTALL_DATA) ./ucode/template/themes/cowboy-bebop/footer.ut $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop/footer.ut
	$(INSTALL_DATA) ./ucode/template/themes/cowboy-bebop/sysauth.ut $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop/sysauth.ut

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/30_luci-theme-cowboy-bebop $(1)/etc/uci-defaults/30_luci-theme-cowboy-bebop
endef

$(eval $(call BuildPackage,luci-theme-cowboy-bebop))

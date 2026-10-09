include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-cowboy-bebop
PKG_RELEASE:=16
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-cowboy-bebop
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=4. Themes
  TITLE:=Cowboy Bebop full LuCI visual theme
  PKGARCH:=all
endef

define Package/luci-theme-cowboy-bebop/description
Full LuCI visual theme matching the project reference UI: dark compact navigation rail, clean light workspace, responsive forms and tables, and branded login page.
endef

define Package/luci-theme-cowboy-bebop/postinst
#!/bin/sh
[ -n "$(IPKG_INSTROOT)" ] || {
    uci -q set luci.themes.CowboyBebop=/luci-static/cowboy-bebop
    uci -q set luci.main.mediaurlbase=/luci-static/cowboy-bebop
    uci -q commit luci
}
exit 0
endef

define Build/Compile
endef

define Package/luci-theme-cowboy-bebop/install
	$(INSTALL_DIR) $(1)/www/luci-static/cowboy-bebop
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/cascade.css $(1)/www/luci-static/cowboy-bebop/cascade.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/reference.css $(1)/www/luci-static/cowboy-bebop/reference.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/mobile.css $(1)/www/luci-static/cowboy-bebop/mobile.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/sidebar.css $(1)/www/luci-static/cowboy-bebop/sidebar.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/navigation-fix.css $(1)/www/luci-static/cowboy-bebop/navigation-fix.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/dashboard-fix.css $(1)/www/luci-static/cowboy-bebop/dashboard-fix.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/controls-fix.css $(1)/www/luci-static/cowboy-bebop/controls-fix.css
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/logo.svg $(1)/www/luci-static/cowboy-bebop/logo.svg
	$(INSTALL_DATA) ./htdocs/luci-static/cowboy-bebop/actions-fix.css $(1)/www/luci-static/cowboy-bebop/actions-fix.css
	$(INSTALL_DIR) $(1)/www/luci-static/resources
	$(INSTALL_DATA) ./htdocs/luci-static/resources/menu-cowboy-bebop.js $(1)/www/luci-static/resources/menu-cowboy-bebop.js
	$(INSTALL_DATA) ./htdocs/luci-static/resources/dashboard-fix.js $(1)/www/luci-static/resources/dashboard-fix.js
	$(INSTALL_DIR) $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop
	$(INSTALL_DATA) ./ucode/template/themes/cowboy-bebop/header.ut $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop/header.ut
	$(INSTALL_DATA) ./ucode/template/themes/cowboy-bebop/footer.ut $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop/footer.ut
	$(INSTALL_DATA) ./ucode/template/themes/cowboy-bebop/sysauth.ut $(1)/usr/share/ucode/luci/template/themes/cowboy-bebop/sysauth.ut
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/30_luci-theme-cowboy-bebop $(1)/etc/uci-defaults/30_luci-theme-cowboy-bebop
endef

$(eval $(call BuildPackage,luci-theme-cowboy-bebop))

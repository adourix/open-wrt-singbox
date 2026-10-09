include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cowboy-bebop
PKG_RELEASE:=9
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-cowboy-bebop
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Cowboy Bebop Manager
  DEPENDS:=+luci-base +rpcd +cowboy-bebop-manager
  PKGARCH:=all
endef

define Package/luci-app-cowboy-bebop/description
LuCI interface for Cowboy Bebop Manager.
endef

define Package/luci-app-cowboy-bebop/postinst
#!/bin/sh
[ -n "$(IPKG_INSTROOT)" ] || {
    chmod 0755 /usr/libexec/rpcd/luci.cowboy_bebop 2>/dev/null || true
    /etc/init.d/rpcd reload 2>/dev/null || true
    rm -f /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
}
exit 0
endef

define Build/Compile
endef

define Package/luci-app-cowboy-bebop/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/cowboy-bebop
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cowboy-bebop/overview.js $(1)/www/luci-static/resources/view/cowboy-bebop/overview.js

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.cowboy_bebop $(1)/usr/libexec/rpcd/luci.cowboy_bebop

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	printf '%s\n' '{' '  "admin/services/cowboy-bebop": {' '    "title": "Cowboy Bebop Manager",' '    "order": 90,' '    "action": {' '      "type": "view",' '      "path": "cowboy-bebop/overview"' '    },' '    "depends": {' '      "acl": ["luci-app-cowboy-bebop"]' '    }' '  }' '}' > $(1)/usr/share/luci/menu.d/luci-app-cowboy-bebop.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	printf '%s\n' '{' '  "luci-app-cowboy-bebop": {' '    "description": "Allow LuCI to manage Cowboy Bebop Manager without exposing proxy credentials",' '    "read": {' '      "ubus": {' '        "luci.cowboy_bebop": ["status", "health", "logs", "preview", "confirm"]' '      }' '    },' '    "write": {' '      "ubus": {' '        "luci.cowboy_bebop": ["apply", "start", "stop", "set_enabled", "confirm"]' '      }' '    }' '  }' '}' > $(1)/usr/share/rpcd/acl.d/luci-app-cowboy-bebop.json
endef

$(eval $(call BuildPackage,luci-app-cowboy-bebop))

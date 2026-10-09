include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cowboy-bebop
PKG_RELEASE:=10
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
Native LuCI application for Cowboy Bebop Manager; preserves the stock LuCI navigation, theme, login, and router pages.
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
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cowboy-bebop/overview.css $(1)/www/luci-static/resources/view/cowboy-bebop/overview.css
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cowboy-bebop/mobile.css $(1)/www/luci-static/resources/view/cowboy-bebop/mobile.css
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cowboy-bebop/configuration.js $(1)/www/luci-static/resources/view/cowboy-bebop/configuration.js
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cowboy-bebop/diagnostics.js $(1)/www/luci-static/resources/view/cowboy-bebop/diagnostics.js
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/cowboy-bebop/recovery.js $(1)/www/luci-static/resources/view/cowboy-bebop/recovery.js
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.cowboy_bebop $(1)/usr/libexec/rpcd/luci.cowboy_bebop
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	printf '%s\n' '{' '  "admin/services/cowboy-bebop": {' '    "title": "Cowboy Bebop Manager",' '    "order": 90,' '    "action": {' '      "type": "view",' '      "path": "cowboy-bebop/overview"' '    },' '    "depends": {' '      "acl": ["luci-app-cowboy-bebop"]' '    }' '  },' '  "admin/services/cowboy-bebop/configuration": {' '    "title": "Configuration",' '    "order": 10,' '    "action": {' '      "type": "view",' '      "path": "cowboy-bebop/configuration"' '    },' '    "depends": {' '      "acl": ["luci-app-cowboy-bebop"]' '    }' '  },' '  "admin/services/cowboy-bebop/diagnostics": {' '    "title": "Logs & Diagnostics",' '    "order": 20,' '    "action": {' '      "type": "view",' '      "path": "cowboy-bebop/diagnostics"' '    },' '    "depends": {' '      "acl": ["luci-app-cowboy-bebop"]' '    }' '  },' '  "admin/services/cowboy-bebop/recovery": {' '    "title": "Recovery",' '    "order": 30,' '    "action": {' '      "type": "view",' '      "path": "cowboy-bebop/recovery"' '    },' '    "depends": {' '      "acl": ["luci-app-cowboy-bebop"]' '    }' '  }' '}' > $(1)/usr/share/luci/menu.d/luci-app-cowboy-bebop.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	printf '%s\n' '{' '  "luci-app-cowboy-bebop": {' '    "description": "Manage Cowboy Bebop without exposing saved proxy credentials",' '    "read": {' '      "ubus": {' '        "luci.cowboy_bebop": ["status", "health", "logs", "preview", "confirm", "settings"]' '      }' '    },' '    "write": {' '      "ubus": {' '        "luci.cowboy_bebop": ["apply", "start", "stop", "set_enabled", "set_settings", "recovery", "confirm"]' '      }' '    }' '  }' '}' > $(1)/usr/share/rpcd/acl.d/luci-app-cowboy-bebop.json
endef

$(eval $(call BuildPackage,luci-app-cowboy-bebop))

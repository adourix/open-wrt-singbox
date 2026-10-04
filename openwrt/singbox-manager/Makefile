include $(TOPDIR)/rules.mk

PKG_NAME:=singbox-manager
PKG_RELEASE:=2
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad

include $(INCLUDE_DIR)/package.mk

define Package/singbox-manager
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Lightweight sing-box manager
  DEPENDS:=+sing-box +jq +nftables +uclient-fetch +kmod-tun +kmod-nfnetlink-queue
endef

define Package/singbox-manager/description
Core CLI, protocol parsers, configuration generator, service integration,
TUN routing safety, DNS policy, validation and recovery for sing-box.
endef

define Package/singbox-manager/conffiles
/etc/config/singbox
endef

define Build/Compile
endef

define Package/singbox-manager/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/singbox-manager $(1)/usr/bin/singbox-manager
	$(INSTALL_DIR) $(1)/usr/lib/singbox-manager/protocol/vmess
	$(INSTALL_DIR) $(1)/usr/lib/singbox-manager/protocol/vless
	$(INSTALL_DIR) $(1)/usr/lib/singbox-manager/config/templates
	$(INSTALL_DATA) ./files/usr/lib/singbox-manager/config/templates/1.13.21.json $(1)/usr/lib/singbox-manager/config/templates/1.13.21.json
	$(INSTALL_DIR) $(1)/usr/lib/singbox-manager/config
	$(INSTALL_DIR) $(1)/usr/lib/singbox-manager/network
	$(INSTALL_DIR) $(1)/usr/lib/singbox-manager/service
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/detector.sh $(1)/usr/lib/singbox-manager/protocol/detector.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/vmess/parser.sh $(1)/usr/lib/singbox-manager/protocol/vmess/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/vless/parser.sh $(1)/usr/lib/singbox-manager/protocol/vless/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/generator.sh $(1)/usr/lib/singbox-manager/config/generator.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/validator.sh $(1)/usr/lib/singbox-manager/config/validator.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/version.sh $(1)/usr/lib/singbox-manager/config/version.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/service/manager.sh $(1)/usr/lib/singbox-manager/service/manager.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/network/firewall.sh $(1)/usr/lib/singbox-manager/network/firewall.sh
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/singbox $(1)/etc/config/singbox
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/singbox $(1)/etc/init.d/singbox
endef

$(eval $(call BuildPackage,singbox-manager))

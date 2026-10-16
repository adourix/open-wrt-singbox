include $(TOPDIR)/rules.mk

PKG_NAME:=cowboy-bebop-manager
PKG_RELEASE:=22
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad
REPLACES:=singbox-manager

include $(INCLUDE_DIR)/package.mk

define Package/cowboy-bebop-manager
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Cowboy Bebop Manager for sing-box
  DEPENDS:=+sing-box-tiny +jq +nftables +uclient-fetch +kmod-tun +kmod-nfnetlink-queue +kmod-nft-queue +kmod-inet-diag
endef

define Package/cowboy-bebop-manager/description
Cowboy Bebop Manager: lightweight sing-box manager with VMess/VLESS parsing,
configuration generation, TUN routing, validation and recovery.
endefine

define Package/cowboy-bebop-manager/conffiles
/etc/config/cowboy-bebop
endefine

define Build/Compile
endefine

define Package/cowboy-bebop-manager/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/cowboy-bebop-manager $(1)/usr/bin/cowboy-bebop-manager

	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/protocol/vmess
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/protocol/vless
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/config/templates
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/config
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/network
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/service

	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/detector.sh $(1)/usr/lib/cowboy-bebop/protocol/detector.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/vmess/parser.sh $(1)/usr/lib/cowboy-bebop/protocol/vmess/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/vless/parser.sh $(1)/usr/lib/cowboy-bebop/protocol/vless/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/config/generator.sh $(1)/usr/lib/cowboy-bebop/config/generator.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/validator.sh $(1)/usr/lib/cowboy-bebop/config/validator.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/version.sh $(1)/usr/lib/cowboy-bebop/config/version.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/network/firewall.sh $(1)/usr/lib/cowboy-bebop/network/firewall.sh
	$(INSTALL_DATA) ./files/usr/lib/singbox-manager/config/templates/1.13.21.json $(1)/usr/lib/cowboy-bebop/config/templates/1.13.21.json
	$(INSTALL_DATA) ./files/usr/lib/singbox-manager/config/templates/1.12.17.json $(1)/usr/lib/cowboy-bebop/config/templates/1.12.17.json
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/service/manager.sh $(1)/usr/lib/cowboy-bebop/service/manager.sh

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/cowboy-bebop $(1)/etc/config/cowboy-bebop

	$(INSTALL_DIR) $(1)/etc/cowboy-bebop

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/singbox $(1)/etc/init.d/cowboy-bebop
endef

$(eval $(call BuildPackage,cowboy-bebop-manager))

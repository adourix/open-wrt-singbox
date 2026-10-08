include $(TOPDIR)/rules.mk

PKG_NAME:=cowboy-bebop-manager
PKG_RELEASE:=14
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad
REPLACES:=cowboy-bebop

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
endef

define Package/cowboy-bebop-manager/conffiles
/etc/config/cowboy-bebop
endef

define Build/Compile
endef

define Package/cowboy-bebop-manager/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/cowboy-bebop-manager $(1)/usr/bin/cowboy-bebop-manager

	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/protocol/vmess
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/protocol/vless
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/config/templates
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/config
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/network
	$(INSTALL_DIR) $(1)/usr/lib/cowboy-bebop/service

	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/protocol/detector.sh $(1)/usr/lib/cowboy-bebop/protocol/detector.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/protocol/vmess/parser.sh $(1)/usr/lib/cowboy-bebop/protocol/vmess/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/protocol/vless/parser.sh $(1)/usr/lib/cowboy-bebop/protocol/vless/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/config/generator.sh $(1)/usr/lib/cowboy-bebop/config/generator.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/config/validator.sh $(1)/usr/lib/cowboy-bebop/config/validator.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/config/version.sh $(1)/usr/lib/cowboy-bebop/config/version.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/network/firewall.sh $(1)/usr/lib/cowboy-bebop/network/firewall.sh
	$(INSTALL_BIN) ./files/usr/lib/cowboy-bebop/config/templates/1.13.21.json $(1)/usr/lib/cowboy-bebop/config/templates/1.13.21.json

	$(INSTALL_DATA) ./files/usr/lib/cowboy-bebop/service/manager.sh $(1)/usr/lib/cowboy-bebop/service/manager.sh
	sed -i \
		-e 's#/usr/lib/cowboy-bebop#/usr/lib/cowboy-bebop#g' \
		-e 's#/etc/cowboy-bebop#/etc/cowboy-bebop#g' \
		-e 's#/etc/init.d/cowboy-bebop#/etc/init.d/cowboy-bebop#g' \
		-e 's#/etc/config/cowboy-bebop#/etc/config/cowboy-bebop#g' \
		-e 's#singbox\.main#cowboy-bebop.main#g' \
		-e 's#uci commit singbox#uci commit cowboy-bebop#g' \
		-e 's#cowboy-bebop-rollback#cowboy-bebop-rollback#g' \
		-e 's/logger -t singbox/logger -t cowboy-bebop/g' \
		$(1)/usr/lib/cowboy-bebop/service/manager.sh

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/cowboy-bebop $(1)/etc/config/cowboy-bebop
	$(INSTALL_DIR) $(1)/etc/cowboy-bebop

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/cowboy-bebop $(1)/etc/init.d/cowboy-bebop
	sed -i \
		-e 's#/etc/cowboy-bebop#/etc/cowboy-bebop#g' \
		-e 's#/etc/config/cowboy-bebop#/etc/config/cowboy-bebop#g' \
		-e 's#/usr/lib/cowboy-bebop#/usr/lib/cowboy-bebop#g' \
		-e 's#config_load singbox#config_load cowboy-bebop#g' \
		-e 's#procd_add_reload_trigger singbox#procd_add_reload_trigger cowboy-bebop#g' \
		-e 's#uci set singbox\.main#uci set cowboy-bebop.main#g' \
		-e 's#uci commit singbox#uci commit cowboy-bebop#g' \
		-e 's#logger -t singbox#logger -t cowboy-bebop#g' \
		$(1)/etc/init.d/cowboy-bebop
endef

$(eval $(call BuildPackage,cowboy-bebop-manager))

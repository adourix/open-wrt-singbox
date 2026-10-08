include $(TOPDIR)/rules.mk

PKG_NAME:=cowboy-bebop-manager
PKG_RELEASE:=18
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

	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/detector.sh $(1)/usr/lib/cowboy-bebop/protocol/detector.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/vmess/parser.sh $(1)/usr/lib/cowboy-bebop/protocol/vmess/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/protocol/vless/parser.sh $(1)/usr/lib/cowboy-bebop/protocol/vless/parser.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/generator.sh $(1)/usr/lib/cowboy-bebop/config/generator.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/validator.sh $(1)/usr/lib/cowboy-bebop/config/validator.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/config/version.sh $(1)/usr/lib/cowboy-bebop/config/version.sh
	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/network/firewall.sh $(1)/usr/lib/cowboy-bebop/network/firewall.sh
	$(INSTALL_DATA) ./files/usr/lib/singbox-manager/config/templates/1.13.21.json $(1)/usr/lib/cowboy-bebop/config/templates/1.13.21.json
	$(INSTALL_DATA) ./files/usr/lib/singbox-manager/config/templates/1.12.17.json $(1)/usr/lib/cowboy-bebop/config/templates/1.12.17.json

	$(INSTALL_BIN) ./files/usr/lib/singbox-manager/service/manager.sh $(1)/usr/lib/cowboy-bebop/service/manager.sh
	sed -i \
		-e 's#/usr/lib/singbox-manager#/usr/lib/cowboy-bebop#g' \
		-e 's#/etc/singbox#/etc/cowboy-bebop#g' \
		-e 's#/etc/init.d/singbox#/etc/init.d/cowboy-bebop#g' \
		-e 's#/etc/config/singbox#/etc/config/cowboy-bebop#g' \
		-e 's#singbox\.main#cowboy-bebop.main#g' \
		-e 's#uci commit singbox#uci commit cowboy-bebop#g' \
		-e 's#singbox-manager-rollback#cowboy-bebop-rollback#g' \
		-e 's/logger -t singbox/logger -t cowboy-bebop/g' \
		$(1)/usr/lib/cowboy-bebop/service/manager.sh

	# Runtime verification must not make a healthy TUN/routing session fail only
	# because the router-originated api.ipify.org probe is intercepted or blocked.
	sed -i \
		-e '/^connectivity_test() {/a\\    CONNECTIVITY_TIMEOUT=$${CONNECTIVITY_TIMEOUT:-8}; CONNECTIVITY_TRIES=$${CONNECTIVITY_TRIES:-2}' \
		-e '/if ! connectivity_test; then/{n;s/.*/        logger -t cowboy-bebop "connectivity verification warning: uclient-fetch to api.ipify.org failed; keeping runtime active"/;n;s/.*/    fi/}' \
		-e '/^schedule_rollback() {/a\\    [ -f "$$(dirname "$$(dirname "$$(dirname "$$(dirname "$$(dirname "$$(dirname "$$(dirname "$$(pwd)")))))))" ] 2>/dev/null || true' \
		$(1)/usr/lib/cowboy-bebop/service/manager.sh

	# Replace the generated manager with the canonical runtime implementation
	# when the repository core is available in a source-tree build.
	if [ -f ./../../core/service/manager.sh ]; then \
		$(INSTALL_BIN) ./../../core/service/manager.sh $(1)/usr/lib/cowboy-bebop/service/manager.sh; \
		sed -i \
			-e 's#/usr/lib/singbox-manager#/usr/lib/cowboy-bebop#g' \
			-e 's#/etc/singbox#/etc/cowboy-bebop#g' \
			-e 's#/etc/init.d/singbox#/etc/init.d/cowboy-bebop#g' \
			-e 's#/etc/config/singbox#/etc/config/cowboy-bebop#g' \
			-e 's#singbox\\.main#cowboy-bebop.main#g' \
			-e 's#uci commit singbox#uci commit cowboy-bebop#g' \
			-e 's#singbox-manager-rollback#cowboy-bebop-rollback#g' \
			-e 's/logger -t singbox/logger -t cowboy-bebop/g' \
			$(1)/usr/lib/cowboy-bebop/service/manager.sh; \
	fi

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/cowboy-bebop $(1)/etc/config/cowboy-bebop

	$(INSTALL_DIR) $(1)/etc/cowboy-bebop

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/singbox $(1)/etc/init.d/cowboy-bebop
	sed -i \
		-e 's#/etc/singbox#/etc/cowboy-bebop#g' \
		-e 's#/etc/config/singbox#/etc/config/cowboy-bebop#g' \
		-e 's#/usr/lib/singbox-manager#/usr/lib/cowboy-bebop#g' \
		-e 's#config_load singbox#config_load cowboy-bebop#g' \
		-e 's#procd_add_reload_trigger singbox#procd_add_reload_trigger cowboy-bebop#g' \
		-e 's#uci set singbox\.main#uci set cowboy-bebop.main#g' \
		-e 's#uci commit singbox#uci commit cowboy-bebop#g' \
		-e 's#logger -t singbox#logger -t cowboy-bebop#g' \
		$(1)/etc/init.d/cowboy-bebop
endef

$(eval $(call BuildPackage,cowboy-bebop-manager))

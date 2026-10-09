include $(TOPDIR)/rules.mk

PKG_NAME:=cowboy-bebop-branding
PKG_RELEASE:=4
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=../../LICENSE
PKG_MAINTAINER:=Abdulrahman Ayad
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/cowboy-bebop-branding
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=Cowboy Bebop system branding
  DEPENDS:=+cowboy-bebop-manager
endef

define Package/cowboy-bebop-branding/description
Optional, lightweight system identity for Cowboy Bebop Manager on OpenWrt.
Generates an SSH banner from the installed OpenWrt release metadata, adds an
interactive login status line, descriptive OS release metadata and a safe
default hostname without changing machine-readable IDs.
endef

define Build/Compile
endef

define Package/cowboy-bebop-branding/install
	$(INSTALL_DIR) $(1)/etc/profile.d
	$(INSTALL_BIN) ./files/etc/profile.d/cowboy-bebop.sh $(1)/etc/profile.d/cowboy-bebop.sh

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/90-cowboy-bebop-branding $(1)/etc/uci-defaults/90-cowboy-bebop-branding
endef

$(eval $(call BuildPackage,cowboy-bebop-branding))

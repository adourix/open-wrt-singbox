# Minimal stand-in for the SDK's package.mk: runs a package's own install
# recipe and writes opkg metadata. Used only by build-ipk.sh.
INSTALL_DIR:=install -d -m0755
INSTALL_BIN:=install -m0755
INSTALL_DATA:=install -m0644
INSTALL_CONF:=install -m0600

define BuildPackage
$(eval $(Package/$(1)))
$(file >$(META)/name,$(1))
$(file >$(META)/release,$(PKG_RELEASE))
$(file >$(META)/license,$(PKG_LICENSE))
$(file >$(META)/maintainer,$(PKG_MAINTAINER))
$(file >$(META)/section,$(SECTION))
$(file >$(META)/title,$(TITLE))
$(file >$(META)/url,$(URL))
$(file >$(META)/depends,$(DEPENDS))
$(file >$(META)/description,$(Package/$(1)/description))
$(file >$(META)/conffiles,$(Package/$(1)/conffiles))
$(file >$(META)/postinst,$(Package/$(1)/postinst))
all:
	$(call Package/$(1)/install,$(STAGE))
endef

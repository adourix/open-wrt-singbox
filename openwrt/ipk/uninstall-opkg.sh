#!/bin/sh
# Remove Cowboy Bebop. Add --with-sing-box to also remove sing-box-tiny and
# anything install-opkg.sh added for it.
cowboy-bebop-manager recovery 2>/dev/null
opkg remove cowboy-bebop-branding luci-app-cowboy-bebop cowboy-bebop-manager
if [ "${1:-}" = --with-sing-box ]; then
    opkg remove sing-box-tiny cowboy-bebop-compat-kmods 2>/dev/null
    sed -i '/^src\/gz cowboy_bebop_kmods /d' /etc/opkg/customfeeds.conf 2>/dev/null
fi
/etc/init.d/rpcd restart 2>/dev/null; rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null
echo "removed"

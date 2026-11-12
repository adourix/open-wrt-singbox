#!/bin/sh
# Install Cowboy Bebop Manager on an opkg-based OpenWrt (24.10 and older).
# Run from the folder that contains ./ipk/*.ipk:   sh install-opkg.sh
#
# sing-box comes from the router's own feed (sing-box-tiny, ~10 MB). Some
# firmware ships a kernel the official kmods feed does not match, so opkg
# refuses sing-box-tiny because kmod-inet-diag / kmod-tun cannot be resolved.
# In that case this script, in order:
#   1. adds the official kmods feed if it matches the running kernel, or
#   2. installs a tiny placeholder package that tells opkg the requirement is
#      met: kmod-tun only if /dev/net/tun already works, kmod-inet-diag always
#      (it is only used for per-process routing rules, which are not used).
set -u
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
R=${INSTALL_ROOT:-}                 # test hook: alternative root
OPKG=${OPKG:-opkg}
SHIM=cowboy-bebop-compat-kmods

say() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
installed() { $OPKG status "$1" 2>/dev/null | grep -q '^Status:.* installed'; }
available() { [ -n "$($OPKG info "$1" 2>/dev/null)" ]; }
sb_version() { "$R/usr/bin/sing-box" version 2>/dev/null | sed -n '1s/.*version[[:space:]]*//p' | awk '{print $1}'; }
sb_ok() { case "$(sb_version)" in 1.13.21|1.12.[0-9]*) return 0 ;; *) return 1 ;; esac; }

[ -n "$R" ] || [ "$(id -u)" = 0 ] || die "run as root"
command -v "${OPKG%% *}" >/dev/null 2>&1 || die "opkg not found (on apk-based OpenWrt 25.12 use the apk packages instead)"
ls "$HERE"/ipk/*.ipk >/dev/null 2>&1 || die "no ipk/*.ipk next to this script"

say "updating package lists"
$OPKG update >/dev/null 2>&1 || warn "opkg update failed (no internet?)"

say "installing dependencies"
for p in jq nftables uclient-fetch ca-bundle; do
    installed "$p" || $OPKG install "$p" >/dev/null 2>&1 || warn "could not install $p"
done
installed jq || die "jq is required"
installed nftables || die "nftables is required"
[ -n "$R" ] || [ -c /dev/net/tun ] || modprobe tun 2>/dev/null || true
[ -n "$R" ] || [ -c /dev/net/tun ] || die "this kernel has no TUN device (/dev/net/tun)"

# --- official kmods feed, only if it matches the running kernel ------------
add_kmods_feed() {
    grep -qs '_kmods ' "$R/etc/opkg/distfeeds.conf" "$R/etc/opkg/customfeeds.conf" && return 1
    kver=$($OPKG status kernel 2>/dev/null | sed -n 's/^Version: //p')      # 6.6.144~<hash>-r1
    case "$kver" in *~*-r*) ;; *) return 1 ;; esac
    base=${kver%%~*}; rest=${kver#*~}; hash=${rest%-r*}; rel=${rest##*-r}
    core=$(sed -n 's/^src\/gz [^ ]*core \(.*\)\/packages$/\1/p' "$R/etc/opkg/distfeeds.conf" | head -n 1)
    [ -n "$core" ] || return 1
    url="$core/kmods/$base-$rel-$hash"
    wget -q -O /dev/null "$url/Packages.gz" 2>/dev/null || return 1
    say "adding matching kernel-module feed $url"
    printf 'src/gz cowboy_bebop_kmods %s\n' "$url" >> "$R/etc/opkg/customfeeds.conf"
    $OPKG update >/dev/null 2>&1
}

# --- placeholder for kernel modules opkg cannot resolve ---------------------
install_shim() {
    provides=''
    for k in kmod-inet-diag kmod-tun; do
        installed "$k" && continue
        available "$k" && continue
        if [ "$k" = kmod-tun ] && [ -z "$R" ] && [ ! -c /dev/net/tun ]; then continue; fi
        provides="${provides:+$provides, }$k"
    done
    [ -n "$provides" ] || return 1
    say "kernel modules not in this firmware's feed: $provides (placeholder package)"
    w=$(mktemp -d) || return 1
    mkdir -p "$w/control" "$w/data/usr/share/cowboy-bebop"
    printf 'Provided by %s for: %s\n' "$SHIM" "$provides" > "$w/data/usr/share/cowboy-bebop/compat-kmods"
    cat > "$w/control/control" <<CTL
Package: $SHIM
Version: 1
Provides: $provides
Architecture: all
Installed-Size: 100
Description: Placeholder: firmware kernel already covers $provides
 Lets opkg install sing-box-tiny on firmware whose kernel is not in the
 official kmods feed. Remove with: opkg remove $SHIM
CTL
    printf '2.0\n' > "$w/debian-binary"
    ( cd "$w/control" && tar -czf ../control.tar.gz ./ ) &&
    ( cd "$w/data" && tar -czf ../data.tar.gz ./ ) &&
    ( cd "$w" && tar -czf "$w/$SHIM.ipk" ./debian-binary ./data.tar.gz ./control.tar.gz ) &&
    $OPKG install "$w/$SHIM.ipk" >/dev/null 2>&1
    rc=$?; rm -rf "$w"; return $rc
}

install_singbox() {
    $OPKG install --force-space sing-box-tiny > "${TMPDIR:-/tmp}/cb-sb.log" 2>&1 && sb_ok
}

if sb_ok; then
    say "sing-box $(sb_version) already installed"
else
    say "installing sing-box-tiny (about 10 MB) from the feed"
    if ! install_singbox; then
        add_kmods_feed && install_singbox
    fi
    if ! sb_ok; then
        install_shim && install_singbox
    fi
    if ! sb_ok; then
        tail -n 5 "${TMPDIR:-/tmp}/cb-sb.log" >&2
        installed sing-box-tiny && $OPKG remove sing-box-tiny >/dev/null 2>&1
        installed "$SHIM" && $OPKG remove "$SHIM" >/dev/null 2>&1
        [ -n "$R" ] || df -h /overlay >&2
        die "could not install a working sing-box-tiny (see lines above)"
    fi
    say "sing-box $(sb_version) installed"
fi
rm -f "${TMPDIR:-/tmp}/cb-sb.log"
# The feed package ships its own service; this project never co-enables it.
if [ -z "$R" ] && [ -x /etc/init.d/sing-box ]; then
    /etc/init.d/sing-box stop 2>/dev/null; /etc/init.d/sing-box disable 2>/dev/null
fi
case "$(sb_version)" in 1.12.*) warn "sing-box $(sb_version) cannot enforce certificate pins (pcs); such links run with TLS verification off" ;; esac

installed luci-theme-cowboy-bebop && $OPKG remove luci-theme-cowboy-bebop >/dev/null 2>&1
installed luci-theme-bootstrap || $OPKG install luci-theme-bootstrap >/dev/null 2>&1 || true

say "installing Cowboy Bebop packages"
$OPKG install "$HERE"/ipk/*.ipk || die "package install failed (see lines above)"

if [ -z "$R" ]; then
    if [ "$(uci -q get luci.main.mediaurlbase)" = /luci-static/cowboy-bebop ] && [ ! -d /www/luci-static/cowboy-bebop ]; then
        uci -q set luci.main.mediaurlbase=/luci-static/bootstrap; uci -q commit luci
    fi
    /etc/init.d/rpcd restart 2>/dev/null
    rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null
    say "done"
    cowboy-bebop-manager version --plain
    printf 'model shown in LuCI : %s\n' "$(cat /tmp/sysinfo/model 2>/dev/null)"
    printf 'LuCI theme          : %s\n' "$(uci -q get luci.main.mediaurlbase)"
    printf 'flash free          : %s\n' "$(df -h /overlay 2>/dev/null | awk 'NR==2 {print $4}')"
    echo
    echo "Next: LuCI -> Services -> Cowboy Bebop, paste the link, Save & Apply, then Confirm."
else
    say "done"
fi

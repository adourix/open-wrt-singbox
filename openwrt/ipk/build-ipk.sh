#!/bin/sh
# Build the project packages as opkg .ipk files without the OpenWrt SDK.
# All three packages are architecture-independent (shell, JS, config), so no
# cross-compiler is needed. Output works with opkg (OpenWrt 24.10 and older).
#
#   sh openwrt/ipk/build-ipk.sh [OUTDIR]
#
# Kernel modules and sing-box-tiny are left out of Depends: on firmware whose
# kernel does not match the official kmods feed, opkg would otherwise refuse
# the install. install-opkg.sh installs sing-box-tiny separately.
set -eu
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
TOP=$(CDPATH='' cd -- "$HERE/.." && pwd)
OUT=${1:-$TOP/../dist}
STRIP_DEPS=${STRIP_DEPS:-'sing-box sing-box-tiny kmod-*'}
mkdir -p "$OUT"; OUT=$(CDPATH='' cd -- "$OUT" && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

strip_dep() {
    for pat in $STRIP_DEPS; do
        # shellcheck disable=SC2254
        case "$1" in $pat) return 0 ;; esac
    done
    return 1
}

for pkg in cowboy-bebop-manager luci-app-cowboy-bebop cowboy-bebop-branding; do
    W="$WORK/$pkg"; mkdir -p "$W/meta" "$W/data" "$W/control"
    make -s -C "$TOP/$pkg" -f Makefile TOPDIR="$HERE" INCLUDE_DIR="$HERE" \
        META="$W/meta" STAGE="$W/data" all >/dev/null
    rel=$(cat "$W/meta/release")
    deps=''
    for d in $(cat "$W/meta/depends"); do
        d=${d#+}; d=${d#@}
        case "$d" in ''|*'('*|*':'*) continue ;; esac
        strip_dep "$d" && continue
        deps="${deps:+$deps, }$d"
    done
    size=$(find "$W/data" -type f -exec cat {} + | wc -c | tr -d " ")
    {
        printf 'Package: %s\n' "$pkg"
        printf 'Version: 1-r%s\n' "$rel"
        [ -z "$deps" ] || printf 'Depends: %s\n' "$deps"
        printf 'Source: https://github.com/adourix/open-wrt-singbox\n'
        printf 'SourceName: %s\n' "$pkg"
        printf 'License: %s\n' "$(cat "$W/meta/license")"
        printf 'Section: %s\n' "$(cat "$W/meta/section")"
        printf 'URL: %s\n' "$(cat "$W/meta/url")"
        printf 'Maintainer: %s\n' "$(cat "$W/meta/maintainer")"
        printf 'Architecture: all\n'
        printf 'Installed-Size: %s\n' "$size"
        printf 'Description: %s\n' "$(cat "$W/meta/title")"
        sed 's/^/ /' "$W/meta/description" | sed '/^ *$/d'
    } > "$W/control/control"
    if [ -s "$W/meta/conffiles" ] && [ -n "$(tr -d ' \n' < "$W/meta/conffiles")" ]; then
        sed '/^[[:space:]]*$/d' "$W/meta/conffiles" > "$W/control/conffiles"
    fi
    # Same wrapper the SDK generates: default_postinst runs uci-defaults and
    # enables/starts init scripts; the package's own postinst runs as -pkg.
    cat > "$W/control/postinst" <<'PI'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_postinst $0 $@
PI
    cat > "$W/control/prerm" <<'PR'
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_prerm $0 $@
PR
    if [ -n "$(sed '/^[[:space:]]*$/d' "$W/meta/postinst")" ]; then
        cp "$W/meta/postinst" "$W/control/postinst-pkg"
        chmod 755 "$W/control/postinst-pkg"
    fi
    chmod 755 "$W/control/postinst" "$W/control/prerm"
    printf '2.0\n' > "$W/debian-binary"
    T="--format=gnu --owner=0 --group=0 --numeric-owner --sort=name --mtime=@0"
    # shellcheck disable=SC2086
    (cd "$W/control" && tar $T -czf "$W/control.tar.gz" ./)
    # shellcheck disable=SC2086
    (cd "$W/data" && tar $T -czf "$W/data.tar.gz" ./)
    ipk="$OUT/${pkg}_1-r${rel}_all.ipk"
    # shellcheck disable=SC2086
    (cd "$W" && tar $T -czf "$ipk" ./debian-binary ./data.tar.gz ./control.tar.gz)
    printf '%s\n' "$ipk"
done

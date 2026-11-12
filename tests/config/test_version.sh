#!/bin/sh
set -eu

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
# shellcheck source=../../core/config/version.sh
. "$ROOT/core/config/version.sh"
SINGBOX_TEMPLATE_DIR="$ROOT/core/config/templates"
export SINGBOX_TEMPLATE_DIR

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/sing-box" <<'EOF'
#!/bin/sh
echo 'sing-box version 1.13.21'
EOF
chmod +x "$TMP/sing-box"

SINGBOX_BIN="$TMP/sing-box"
[ "$(singbox_version)" = "1.13.21" ]
check_singbox_version

cat > "$TMP/sing-box" <<'EOF'
#!/bin/sh
echo 'sing-box version 1.14.0'
EOF
if check_singbox_version; then
    exit 1
fi

# The 1.12 patch series (OpenWrt 24.10 feed) is accepted, without the pin feature.
for v in 1.12.22 1.12.17; do
    printf '#!/bin/sh\necho "sing-box version %s"\n' "$v" > "$TMP/sing-box"
    check_singbox_version || exit 1
    if singbox_supports_pubkey_pin; then exit 1; fi
done
printf '#!/bin/sh\necho "sing-box version 1.13.21"\n' > "$TMP/sing-box"
singbox_supports_pubkey_pin || exit 1
# Other 1.13 patch levels, 1.11 and garbage are refused.
for v in 1.13.20 1.11.15 1.12 banana; do
    printf '#!/bin/sh\necho "sing-box version %s"\n' "$v" > "$TMP/sing-box"
    if check_singbox_version; then exit 1; fi
done

echo "version tests: PASS"

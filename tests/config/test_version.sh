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

echo "version tests: PASS"

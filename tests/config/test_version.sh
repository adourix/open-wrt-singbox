#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/core/config/version.sh"

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
check_singbox_version && exit 1 || true

echo "version tests: PASS"

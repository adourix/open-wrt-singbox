#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/core/config/validator.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fake="$TMP/fake-sing-box"
cat > "$fake" <<'EOF'
#!/bin/sh
if [ "$1" = check ] && [ "$2" = -c ]; then
    [ -f "$3" ] && grep -q "VALID" "$3"
else
    exit 2
fi
EOF
chmod +x "$fake"

printf '%s\n' VALID > "$TMP/new"
printf '%s\n' OLD > "$TMP/config.json"

SINGBOX_BIN="$fake" install_validated_config \
    "$TMP/new" "$TMP/config.json" "$TMP/config.json.bak"

grep -q OLD "$TMP/config.json.bak"
grep -q VALID "$TMP/config.json"
[ ! -e "$TMP/new" ]

printf '%s\n' BAD > "$TMP/bad"
if SINGBOX_BIN="$fake" install_validated_config \
    "$TMP/bad" "$TMP/config.json" "$TMP/config.json.bak"; then
    exit 1
fi

grep -q VALID "$TMP/config.json"
printf '%s\n' "Validator tests: PASS"

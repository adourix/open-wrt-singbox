#!/bin/sh
# Reseller identity cleanup: model text and reseller LuCI theme.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SCRIPT="$ROOT/openwrt/cowboy-bebop-branding/files/etc/init.d/cowboy-bebop-identity"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
R="$TMP/root"
mkdir -p "$R/tmp/sysinfo" "$R/etc" "$R/www/luci-static/vendor" "$R/www/luci-static/bootstrap" "$TMP/bin"

# Model string as shipped by the reseller firmware (emoji + name + phone).
printf '%s\n' 'KT-708 👉BASEM LG👈 (+200000000000)' > "$R/tmp/sysinfo/model"
printf '%s\n' '{"model":{"id":"mercury,ti04_708h","name":"KT-708 BASEM LG (+200000000000)"}}' > "$R/etc/board.json"
printf '%s\n' '<a class="brand">BASEM<span>LG</span></a>' > "$R/www/luci-static/vendor/header.htm"

# Minimal uci stub backed by a flat file.
UCI_DB="$TMP/uci.db"
printf '%s\n' 'luci.main.mediaurlbase=/luci-static/vendor' 'system.@system[0].description=Basem LG router' > "$UCI_DB"
cat > "$TMP/bin/uci" <<'STUB'
#!/bin/sh
# Keys are matched literally (they contain "[0]").
[ "$1" = -q ] && shift
db_get() { awk -v k="$1=" 'index($0,k)==1 { print substr($0,length(k)+1); f=1; exit } END { exit !f }' "$UCI_DB"; }
db_del() { awk -v k="$1=" 'index($0,k)!=1' "$UCI_DB" > "$UCI_DB.n"; mv "$UCI_DB.n" "$UCI_DB"; }
case "$1" in
  get) db_get "$2" ;;
  set) key=${2%%=*}; val=${2#*=}; db_del "$key"; printf '%s=%s\n' "$key" "$val" >> "$UCI_DB" ;;
  delete) db_del "$2" ;;
  commit) : ;;
esac
STUB
printf '#!/bin/sh\n:\n' > "$TMP/bin/logger"
chmod +x "$TMP/bin/uci" "$TMP/bin/logger"
export UCI_DB

run() { PATH="$TMP/bin:$PATH" IDENTITY_ROOT="$R" sh -c '. "$1"; start' _ "$SCRIPT"; }

run
[ "$(cat "$R/tmp/sysinfo/model")" = "KT-708" ] || fail "sysinfo model"
[ "$(jq -r .model.name "$R/etc/board.json")" = "KT-708" ] || fail "board.json model"
[ "$(jq -r .model.id "$R/etc/board.json")" = "mercury,ti04_708h" ] || fail "board id must not change"
[ -f "$R/etc/board.json.vendor" ] || fail "board.json backup"
grep -qx 'luci.main.mediaurlbase=/luci-static/bootstrap' "$UCI_DB" || fail "theme switch"
! grep -q 'description' "$UCI_DB" || fail "system description"

# Idempotent: a second run changes nothing.
cp "$UCI_DB" "$TMP/before"
run
cmp -s "$UCI_DB" "$TMP/before" || fail "second run changed uci"
[ "$(cat "$R/tmp/sysinfo/model")" = "KT-708" ] || fail "second run model"

# A clean device and a user-chosen stock theme are left alone.
printf '%s\n' 'TP-Link Archer C7 v5 (EU)' > "$R/tmp/sysinfo/model"
printf '%s\n' 'luci.main.mediaurlbase=/luci-static/material' > "$UCI_DB"
mkdir -p "$R/www/luci-static/material"
run
[ "$(cat "$R/tmp/sysinfo/model")" = "TP-Link Archer C7 v5 (EU)" ] || fail "clean model changed"
grep -qx 'luci.main.mediaurlbase=/luci-static/material' "$UCI_DB" || fail "stock theme changed"

# The removed Cowboy Bebop theme must never stay selected.
printf '%s\n' 'luci.main.mediaurlbase=/luci-static/cowboy-bebop' > "$UCI_DB"
run
grep -qx 'luci.main.mediaurlbase=/luci-static/bootstrap' "$UCI_DB" || fail "dangling theme"

printf '%s\n' 'identity cleanup tests: PASS'

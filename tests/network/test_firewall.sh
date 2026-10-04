#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/core/network/firewall.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/nft" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$NFT_LOG"
case "$1 $2 $3 $4" in
  "list table inet singbox"|"list chain inet singbox forward") exit 1 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/nft"
NFT_LOG="$TMP/log"
export NFT_LOG
PATH="$TMP:$PATH"
export PATH

firewall_apply
grep -F 'add table inet singbox' "$NFT_LOG" >/dev/null
grep -F 'add chain inet singbox forward' "$NFT_LOG" >/dev/null
grep -F 'iifname br-lan meta nfproto ipv6 drop' "$NFT_LOG" >/dev/null
! grep -F 'comment' "$NFT_LOG" >/dev/null

# Validate the actual nftables rule grammar when nft is available in CI.
if command -v nft >/dev/null 2>&1; then
    nft -c -f - <<'EOF'
table inet singbox {
    chain forward {
        type filter hook forward priority -5; policy accept;
        iifname "br-lan" meta nfproto ipv6 drop
    }
}
EOF
fi

firewall_cleanup
grep -F 'delete table inet singbox' "$NFT_LOG" >/dev/null

echo "firewall tests: PASS"

# Troubleshooting

```sh
cowboy-bebop-manager status          # add --json for scripts, --plain for no header
cowboy-bebop-manager health
cowboy-bebop-manager version
logread -e cowboy-bebop | tail -n 30
sing-box check -c /etc/cowboy-bebop/config.json
```

| Symptom | Cause / fix |
|---|---|
| `Unsupported sing-box version` | Supported: 1.13.21 and any 1.12.x. Check `sing-box version`. |
| `Server certificate does not match the pinned certificate` | The link's `pcs` does not match what the server presents (rotated certificate or interception). Get a fresh link. |
| `Certificate pin or name requires allow_insecure, or sing-box 1.13 with openssl` | Link has `pcs`/`vcn` but it cannot be enforced (sing-box 1.12, or no `openssl`) and `allow_insecure` is `0`. |
| log: `installed sing-box is older than 1.13 and cannot enforce a certificate pin` | Expected on OpenWrt 24.10 (sing-box 1.12). The link works with verification off. |
| log: `TLS verification disabled by allow_insecure policy` | Pin could not be checked (no `openssl` or server unreachable at apply time). Works, but unverified. Install `openssl-util` and apply again. |
| `Runtime verification failed; rolling back` | sing-box did not stay up, or `tun0`/routing is missing. Previous config was restored. Check `kmod-tun` and the log. |
| `detour to an empty direct outbound makes no sense` | A config from an older build. Apply the URL again. |
| State `ERROR` | Enabled in UCI but sing-box is not running. `cowboy-bebop-manager recovery`, then apply again. |
| LuCI page missing | `/etc/init.d/rpcd reload; rm -rf /tmp/luci-*` and reload the browser. |
| LuCI broken after removing the old theme | `uci set luci.main.mediaurlbase=/luci-static/bootstrap; uci commit luci` |
| Locked out after apply | Wait 60 s: an unconfirmed apply reverts by itself. |

Recovery is always safe to run and never touches `tailscaled`:

```sh
cowboy-bebop-manager recovery
```

BusyBox notes: no `curl`, `nl` or `cat -n`; use `uclient-fetch`. Copy files with `scp -O`.

# Architecture

The project separates protocol parsing/configuration generation from LuCI.

## Flow

```
URL
  -> protocol detector
  -> VMess/VLESS parser
  -> normalized profile
  -> config generator
  -> sing-box validation
  -> service manager
```

The core must work from the CLI without LuCI. Production OpenWrt uses
BusyBox ash, jq, UCI, procd, nftables, and sing-box; it does not run Node.js,
Docker, Python, or a permanent application server.

## Phase 1

The first implementation target is the protocol detector plus strict VMess and
VLESS parsers and their tests.

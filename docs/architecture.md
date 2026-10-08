# Architecture

## Runtime flow

VMess / VLESS URL
       |
       v
Protocol detector
       |
       v
Strict parser
       |
       v
Normalized profile v1
       |
       v
Config generator (sing-box 1.13.21)
       |
       v
config.json.new
       |
       v
sing-box check
       |
       v
atomic install + backup
       |
       v
procd / sing-box
       |
       +--> TUN auto_route + auto_redirect
       +--> route sniff + DNS hijack
       +--> direct private/router traffic
       +--> proxy everything else
       |
       v
health + connectivity
       |
       v
commit-confirm / rollback

## Layers

### Protocol

- core/protocol/detector.sh
- core/protocol/vmess/parser.sh
- core/protocol/vless/parser.sh

Input is untrusted. No eval, command execution, or decoded JSON execution is allowed.

### Normalized profile

docs/normalized-profile-v1.md is the contract between parsers and the generator. It is not a sing-box configuration.

### Configuration

- core/config/generator.sh
- core/config/validator.sh
- core/config/version.sh

The generator is pinned to sing-box 1.13.21 and emits TUN, DNS, route and VMess/VLESS outbound configuration. The validator uses sing-box check before activation.

### Runtime

- core/service/manager.sh
- core/network/firewall.sh
- openwrt/cowboy-bebop/files/etc/init.d/cowboy-bebop

The manager owns desired state in UCI and observes actual process/TUN/routing state. OpenWrt procd owns the process lifecycle. sing-box auto_redirect owns transparent interception integration with Linux/fw4; the project-owned nft table is reserved for safety policy and IPv6 leak prevention.

### UI

LuCI calls a small rpcd executable backend. The backend never returns the stored proxy URL or UUID. Profile preview returns only non-secret metadata.

### Packaging

- openwrt/cowboy-bebop: core runtime package
- openwrt/luci-app-cowboy-bebop: LuCI/rpcd package
- openwrt/imagebuilder: x86_64 image assembly

The runtime image contains no Node.js, Docker, Python or permanent application server.

## Failure model

Invalid configuration is never activated. Failed restart or failed runtime verification restores the previous configuration. Successful applies enter a 60-second commit-confirm state. cowboy-bebop confirm commits the new configuration; timeout or a reboot before confirmation restores the backup.

## Tests

tests/ is development/CI-only. It is not installed into either runtime package.
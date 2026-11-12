# Cowboy Bebop Manager — OpenWrt sing-box Project

A lightweight OpenWrt management application for configuring and
controlling `sing-box` through a minimal LuCI interface.

The application accepts `vmess://` and `vless://` links, parses them,
generates a compatible `sing-box` configuration, validates it, and
controls the sing-box service.

The project is designed to be developed first on a Linux VM and then
packaged for OpenWrt routers with minimal CPU, RAM, storage, and runtime
dependencies.

------------------------------------------------------------------------

# 1. Project Goals

The project must provide:

-   VMess URL support.
-   VLESS URL support.
-   Automatic protocol detection.
-   Automatic parsing of share URLs.
-   Automatic sing-box configuration generation.
-   Configuration validation before activation.
-   Start/stop/restart control.
-   ON/OFF control from LuCI.
-   Optional start-at-boot.
-   TUN-based transparent proxying.
-   Basic LAN routing through sing-box.
-   Basic DNS handling.
-   Recovery when sing-box fails.
-   Automatic rollback of a failed apply.
-   Low resource usage.
-   No Node.js, Docker, React, Vue, Python, or permanent application
    server on production OpenWrt.

The final user workflow should be:

``` text
Open LuCI
    |
    v
Services -> Sing-box
    |
    v
Paste VMess/VLESS URL
    |
    v
Automatic protocol detection
    |
    v
Parse URL
    |
    v
Generate sing-box config
    |
    v
Validate config
    |
    v
Save config
    |
    v
Start sing-box
    |
    v
TUN
    |
    v
LAN traffic -> Proxy
```

------------------------------------------------------------------------

# 2. Core Design Principles

## 2.1 Lightweight

Production OpenWrt must not require:

-   Node.js
-   npm
-   Docker
-   Python
-   React
-   Vue
-   Express
-   Fastify
-   A separate web server

Use:

-   LuCI (modern JavaScript views + rpcd backend; the legacy Lua/CBI
    stack is not used for new development)
-   POSIX shell (busybox `ash` compatible) for small system tasks
-   `jq` for JSON parsing and generation (never build JSON by string
    concatenation)
-   UCI
-   OpenWrt init system
-   nftables
-   sing-box

The sing-box process is the main runtime workload.

------------------------------------------------------------------------

## 2.2 Separate Core From UI

Protocol parsing and configuration generation must not depend on LuCI.

Architecture:

``` text
                    +----------------+
                    |    LuCI UI     |
                    +-------+--------+
                            |
                            v
                  +-------------------+
                  | cowboy-bebop-manager   |
                  +---------+---------+
                            |
          +-----------------+-----------------+
          |                 |                 |
          v                 v                 v
   Protocol Parser    Config Generator   Service Manager
          |                 |                 |
          +-----------------+-----------------+
                            |
                            v
                        sing-box
```

The core must be usable from the CLI without LuCI.

------------------------------------------------------------------------

## 2.3 Implementation Priority

The project is **router-first**. The production OpenWrt router, its core
manager, networking, reliability, and LuCI interface are the primary
scope. Remote services must not delay or complicate the router MVP.

The implementation priority is fixed as follows:

``` text
P0  Router Core + LuCI UI
    - Protocol parsing
    - sing-box configuration generation
    - Validation
    - Service control
    - TUN / routing / DNS
    - ON/OFF
    - Save & Apply
    - Auto Start
    - Health / recovery / rollback
    - Lightweight LuCI interface

P1  OpenWrt Reliability + Real Router Support
    - Package integration
    - Boot / restart behavior
    - Resource usage
    - Firewall / nftables behavior
    - Real hardware testing
    - Recovery and accessibility guarantees

P2  Remote Config Sync
    - Implement only after the local router workflow is stable
    - Router pulls approved configuration from a remote source
    - Validate before activation
    - Keep a working backup
    - Roll back automatically when the new configuration fails
    - Must not be required for normal local operation

P3  Web Panel
    - Final feature in the roadmap
    - Optional management layer for remote configuration
    - May integrate with external systems such as Marzban later
    - Must consume the stable router/config-sync interfaces rather than
      becoming a dependency of the router core
```

### Priority rules

1. The router must be fully usable without Remote Config Sync.
2. Remote Config Sync must be fully usable without a Web Panel.
3. The Web Panel is the last major feature and must not block router
   development, packaging, testing, or release.
4. No web backend, database, Node.js service, Docker stack, or cloud
   dependency is added to the production router just to support future
   remote features.
5. The local LuCI workflow remains the primary and supported management
   path.

------------------------------------------------------------------------

# 3. Target Environments

## 3.1 Development Environment

Initial development should happen on a Linux VM.

Recommended:

-   Debian 13
-   Ubuntu 24.04+
-   x86_64

The VM is used for:

-   VMess parsing.
-   VLESS parsing.
-   Configuration generation.
-   sing-box validation.
-   sing-box execution.
-   TUN testing.
-   DNS testing.
-   Routing testing.
-   Service lifecycle testing.

------------------------------------------------------------------------

## 3.2 OpenWrt Development VM

After the Linux core works, use an OpenWrt VM for:

-   LuCI.
-   UCI.
-   init scripts.
-   nftables.
-   routing.
-   TUN.
-   package building.
-   package installation.
-   reboot testing.

Recommended topology:

``` text
                    Internet
                       |
                       |
                +------+------+
                | OpenWrt VM  |
                |             |
                | LuCI        |
                | sing-box    |
                | nftables    |
                +------+------+
                       |
                      LAN
                       |
                +------+------+
                | Test Client |
                +-------------+
```

------------------------------------------------------------------------

## 3.3 Production

The final application targets real OpenWrt routers.

The final application should be distributable as OpenWrt packages:

``` text
cowboy-bebop-manager      (core CLI, no LuCI dependency)
luci-app-cowboy-bebop     (UI, depends on cowboy-bebop-manager)
sing-box             (dependency: OpenWrt feed or custom build)
```

Potential architectures:

``` text
x86_64
aarch64
arm
mips
mipsel
riscv64
```

Actual support depends on the target router and available sing-box
builds.

------------------------------------------------------------------------

## 3.4 Version and Hardware Requirements

-   Define a minimum supported OpenWrt release (nftables/fw4 based) and
    a minimum supported sing-box version. Pin both in
    `docs/openwrt.md`.
-   The OpenWrt feed already ships a `sing-box` package with its own
    init script and UCI config. This project must not overwrite or
    co-enable them. It uses distinct names: UCI `singbox`, init script
    `/etc/init.d/cowboy-bebop`, config dir `/etc/cowboy-bebop/`.
-   Package format depends on the OpenWrt release (`.ipk` on older
    releases, `.apk` on newer ones). Build for the format of the
    selected release.
-   A full sing-box binary is large (tens of MB uncompressed). Devices
    with very small flash or RAM are likely out of scope unless a
    reduced-feature build is used. Set an explicit minimum hardware
    target and confirm it with measurements in Phase 8.

------------------------------------------------------------------------

# 4. High-Level Architecture

``` text
                         LAN Clients
                              |
                              v
                    +-------------------+
                    |  OpenWrt Router   |
                    |                   |
                    |  Firewall         |
                    |      |            |
                    |      v            |
                    |   sing-box TUN    |
                    |      |            |
                    |      v            |
                    | VMess / VLESS     |
                    |      |            |
                    +------+------------+
                           |
                           v
                        Internet
```

Management:

``` text
Browser
   |
   v
LuCI
   |
   v
cowboy-bebop-manager
   |
   +-- protocol detection
   +-- VMess parser
   +-- VLESS parser
   +-- config generator
   +-- config validation
   +-- service control
   +-- health checks
   |
   v
sing-box
```

------------------------------------------------------------------------

# 5. Repository Structure

``` text
open-wrt-singbox/
|
+-- README.md
+-- PROJECT.md
+-- LICENSE
|
+-- core/
|   |
|   +-- protocol/
|   |   |
|   |   +-- detector.sh
|   |   |
|   |   +-- vmess/
|   |   |   +-- parser.sh
|   |   |
|   |   +-- vless/
|   |       +-- parser.sh
|   |
|   +-- config/
|   |   |
|   |   +-- generator.sh
|   |   +-- templates/
|   |
|   +-- service/
|       +-- manager.sh
|
+-- openwrt/
|   |
|   +-- cowboy-bebop-manager/
|   |   |
|   |   +-- Makefile
|   |   |
|   |   +-- root/
|   |       +-- etc/config/singbox
|   |       +-- etc/init.d/singbox
|   |       +-- usr/bin/cowboy-bebop-manager
|   |
|   +-- luci-app-cowboy-bebop/
|       |
|       +-- Makefile
|       |
|       +-- htdocs/luci-static/resources/view/singbox/main.js
|       |
|       +-- root/
|           +-- usr/libexec/rpcd/singbox
|           +-- usr/share/luci/menu.d/luci-app-cowboy-bebop.json
|           +-- usr/share/rpcd/acl.d/luci-app-cowboy-bebop.json
|
+-- tests/
|   |
|   +-- protocol/
|   +-- vmess/
|   +-- vless/
|   +-- config/
|   +-- integration/
|
+-- docs/
    |
    +-- architecture.md
    +-- openwrt.md
    +-- vmess.md
    +-- vless.md
    +-- routing.md
    +-- dns.md
    +-- troubleshooting.md
```

------------------------------------------------------------------------

# 6. Supported Protocols

The MVP supports:

``` text
VMess
VLESS
```

Accepted URL schemes:

``` text
vmess://...
vless://...
```

Protocol detection must be automatic.

``` text
URL
 |
 +-- vmess:// -> VMess parser
 |
 +-- vless:// -> VLESS parser
 |
 +-- anything else -> unsupported
```

The UI must not require the user to manually select VMess or VLESS.

------------------------------------------------------------------------

# 7. Protocol-Agnostic Architecture

Both protocols must eventually produce the same internal representation.

``` text
VMess URL
   |
   v
VMess Parser
   |
   +----------------+
                    |
                    v
             Normalized Profile
                    ^
                    |
   +----------------+
   |
VLESS URL
   |
   v
VLESS Parser
```

Then:

``` text
Normalized Profile
       |
       v
Config Generator
       |
       +-- VMess outbound
       |
       +-- VLESS outbound
```

This architecture allows additional protocols later without redesigning
the application.

------------------------------------------------------------------------

# 8. Protocol Detection

Implement:

``` text
detect_protocol(url)
```

Possible results:

``` text
vmess
vless
unsupported
invalid
```

Examples:

``` text
vmess://...
    -> vmess
```

``` text
vless://...
    -> vless
```

``` text
trojan://...
    -> unsupported
```

until Trojan is explicitly implemented.

------------------------------------------------------------------------

# 9. Normalized Profile

Both parsers must produce a normalized profile.

Example:

``` json
{
  "protocol": "vless",
  "server": "example.com",
  "server_port": 443,
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "flow": null,
  "tls": {
    "enabled": true,
    "server_name": "example.com"
  },
  "transport": {
    "type": "ws",
    "path": "/ws",
    "headers": {
      "Host": "example.com"
    }
  },
  "metadata": {
    "name": "My Server"
  }
}
```

VMess can produce the same structure:

``` json
{
  "protocol": "vmess",
  "server": "example.com",
  "server_port": 443,
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tls": {
    "enabled": true,
    "server_name": "example.com"
  },
  "transport": {
    "type": "ws",
    "path": "/ws",
    "headers": {
      "Host": "example.com"
    }
  },
  "metadata": {
    "name": "My Server"
  }
}
```

The normalized model must contain only information needed by the config
generator.

Define the schema explicitly (required vs optional fields, defaults, and
a `schema_version`) in `docs/architecture.md`. Fields the examples above
omit but the generator needs: `security` and `alter_id` for VMess;
`tls.alpn`, `tls.utls.fingerprint` and `tls.reality.*` where applicable;
and an `insecure` flag that defaults to `false`.

------------------------------------------------------------------------

# 10. VMess URL Parsing

Input:

``` text
vmess://BASE64_DATA
```

Typical VMess payload is Base64 encoded JSON.

Parser workflow:

``` text
VMess URL
   |
   v
Validate scheme
   |
   v
Extract payload
   |
   v
Base64 decode
   |
   v
Parse JSON
   |
   v
Validate fields
   |
   v
Normalize profile
```

Required information should include, when applicable:

``` text
server
port
uuid
alterId
security
network
TLS
SNI
Host
Path
```

Common transports:

``` text
tcp
ws
grpc
```

The parser must safely handle optional fields.

Real-world VMess links are messy. The parser must also handle:

-   Base64 variants: standard and URL-safe alphabets, missing padding.
-   Numeric fields (`port`, `aid`) encoded as numbers or strings.
-   Missing or empty `scy` (default security) and `aid` (default 0).
-   Header fields (`type`, `host`, `path`) that only apply to some
    transports.
-   Leading/trailing whitespace and line breaks in pasted input.

------------------------------------------------------------------------

# 11. VLESS URL Parsing

VLESS uses a URI structure similar to:

``` text
vless://UUID@HOST:PORT?PARAMETERS#NAME
```

Example:

``` text
vless://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx@example.com:443?type=ws&security=tls&sni=example.com&path=%2Fws&host=example.com#MyServer
```

The parser must extract, when present:

``` text
UUID
server
port
name
type
security
sni
host
path
serviceName
flow
fingerprint
public key
short ID
ALPN
```

The parser must URL-decode query parameters.

Unknown parameters must not automatically be passed to sing-box.

Additional rules:

-   Accept IPv6 literals in brackets (`[2001:db8::1]:443`).
-   `encryption` must be `none` (or absent); anything else is an error.
-   `allowInsecure` / `insecure` (skip certificate verification) must
    not be honored silently. Default: reject the profile with a clear
    error; allow only through an explicit opt-in setting.
-   Transports sing-box does not support (for example Xray-only
    transports) must produce `Unsupported transport`, never a guessed
    mapping.
-   Enforce a maximum input length (for example 8 KB) before decoding.
-   The `#NAME` fragment is untrusted text: URL-decode it, strip control
    characters, and never pass it to a shell.

------------------------------------------------------------------------

# 12. VLESS UUID

The VLESS UUID must be validated before configuration generation.

Invalid:

``` text
vless://hello@example.com:443
```

must produce:

``` text
Invalid VLESS UUID
```

No configuration should be generated from an invalid profile.

------------------------------------------------------------------------

# 13. VLESS Transport Support

Initial transport support:

``` text
TCP
WebSocket
```

Additional transport support:

``` text
gRPC
```

should be implemented when the parameter mapping is verified.

Future:

``` text
HTTP/2
HTTP
```

if required by supported sing-box versions.

------------------------------------------------------------------------

# 14. VLESS TLS

Example normalized profile:

``` json
{
  "protocol": "vless",
  "server": "example.com",
  "server_port": 443,
  "uuid": "UUID",
  "tls": {
    "enabled": true,
    "server_name": "example.com"
  }
}
```

Generated VLESS outbound conceptually:

``` json
{
  "type": "vless",
  "tag": "proxy",
  "server": "example.com",
  "server_port": 443,
  "uuid": "UUID",
  "tls": {
    "enabled": true,
    "server_name": "example.com"
  }
}
```

The exact configuration schema must follow the installed sing-box
version.

------------------------------------------------------------------------

# 15. VLESS WebSocket

Example:

``` text
vless://UUID@example.com:443?type=ws&security=tls&sni=example.com&path=%2Fws&host=example.com
```

Normalized:

``` json
{
  "protocol": "vless",
  "server": "example.com",
  "server_port": 443,
  "uuid": "UUID",
  "tls": {
    "enabled": true,
    "server_name": "example.com"
  },
  "transport": {
    "type": "ws",
    "path": "/ws",
    "headers": {
      "Host": "example.com"
    }
  }
}
```

Generated configuration must map this structure to the sing-box VLESS
outbound schema.

------------------------------------------------------------------------

# 16. VLESS TCP

Example:

``` text
vless://UUID@example.com:443?type=tcp&security=tls&sni=example.com
```

The generator must not create a WebSocket transport when the selected
transport is TCP.

Only required transport options should be emitted.

------------------------------------------------------------------------

# 17. VLESS gRPC

Potential URL:

``` text
vless://UUID@example.com:443?type=grpc&security=tls&sni=example.com&serviceName=my-service
```

Normalized:

``` json
{
  "protocol": "vless",
  "transport": {
    "type": "grpc",
    "service_name": "my-service"
  }
}
```

The generator must translate this into the installed sing-box version's
gRPC transport schema.

------------------------------------------------------------------------

# 18. VLESS Reality

VLESS URLs may contain Reality-related parameters.

Potential parameters:

``` text
security=reality
sni=example.com
fp=chrome
pbk=PUBLIC_KEY
sid=SHORT_ID
spx=...
```

These should be normalized into a dedicated TLS/Reality structure.

Conceptually:

``` json
{
  "tls": {
    "enabled": true,
    "server_name": "example.com",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "PUBLIC_KEY",
      "short_id": "SHORT_ID"
    }
  }
}
```

Important:

The exact sing-box field names and supported options must be verified
against the installed sing-box version.

Do not blindly copy Xray/V2Ray parameters into sing-box.

------------------------------------------------------------------------

# 19. VLESS Flow

If a VLESS URL contains:

``` text
flow=...
```

the parser should preserve it.

Example:

``` json
{
  "protocol": "vless",
  "flow": "xtls-rprx-vision"
}
```

The generator must emit the flow only if it is supported and valid for
the selected transport and TLS configuration.

------------------------------------------------------------------------

# 20. Config Generation

The generator accepts:

``` text
NormalizedProfile
```

and produces:

``` text
/etc/cowboy-bebop/config.json
```

The configuration should contain at minimum:

``` text
log
inbounds
outbounds
route
```

Example structure:

``` json
{
  "log": {
    "level": "warn"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "singtun0",
      "address": [
        "172.19.0.1/30"
      ],
      "auto_route": true
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "example.com",
      "server_port": 443,
      "uuid": "UUID",
      "tls": {
        "enabled": true,
        "server_name": "example.com"
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ],
    "final": "proxy"
  }
}
```

This is a structural example. The actual generated fields must match the
selected profile.

Notes on the example:

-   `strict_route` is intentionally omitted. On a router it can cut off
    access to the router itself; enable it only after testing.
-   `auto_detect_interface` keeps sing-box's own outbound traffic (to
    the proxy server) off the TUN, preventing a routing loop.
-   The `sniff` / `hijack-dns` rule actions handle DNS arriving through
    the TUN in current sing-box versions.
-   Private destinations go direct so LAN and router management keep
    working.
-   The `dns` section, and any resolver needed for the proxy server's
    own hostname, depend on the pinned sing-box version (section 59).
-   Evaluate `auto_redirect` (Linux, nftables) as the router-oriented
    alternative to plain `auto_route`; test both.

------------------------------------------------------------------------

# 21. Config Generator Interface

Implement conceptually:

``` text
generate_config(profile)
```

or:

``` text
generate_outbound(profile)
```

Logic:

``` text
if protocol == vmess:
    generate VMess outbound

if protocol == vless:
    generate VLESS outbound

otherwise:
    return unsupported protocol
```

The common TUN, route, and service configuration should remain shared.

------------------------------------------------------------------------

# 22. Configuration Validation

Never activate an unvalidated configuration.

Workflow:

``` text
Input URL
   |
   v
Parse
   |
   v
Generate temporary config
   |
   v
sing-box check
   |
   +---- invalid ----> keep current config
   |
   v
valid
   |
   v
backup current config
   |
   v
install new config
   |
   v
restart service
```

Candidate file (same filesystem as the target, so the final `mv` is atomic):

``` text
/etc/cowboy-bebop/config.json.new
```

Validation:

``` sh
sing-box check -c /etc/cowboy-bebop/config.json.new
```

Only after validation:

``` sh
mv /etc/cowboy-bebop/config.json.new /etc/cowboy-bebop/config.json
```

Notes:

-   Create the candidate with `umask 077` (it contains the UUID). Never
    use a predictable path in world-writable `/tmp`.
-   The candidate lives next to the target so `mv` is an atomic rename
    (a move from tmpfs to the overlay filesystem is not).
-   `sing-box check` validates syntax and schema only. It does not prove
    the server is reachable or that TUN/routing works; steps 10-12 of
    the apply workflow cover that.
-   Delete the candidate on failure.

------------------------------------------------------------------------

# 23. Configuration Backup

Before replacing:

``` text
/etc/cowboy-bebop/config.json
```

keep:

``` text
/etc/cowboy-bebop/config.json.bak
```

Only one previous backup is required for the MVP.

If activation fails, restore the previous configuration.

------------------------------------------------------------------------

# 24. OpenWrt UCI Configuration

Use:

``` text
/etc/config/cowboy-bebop
```

Example:

``` text
config singbox 'main'
    option enabled '0'
    option auto_start '0'
    option mode 'tun'
    option log_level 'warn'
    option proxy_url ''
```

The URL field is named `proxy_url` from the start because it accepts
both VMess and VLESS. Do not introduce a protocol-specific field name.

The UCI file contains the proxy URL (UUID included). Restrict it to root
(`chmod 600 /etc/config/cowboy-bebop`, and verify the permissions survive
`uci commit`) and keep it out of logs and support output.

------------------------------------------------------------------------

# 25. Sensitive Data

Proxy URLs may contain:

-   UUIDs.
-   Server addresses.
-   Server ports.
-   TLS settings.
-   transport parameters.
-   Reality parameters.

Therefore:

``` text
/etc/cowboy-bebop/config.json
```

must be protected.

Target permissions:

``` sh
chmod 600 /etc/cowboy-bebop/config.json
```

Do not print the full URL in logs.

Do not print UUIDs in normal logs.

Do not expose private keys or sensitive credentials in the UI.

------------------------------------------------------------------------

# 26. Service Manager

Create:

``` text
/usr/bin/cowboy-bebop-manager
```

Supported commands:

``` sh
cowboy-bebop-manager status
cowboy-bebop-manager start
cowboy-bebop-manager stop
cowboy-bebop-manager restart
cowboy-bebop-manager enable
cowboy-bebop-manager disable
cowboy-bebop-manager apply
cowboy-bebop-manager validate
cowboy-bebop-manager health
cowboy-bebop-manager recovery
```

------------------------------------------------------------------------

# 27. Apply Workflow

When the user presses Save & Apply:

``` text
1. Read proxy URL.
2. Detect protocol.
3. Parse VMess or VLESS.
4. Normalize profile.
5. Generate temporary config.
6. Validate config.
7. Backup current config.
8. Install new config.
9. Restart sing-box.
10. Verify process.
11. Verify TUN.
12. Verify routing.
13. Return success.
```

If any critical step fails:

``` text
STOP
```

and preserve the previous working configuration.

Steps 10-12 are the real test and must be active checks, not just
"process exists": TUN interface is up, expected routes exist, and a
test connection through the proxy succeeds. If any of them fails after
the new configuration was installed:

``` text
Restore config.json.bak
Restart sing-box
Verify the previous state works
Report the original failure
```

## Safe apply (commit-confirm)

Changing TUN/routing on a router can cut off the administrator. Use a
confirm-or-revert timer, similar to OpenWrt's own rollback:

``` text
apply
  |
  v
start revert timer (for example 60 s)
  |
  +-- user confirms in LuCI -> cancel timer, keep config
  |
  +-- no confirmation       -> run recovery
```

The timer must be a background process owned by `cowboy-bebop-manager`, not
tied to the LuCI/HTTP session, so it still fires if the browser
connection is lost.

------------------------------------------------------------------------

# 28. OpenWrt Init Script

Create:

``` text
/etc/init.d/cowboy-bebop
```

Required:

``` sh
/etc/init.d/cowboy-bebop start
/etc/init.d/cowboy-bebop stop
/etc/init.d/cowboy-bebop restart
/etc/init.d/cowboy-bebop status
/etc/init.d/cowboy-bebop enable
/etc/init.d/cowboy-bebop disable
```

The init script must manage the service.

Requirements:

-   Use `procd` (`USE_PROCD=1`) so the process is supervised.
-   Enable `respawn` with sane limits so a crash-looping sing-box does
    not spin forever, and start only when enabled in UCI.
-   Use the name `singbox`; never reuse the feed package's `sing-box`
    init script or config.
-   On stop, run the firewall cleanup (section 40) so no stale
    interception rules remain.
-   Logs go through `logd` (RAM), not to flash.

Configuration generation must remain in `cowboy-bebop-manager`.

------------------------------------------------------------------------

# 29. ON / OFF

## ON

Workflow:

``` text
UI
 |
 v
Validate config
 |
 v
Start sing-box
 |
 v
Verify process
 |
 v
Verify TUN
 |
 v
Running
```

## OFF

Workflow:

``` text
UI
 |
 v
Stop sing-box
 |
 v
Verify process
 |
 v
Stopped
```

Turning OFF must not delete the saved proxy configuration.

------------------------------------------------------------------------

# 30. Auto Start

UI:

``` text
Start automatically on boot
[ ON / OFF ]
```

ON:

``` sh
/etc/init.d/cowboy-bebop enable
```

OFF:

``` sh
/etc/init.d/cowboy-bebop disable
```

------------------------------------------------------------------------

# 31. LuCI UI

The UI should be minimal.

Location:

``` text
Services
    |
    +-- Sing-box
```

Main page:

``` text
+--------------------------------------+
|              Sing-box                |
+--------------------------------------+
|                                      |
| Status:  Running                     |
|                                      |
| Proxy URL                            |
| +----------------------------------+ |
| | (saved - hidden)                  | |
| |                                  | |
| +----------------------------------+ |
|                                      |
| Protocol: VLESS                      |
| Server: example.com                  |
| Port: 443                            |
| Transport: WebSocket                 |
| TLS: Enabled                         |
|                                      |
|        [ Save & Apply ]              |
|                                      |
|        [ ON ]      [ OFF ]           |
|                                      |
| Auto Start: [ ON ]                   |
|                                      |
| [ View Logs ]                        |
+--------------------------------------+
```

------------------------------------------------------------------------

# 32. UI Requirements

The UI must provide:

## Status

``` text
Running
Stopped
Error
Starting
Stopping
```

## Proxy URL

Use a textarea.

Once saved, the URL must not be sent back to the browser: show a masked
placeholder (for example `Saved - hidden`) plus the non-sensitive
preview from section 33. Editing means pasting a new URL.

It must accept:

``` text
vmess://...
vless://...
```

## Save & Apply

This must execute the complete apply workflow.

## ON / OFF

Simple control.

## Auto Start

Simple control.

## Logs

Show a limited amount of logs.

Example:

``` text
Last 30 lines
```

------------------------------------------------------------------------

# 33. Protocol Preview

After parsing the URL, show non-sensitive details:

``` text
Protocol: VLESS
Server: example.com
Port: 443
Transport: WebSocket
TLS: Enabled
SNI: example.com
```

Do not display the UUID by default.

Do not display the full URL after saving.

------------------------------------------------------------------------

# 34. UI Error Handling

Possible errors:

``` text
Invalid proxy URL
Unsupported protocol
Invalid VMess Base64
Invalid VMess JSON
Invalid VLESS UUID
Missing server
Invalid port
Unsupported transport
Unsupported security mode
Invalid TLS configuration
Invalid sing-box configuration
Failed to start sing-box
TUN creation failed
Routing setup failed
DNS setup failed
```

UI messages must be short and readable.

Example:

``` text
Failed to apply configuration.

Reason:
Invalid VLESS UUID.
```

Detailed diagnostic information belongs in logs.

------------------------------------------------------------------------

# 35. TUN Mode

The initial transparent proxy mode is TUN.

Concept:

``` text
LAN
 |
 v
OpenWrt routing
 |
 v
singtun0
 |
 v
sing-box
 |
 v
VMess / VLESS
 |
 v
Internet
```

Example inbound:

``` json
{
  "type": "tun",
  "tag": "tun-in",
  "interface_name": "singtun0",
  "address": [
    "172.19.0.1/30"
  ],
  "auto_route": true,
  "strict_route": true
}
```

The exact TUN configuration must be tested against the selected OpenWrt
and sing-box versions.

------------------------------------------------------------------------

# 36. LAN Traffic

Target behavior:

``` text
Client
  |
  v
OpenWrt LAN
  |
  v
Transparent interception
  |
  v
sing-box
  |
  v
VMess / VLESS
  |
  v
Internet
```

The router must remain accessible for administration.

------------------------------------------------------------------------

# 37. Direct Outbound

Always include a direct outbound:

``` json
{
  "type": "direct",
  "tag": "direct"
}
```

MVP rules (not future work: the router must stay reachable):

``` text
Private networks -> direct
Router management -> direct
LAN -> direct
Everything else -> proxy
```

Future rules:

``` text
Selected domains -> direct
Selected domains -> proxy
```

------------------------------------------------------------------------

# 38. Initial Routing Policy

MVP routing:

``` text
Most traffic -> proxy
Private/LAN/router traffic -> direct (section 37)
```

Do not implement a large routing-rule editor in the MVP.

Future routing:

``` text
Selected domains -> proxy
Selected domains -> direct
Specific applications -> proxy
```

------------------------------------------------------------------------

# 39. DNS

DNS is critical for transparent proxying.

Requirements:

-   Prevent DNS loops.
-   Keep router DNS functional.
-   Prevent proxy DNS traffic from routing back into itself.
-   Ensure domain resolution works.
-   Keep LAN clients functional.

Concrete MVP requirements:

-   Traffic from sing-box to the proxy server must bypass the TUN
    (`auto_detect_interface`, section 20).
-   If the proxy server is a hostname, it must be resolvable without
    going through the proxy; otherwise the tunnel cannot come up.
-   Define the relationship with `dnsmasq`: LAN clients keep using
    OpenWrt's DNS and sing-box must not bind port 53 on the router.
-   Decide the IPv6 policy explicitly: proxy IPv6 too, or block/disable
    it for LAN clients. Leaving it unhandled leaks traffic around the
    proxy.
-   Test for DNS leaks in Phase 4.

Initial DNS design should remain simple.

Potential future:

``` text
LAN client
    |
    v
OpenWrt DNS
    |
    v
sing-box DNS
    |
    +-- direct
    |
    +-- proxy
```

Fake-IP and advanced DNS routing should not be part of the first MVP
unless required.

------------------------------------------------------------------------

# 40. Firewall Integration

OpenWrt firewall integration should use the appropriate nftables-based
mechanisms for the target OpenWrt release.

Architecture:

``` text
cowboy-bebop-manager
       |
       v
Firewall manager
       |
       v
nftables
```

Firewall rules must be:

-   deterministic.
-   reversible.
-   minimal.
-   safe when sing-box is stopped.

Do not leave stale interception rules after disabling the proxy.

Implementation notes:

-   Use a dedicated nftables table owned by this project (for example
    `inet singbox`) so cleanup is a single table delete. Do not edit
    fw4's own tables directly.
-   If sing-box's `auto_redirect` is used, it creates its own rules:
    verify they are removed on stop, after a crash, and after SIGKILL.
-   `recovery` must be idempotent: running it twice, or when nothing is
    running, must succeed.

------------------------------------------------------------------------

# 41. Router Safety

A failed proxy must not make the router inaccessible.

If sing-box fails:

``` text
LuCI -> must remain accessible
SSH  -> must remain accessible
LAN  -> must remain recoverable
```

Never activate invalid configuration.

Firewall changes must be reversible.

------------------------------------------------------------------------

# 42. Recovery

Provide:

``` sh
cowboy-bebop-manager recovery
```

Expected behavior:

``` text
Stop sing-box
Remove proxy interception rules
Restore previous config if needed
Restore normal routing
Verify LAN management
```

Recovery must be tested before production use.

------------------------------------------------------------------------

## 42.1 Remote Admin Access (Tailscale)

Goal: reach the router (SSH/LuCI) from outside through Tailscale.

Out of scope: subnet routing, exit node, LAN clients through Tailscale,
and any Tailscale UI inside this application (the existing
`luci-app-tailscale` can be used separately).

Rules:

-   `tailscaled` is a separate service, independent from sing-box. No
    init dependency in either direction.
-   `cowboy-bebop-manager stop`, `restart` and `recovery` must not stop or
    reconfigure `tailscaled`.
-   Baseline: sing-box TUN and `tailscaled` were tested together on a
    Debian server with no special exclusion, and worked. This is not
    assumed to carry over to OpenWrt (forwarding and fw4 differ).
-   No mandatory exclusion in the MVP. If the OpenWrt test fails, fall
    back to:
    -   `100.64.0.0/10` and `tailscale0` -> direct (route rule and TUN
        exclusion).
    -   Keep `tailscaled`'s own underlay traffic direct. The method (UID,
        UDP port 41641, or mark) must be verified on the pinned
        sing-box version.
-   Firewall (fw4): a dedicated zone for `tailscale0`; allow input to
    the router only for required ports (for example 22/80/443); no
    forwarding to lan/wan. Never expose SSH or LuCI on the WAN.
-   Tailscale side: disable key expiry for the router and restrict
    access with ACLs.

Main risk: if `tailscaled`'s underlay traffic goes through the proxy and
the proxy server is down, remote access is lost exactly when it is
needed.

Tests:

``` text
Tailscale + sing-box ON: SSH and LuCI reachable via 100.x
Proxy server unreachable: router still reachable via Tailscale
sing-box OFF / recovery: Tailscale stays connected
Router reboot: both start, router reachable via Tailscale
```

------------------------------------------------------------------------

# 43. Desired State vs Actual State

Desired state:

``` text
/etc/config/cowboy-bebop
```

Actual state:

``` text
sing-box process
TUN interface
routing state
firewall state
```

Example:

``` text
Desired:
enabled=1

Actual:
sing-box stopped

Action:
start
```

This makes reboot and failure recovery more reliable.

------------------------------------------------------------------------

# 44. Service State Machine

States:

``` text
STOPPED
STARTING
RUNNING
ERROR
STOPPING
```

Normal:

``` text
STOPPED
   |
   | ON
   v
STARTING
   |
   v
RUNNING
```

Failure:

``` text
STARTING
   |
   v
ERROR
```

The UI should reflect the actual state.

------------------------------------------------------------------------

# 45. Health Check

Implement:

``` sh
cowboy-bebop-manager health
```

Checks:

``` text
sing-box binary exists
configuration exists
configuration valid
process running
TUN exists
routing exists
```

Example:

``` text
sing-box:       OK
configuration:  OK
process:        OK
TUN:            OK
routing:        OK
```

------------------------------------------------------------------------

# 46. CLI

The manager must work without LuCI.

Example:

``` sh
cowboy-bebop-manager status
```

Output:

``` text
Sing-box: running
Protocol: VLESS
Mode: tun
Config: valid
TUN: singtun0
```

Other commands:

``` sh
cowboy-bebop-manager start
cowboy-bebop-manager stop
cowboy-bebop-manager restart
cowboy-bebop-manager apply
cowboy-bebop-manager validate
cowboy-bebop-manager health
cowboy-bebop-manager recovery
```

------------------------------------------------------------------------

# 47. Security

The application must:

-   Validate all user input.
-   Never execute the proxy URL as shell code.
-   Never use `eval` with user input.
-   Never execute decoded VMess JSON.
-   Avoid shell injection.
-   Restrict configuration permissions.
-   Avoid leaking UUIDs.
-   Avoid leaking full proxy URLs.
-   Validate generated JSON.
-   Validate sing-box configuration before activation.

Never:

``` sh
eval "$PROXY_URL"
```

Never:

``` sh
sh "$USER_INPUT"
```

Never directly insert arbitrary user input into shell commands.

------------------------------------------------------------------------

# 48. Protocol Parser Security

VMess and VLESS input must be treated as untrusted.

Validate:

``` text
scheme
Base64
JSON
UUID
server
port
transport
TLS
security
query parameters
```

The parser must never execute decoded content.

------------------------------------------------------------------------

# 49. Configuration Generator Rules

Generation must be deterministic.

Same:

``` text
Normalized Profile
+
Application settings
```

must produce equivalent configuration.

Do not generate random values unless required.

------------------------------------------------------------------------

# 50. Logging

Default:

``` text
warn
```

Do not use debug logging in production unless troubleshooting.

Never log:

``` text
full VMess URL
full VLESS URL
UUID
private keys
sensitive credentials
```

Logs should focus on:

``` text
service state
configuration validation
TUN state
routing state
errors
```

------------------------------------------------------------------------

# 51. Resource Requirements

The router application should consume minimal resources.

Production should not have a permanent backend server.

Expected runtime:

``` text
LuCI
cowboy-bebop-manager only when needed
sing-box
OpenWrt services
```

The majority of CPU and RAM usage should come from sing-box itself, not
the management UI.

------------------------------------------------------------------------

## 51.1 Resource Budget and Feasibility Gate

Rule: the router must stay usable first. The proxy is secondary. We do
not ship anything until we have measured that it fits.

Target profile: 256 MB RAM, 256 MB flash. CPU is not decided yet.

Budget (starting targets, adjust after the first measurements and record
the final numbers in `docs/openwrt.md`):

-   Management layer (everything except sing-box and tailscaled): no
    resident process, negligible RAM.
-   sing-box + tailscaled idle RAM: about a third of total RAM at most.
-   Free RAM under load: at least about a quarter of total RAM.
-   Free overlay space after install: at least about 30%.

Measure before building more (feasibility gate):

``` text
sing-box and tailscale package size for the target release/arch
free overlay space after installing everything (df -h /overlay)
idle RSS of sing-box and tailscaled
RSS under load (many connections, high throughput)
boot time and time until the proxy is up
CPU use at the throughput levels in section 55
```

Also confirm the packages exist for the chosen release and architecture
(`sing-box`, `tailscale`, `jq`, `luci`). If one is missing, a custom
build (SDK) is required and must be planned before Phase 7.

Where to run the gate: the OpenWrt VM constrained to the target profile
(for example QEMU with 256 MB RAM, 1-2 vCPUs and a 256 MB root disk),
before touching real hardware. VM CPU numbers are not router CPU
numbers, so Phase 8 re-measures on the device.

Pass criteria:

-   Install fits within the flash budget.
-   Router core services (SSH, LuCI, DNS, DHCP, network) stay responsive
    while sing-box is under load.
-   No OOM kills in a sustained test.
-   Memory use is stable over time (no steady growth).

If the gate fails: do not ship. Options are a reduced-feature sing-box
build, removing optional features, or raising the minimum hardware.

Design rules that follow from this:

-   No permanent backend, no polling daemon, no extra always-on process.
-   Logs go to RAM with a size cap.
-   Evaluate memory limits for sing-box through procd (verify what the
    target release supports), so sing-box is the first thing to suffer
    under pressure, not the router.

------------------------------------------------------------------------

# 52. Testing Strategy

## 52.1 Unit Tests

VMess:

``` text
valid VMess
invalid Base64
invalid JSON
missing UUID
missing server
invalid port
WebSocket
TCP
TLS
non-TLS
```

VLESS:

``` text
valid VLESS
invalid UUID
missing server
invalid port
TCP
WebSocket
TLS
gRPC
flow
Reality parameters
URL decoding
```

------------------------------------------------------------------------

## 52.2 Generator Tests

Verify:

``` text
VMess profile -> valid VMess outbound
VLESS profile -> valid VLESS outbound
TLS -> correct TLS section
WebSocket -> correct transport
TCP -> no unnecessary WS transport
gRPC -> correct transport when supported
```

Every generated configuration must pass:

``` sh
sing-box check -c config.json
```

------------------------------------------------------------------------

## 52.3 Security and Portability Tests

``` text
shell-injection strings in every URL field and in #NAME
    ($(...), backticks, ;, quotes, newlines)
oversized input
malformed UTF-8 and control characters
Base64 edge cases (URL-safe alphabet, missing padding)
shellcheck passes on all scripts
all scripts run under busybox ash, not only bash/dash
UUID / URL never appear in logs, status output, or LuCI responses
```

------------------------------------------------------------------------

# 53. Integration Tests

Test:

``` text
URL
 |
 v
Parser
 |
 v
Normalized Profile
 |
 v
Config Generator
 |
 v
sing-box check
 |
 v
sing-box start
 |
 v
Connectivity
```

------------------------------------------------------------------------

# 54. OpenWrt Tests

Test:

``` text
boot
shutdown
restart
ON
OFF
Save & Apply
invalid URL
invalid configuration
server unreachable
sing-box crash
network restart
router reboot
```

Verify after reboot:

``` text
configuration exists
service starts if enabled
TUN exists
routing works
LuCI remains accessible
```

------------------------------------------------------------------------

# 55. Performance Testing

Measure:

``` text
Idle RAM
Idle CPU
Proxy RAM
Proxy CPU
Throughput
Latency
Concurrent clients
```

Depending on hardware, test:

``` text
10 Mbps
50 Mbps
100 Mbps
```

and higher where practical.

------------------------------------------------------------------------

# 56. Development Phases

## Phase 1 --- Core Parser

Implement:

``` text
Protocol detector
VMess parser
VLESS parser
Normalized profile
```

No LuCI.

------------------------------------------------------------------------

## Phase 2 --- Config Generator

Implement:

``` text
VMess outbound generator
VLESS outbound generator
TUN inbound
direct outbound
routing
```

Validate with:

``` sh
sing-box check
```

------------------------------------------------------------------------

## Phase 3 --- CLI Manager

Implement:

``` text
status
start
stop
restart
apply
validate
health
recovery
```

------------------------------------------------------------------------

## Phase 4 --- Linux VM Networking

Test:

``` text
sing-box
TUN
routing
DNS
VMess
VLESS
```

------------------------------------------------------------------------

## Phase 5 --- OpenWrt VM

Port:

``` text
UCI
init script
nftables
TUN
service manager
```

------------------------------------------------------------------------

## Phase 6 --- LuCI

Implement:

``` text
status
proxy URL
protocol detection
profile preview
Save & Apply
ON/OFF
Auto Start
logs
```

------------------------------------------------------------------------

## Phase 7 --- Package

Build:

``` text
luci-app-cowboy-bebop
cowboy-bebop-manager
(.ipk or .apk, matching the target OpenWrt release)
```

and required packages for the target architecture.

### 7.1 Bootable Image (x86 VM first)

Scope for now: x86 VM only. Router models are not decided yet.

-   Build the packages with the OpenWrt SDK.
-   Assemble the image with the OpenWrt Image Builder: the packages
    above, `sing-box`, `tailscale`, `jq`, plus a `files/` directory for
    non-sensitive defaults (`uci-defaults`).
-   Output: x86 `combined-efi` `.img` (convertible to qcow2/vmdk with
    `qemu-img`). OpenWrt does not produce ISOs.
-   Never embed the proxy URL or the Tailscale auth key in the image.
    Secrets are added after first boot.
-   Pin the OpenWrt and sing-box versions so builds are reproducible.

Deferred until router models are known:

-   One Image Builder target/profile per router model (a
    `sysupgrade.bin` is specific to each device).
-   CI matrix with checksums, a signed package feed for updates, and
    reflash-free upgrades through that feed.

------------------------------------------------------------------------

## Phase 8 --- Real Router

Test on real hardware.

Hardware model(s) are not decided yet. Known so far: 256 MB RAM and
256 MB flash. Record the exact models and CPU here once chosen, and test
with physical access to the device, not remotely.

Phase 8 starts only after the feasibility gate (section 51.1) has passed
in the constrained VM.

Measure:

``` text
CPU
RAM
throughput
latency
stability
reboot behavior
```

------------------------------------------------------------------------

## Phase 9 --- Remote Config Sync

This phase starts only after the local router product is stable and the
real-router tests are passing.

Scope:

``` text
Remote config source
        |
        v
Router fetch
        |
        v
Validate
        |
        v
Backup current working config
        |
        v
Apply
        |
        v
Health check
        |
        +---- success ----> keep new config
        |
        +---- failure ----> rollback
```

Requirements:

-   The router remains fully functional without remote sync.
-   Remote sync must not replace the local LuCI configuration workflow.
-   A remote configuration must pass the same validation used by local
    configuration.
-   Failed remote applies must preserve the previous working state.
-   The sync mechanism must be lightweight and suitable for constrained
    OpenWrt hardware.
-   Remote sync is an infrastructure feature, not a prerequisite for the
    MVP.

------------------------------------------------------------------------

## Phase 10 --- Web Panel

The Web Panel is the **last major feature** in the project roadmap.

It must not be started until:

``` text
Router Core        -> stable
LuCI UI            -> stable
Real Router        -> tested
Remote Config Sync -> stable
```

Potential future architecture:

``` text
                 Web Panel
                     |
                     v
          Remote Configuration API
                     |
                     v
             OpenWrt Router
                     |
                     v
              Remote Config Sync
                     |
                     v
          Validate / Backup / Apply
                     |
                     v
                  sing-box
```

The Web Panel may later provide features such as:

-   Remote profile management.
-   Remote configuration generation.
-   Router assignment and status.
-   Integration with Marzban or other compatible backends.
-   Centralized management of multiple routers.

These features are explicitly deferred. The Web Panel must remain an
optional management layer and must never become a runtime dependency of
the OpenWrt router.

------------------------------------------------------------------------

# 57. MVP Scope

The MVP must contain:

``` text
[+] VMess
[+] VLESS
[+] automatic protocol detection
[+] VMess parsing
[+] VLESS parsing
[+] normalized profile
[+] VMess outbound
[+] VLESS outbound
[+] TLS
[+] WebSocket
[+] TCP
[+] basic gRPC support where verified
[+] configuration validation
[+] config backup
[+] TUN mode
[+] basic routing
[+] basic DNS
[+] LuCI
[+] ON/OFF
[+] Save & Apply
[+] Auto Start
[+] Status
[+] Logs
[+] Health Check
[+] Recovery
```

Do not initially implement:

``` text
[-] multiple profiles
[-] subscriptions
[-] server rotation
[-] load balancing
[-] advanced routing UI
[-] traffic accounting
[-] statistics dashboard
[-] QR scanner
[-] large protocol catalog
[-] complex DNS UI
```

------------------------------------------------------------------------

# 58. Future Features

After the MVP is stable:

> **Roadmap boundary:** Remote Config Sync and the Web Panel are not part
> of the MVP. Remote Config Sync is planned only after the router is
> stable; the Web Panel is the final major feature and is intentionally
> deferred until all router-side work is complete.

## Multiple Profiles

``` text
Profile 1
Profile 2
Profile 3
```

------------------------------------------------------------------------

## Server Selection

``` text
Germany
Netherlands
Turkey
Egypt
```

with:

``` text
Connect
Disconnect
```

------------------------------------------------------------------------

## Subscriptions

Later:

``` text
Subscription URL
       |
       v
Fetch
       |
       v
Parse
       |
       v
Profiles
```

Subscription support must come after the single-profile architecture is
stable.

------------------------------------------------------------------------

## More Protocols

Potential future:

``` text
Trojan
Shadowsocks
Hysteria
TUIC
```

Each protocol should have:

``` text
parser
normalizer
generator
tests
```

The UI should remain protocol-agnostic.

------------------------------------------------------------------------

# 59. Compatibility Rule

The installed sing-box version is the source of truth for configuration
syntax.

Do not assume:

``` text
Xray config == sing-box config
```

or:

``` text
V2Ray parameter == sing-box parameter
```

The parser must translate supported parameters into the correct sing-box
representation.

Unknown parameters must either:

1.  be ignored when non-essential, or
2.  generate a clear error when required for the connection.

Version policy:

-   Pin a minimum sing-box version and record it in `docs/openwrt.md`.
-   `cowboy-bebop-manager` reads `sing-box version`, selects the matching
    template from `core/config/templates/`, and refuses to apply on
    unsupported versions.
-   sing-box deprecates and removes legacy options between releases
    (for example the old special outbounds and inbound-level sniffing,
    replaced by route rule actions, and the older DNS server format).
    Do not generate deprecated syntax; track the changelog of the
    pinned version.
-   CI runs `sing-box check` against every supported version.

------------------------------------------------------------------------

# 60. Architecture Evolution

Phase 1:

``` text
Linux VM
 |
 +-- protocol parser
 +-- config generator
 +-- sing-box
```

Phase 2:

``` text
OpenWrt VM
 |
 +-- sing-box
 +-- manager
 +-- UCI
 +-- LuCI
```

Phase 3:

``` text
Real OpenWrt Router
 |
 +-- sing-box
 +-- luci-app-cowboy-bebop
 +-- nftables
 +-- TUN
```

Phase 4:

``` text
Production
 |
 +-- multiple profiles
 +-- subscriptions
 +-- routing rules
 +-- DNS controls
 +-- monitoring
```

------------------------------------------------------------------------

# 61. Definition of Done --- MVP

The MVP is complete when all are true:

``` text
[ ] vmess:// is accepted
[ ] vless:// is accepted
[ ] protocol is automatically detected
[ ] VMess is parsed
[ ] VLESS is parsed
[ ] VMess config is generated
[ ] VLESS config is generated
[ ] TLS works
[ ] WebSocket works
[ ] TCP works
[ ] verified gRPC profiles work
[ ] invalid URLs are rejected
[ ] unsupported parameters are handled safely
[ ] generated config passes sing-box validation
[ ] old working config is preserved on failure
[ ] ON/OFF works
[ ] auto-start works
[ ] TUN works
[ ] LAN traffic works
[ ] DNS works
[ ] router remains accessible
[ ] LuCI displays protocol information
[ ] sensitive credentials are not logged
[ ] OpenWrt package installs correctly
[ ] reboot behavior is verified
[ ] recovery works
[ ] feasibility gate (51.1) passed on the 256 MB RAM / 256 MB flash profile
[ ] router reachable via Tailscale with sing-box ON, and when the proxy server is down
[ ] recovery/stop does not touch tailscaled
[ ] failed apply rolls back to the previous working config
[ ] commit-confirm timer reverts an unconfirmed apply
[ ] no stale nftables rules after stop, crash, or recovery
[ ] no UUID/URL in logs, status output, or LuCI responses
[ ] IPv6 and DNS leak behavior verified
```

------------------------------------------------------------------------

# 62. Recommended Implementation Order

Do not start with LuCI.

Implement in this order:

``` text
1. Protocol detector
2. VMess parser
3. VLESS parser
4. Normalized profile
5. Config generator
6. sing-box validation
7. CLI manager
8. sing-box service
9. TUN
10. routing
11. DNS
12. OpenWrt integration
13. UCI
14. LuCI
15. packaging
16. real router testing
```

This ensures networking and configuration problems are solved before UI
development.

------------------------------------------------------------------------

# 63. Final User Experience

The final application should feel like a very small router plugin.

``` text
Open Router IP
      |
      v
LuCI
      |
      v
Services -> Sing-box
      |
      v
Paste VMess or VLESS URL
      |
      v
Protocol detected automatically
      |
      v
Configuration preview
      |
      v
Save & Apply
      |
      v
sing-box validation
      |
      v
Service starts
      |
      v
TUN starts
      |
      v
LAN traffic uses proxy
```

Turning the proxy off:

``` text
OFF
 |
 v
sing-box stops
 |
 v
proxy interception stops
 |
 v
normal router networking remains available
```

The production application must remain small enough to run on OpenWrt
hardware meeting the minimum requirements in section 3.4, without
requiring a heavyweight application runtime.

------------------------------------------------------------------------

# 64. Project Success Criteria

The project is successful when a user can install the package on a
supported OpenWrt router and perform the complete workflow without SSH:

``` text
Install package
      |
      v
Open LuCI
      |
      v
Paste VMess/VLESS URL
      |
      v
Save & Apply
      |
      v
ON
      |
      v
LAN clients use the proxy
```

The user should only need SSH for:

-   initial installation on unsupported systems.
-   diagnostics.
-   development.
-   advanced recovery.

The normal operation must be handled entirely from LuCI.

# 60. Current Implementation and Real-Device Lab Status — 2026-10-07

This section records the implementation and testing work completed after the original project specification, including the real KT-708 OpenWrt build, package CI, sing-box TUN/auto-redirect testing, and the current configuration state.

## 60.1 Repository

GitHub repository:

```text
https://github.com/adourix/open-wrt-singbox
```

The project is currently organized around:

```text
openwrt/cowboy-bebop-manager/
openwrt/luci-app-cowboy-bebop/
.github/workflows/build-packages.yml
```

The core package is intentionally lightweight and is designed to run on OpenWrt without Node.js, Docker, React, Vue, Python, or a resident application server.

---

## 60.2 OpenWrt Target: Mercury KT-708

The first real hardware target tested is:

```text
Device:          Mercury KT-708
DTS compatible:  mercury,ti04_708h
OpenWrt target:  ipq40xx/generic
SoC:             Qualcomm IPQ4019
CPU:             ARM Cortex-A7
Architecture:    arm_cortex-a7_neon-vfpv4
RAM:             256 MB
```

The running board DTS uses:

```dts
compatible = "mercury,ti04_708h";
```

The image device definition is:

```text
target/linux/ipq40xx/image/generic.mk
```

Device definition:

```make
TARGET_DEVICES += mercury_ti04-708h
```

The device definition uses:

```text
DEVICE_MODEL   := KT-708
DEVICE_VARIANT := ti04_708h
SOC            := qcom-ipq4019
DEVICE_DTS     := qcom-ipq4019-ti04-708h
```

A compatibility issue was found between the image device name and the running board's reported compatible string. The device definition was updated with:

```make
SUPPORTED_DEVICES := mercury,ti04_708h
```

This made `sysupgrade -T` accept the generated image.

---

## 60.3 Local Full OpenWrt Build

A full OpenWrt firmware image was built locally for:

```text
ipq40xx/generic
mercury_ti04-708h
```

Build output directory:

```text
bin/targets/ipq40xx/generic/
```

Important generated files:

```text
openwrt-ipq40xx-generic-mercury_ti04-708h-initramfs-uImage.itb
openwrt-ipq40xx-generic-mercury_ti04-708h-squashfs-factory.ubi
openwrt-ipq40xx-generic-mercury_ti04-708h-squashfs-sysupgrade.bin
```

Approximate sizes observed:

```text
initramfs-uImage.itb       ~21 MB
squashfs-factory.ubi      ~17 MB
squashfs-sysupgrade.bin   ~17 MB
```

The sysupgrade image was copied to the router with OpenSSH/SCP legacy protocol because the router does not provide the SFTP server expected by modern SCP:

```sh
scp -O bin/targets/ipq40xx/generic/openwrt-ipq40xx-generic-mercury_ti04-708h-squashfs-sysupgrade.bin \
    root@192.168.1.5:/tmp/
```

The image was initially rejected because the router reported:

```text
Device mercury,ti04_708h not supported by this image
Supported devices: mercury,ti04-708h
```

After adding:

```make
SUPPORTED_DEVICES := mercury,ti04_708h
```

and rebuilding, the following test passed without an error:

```sh
sysupgrade -T /tmp/openwrt-ipq40xx-generic-mercury_ti04-708h-squashfs-sysupgrade.bin
```

The image was therefore accepted by the device compatibility check.

At the time of the first real-device image test, the generated manifest contained:

```text
sing-box-tiny - 1.12.17-r1
```

The custom manager/LuCI packages were intentionally not included in that first image test; they are being developed and packaged separately.

---

## 60.4 OpenWrt Package Manager: apk

The tested OpenWrt build uses the newer `apk` package manager rather than `opkg`.

Do not use old `opkg` commands on this target.

Useful commands:

```sh
apk list --installed
apk list --installed | grep -E 'sing-box|nfnetlink|nfq|nft'
apk update
apk add <package>
```

The target currently has these relevant packages installed:

```text
kmod-nfnetlink-6.12.94-r1
kmod-nft-core-6.12.94-r1
kmod-nft-fib-6.12.94-r1
kmod-nft-nat-6.12.94-r1
kmod-nft-offload-6.12.94-r1
libnftnl11-1.3.1-r1
nftables-json-1.1.6-r2
sing-box-tiny-1.12.17-r1
```

`kmod-tun` was also installed during TUN testing.

OpenWrt apk documentation:

```text
https://openwrt.org/docs/guide-user/additional-software/apk
https://openwrt.org/docs/guide-user/additional-software/opkg-to-apk-cheatsheet
```

---

## 60.5 sing-box-tiny

The project uses the OpenWrt feed's reduced package:

```text
sing-box-tiny
```

rather than requiring the full `sing-box` package on the target router.

Installed version during the KT-708 test:

```text
sing-box-tiny 1.12.17-r1
```

The project package dependency was changed from the full package to the tiny package:

```make
DEPENDS:=+sing-box-tiny +jq +nftables +uclient-fetch +kmod-tun +kmod-nfnetlink-queue +kmod-nft-queue +kmod-inet-diag
```

This is important because the OpenWrt packages feed defines `sing-box-tiny` as a provider/conflict alternative to the full `sing-box` package. A direct dependency configuration that causes both package symbols to be selected can create a Kconfig recursive dependency.

---

## 60.6 cowboy-bebop-manager Package

Current package:

```text
openwrt/cowboy-bebop-manager/Makefile
```

Current package release:

```text
PKG_RELEASE:=10
```

Current dependencies:

```text
sing-box-tiny
jq
nftables
uclient-fetch
kmod-tun
kmod-nfnetlink-queue
kmod-nft-queue
kmod-inet-diag
```

The package installs the manager and its core components under:

```text
/usr/bin/cowboy-bebop-manager
/usr/lib/cowboy-bebop-manager/
```

and installs:

```text
/etc/config/cowboy-bebop
/etc/init.d/cowboy-bebop
```

The manager package is intended to remain independent of LuCI.

Commit containing the updated manager Makefile:

```text
21e099fdecb6a9d41c76be776d2f841dc570b1ba
```

---

## 60.7 LuCI Package

The UI package is:

```text
openwrt/luci-app-cowboy-bebop/
```

It depends on:

```text
cowboy-bebop-manager
```

The package is built separately from the core manager and is not required for the core CLI/TUN testing.

---

## 60.8 GitHub Actions Package CI

The project moved to a package-only OpenWrt SDK CI workflow.

Workflow:

```text
.github/workflows/build-packages.yml
```

The CI does not build complete firmware images. It builds the project packages using the OpenWrt SDK.

Current SDK release pinned in the workflow:

```text
OpenWrt 25.12.5
```

SDKs:

```text
x86-64:
openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst

KT-708 target:
openwrt-sdk-25.12.5-ipq40xx-generic_gcc-14.3.0_musl_eabi.Linux-x86_64.tar.zst
```

KT-708 target configuration:

```text
target: ipq40xx/generic
arch:   arm_cortex-a7_neon-vfpv4
```

The workflow:

1. Installs host dependencies including `zstd`.
2. Downloads the OpenWrt SDK.
3. Verifies the SDK using OpenWrt checksums.
4. Updates the `packages` and `luci` feeds.
5. Installs the feeds.
6. Copies the project's OpenWrt packages into the SDK.
7. Runs `make defconfig`.
8. Verifies package Makefiles and the `sing-box-tiny` dependency.
9. Builds:

```sh
make package/cowboy-bebop-manager/compile package/luci-app-cowboy-bebop/compile V=s
```

10. Stores build logs and package artifacts.

Workflow commit:

```text
0207f000aeec35ffbd14e8153a6f3d846d92d820
```

---

## 60.9 CI Failure and Resolution

Build run #75:

```text
Run ID: 37510623307
Commit: 1653f85bc53350808c879a633dc867dfda90902c
```

The failure was a Kconfig recursive dependency involving `sing-box` and `sing-box-tiny`:

```text
PACKAGE_cowboy-bebop-manager depends on PACKAGE_sing-box-tiny
PACKAGE_sing-box-tiny depends on PACKAGE_sing-box
PACKAGE_sing-box is selected by PACKAGE_cowboy-bebop-manager
```

The resulting broken configuration also caused:

```text
No rule to make target 'package/luci-app-cowboy-bebop/compile'
```

The latter was treated as a consequence of the broken Kconfig state rather than the primary cause.

The manager dependency was changed to explicitly use the tiny package, and the package build workflow was cleaned up accordingly.

Future CI runs must be checked by run ID/status rather than assuming success from the workflow file alone.

---

## 60.10 Real KT-708 sing-box Test

The real router currently uses:

```text
Router IP: 192.168.1.5
LAN:       192.168.1.0/24
Gateway:   192.168.1.1
```

Basic Internet connectivity was verified independently of sing-box:

```text
ping google.com       -> successful
ping 192.168.1.1      -> successful
ping 1.1.1.1          -> successful
DNS via 192.168.1.1  -> successful
```

Therefore the WAN/default route and normal DNS path are functional.

---

## 60.11 TUN Device Verification

The router has:

```text
/dev/net/tun
```

with:

```text
crw------- 1 root root 10, 200 ... /dev/net/tun
```

Running:

```sh
sing-box check -c /etc/sing-box/config.json
```

successfully produced no error when the JSON was valid.

Running sing-box created a TUN interface. During an earlier configuration test the interface was:

```text
singtun0
```

and later the current configuration uses:

```text
tun0
```

The current configuration therefore expects:

```text
tun0
```

The TUN interface was observed as:

```text
<POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP>
```

This proves that the kernel TUN device and sing-box TUN creation path are functional.

---

## 60.12 sing-box auto_route / auto_redirect

The real router successfully demonstrated sing-box policy routing and nftables integration with:

```json
"auto_route": true,
"auto_redirect": true,
"strict_route": true
```

Observed routing rules:

```text
9000: from all fwmark 0x2024 lookup unspec local
9001: from all fwmark 0x2023 lookup 2022
```

Observed proxy routing table:

```text
default via 172.19.0.2 dev singtun0 table 2022
```

The main routing table remained:

```text
default via 192.168.1.1 dev br-lan
192.168.1.0/24 dev br-lan scope link src 192.168.1.5
```

This is expected for `auto_redirect`: the normal default route is not replaced by a simple `default dev tun0`. Traffic selected by marks/policy routing is redirected through the sing-box TUN path.

---

## 60.13 sing-box nftables Table

When `auto_redirect` was active, sing-box created its own nftables table:

```text
table inet sing-box
```

It contained a local-address set including:

```text
127.0.0.0/8
172.19.0.0/30
192.168.1.0/24
```

and chains for output/prerouting processing.

Observed behavior included:

```text
DNS redirection to 172.19.0.2
TCP redirect to a sing-box local port
fwmark 0x2023
fwmark 0x2024
```

Counters were observed increasing while traffic was processed.

This confirms that `auto_redirect` is not merely creating the TUN interface; it is integrating with nftables/policy routing on the real OpenWrt device.

---

## 60.14 Current Routing Model

The intended production model is:

```text
                 Internet
                    ^
                    |
                 VLESS
                    |
              +-----------+
              | sing-box  |
              |   TUN     |
              +-----+-----+
                    ^
                    |
              nftables/fw4
                    ^
                    |
             OpenWrt bridge
                    ^
          +---------+---------+
          |         |         |
        Client    Client    Client
```

Policy:

```text
LAN/private/router-management traffic -> direct
Internet-bound client traffic        -> proxy
sing-box's own proxy-server traffic  -> physical/default interface
```

Private/local traffic must not be blindly proxied because that can break access to the router and LAN.

---

## 60.15 Current VLESS Test Configuration

The latest manually tested configuration uses a VLESS outbound with:

```text
Protocol: VLESS
Transport: WebSocket
TLS: enabled
ALPN: http/1.1
uTLS fingerprint: ios
WebSocket path: /
```

The proxy endpoint is intentionally not documented here with credentials. The actual endpoint and UUID must remain local configuration data and must never be committed to Git or printed in project logs.

The current configuration structure is:

```json
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "address": [
        "172.19.0.1/30"
      ],
      "auto_route": true,
      "auto_redirect": true,
      "strict_route": true
    }
  ],
  "dns": {
    "servers": [
      {
        "type": "udp",
        "tag": "configured-dns-0",
        "server": "1.1.1.1",
        "server_port": 53
      },
      {
        "type": "udp",
        "tag": "configured-dns-1",
        "server": "8.8.8.8",
        "server_port": 53
      }
    ],
    "final": "configured-dns-0",
    "strategy": "ipv4_only"
  },
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "vless",
      "tag": "proxy-out",
      "server": "<PROXY_SERVER>",
      "server_port": <PROXY_PORT>,
      "uuid": "<UUID>",
      "domain_resolver": {
        "server": "configured-dns-0",
        "strategy": "ipv4_only"
      },
      "tls": {
        "enabled": true,
        "server_name": "<SNI>",
        "alpn": [
          "http/1.1"
        ],
        "insecure": true,
        "utls": {
          "enabled": true,
          "fingerprint": "ios"
        }
      },
      "transport": {
        "type": "ws",
        "path": "/"
      }
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "ip_cidr": [
          "1.1.1.1/32",
          "8.8.8.8/32"
        ],
        "outbound": "direct"
      }
    ],
    "default_domain_resolver": {
      "server": "configured-dns-0",
      "strategy": "ipv4_only"
    },
    "final": "proxy-out"
  }
}
```

`<PROXY_SERVER>`, `<PROXY_PORT>`, `<UUID>`, and `<SNI>` are placeholders. Do not replace them in the project documentation with real credentials.

Important: `insecure: true` is currently used only in manual testing. The production parser must not silently honor `allowInsecure`; it must require an explicit opt-in as already specified in the VLESS parsing rules.

---

## 60.16 Config Path Correction

The actual manually tested router path is:

```text
/etc/sing-box/config.json
```

The earlier project text contains examples using:

```text
/etc/cowboy-bebop/config.json
/etc/cowboy-bebop/
```

These names must be reconciled before the production package is finalized. The implementation should choose one canonical path and use it consistently across:

```text
config generator
validator
init script
LuCI RPC
backup/recovery
health checks
```

The real sing-box package/config layout on the selected OpenWrt release must be treated as authoritative when integrating with the feed package.

---

## 60.17 JSON Validation Incident

During manual testing, the config was temporarily invalid because an extra object opening brace was inserted after the `inbounds` array.

The error was:

```text
invalid character '{' looking for beginning of object key string: row 30, column 1
```

The issue was fixed by removing the extra `{`.

The required validation workflow is now explicitly:

```sh
sing-box check -c /etc/sing-box/config.json
```

Only after validation succeeds should the service be started.

This reinforces the project requirement that invalid generated configuration must never be activated.

---

## 60.18 OpenWrt BusyBox Constraints Observed

The KT-708 build uses a minimal BusyBox environment. During troubleshooting:

```text
nl       -> not installed
cat -n   -> unsupported by this BusyBox build
curl     -> not installed
```

Therefore scripts must not assume GNU utilities or `curl` are available.

Preferred production-compatible tools include:

```text
ash
sed
awk
grep
cat
uci
jq
uclient-fetch
ip
nft
```

The manager must remain BusyBox/OpenWrt compatible.

---

## 60.19 Testing Lessons

### Do not use `curl` as a required router test tool

The target may not contain curl. Prefer:

```sh
uclient-fetch -qO- https://api.ipify.org
```

when appropriate, or use a LAN client for public-IP verification.

### Do not confuse TUN creation with successful proxying

A successful:

```text
ip link show tun0
```

only proves that the TUN interface exists.

Successful proxy operation requires all of:

```text
valid sing-box config
+ reachable proxy endpoint
+ successful VLESS handshake
+ correct routing
+ correct nftables interception
+ working DNS
+ no proxy loop
```

### Do not replace the main default route manually

With `auto_redirect`, the main route can remain:

```text
default via 192.168.1.1 dev br-lan
```

while selected traffic is sent through policy routing/table `2022` and the TUN.

### Keep the proxy endpoint outside the proxy path

`auto_detect_interface` is important so the outbound connection used by sing-box to reach the proxy server does not get redirected back into its own TUN.

---

## 60.20 Current Validation Checklist

### Router / kernel

```text
[x] OpenWrt running on KT-708
[x] ipq40xx/generic target
[x] /dev/net/tun exists
[x] kmod-nfnetlink installed
[x] nftables-json installed
[x] sing-box-tiny installed
[x] basic WAN connectivity
[x] DNS connectivity
```

### sing-box

```text
[x] sing-box binary runs
[x] valid config can pass sing-box check
[x] TUN interface can be created
[x] auto_route creates policy-routing state
[x] auto_redirect creates sing-box nftables state
[ ] VLESS end-to-end handshake fully verified with the current profile
[ ] LAN client public IP confirmed through the proxy
[ ] DNS leak test completed
[ ] IPv6 leak policy finalized
```

### OpenWrt package

```text
[x] cowboy-bebop-manager Makefile updated
[x] sing-box-tiny dependency selected
[x] package-only SDK CI created
[x] x86 SDK target defined
[x] ipq40xx/generic SDK target defined
[ ] latest CI run confirmed green
[ ] final package installation tested on KT-708
[ ] procd service tested through reboot
[ ] recovery tested after SIGKILL/crash
```

### LuCI

```text
[ ] final UI integration
[ ] Save & Apply integration
[ ] ON/OFF integration
[ ] Auto Start
[ ] status
[ ] logs
[ ] health check
[ ] recovery
```

---

## 60.21 Recommended Next Sequence

The next implementation order for the real KT-708 target is:

```text
1. Validate the current VLESS profile with sing-box check
2. Verify the VLESS handshake
3. Verify LAN client -> proxy -> Internet
4. Verify public IP from a LAN client
5. Verify DNS behavior/leaks
6. Decide explicit IPv6 policy
7. Finalize config path
8. Implement/verify procd service
9. Implement recovery/rollback
10. Package cowboy-bebop-manager
11. Install package on KT-708 using apk
12. Test enable/start/restart/stop
13. Reboot router and verify automatic startup
14. Integrate LuCI
15. Test Save & Apply and ON/OFF without SSH
16. Re-run package CI for x86 and KT-708
```

Do not move to a polished LuCI workflow before the core VLESS + TUN + LAN routing path is reliable.

---

## 60.22 Security Rules for the Repository

Never commit:

```text
VLESS UUIDs
VMess UUIDs
private keys
Reality private keys
proxy subscription URLs
personal access tokens
Tailscale auth keys
```

Project documentation should use placeholders such as:

```text
<UUID>
<PROXY_SERVER>
<PROXY_PORT>
<SNI>
<PUBLIC_KEY>
<SHORT_ID>
```

Logs and status output must not expose credentials.

The parser must not execute decoded URL content as shell code.

All generated JSON must be built structurally with `jq` or equivalent safe mechanisms rather than unsafe shell string concatenation.

---

## 60.23 Current Project State

The project has moved from specification-only work into real OpenWrt hardware validation.

Current status:

```text
Specification                 -> complete baseline
Linux/VM design               -> defined
VMess/VLESS architecture      -> defined
OpenWrt package structure     -> implemented
sing-box-tiny integration     -> implemented/tested
GitHub SDK package CI         -> implemented
KT-708 firmware build         -> completed locally
KT-708 image compatibility    -> fixed/tested with sysupgrade -T
apk-based package management  -> confirmed
TUN creation                  -> confirmed
sing-box auto_route           -> confirmed
sing-box auto_redirect        -> confirmed
nftables integration          -> confirmed
Basic router Internet         -> confirmed
VLESS end-to-end              -> still being validated
LAN-wide proxy                -> still being validated
procd lifecycle               -> pending
Recovery/rollback             -> pending
LuCI final workflow            -> pending
```

The immediate engineering goal is therefore not another firmware rebuild. The immediate goal is to finish the end-to-end traffic path on the already working KT-708 OpenWrt installation, then package and automate that working configuration.


# 61. Authoritative Current Package Specification — Cowboy Bebop

This section is the current implementation contract. If an older section in this document conflicts with this section, this section is authoritative for the current repository state.

## 61.1 Project Identity

```text
GitHub:
https://github.com/adourix/open-wrt-singbox

Project name:
Cowboy Bebop Manager

External runtime:
sing-box

OpenWrt release tested:
25.12.5
```

The project is a lightweight OpenWrt management layer around the `sing-box` binary. `sing-box` remains the actual proxy engine; Cowboy Bebop is responsible for URL parsing, configuration generation, validation, service lifecycle, routing/firewall integration, recovery, and LuCI control.

The production system must not require Node.js, Docker, React, Vue, Python, or a permanent application server.

## 61.2 Canonical Naming

All project-owned runtime names use the Cowboy Bebop naming scheme:

```text
service:          cowboy-bebop
config:           /etc/cowboy-bebop/config.json
candidate:        /etc/cowboy-bebop/config.json.new
backup:           /etc/cowboy-bebop/config.json.bak
pending:          /etc/cowboy-bebop/config.pending
pending state:    /etc/cowboy-bebop/state.pending.json
manager:          /usr/bin/cowboy-bebop-manager
init:             /etc/init.d/cowboy-bebop
library:          /usr/lib/cowboy-bebop/
package:          cowboy-bebop-manager
LuCI package:     luci-app-cowboy-bebop
LuCI URL:         /admin/services/cowboy-bebop
UCI config:       /etc/config/cowboy-bebop
UCI section:      cowboy-bebop.main
rollback PID:     /var/run/cowboy-bebop-rollback.pid
```

The name `sing-box` is intentionally retained because it is the real external binary and protocol engine.

## 61.3 Repository Package Layout

The intended repository layout is:

```text
open-wrt-singbox/
|
+-- core/
|   +-- protocol/
|   |   +-- detector.sh
|   |   +-- vmess/parser.sh
|   |   +-- vless/parser.sh
|   +-- config/
|   |   +-- generator.sh
|   |   +-- validator.sh
|   |   +-- version.sh
|   |   +-- templates/
|   +-- service/
|       +-- manager.sh
|
+-- openwrt/
|   +-- cowboy-bebop-manager/
|   |   +-- Makefile
|   |   +-- files/
|   |       +-- etc/config/cowboy-bebop
|   |       +-- etc/init.d/cowboy-bebop
|   |       +-- usr/bin/cowboy-bebop-manager
|   |       +-- usr/lib/cowboy-bebop/
|   |
|   +-- luci-app-cowboy-bebop/
|       +-- Makefile
|       +-- htdocs/luci-static/resources/view/cowboy-bebop/overview.js
|       +-- root/usr/libexec/rpcd/luci.cowboy_bebop
|
+-- openwrt/imagebuilder/
+-- tests/
+-- docs/
+-- .github/workflows/build-packages.yml
```

The source tree should not contain project-owned runtime paths such as `/etc/singbox`, `/usr/lib/singbox-manager`, or the old manager executable name. The only intentionally retained `sing-box` name is the external proxy engine.

## 61.4 Core Manager Package

Package metadata:

```make
PKG_NAME:=cowboy-bebop-manager
PKG_RELEASE:=14
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Abdulrahman Ayad
```

Current package dependencies:

```text
+sing-box-tiny
+jq
+nftables
+uclient-fetch
+kmod-tun
+kmod-nfnetlink-queue
+kmod-nft-queue
+kmod-inet-diag
```

The package is deliberately independent of LuCI. The manager must work from the CLI and can be used by the LuCI RPC layer.

The package installs:

```text
/usr/bin/cowboy-bebop-manager
/usr/lib/cowboy-bebop/protocol/detector.sh
/usr/lib/cowboy-bebop/protocol/vmess/parser.sh
/usr/lib/cowboy-bebop/protocol/vless/parser.sh
/usr/lib/cowboy-bebop/config/generator.sh
/usr/lib/cowboy-bebop/config/validator.sh
/usr/lib/cowboy-bebop/config/version.sh
/usr/lib/cowboy-bebop/config/templates/1.13.21.json
/usr/lib/cowboy-bebop/network/firewall.sh
/usr/lib/cowboy-bebop/service/manager.sh
/etc/config/cowboy-bebop
/etc/init.d/cowboy-bebop
```

The packaged template is pinned to sing-box `1.13.21` for the current manager implementation. The installed binary/version must be checked before generating or activating a configuration.

## 61.5 UCI Defaults and Auto Start

The image-builder first-boot defaults are:

```sh
uci -q set cowboy-bebop.main.enabled='1'
uci -q set cowboy-bebop.main.auto_start='1'
uci -q set cowboy-bebop.main.allow_insecure='1'
uci -q set cowboy-bebop.main.ipv6_policy='block'
uci -q delete cowboy-bebop.main.proxy_url 2>/dev/null || true
uci -q commit cowboy-bebop
```

The intended behavior is that a valid installed configuration can start automatically without requiring the user to manually execute:

```sh
uci set cowboy-bebop.main.enabled='1'
uci commit cowboy-bebop
/etc/init.d/cowboy-bebop enable
/etc/init.d/cowboy-bebop restart
```

Those commands remain useful for diagnostics but are not the normal user workflow.

## 61.6 Init / procd Contract

The service is:

```text
/etc/init.d/cowboy-bebop
```

It uses OpenWrt `procd` and runs:

```text
/usr/bin/sing-box run -c /etc/cowboy-bebop/config.json
```

Before starting it must:

1. Recover a pending configuration if one exists.
2. Verify that the sing-box binary exists.
3. Verify the configuration with `sing-box check`.
4. Apply the Cowboy Bebop firewall integration.
5. Start sing-box under procd.
6. Provide respawn behavior.

On stop it must clean up the Cowboy Bebop firewall state.

The service must never start an invalid configuration.

## 61.7 Manager Runtime Contract

The wrapper `/usr/bin/cowboy-bebop-manager` exports:

```text
INIT=/etc/init.d/cowboy-bebop
MANAGER_LIB=/usr/lib/cowboy-bebop
CONFIG_DIR=/etc/cowboy-bebop
CONFIG=/etc/cowboy-bebop/config.json
CANDIDATE=/etc/cowboy-bebop/config.json.new
BACKUP=/etc/cowboy-bebop/config.json.bak
PENDING=/etc/cowboy-bebop/config.pending
PENDING_STATE=/etc/cowboy-bebop/state.pending.json
```

The wrapper then executes the core service manager.

The apply flow is:

```text
LuCI / CLI
   |
   v
read proxy URL + policy
   |
   v
protocol detection
   |
   +---- VMess parser
   |
   +---- VLESS parser
   |
   v
Normalized profile
   |
   v
configuration generator
   |
   v
config.json.new
   |
   v
sing-box check
   |
   v
install validated config
   |
   v
restart service
   |
   v
health verification
   |
   v
confirmed / rollback
```

## 61.8 Configuration Safety and Rollback

The manager keeps:

```text
config.json.new
config.json.bak
config.pending
state.pending.json
```

The pending state stores the previous UCI state needed for recovery, including:

```text
proxy_url
allow_insecure
auto_start
enabled
```

If a pending transaction is detected during boot:

- Restore the last valid backup when available.
- Restore the saved UCI state.
- Re-enable/disable the init service according to the saved `auto_start` value.
- Remove pending markers.

If there is no valid backup, the safe behavior is to disable Cowboy Bebop rather than repeatedly booting into a broken proxy configuration.

## 61.9 VMess Parser Contract

Input:

```text
vmess://BASE64_DATA
```

The parser:

1. Validates the scheme.
2. Decodes the Base64 payload.
3. Parses the JSON.
4. Validates required values.
5. Normalizes the result.

It must handle common real-world variations such as:

```text
standard Base64
URL-safe Base64
missing padding
numeric strings vs numbers
missing aid
missing/empty scy
optional ws/grpc fields
whitespace around pasted links
```

The normalized VMess profile is passed to the same generator pipeline used by VLESS.

## 61.10 VLESS Parser Contract

Input:

```text
vless://UUID@HOST:PORT?PARAMETERS#NAME
```

The current parser extracts the values needed by the generator, including:

```text
UUID
server
port
type
security
sni
host
path
serviceName
flow
fp
pbk
sid
alpn
allowInsecure / insecure
encryption
```

The parser URL-decodes query parameters and normalizes boolean values.

The generator must not assume that all VLESS links have the same transport or TLS settings. The URL is the source of profile-specific values; project-wide behavior is added by the generator.

Validation rules include:

```text
invalid UUID -> reject
unsupported encryption -> reject
unsupported transport -> reject
invalid/unsafe input -> reject
unknown URL parameters -> do not blindly pass through
```

Input length must be bounded and fragment/name data must never be executed as shell code.

## 61.11 VLESS Generator Contract

The generated VLESS outbound always uses the profile values for:

```text
server
server_port
uuid
```

The generator adds project-defined/static configuration such as:

```json
"domain_resolver": {
  "server": "configured-dns-0",
  "strategy": "ipv4_only"
}
```

TLS values come from the URL profile where present:

```text
server_name / SNI
ALPN
insecure
uTLS fingerprint
Reality settings
```

Transport mapping:

```text
ws   -> WebSocket transport with path/headers
grpc -> gRPC transport with service_name
tcp  -> no WebSocket transport object
```

Reality values are mapped only to fields supported by the pinned sing-box version.

`allowInsecure` is not supposed to become an unconditional `insecure:true` for every VLESS profile. The link value and the explicit project policy must both be considered.

## 61.12 Current Generated sing-box Baseline

The currently proven manual configuration uses:

```text
TUN interface: tun0
TUN address:   172.19.0.1/30
DNS:           1.1.1.1 and 8.8.8.8
DNS strategy:  ipv4_only
TUN:
  auto_route=true
  auto_redirect=true
  strict_route=true
Routing:
  auto_detect_interface=true
Final outbound: proxy-out
```

The tested VLESS transport was:

```text
VLESS
WebSocket
TLS
ALPN: http/1.1
uTLS fingerprint: ios
```

The exact proxy endpoint and UUID must never be committed to this documentation.

## 61.13 Current Routing Model

The intended traffic path is:

```text
LAN client
   |
   v
OpenWrt bridge / fw4
   |
   v
sing-box TUN + policy routing
   |
   v
VLESS outbound
   |
   v
Internet
```

Direct exceptions include the DNS servers used to resolve the proxy endpoint:

```text
1.1.1.1/32 -> direct
8.8.8.8/32 -> direct
```

`auto_detect_interface=true` is required to prevent sing-box's own connection to the proxy server from being recursively redirected into its TUN.

Private/router-management traffic must remain direct according to the final routing policy.

## 61.14 Proven Real-Device Test

On the Mercury KT-708, the following has been proven:

```text
[x] /dev/net/tun exists
[x] TUN interface creation
[x] sing-box configuration validation
[x] auto_route policy-routing state
[x] auto_redirect nftables integration
[x] normal WAN connectivity
[x] normal DNS connectivity
```

The following has also been observed during a successful manual VLESS/TUN test on the working environment:

```text
LAN traffic entered the sing-box TUN.
DNS packets were handled through the configured path.
VLESS outbound connections were created.
Internet connectivity through the proxy path was confirmed.
```

The final package-level end-to-end test still needs to verify the same behavior after installing the Cowboy Bebop packages and rebooting the router.

## 61.15 LuCI Package

Current package:

```text
luci-app-cowboy-bebop
```

Current package release in the repository state being documented:

```text
PKG_RELEASE:=7
```

LuCI view:

```text
htdocs/luci-static/resources/view/cowboy-bebop/overview.js
```

RPC backend:

```text
/usr/libexec/rpcd/luci.cowboy_bebop
```

The RPC backend talks to:

```text
/usr/bin/cowboy-bebop-manager
/etc/init.d/cowboy-bebop
/etc/cowboy-bebop/config.json
/usr/lib/cowboy-bebop/
```

The LuCI page is exposed at:

```text
/admin/services/cowboy-bebop
```

The UI is intentionally minimal: proxy URL input, apply/save, ON/OFF state, and service status are the primary controls. The core manager remains independent of the UI.

## 61.16 OpenWrt ImageBuilder Integration

The ImageBuilder first-boot script is now named:

```text
openwrt/imagebuilder/files/etc/uci-defaults/99-cowboy-bebop
```

The old project-specific `99-singbox-manager` script is removed from the current naming scheme.

The ImageBuilder package list uses:

```text
cowboy-bebop-manager
luci-app-cowboy-bebop
```

## 61.17 Package CI

The package CI targets OpenWrt `25.12.5` and builds at least:

```text
x86_64
ipq40xx/generic (KT-708)
```

x86 SDK:

```text
openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst
```

KT-708 SDK:

```text
openwrt-sdk-25.12.5-ipq40xx-generic_gcc-14.3.0_musl_eabi.Linux-x86_64.tar.zst
```

The CI builds packages rather than complete firmware images. This keeps package development fast and allows the same artifacts to be installed on an existing OpenWrt target.

## 61.18 Package Installation / Clean Upgrade Notes

For a clean test installation, stop the service before removing packages:

```sh
/etc/init.d/cowboy-bebop stop 2>/dev/null || true
```

Do not remove the `sing-box` executable when cleaning Cowboy Bebop. It is an external runtime dependency.

When migrating from an old development build, old project-owned paths can be removed after the service is stopped:

```text
/etc/singbox
/usr/lib/singbox-manager
/usr/bin/singbox-manager
/etc/init.d/singbox
/etc/config/singbox
```

Only remove these when they belong to the old Cowboy Bebop predecessor and are not the actual feed-provided `sing-box` package's own files. On a production router, verify package ownership before deleting any file named `sing-box` or any feed-owned service/config.

## 61.19 Security Requirements

Never commit:

```text
VMess UUIDs
VLESS UUIDs
private keys
Reality private keys
subscription URLs
Tailscale auth keys
access tokens
real proxy credentials
```

Use placeholders in documentation:

```text
<UUID>
<PROXY_SERVER>
<PROXY_PORT>
<SNI>
<PUBLIC_KEY>
<SHORT_ID>
```

All URL-derived data is untrusted input. Parsers must never execute URL content as shell commands.

JSON must be generated structurally with `jq` or another safe JSON mechanism, not by unsafe shell concatenation.

## 61.20 Current Remaining Work

The remaining work is implementation validation, not redesign:

```text
[ ] finish/verify physical source-tree rename after the Codespace git mv
[ ] remove stale old-name references from tests/docs/workflows
[ ] run grep for old project-owned names
[ ] run package CI and confirm x86_64 + KT-708 builds
[ ] install latest packages on KT-708
[ ] verify service enable/start/restart/stop
[ ] reboot and verify automatic startup
[ ] verify Save & Apply from LuCI
[ ] verify ON/OFF from LuCI
[ ] verify rollback after a deliberately bad configuration
[ ] verify LAN-wide proxying after package installation
[ ] finalize IPv6 policy behavior
```

## 61.21 Definition of Current Success

The project is considered functionally complete for the MVP when a fresh supported OpenWrt router can perform:

```text
Install packages
      |
      v
Open LuCI -> Services -> Cowboy Bebop
      |
      v
Paste VMess/VLESS URL
      |
      v
Automatic detection + parsing
      |
      v
Generate config
      |
      v
Validate with sing-box check
      |
      v
Apply + restart
      |
      v
Health verification
      |
      v
LAN traffic -> TUN -> proxy
```

No SSH should be required for normal operation.

------------------------------------------------------------------------

# 65. Product Identity and Branding

Goal: anyone who runs an image built from this project can tell, from the
first SSH login and the first LuCI page, that it is our product. The
visual and verbal theme is a retro space-western / jazz-lounge mood.

This section is cosmetic. It never changes how the manager works.

## 65.1 Rules

-   **Branding is a separate layer.** It lives in its own package
    (`cowboy-bebop-branding`) and, for the image, in the Image Builder
    `files/` overlay. `cowboy-bebop-manager` and `luci-app-cowboy-bebop`
    must keep working on a stock OpenWrt without it.
-   **Machine-readable output is never branded.** JSON output, log lines,
    exit codes, UCI values and anything the tests parse stay plain.
    Branded text appears only in human-facing headers, footers, banners
    and empty states.
-   **Interactive terminals only.** Anything printed at login or by a
    shell profile script must print only when stdout and stdin are a TTY.
    Otherwise `scp`, `rsync` and `ssh host command` break. The CLI honors
    `NO_COLOR` and `COWBOY_BEBOP_NO_BRAND=1`, and offers `--plain`.
-   **Errors stay plain.** Error and recovery messages must be clear and
    actionable. Flavor text never replaces the actual reason.
-   **Do not break OpenWrt compatibility.** Keep `DISTRIB_ID`,
    `DISTRIB_TARGET`, `DISTRIB_ARCH`, `VERSION_ID` and the package
    architecture unchanged so sysupgrade, package feeds and tooling still
    work. Change only descriptive fields.
-   **Be honest about the base.** The product says it is based on
    OpenWrt. It does not call itself OpenWrt and does not use the OpenWrt
    logo as its own.
-   **Idempotent and non-destructive.** First-boot branding scripts must
    not overwrite anything the user changed (for example a custom
    hostname) and must be safe to run twice.
-   **Do not rebrand `sing-box`.** It is the real external engine and
    keeps its own name and notices.

## 65.2 Touchpoints

Chosen for impact versus cost and risk:

| Where | What | Notes |
|---|---|---|
| SSH login banner (`/etc/banner`) | Original ASCII art, product name, "based on OpenWrt <version>", one hint line | Write final text (no `%D`/`%V` tokens); an overlay file is not processed at build time. Generate at first boot from `/etc/openwrt_release` if the version must appear. |
| Login status line (`/etc/profile.d/cowboy-bebop.sh`) | One line: proxy ON/OFF, TUN state, sing-box version | Interactive TTY only. Must be fast (no network, short timeout, no heavy `jq`). |
| Shell prompt | Brand color and short prompt | Optional. Respect `NO_COLOR`. |
| `/etc/os-release` | `NAME`, `PRETTY_NAME`, `HOME_URL`, `BUG_REPORT_URL` | Keep `ID` and `VERSION_ID` as they are. |
| `/etc/openwrt_release` | `DISTRIB_DESCRIPTION` only | LuCI shows this as the firmware version. |
| Default hostname | `<brand>-router` or similar | Only if the hostname is still the stock default. |
| CLI headers | `cowboy-bebop-manager status` and `version` print a short branded header | `--plain` and non-TTY output stay unbranded. |
| LuCI app page | Header motif, brand name, themed subtitles, footer | Keep status labels literal (see 65.4). |
| LuCI theme (`luci-theme-cowboy-bebop`) | Colors, logo, favicon, login page | Phase 2. A fork of the bootstrap theme must track upstream changes. Start with a small CSS/logo overlay. |
| Image file names | `cowboy-bebop-<version>-<target>-<profile>-sysupgrade.<ext>` | Image Builder supports an extra image name suffix; verify on the pinned release. |
| Package metadata | `TITLE`, `URL`, `PKG_MAINTAINER`, feed/repository name | Cheap and visible in `apk info`. |
| Docs and releases | README header, release notes, install guide | Same name, palette and disclaimer. |

Rejected on purpose:

-   Boot splash: routers have no display, and kernel boot output is not
    worth patching.
-   Changing `DISTRIB_ID` or architecture strings: breaks tooling.
-   Easter eggs that print on every command: slow and annoying.
-   Replacing `sing-box` names in logs or paths.

## 65.3 Visual and verbal theme

Palette (starting point, tune later): warm amber/orange, deep teal or
navy, cream, near-black. Typography: a retro, slightly condensed
display face for titles and a plain monospace/system face for data.

Original ASCII art only. A sample banner (placeholder name, drawn for
this project, not taken from anywhere):

``` text
        .        *        .       +        .
   *        .         __|__        .   *
        .       ___ __/ o \__ ___        .
   +        ___/___|_______|___\___   .
      .    <_______[=======]_______>      *
   .          *   '---------'    .      +

   <BRAND>  -  based on OpenWrt <version>
   Session ready. Try: cowboy-bebop-manager status
```

Copy style: short, calm, a little dry, never cute where it hides
information.

## 65.4 UI wording

The label is literal. The subtitle may carry the mood.

| State | Label (always shown) | Optional subtitle |
|---|---|---|
| Proxy on and healthy | Tunnel up | Smooth sailing. |
| Proxy off | Tunnel down | Router is on direct routes. |
| Applying | Checking configuration | Running validation. |
| Waiting for confirmation | Confirm within N s | Auto-revert if no answer. |
| Rolled back | Reverted to last good config | Nothing was lost. |
| Recovery | Safe mode | Direct routing restored. |

Subtitles must be original wording and optional. Do not use catchphrases
or quotes from the series.

## 65.5 Legal and licensing

Not legal advice. Check these before any public or commercial release.

-   **"Cowboy Bebop" is a third-party property.** It is the name of an
    anime series owned by its rights holders. It is not our trademark.
    Using the name, logo, key art, character names or likenesses, ship
    names, music, lyrics or samples, screenshots, or catchphrases in a
    distributed (especially commercial) product can infringe. We take
    only the mood: palette, typography, original art and original copy.
-   **Choose the real product name before the first public release.**
    The current package names (`cowboy-bebop-manager`,
    `luci-app-cowboy-bebop`) and runtime paths (`/etc/cowboy-bebop/`,
    `/etc/config/cowboy-bebop`, `/usr/lib/cowboy-bebop/`) embed the
    series name. Renaming later is a breaking change for users. If a
    different commercial name is likely, rename first, keep the series
    only as an internal codename, and do a trademark search in the target
    markets.
-   **If any reference stays,** add a clear "unofficial, not affiliated"
    notice in the README and the image.
-   **OpenWrt:** state that the image is based on OpenWrt, keep upstream
    copyright notices, and follow the OpenWrt trademark guidance
    (do not present the image as an official OpenWrt build).
-   **GPL:** images contain GPL software (kernel, BusyBox and others).
    Ship license texts and provide the corresponding source or a written
    offer, together with the exact build scripts and the Image Builder
    configuration.
-   **sing-box:** keep its license and notices. Check its license for
    conditions on using its name, and do not rebrand it.
-   **Our own packages:** MIT (see `PKG_LICENSE`). Third-party notices go
    in `docs/licenses.md`.

## 65.6 Implementation plan

1.  Phase A (cheap, no risk): banner, login status line, `os-release`
    and `DISTRIB_DESCRIPTION`, default hostname, CLI header with
    `--plain`, package metadata, image naming.
2.  Phase B: branded header and footer in the LuCI app page.
3.  Phase C: LuCI theme package (CSS, logo, favicon, login page).
4.  Phase D: licenses document, disclaimer, and the final-name decision
    from 65.5.

Files for Phase A:

``` text
openwrt/cowboy-bebop-branding/
  Makefile
  files/etc/banner
  files/etc/profile.d/cowboy-bebop.sh
  files/etc/uci-defaults/90-cowboy-bebop-branding
```

## 65.7 Tests and definition of done

``` text
ssh root@host true             prints nothing extra
scp / rsync to the router      work normally
non-TTY: no banner or status line is printed
NO_COLOR=1 and --plain         remove all color and branded text
status --json                  unchanged and valid JSON
login status line              appears in under 100 ms and needs no network
hostname set by the user       is not overwritten
branding script run twice      produces the same result
sysupgrade and apk update      still work (DISTRIB_* untouched)
branding package removed       manager and LuCI app still work
no logo, art, quote or music from the series appears anywhere
```

-   [ ] Banner and login status line in place and TTY-only
-   [ ] `os-release` and `DISTRIB_DESCRIPTION` updated, IDs untouched
-   [ ] CLI and LuCI branding does not change machine-readable output
-   [ ] Branding is a separate package that can be removed
-   [ ] Final product name decided and trademark-checked before release
-   [ ] Disclaimer, license texts and GPL source offer published

------------------------------------------------------------------------

# 66. Repository Changes — 2026-11-12

This section records changes made after section 61. Where it conflicts with an
earlier section, this section is authoritative.

## 66.1 Packages

The repository builds exactly three packages:

``` text
cowboy-bebop-manager    PKG_RELEASE 23
luci-app-cowboy-bebop   PKG_RELEASE 10
cowboy-bebop-branding   PKG_RELEASE 5
```

`luci-theme-cowboy-bebop` (the private LuCI theme) and its workflow were
removed. The LuCI app now carries its own minimal styling and works with any
stock theme. The LuCI app postinst and the branding package reset
`luci.main.mediaurlbase` to bootstrap if it still points at the removed theme.

Release numbers continue upward from the repository state (not the values in
61.4/61.15) so `apk` upgrades on installed routers keep working.

## 66.2 Manager package layout

The manager package now matches 61.3/61.4 exactly: sources live in
`files/usr/lib/cowboy-bebop/`, the init script is
`files/etc/init.d/cowboy-bebop`, only the `1.13.21.json` template ships, and
every packaged file is byte-identical to `core/` (enforced by
`tests/service/test_package_layout.sh`). The Makefile previously used
`endefine`, which GNU make rejects; it now uses `endef`.

## 66.3 Xray certificate options (pcs / vcn)

Share links may carry `pcs` (SHA-256 of the whole leaf certificate) and `vcn`
(name to verify the certificate against instead of the SNI). sing-box 1.13 can
only pin the public key (`certificate_public_key_sha256`) and cannot verify a
name other than `server_name`.

- The parsers normalize them into `tls.pinned_cert_sha256` and
  `tls.verify_names` (plain TLS only).
- On apply the manager fetches the leaf certificate with `openssl s_client`,
  checks it against the pin and, on a match, enforces the public-key pin.
- A mismatching certificate is always rejected.
- If the pin cannot be checked (no `openssl`, endpoint unreachable), or only a
  differing `vcn` is present, `insecure` is set only when
  `allow_insecure=1`; otherwise the apply fails.
- The generator never emits a configuration that silently drops a requested
  pin or name.

`openssl-util` is optional and not a package dependency (61.4 is unchanged); it
is included in the Image Builder package list.

Also: `headerType=http` on TCP is rejected as an unsupported transport, and the
`allow_insecure` policy is now enforced by the VLESS parser.

## 66.4 VMess Base64 padding

Links with a single `=` padding character were rejected as invalid Base64. Fixed
and covered by tests.

## 66.5 Reseller identity

Reseller firmware may inject a name and phone number into the board model
(`/tmp/sysinfo/model`, `/etc/board.json`) and ship a rebranded LuCI theme. The
branding package adds `/etc/init.d/cowboy-bebop-identity` (runs at every boot,
`/tmp/sysinfo` is rebuilt each boot) which:

- strips reseller text and phone numbers from the displayed model
  (`board_name` and `model.id` are never changed; a copy of the original
  `board.json` is kept as `board.json.vendor`),
- removes reseller text from the system description/notes,
- switches LuCI to a stock theme when the active theme's files contain
  reseller branding.

A logo that exists only as a raster image cannot be detected; switch the theme
manually in that case.

## 66.6 Tests

CI now runs every test under both `dash` and `busybox sh`, a `shellcheck`
error-level pass, and `sing-box check` (pinned 1.13.21) against generated
configurations for every supported profile shape. Test data uses placeholders
only; real share links are never committed (60.22).

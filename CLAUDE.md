# Project: luci-app-podkop-tgbot

## What this is

An OpenWrt/FriendlyWrt package that runs a lightweight Telegram bot as a system service. The bot accepts IP addresses and domain names via Telegram messages and appends them to podkop custom routing list files, then restarts podkop. The package also provides a LuCI web UI configuration page under Services.

## Repository layout

```
/
├── Makefile                          OpenWrt build system package definition
├── install.sh                        Direct install script (run on the router itself)
├── CLAUDE.md
├── README.md
└── src/                           Source scripts and configs; install 1:1 to router filesystem
    ├── tgbot.sh                   -> /usr/bin/tgbot.sh
    ├── tgbot.init                 -> /etc/init.d/tgbot
    ├── tgbot.config               -> /etc/config/tgbot  (default, not overwritten on upgrade)
    └── luci/
        ├── controller/tgbot.lua   -> /usr/lib/lua/luci/controller/tgbot.lua
        └── model/cbi/tgbot.lua    -> /usr/lib/lua/luci/model/cbi/tgbot.lua
```

## Runtime files (on the router)

| Path | Purpose |
|------|---------|
| `/etc/config/tgbot` | UCI config: token, allowed_chats list, file paths |
| `/usr/bin/tgbot.sh` | Long-polling daemon; reads UCI config on every start |
| `/etc/init.d/tgbot` | procd init script; START=99, respawn enabled |
| `/tmp/tgbot.offset` | Last processed Telegram update_id+1; deleted on reboot (intentional) |
| `/var/run/tgbot.pid` | PID file written by the daemon |

## UCI config structure

```
config tgbot 'main'
    option token         'BOT_TOKEN'
    option domains_file  '/etc/podkop/custom_domains.txt'
    option ips_file      '/etc/podkop/custom_ips.txt'
    list   allowed_chats '123456789'
    list   allowed_chats '987654321'
```

`allowed_chats` is a multi-value UCI list. The daemon reads it via `config_list_foreach`. The LuCI CBI model uses `DynamicList` which maps directly to UCI list entries.

## How the daemon works

- Uses Telegram Bot API long polling (`getUpdates?timeout=30`)
- JSON parsing done with `jsonfilter` (part of `libubox`, always present on OpenWrt)
- HTTP done with `curl` (required dependency)
- On `/start` command: replies with the sender's `chat.id`
- On any other text: parses line by line, validates each line as IPv4/CIDR or domain, appends new entries to the respective file, then calls `/etc/init.d/podkop restart`
- Unauthorized senders get a rejection message that includes their chat ID (so they can ask to be added)
- Duplicate entries are skipped (`grep -qxF`)

## Validation rules

- **IPv4 / CIDR**: strict octet ranges 0–255, optional `/0`–`/32` suffix
- **Domain**: standard labels + TLD, optional `*.` wildcard prefix; case-insensitive

## LuCI integration

- Controller: `luci.controller.tgbot` — registers page at `admin → Services → Podkop TG Bot`; also exposes `action` endpoint for Start/Stop/Restart
- CBI model: `cbi/tgbot` — shows running status (green/red), control buttons via GET links, and four config fields
- After saving config LuCI writes UCI; procd detects `/etc/config/tgbot` change via `service_triggers` and reloads the service automatically
- LuCI index cache must be cleared after install: `rm -f /tmp/luci-indexcache` (done by `install.sh` and `postinst`)

## Development workflow

1. Edit files under `src/`
2. Copy changed files to router with `scp` and reload:
   ```sh
   scp src/tgbot.sh root@router:/usr/bin/tgbot.sh
   /etc/init.d/tgbot restart
   ```
3. For LuCI changes also run `rm -f /tmp/luci-indexcache` and hard-refresh the browser
4. Logs: `logread -f -e tgbot`

## Building an .ipk

Requires a configured OpenWrt build environment:
```sh
cp -r . $OPENWRT_DIR/package/luci-app-podkop-tgbot
cd $OPENWRT_DIR
make package/luci-app-podkop-tgbot/compile V=s
# .ipk lands in bin/packages/.../
```

## Key constraints

- No Python, no Lua sockets, no extra opkg packages required — only `curl` (common) and `jsonfilter` (built-in)
- The offset file lives in `/tmp` so it is wiped on reboot; this is intentional — on next start the bot processes only new messages (offset=0 would replay all history)
- `procd_set_param respawn 3600 5 0` means: respawn window 3600s, min 5s between restarts, 0 failures before permanent stop (respawn forever)
- The service does NOT start if `token` is empty; this is enforced in `start_service()` before opening the procd instance

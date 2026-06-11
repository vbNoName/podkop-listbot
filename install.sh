#!/bin/sh
# Install luci-app-podkop-tgbot from GitHub
#
# Run on the router:
#   wget -O - https://raw.githubusercontent.com/vbNoName/podkop-listbot/main/install.sh | sh

set -e

REPO_RAW="https://raw.githubusercontent.com/vbNoName/podkop-listbot/main"
SRC="${REPO_RAW}/src"

log()  { echo "[tgbot] $*"; }
fail() { echo "[tgbot] ERROR: $*" >&2; exit 1; }

dl() {
    local url="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    wget -qO "$dst" "$url" || fail "Failed to download: $url"
}

log "Checking dependencies..."
if ! opkg list-installed 2>/dev/null | grep -q "^curl "; then
    log "Installing curl..."
    opkg update >/dev/null 2>&1
    opkg install curl >/dev/null 2>&1
fi

log "Downloading files..."
dl "${SRC}/tgbot.sh"                  /usr/bin/tgbot.sh
dl "${SRC}/tgbot.init"                /etc/init.d/tgbot
dl "${SRC}/luci/controller/tgbot.lua" /usr/lib/lua/luci/controller/tgbot.lua
dl "${SRC}/luci/model/cbi/tgbot.lua"  /usr/lib/lua/luci/model/cbi/tgbot.lua

chmod 755 /usr/bin/tgbot.sh /etc/init.d/tgbot

if [ ! -f /etc/config/tgbot ]; then
    dl "${SRC}/tgbot.config" /etc/config/tgbot
    chmod 600 /etc/config/tgbot
    log "Created /etc/config/tgbot"
else
    log "Kept existing /etc/config/tgbot (config preserved)"
fi

/etc/init.d/tgbot enable
rm -f /tmp/luci-indexcache

log "Done! Open LuCI -> Services -> Podkop TG Bot to configure."

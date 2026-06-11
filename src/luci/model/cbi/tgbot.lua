local sys  = require("luci.sys")
local disp = require("luci.dispatcher")

local running = sys.call("pgrep -f /usr/bin/tgbot.sh >/dev/null 2>&1") == 0
local status  = running and "<b style='color:green'>Running</b>" or "<b style='color:red'>Stopped</b>"
local base    = disp.build_url("admin", "services", "tgbot", "action")

local ctrl = string.format(
    "%s &nbsp; "..
    "<a class='btn cbi-button cbi-button-apply'  href='%s?action=start'>Start</a> "..
    "<a class='btn cbi-button cbi-button-reset'  href='%s?action=stop'>Stop</a> "..
    "<a class='btn cbi-button cbi-button-reload' href='%s?action=restart'>Restart</a>",
    status, base, base, base
)

m = Map("tgbot",
    translate("Podkop Telegram Bot"),
    ctrl
)

s = m:section(TypedSection, "tgbot", translate("Settings"))
s.anonymous = true
s.addremove  = false

-- Bot token
o = s:option(Value, "token", translate("Bot Token"))
o.password   = true
o.placeholder = "123456789:AABBccDDeeFFggHHiiJJ"
o.rmempty    = false

-- Allowed chat IDs
o = s:option(DynamicList, "allowed_chats",
    translate("Allowed Chat IDs"),
    translate("Telegram user/group IDs that are allowed to send domains and IPs. Send /start to the bot to get your ID."))
o.datatype   = "integer"
o.placeholder = "123456789"

-- Domains file path
o = s:option(Value, "domains_file",
    translate("Domains File"),
    translate("Path to the file where received domain names are stored"))
o.default    = "/etc/podkop/custom_domains.txt"
o.rmempty    = false

-- IPs file path
o = s:option(Value, "ips_file",
    translate("IP Addresses File"),
    translate("Path to the file where received IP addresses (and CIDRs) are stored"))
o.default    = "/etc/podkop/custom_ips.txt"
o.rmempty    = false

return m

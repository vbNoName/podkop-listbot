module("luci.controller.tgbot", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/tgbot") then
        return
    end

    entry(
        {"admin", "services", "tgbot"},
        cbi("tgbot"),
        _("Podkop TG Bot"),
        60
    ).dependent = true

    entry({"admin", "services", "tgbot", "action"}, call("action_service")).leaf = true
end

function action_service()
    local action = luci.http.formvalue("action")
    if action == "start" then
        luci.sys.call("/etc/init.d/tgbot start")
    elseif action == "stop" then
        luci.sys.call("/etc/init.d/tgbot stop")
    elseif action == "restart" then
        luci.sys.call("/etc/init.d/tgbot restart")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin", "services", "tgbot"))
end

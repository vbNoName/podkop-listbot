include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-podkop-tgbot
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Custom
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-podkop-tgbot
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI — Podkop Telegram Bot
  DEPENDS:=+luci-base +curl
  PKGARCH:=all
endef

define Package/luci-app-podkop-tgbot/description
  Telegram bot that accepts IP addresses and domain names via chat
  and appends them to podkop custom routing lists, then restarts podkop.
  Includes a LuCI configuration page under Services.
endef

define Build/Compile
endef

define Package/luci-app-podkop-tgbot/conffiles
/etc/config/tgbot
endef

define Package/luci-app-podkop-tgbot/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./src/tgbot.sh $(1)/usr/bin/tgbot.sh

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./src/tgbot.init $(1)/etc/init.d/tgbot

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./src/tgbot.config $(1)/etc/config/tgbot

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./src/luci/controller/tgbot.lua \
		$(1)/usr/lib/lua/luci/controller/tgbot.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./src/luci/model/cbi/tgbot.lua \
		$(1)/usr/lib/lua/luci/model/cbi/tgbot.lua
endef

define Package/luci-app-podkop-tgbot/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/tgbot enable
rm -f /tmp/luci-indexcache
exit 0
endef

define Package/luci-app-podkop-tgbot/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/tgbot stop 2>/dev/null
/etc/init.d/tgbot disable 2>/dev/null
exit 0
endef

$(eval $(call BuildPackage,luci-app-podkop-tgbot))

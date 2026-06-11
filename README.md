# Podkop Listbot

Telegram-бот для управления пользовательскими списками [podkop](https://github.com/itdoginfo/podkop) на роутерах с OpenWrt и FriendlyWrt.

Пишешь боту домены или IP-адреса — он добавляет их в файлы podkop и перезапускает сервис. Настраивается через веб-интерфейс LuCI.

> **Компилировать ничего не нужно.** Все файлы — shell-скрипты и Lua — работают на роутере напрямую.

---

## Содержание

1. [Требования](#требования)
2. [Шаг 1 — Создать Telegram-бота](#шаг-1--создать-telegram-бота)
3. [Шаг 2 — Установка на роутер](#шаг-2--установка-на-роутер)
4. [Шаг 3 — Настройка в LuCI](#шаг-3--настройка-в-luci)
5. [Шаг 4 — Узнать свой Telegram ID и добавить в разрешённые](#шаг-4--узнать-свой-telegram-id-и-добавить-в-разрешённые)
6. [Использование бота](#использование-бота)
7. [Логи и диагностика](#логи-и-диагностика)
8. [Ручное управление через SSH](#ручное-управление-через-ssh)

---

## Требования

- OpenWrt 21.02+ или FriendlyWrt (NanoPi R2S/R4S/R5S и др.)
- Установленный и настроенный [podkop](https://github.com/itdoginfo/podkop)
- Доступ в интернет с роутера (для обращения к Telegram API и скачивания файлов)

---

## Шаг 1 — Создать Telegram-бота

1. Откройте Telegram и найдите [@BotFather](https://t.me/BotFather)
2. Отправьте команду `/newbot`
3. BotFather спросит **имя бота** (то, что видят пользователи, например `My Router Bot`) — введите любое
4. Затем спросит **username бота** — должен заканчиваться на `bot`, например `myrouter_podkop_bot`
5. BotFather ответит сообщением вида:
   ```
   Done! Use this token to access the HTTP API:
   7123456789:AABBccDDeeFFggHHiiJJkkLLmmNNooP
   ```
6. **Скопируйте токен** — он понадобится при настройке

> Токен — секретный. Кто его знает, тот управляет ботом. Не публикуйте его.

---

## Шаг 2 — Установка на роутер

### Одна команда через терминал

Подключитесь к роутеру по SSH и выполните:

```sh
wget -O - https://raw.githubusercontent.com/vbNoName/podkop-listbot/main/install.sh | sh
```

Скрипт сам:
- установит `curl` если его нет (`opkg install curl`)
- скачает все файлы с GitHub
- пропишет автозапуск
- очистит LuCI-кэш

### Установка прямо из веб-интерфейса LuCI

Если у вас установлен пакет `luci-app-ttyd` (веб-терминал), можно сделать всё не выходя из браузера:

1. Откройте LuCI → **Services → Terminal** (или **ttyd**)
2. Вставьте команду выше и нажмите Enter

Если `luci-app-ttyd` нет, установите его:

```sh
opkg update && opkg install luci-app-ttyd
```

После этого в LuCI появится пункт **Services → Terminal**.

### Если wget не может подключиться по HTTPS

На некоторых сборках OpenWrt нет CA-сертификатов. Попробуйте:

```sh
opkg update && opkg install ca-bundle
```

Или как крайний вариант (небезопасно, только для изолированной сети):

```sh
wget --no-check-certificate -O - https://raw.githubusercontent.com/vbNoName/podkop-listbot/main/install.sh | sh
```

---

## Шаг 3 — Настройка в LuCI

1. Откройте веб-интерфейс роутера (обычно `http://192.168.1.1`)
2. Перейдите **Services → Podkop TG Bot**
3. Заполните поля:

| Поле | Что вводить |
|------|------------|
| **Bot Token** | Токен от BotFather (шаг 1) |
| **Allowed Chat IDs** | Telegram ID пользователей, которым разрешено управлять ботом (как добавить — см. шаг 4) |
| **Domains File** | Путь к файлу доменов podkop. По умолчанию `/etc/podkop/custom_domains.txt` |
| **IP Addresses File** | Путь к файлу IP-адресов podkop. По умолчанию `/etc/podkop/custom_ips.txt` |

4. Нажмите **Save & Apply**
5. Нажмите кнопку **Start** на этой же странице

Если сервис запустился — статус сверху сменится на **Running** (зелёный).

> Файлы доменов и IP создаются автоматически при первом добавлении записи. Директория тоже.

---

## Шаг 4 — Узнать свой Telegram ID и добавить в разрешённые

Пока список `Allowed Chat IDs` пуст, бот будет **отклонять** все сообщения и отвечать:
```
Access denied. Your Telegram ID: 123456789
```

Воспользуйтесь этим, чтобы узнать свой ID:

1. Найдите своего бота в Telegram по username и отправьте ему `/start`
2. Бот ответит сообщением с вашим ID, например:
   ```
   Your Telegram ID: 123456789
   ```
3. Вернитесь в LuCI → **Services → Podkop TG Bot**
4. В поле **Allowed Chat IDs** нажмите **+** и введите свой ID
5. Нажмите **Save & Apply** — изменения применятся без перезапуска бота

Можно добавить несколько ID (членов семьи, коллег и т.д.).

---

## Использование бота

### Команды

| Сообщение | Ответ бота |
|-----------|-----------|
| `/start` | Ваш Telegram ID + краткая инструкция |
| Любая другая `/команда` | "Unknown command" |

### Добавление доменов и IP

Отправьте боту текстовое сообщение, где каждый домен или IP-адрес на **отдельной строке**:

```
example.com
sub.example.com
*.blocked-site.org
1.2.3.4
10.0.0.0/8
```

Бот ответит итогом:
```
Done:
+ Domains: 3
+ IPs: 2
```

После этого podkop автоматически перезапустится.

### Поддерживаемые форматы

**Домены:**
- `example.com`
- `sub.domain.example.com`
- `*.example.com` (wildcard)

**IP-адреса:**
- `1.2.3.4` (одиночный IPv4)
- `192.168.0.0/24` (CIDR-подсеть, маска /0 до /32)

**Что не поддерживается:**
- IPv6
- URL вида `https://example.com` — нужно вводить только домен без схемы
- Несколько записей в одной строке

### Защита от дублирования

Если домен или IP уже есть в файле, повторно он не добавится.

---

## Логи и диагностика

### Просмотр логов в реальном времени

```sh
logread -f -e tgbot
```

Пример нормального вывода:
```
tgbot: Started. pid=1234  domains=/etc/podkop/custom_domains.txt  ips=/etc/podkop/custom_ips.txt
tgbot: Processed: domains+2 ips+1 skip=0
tgbot: Restarting podkop
```

### Частые проблемы

**Статус Stopped после нажатия Start**

```sh
logread | grep tgbot
```
Скорее всего, поле Token пусто или токен введён неверно.

**Бот не отвечает на сообщения**

1. Убедитесь, что сервис Running
2. Проверьте доступ к Telegram API с роутера:
   ```sh
   curl -s https://api.telegram.org
   ```
3. Если Telegram заблокирован — боту нужен прямой доступ, он работает с роутера

**Страница в LuCI не появилась после установки**

```sh
rm -f /tmp/luci-indexcache
```
Затем Ctrl+Shift+R в браузере.

**После сохранения настроек бот не перезапустился**

```sh
/etc/init.d/tgbot restart
```

---

## Ручное управление через SSH

```sh
/etc/init.d/tgbot start    # запустить
/etc/init.d/tgbot stop     # остановить
/etc/init.d/tgbot restart  # перезапустить
/etc/init.d/tgbot enable   # включить автозапуск при загрузке
/etc/init.d/tgbot disable  # отключить автозапуск
```

### Прямое редактирование конфига

```sh
vi /etc/config/tgbot
```

```
config tgbot 'main'
	option token         '7123456789:AABBccDDeeFFggHHiiJJ'
	option domains_file  '/etc/podkop/custom_domains.txt'
	option ips_file      '/etc/podkop/custom_ips.txt'
	list   allowed_chats '123456789'
	list   allowed_chats '987654321'
```

После редактирования вручную:
```sh
/etc/init.d/tgbot restart
```

### Посмотреть текущее содержимое файлов

```sh
cat /etc/podkop/custom_domains.txt
cat /etc/podkop/custom_ips.txt
```

---

## Лицензия

MIT

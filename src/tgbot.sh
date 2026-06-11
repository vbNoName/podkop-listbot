#!/bin/sh
# Telegram bot for managing podkop custom domain/IP lists
# Requires: curl, jsonfilter (standard on OpenWrt)

. /lib/functions.sh

OFFSET_FILE="/tmp/tgbot.offset"
PID_FILE="/var/run/tgbot.pid"
LOG_TAG="tgbot"

log() { logger -t "$LOG_TAG" "$*"; }
die() { log "FATAL: $*"; exit 1; }

ALLOWED_CHATS=""
add_allowed_chat() { ALLOWED_CHATS="$ALLOWED_CHATS $1"; }

load_config() {
    config_load tgbot
    config_get BOT_TOKEN    main token        ""
    config_get DOMAINS_FILE main domains_file "/etc/podkop/custom_domains.txt"
    config_get IPS_FILE     main ips_file     "/etc/podkop/custom_ips.txt"
    ALLOWED_CHATS=""
    config_list_foreach main allowed_chats add_allowed_chat
}

is_allowed() {
    local chat_id="$1" id
    for id in $ALLOWED_CHATS; do
        [ "$id" = "$chat_id" ] && return 0
    done
    return 1
}

send_message() {
    local chat_id="$1" text="$2" tmp
    tmp=$(mktemp /tmp/tgbot_send.XXXXXX)
    printf '%s' "$text" > "$tmp"
    curl -s --max-time 10 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -F "chat_id=${chat_id}" \
        -F "text=<${tmp}" \
        -o /dev/null 2>/dev/null
    rm -f "$tmp"
}

is_valid_ipv4() {
    echo "$1" | grep -qE \
        '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'
}

is_valid_domain() {
    echo "$1" | grep -qiE \
        '^(\*\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$'
}

process_entries() {
    local chat_id="$1" text_file="$2" mode="${3:-add}"
    local domains_done=0 ips_done=0 skipped=0 line file tmp

    mkdir -p "$(dirname "$DOMAINS_FILE")" "$(dirname "$IPS_FILE")" 2>/dev/null
    [ "$mode" = "add" ] && touch "$DOMAINS_FILE" "$IPS_FILE"

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue

        if is_valid_ipv4 "$line"; then
            file="$IPS_FILE"
        elif is_valid_domain "$line"; then
            file="$DOMAINS_FILE"
        else
            skipped=$((skipped + 1))
            continue
        fi

        case "$mode" in
            add)
                if ! grep -qxF "$line" "$file" 2>/dev/null; then
                    printf '%s\n' "$line" >> "$file"
                    [ "$file" = "$IPS_FILE" ] \
                        && ips_done=$((ips_done + 1)) \
                        || domains_done=$((domains_done + 1))
                fi
                ;;
            delete)
                if grep -qxF "$line" "$file" 2>/dev/null; then
                    tmp=$(mktemp /tmp/tgbot_tmp.XXXXXX)
                    grep -vxF "$line" "$file" > "$tmp" && mv "$tmp" "$file" || rm -f "$tmp"
                    [ "$file" = "$IPS_FILE" ] \
                        && ips_done=$((ips_done + 1)) \
                        || domains_done=$((domains_done + 1))
                else
                    skipped=$((skipped + 1))
                fi
                ;;
            comment)
                if grep -qxF "$line" "$file" 2>/dev/null; then
                    tmp=$(mktemp /tmp/tgbot_tmp.XXXXXX)
                    awk -v pat="$line" '$0 == pat { print "// " $0; next } 1' "$file" > "$tmp" \
                        && mv "$tmp" "$file" || rm -f "$tmp"
                    [ "$file" = "$IPS_FILE" ] \
                        && ips_done=$((ips_done + 1)) \
                        || domains_done=$((domains_done + 1))
                else
                    skipped=$((skipped + 1))
                fi
                ;;
        esac
    done < "$text_file"

    local action_label
    case "$mode" in
        add)     action_label="Added" ;;
        delete)  action_label="Deleted" ;;
        comment) action_label="Commented out" ;;
    esac

    local reply="${action_label}:
+ Domains: ${domains_done}
+ IPs: ${ips_done}"
    [ "$skipped" -gt 0 ] && reply="${reply}
? Skipped (not found or invalid): ${skipped}"

    send_message "$chat_id" "$reply"
    log "${action_label}: domains+$domains_done ips+$ips_done skip=$skipped"

    if [ $((domains_done + ips_done)) -gt 0 ]; then
        log "Restarting podkop"
        /etc/init.d/podkop restart >/dev/null 2>&1 || true
    fi
}

handle_update() {
    local response="$1" idx="$2"
    local update_id chat_id text tmp body

    update_id=$(echo "$response" | jsonfilter -e "@.result[${idx}].update_id" 2>/dev/null)
    [ -z "$update_id" ] || [ "$update_id" = "null" ] && return 1

    chat_id=$(echo "$response" | jsonfilter -e "@.result[${idx}].message.chat.id" 2>/dev/null)
    text=$(echo "$response" | jsonfilter -e "@.result[${idx}].message.text" 2>/dev/null)

    # Always advance offset first
    printf '%d' "$((update_id + 1))" > "$OFFSET_FILE"

    [ -z "$chat_id" ] || [ "$chat_id" = "null" ] && return 0
    [ -z "$text" ] || [ "$text" = "null" ] && return 0

    if ! is_allowed "$chat_id"; then
        log "Rejected message from chat_id=$chat_id"
        send_message "$chat_id" "Access denied. Your Telegram ID: ${chat_id}"
        return 0
    fi

    case "$text" in
        /start*)
            send_message "$chat_id" "Your Telegram ID: ${chat_id}

Send IP addresses and/or domain names (one per line) to add them to podkop.

Commands:
/add — add entries (default, works without the command)
/delete — remove entries
/comment — comment out entries"
            ;;
        /add*)
            body=$(printf '%s' "$text" | sed 's|^/add[[:space:]]*||')
            tmp=$(mktemp /tmp/tgbot_msg.XXXXXX)
            printf '%s' "$body" > "$tmp"
            process_entries "$chat_id" "$tmp" "add"
            rm -f "$tmp"
            ;;
        /delete*)
            body=$(printf '%s' "$text" | sed 's|^/delete[[:space:]]*||')
            tmp=$(mktemp /tmp/tgbot_msg.XXXXXX)
            printf '%s' "$body" > "$tmp"
            process_entries "$chat_id" "$tmp" "delete"
            rm -f "$tmp"
            ;;
        /comment*)
            body=$(printf '%s' "$text" | sed 's|^/comment[[:space:]]*||')
            tmp=$(mktemp /tmp/tgbot_msg.XXXXXX)
            printf '%s' "$body" > "$tmp"
            process_entries "$chat_id" "$tmp" "comment"
            rm -f "$tmp"
            ;;
        /*)
            send_message "$chat_id" "Unknown command. Use /start to get your Telegram ID."
            ;;
        *)
            tmp=$(mktemp /tmp/tgbot_msg.XXXXXX)
            printf '%s' "$text" > "$tmp"
            process_entries "$chat_id" "$tmp" "add"
            rm -f "$tmp"
            ;;
    esac

    return 0
}

main() {
    command -v jsonfilter >/dev/null 2>&1 || die "jsonfilter not found"
    command -v curl       >/dev/null 2>&1 || die "curl not found"

    load_config
    [ -z "$BOT_TOKEN" ] && die "No token configured in /etc/config/tgbot"

    printf '%d' "$$" > "$PID_FILE"
    log "Started. pid=$$  domains=$DOMAINS_FILE  ips=$IPS_FILE"

    local offset=0
    [ -f "$OFFSET_FILE" ] && offset=$(cat "$OFFSET_FILE")

    while true; do
        local response ok idx

        response=$(curl -s --max-time 40 \
            "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${offset}&timeout=30&allowed_updates=message" \
            2>/dev/null)

        if [ -z "$response" ]; then
            sleep 5
            continue
        fi

        ok=$(echo "$response" | jsonfilter -e '@.ok' 2>/dev/null)
        if [ "$ok" != "true" ]; then
            local desc
            desc=$(echo "$response" | jsonfilter -e '@.description' 2>/dev/null)
            log "API error: $desc"
            sleep 15
            continue
        fi

        idx=0
        while handle_update "$response" "$idx"; do
            offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo "$offset")
            idx=$((idx + 1))
        done

        sleep 1
    done
}

main

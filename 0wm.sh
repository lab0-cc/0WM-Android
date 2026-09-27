#!/system/bin/sh

IFACE=eth0
STATE="/data/adb/0wm-$IFACE"

update() {
    tmp="$STATE.new"
    truncate -s0 "$tmp"

    if [ -e "/sys/class/net/$IFACE" ]; then
        # Discover ULA prefixes
        ip -6 route show table all dev "$IFACE" proto kernel | awk '$1 ~ /^f[cd]/ { print $1 }' | sort -u > "$tmp"
    fi

    # Remove previous routes
    if [ -f "$STATE" ]; then
        while read -r prefix; do
            grep -qxF "$prefix" "$tmp" || ip -6 route del table local "$prefix" dev "$IFACE"
        done < "$STATE"
    fi

    # Add new routes
    while read -r prefix; do
        ip -6 route replace table local "$prefix" dev "$IFACE"
    done < "$tmp"

    mv "$tmp" "$STATE"
}

while true; do
    # Catch changes not caught by the monitor
    update

    ip -6 monitor link address | while read -r event; do
        case "$event" in
            *" $IFACE:"*) update;;
        esac
    done

    sleep 1
done

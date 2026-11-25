#!/bin/bash
# Darkroot OS - finalize the chosen desktop edition inside the target system.
#   edition.sh shell   Darkroot Shell (Hyprland, Apple-style)  [already on the ISO]
#   edition.sh gnome   GNOME minimal (installed from Gentoo binhost)
set -uo pipefail
EDITION=${1:-shell}
LOG=/var/log/darkroot-edition.log
exec >>"$LOG" 2>&1
echo "=== edition: $EDITION ($(date)) ==="

emerge_dr() {
    emerge --quiet-build=y --getbinpkg --with-bdeps=y --jobs=2 --load-average="$(nproc)" \
           --autounmask=y --autounmask-continue=y "$@"
}

set_default_session() {
    install -d -o sddm -g sddm /var/lib/sddm 2>/dev/null || install -d /var/lib/sddm
    printf '[Last]\nSession=%s\n' "$1" > /var/lib/sddm/state.conf
    chown sddm:sddm /var/lib/sddm/state.conf 2>/dev/null || true
}

case "$EDITION" in
    gnome)
        [[ -d /var/db/repos/gentoo/profiles ]] || emerge-webrsync -q
        emerge_dr --noreplace darkroot-base/darkroot-gnome || exit 1
        # debloat: drop the Hyprland desktop that came with the live image
        emerge --deselect darkroot-base/darkroot-shell
        emerge --depclean --quiet || true
        install -d /etc/dconf/profile /etc/dconf/db/local.d
        printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
        cat > /etc/dconf/db/local.d/00-darkroot <<'EOF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
accent-color='purple'
font-name='Inter 11'
monospace-font-name='JetBrains Mono 11'
clock-show-weekday=true

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/darkroot/darkroot-apple.png'
picture-uri-dark='file:///usr/share/backgrounds/darkroot/darkroot-apple.png'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/darkroot/darkroot-apple.png'

[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:'

[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop','org.gnome.Terminal.desktop','firefox-bin.desktop','code.desktop','spotify.desktop']
EOF
        dconf update || true
        set_default_session /usr/share/wayland-sessions/gnome.desktop
        ;;
    shell|*)
        set_default_session /usr/share/wayland-sessions/darkroot-shell.desktop
        ;;
esac
install -d /etc/darkroot
echo "$EDITION" > /etc/darkroot/edition
echo "=== edition done ==="

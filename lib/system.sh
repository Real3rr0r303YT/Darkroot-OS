# shellcheck shell=bash
# Darkroot OS - system setup shared by the ISO builder and the text installer.
# Expects: $DR_SRC (repo checkout inside the chroot)

DR_SERVICES="udevd syslogd dbus elogind NetworkManager chronyd sddm agetty-tty1 agetty-tty2 agetty-tty3"

# Copy the rootfs overlay (/etc/runit, /etc/sv, themes, configs, tools) into /
dr_install_rootfs() {
    cp -a "$DR_SRC/rootfs/." /
    chmod 755 /etc/runit/1 /etc/runit/2 /etc/runit/3 /etc/runit/ctrlaltdel
    chmod 755 /etc/sv/*/run /usr/local/bin/* /usr/local/lib/darkroot/*
    install -Dm644 "$DR_SRC/assets/logo.svg" /usr/share/darkroot/logo.svg
    install -Dm644 "$DR_SRC/assets/logo-256.png" /usr/share/darkroot/logo.png
    install -Dm644 "$DR_SRC/assets/logo.svg" /usr/share/sddm/themes/darkroot-mac/logo.svg
    install -Dm644 "$DR_SRC/assets/logo-256.png" /usr/share/pixmaps/darkroot.png
    install -Dm644 "$DR_SRC/assets/logo-256.png" /usr/share/icons/hicolor/256x256/apps/darkroot.png

    local th
    for th in /usr/share/darkroot/themes/*/; do
        ln -sfn "/usr/share/backgrounds/darkroot/$(cat "$th/wallpaper.name")" "$th/wallpaper.png"
    done
    # new users start with the Apple look already in place
    local A=/usr/share/darkroot/themes/apple S=/etc/skel/.config
    install -d "$S/darkroot" "$S/mako"
    cp "$A/hypr-theme.lua"  "$S/hypr/theme.lua"
    cp "$A/waybar.css"      "$S/waybar/theme.css"
    cp "$A/foot-colors.ini" "$S/foot/colors.ini"
    cp "$A/wofi.css"        "$S/wofi/style.css"
    cp "$A/mako.conf"       "$S/mako/config"
}

# Make runit PID 1 and enable the default services
dr_setup_runit() {
    local sbin t svc
    sbin=$(readlink -f /sbin)
    install -d /etc/runit/runsvdir/default /etc/runit/runsvdir/single
    ln -sfn /run/runit/stopit /etc/runit/stopit
    ln -sfn /run/runit/reboot /etc/runit/reboot
    ln -sfn default /etc/runit/runsvdir/current
    rm -rf /var/service
    ln -sfn /etc/runit/runsvdir/current /var/service
    echo 'export SVDIR=/var/service' > /etc/profile.d/runit.sh

    for t in reboot poweroff halt shutdown; do
        install -m755 /usr/local/lib/darkroot/power-wrapper "$sbin/$t"
    done
    for svc in $DR_SERVICES; do
        ln -sfn "/etc/sv/$svc" "/etc/runit/runsvdir/default/$svc"
    done
    ln -sfn /etc/sv/agetty-tty1 /etc/runit/runsvdir/single/agetty-tty1
    ln -sfn /etc/sv/udevd /etc/runit/runsvdir/single/udevd

    # OpenRC user services (pam_openrc) are not used under runit: on every
    # login they ran `openrc --user` ("Caching service dependencies ...").
    sed -i '/pam_openrc\.so/s/^\([^#]\)/#\1/' /etc/pam.d/* 2>/dev/null || true
}

dr_branding() {
    rm -f /etc/os-release
    cat > /etc/os-release <<EOF
NAME="Darkroot OS"
PRETTY_NAME="Darkroot OS"
ID=darkroot
ID_LIKE=gentoo
VERSION_ID="$(date +%Y.%m)"
LOGO=darkroot
ANSI_COLOR="1;35"
HOME_URL="https://real3rr0r303yt.github.io/Darkroot-OS/"
SUPPORT_URL="https://github.com/Real3rr0r303YT/Darkroot-OS/issues"
EOF
    printf '\n\e[1;35mDarkroot OS\e[0m \\r (\\l)\n\n' > /etc/issue
    # Gentoo's sudo package does not create the drop-in directory
    install -d -m750 /etc/sudoers.d
    grep -q '^@includedir /etc/sudoers.d' /etc/sudoers || echo '@includedir /etc/sudoers.d' >> /etc/sudoers
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
    chmod 440 /etc/sudoers.d/10-wheel
    # GRUB
    sed -i -E '/^#?\s*GRUB_(DISTRIBUTOR|CMDLINE_LINUX_DEFAULT|TIMEOUT)=/d' /etc/default/grub
    cat >> /etc/default/grub <<'EOF'
GRUB_DISTRIBUTOR="Darkroot"
GRUB_CMDLINE_LINUX_DEFAULT="init=/sbin/runit-init quiet"
GRUB_TIMEOUT="3"
EOF
}

# Inter (the Apple-ish UI font) is not in ::gentoo, so fetch the upstream release
dr_install_inter_font() {
    [[ -d /usr/share/fonts/inter ]] && return 0
    local tmp
    tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/inter.zip" https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip; then
        install -d /usr/share/fonts/inter
        (cd "$tmp" && unzip -qo inter.zip 'extras/ttf/*' 2>/dev/null || unzip -qo inter.zip)
        find "$tmp" -name 'Inter-*.ttf' -exec install -m644 {} /usr/share/fonts/inter/ \;
        find "$tmp" -name 'InterVariable*.ttf' -exec install -m644 {} /usr/share/fonts/inter/ \;
        fc-cache -f >/dev/null 2>&1 || true
    fi
    rm -rf "$tmp"
}

# macOS look for the Darkroot Shell (approved by the project owner):
# WhiteSur icons, cursors and GTK theme by vinceliuice (GPL-3.0), not in ::gentoo.
dr_install_macos_look() {
    local tmp f gh=https://github.com/vinceliuice
    tmp=$(mktemp -d)
    if [[ ! -d /usr/share/icons/WhiteSur-dark ]] &&
       git clone -q --depth 1 "$gh/WhiteSur-icon-theme.git" "$tmp/icons"; then
        (cd "$tmp/icons" && ./install.sh -d /usr/share/icons -t default >/dev/null) || warn "WhiteSur icons failed"
    fi
    if [[ ! -d /usr/share/icons/WhiteSur-cursors ]] &&
       git clone -q --depth 1 "$gh/WhiteSur-cursors.git" "$tmp/cursors"; then
        cp -r "$tmp/cursors/dist" /usr/share/icons/WhiteSur-cursors || warn "WhiteSur cursors failed"
    fi
    if [[ ! -d /usr/share/themes/WhiteSur-Dark ]] &&
       git clone -q --depth 1 "$gh/WhiteSur-gtk-theme.git" "$tmp/gtk"; then
        f=$(ls "$tmp"/gtk/release/WhiteSur-Dark.tar.xz 2>/dev/null | head -n1 || true)
        if [[ -n $f ]]; then tar xf "$f" -C /usr/share/themes; else warn "WhiteSur GTK release not found"; fi
    fi
    # default cursor for every session (SDDM and Hyprland too)
    install -d /usr/share/icons/default
    printf '[Icon Theme]\nInherits=WhiteSur-cursors\n' > /usr/share/icons/default/index.theme
    gtk-update-icon-cache -qf /usr/share/icons/WhiteSur-dark 2>/dev/null || true
    rm -rf "$tmp"
}

# Spicetify needs write access to the Spotify install
dr_spotify_perms() {
    local sp
    sp=$(find /opt -maxdepth 4 -type f -name spotify -perm -u+x 2>/dev/null | head -n1 || true)
    [[ -n $sp ]] || return 0
    sp=$(dirname "$sp")
    chmod a+wr "$sp"
    [[ -d $sp/Apps ]] && chmod -R a+wr "$sp/Apps"
    install -d /etc/darkroot
    echo "$sp" > /etc/darkroot/spotify-path
}

#!/usr/bin/env bash
# =====================================================================
#  Darkroot Linux – Teil 2: läuft IM neuen System (chroot)
# =====================================================================
set -Eeuo pipefail

D=/root/darkroot
# shellcheck source=lib/ui.sh
source "$D/lib/ui.sh"
# shellcheck source=/dev/null
source "$D/install.conf"
set +u; source /etc/profile; set -u
export PS1="(darkroot) # "

trap 'die "Fehler in Zeile $LINENO (chroot)."' ERR

NPROC=$(nproc)
EMERGE=(emerge --quiet-build=y --getbinpkg --with-bdeps=y --jobs=2 --load-average="$NPROC")

# set_kv DATEI SCHLÜSSEL WERT  -> setzt/ersetzt KEY="WERT" in einer Shell-Konfig
set_kv() {
    local f=$1 k=$2 v=$3
    touch "$f"
    if grep -qE "^#?\s*${k}=" "$f"; then
        sed -i -E "s|^#?\s*${k}=.*|${k}=\"${v}\"|" "$f"
    else
        printf '%s="%s"\n' "$k" "$v" >> "$f"
    fi
}

# ---------------------------------------------------------------------
portage_setup() {
    section "Portage einrichten"
    mkdir -p /etc/portage/{package.use,package.license,package.accept_keywords,package.env,env,repos.conf}

    local grub_platform="efi-64"
    [[ $BOOTMODE == bios ]] && grub_platform="pc"

    cat >> /etc/portage/make.conf <<EOF

# ---------------- Darkroot Linux ----------------
MAKEOPTS="-j${NPROC} -l${NPROC}"
FEATURES="\${FEATURES} getbinpkg binpkg-request-signature parallel-fetch"
USE="-systemd elogind dbus networkmanager pipewire pulseaudio dist-kernel X wayland"
ACCEPT_LICENSE="-* @FREE @BINARY-REDISTRIBUTABLE"
VIDEO_CARDS="${VIDEO_CARDS}"
INPUT_DEVICES="libinput"
GRUB_PLATFORMS="${grub_platform}"
L10N="de en"
EOF

    cat > /etc/portage/package.use/darkroot <<'EOF'
sys-kernel/installkernel dracut grub
media-video/pipewire sound-server
EOF
    cat > /etc/portage/package.license/darkroot <<'EOF'
app-editors/vscode Microsoft-vscode
media-sound/spotify Spotify
sys-kernel/linux-firmware linux-fw-redistributable
x11-drivers/nvidia-drivers NVIDIA-r2
EOF
    cat > /etc/portage/package.accept_keywords/darkroot <<'EOF'
app-editors/vscode
media-sound/spotify
EOF

    # Die sysvinit-Befehle reboot/poweroff/... ersetzt Darkroot durch eigene,
    # runit-fähige Versionen (siehe runit/power-wrapper).
    local m="" b
    for b in reboot halt poweroff shutdown; do m+="/sbin/$b /usr/sbin/$b /bin/$b /usr/bin/$b "; done
    printf 'INSTALL_MASK="%s"\n' "$m" > /etc/portage/env/darkroot-no-sysv-power.conf
    echo "sys-apps/sysvinit darkroot-no-sysv-power.conf" > /etc/portage/package.env/darkroot

    info "Lade Gentoo-Paketbaum ..."
    emerge-webrsync -q
    getuto
    eselect profile set default/linux/amd64/23.0/desktop/plasma
    ok "Profil: $(eselect profile show | tail -n1 | xargs)"
}

locale_time() {
    section "Sprache & Zeit"
    if [[ -e /usr/share/zoneinfo/$TIMEZONE ]]; then
        ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
        echo "$TIMEZONE" > /etc/timezone
    else
        warn "Zeitzone $TIMEZONE unbekannt – benutze UTC."
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    fi
    {
        echo "en_US.UTF-8 UTF-8"
        if [[ $LOCALE != en_US.UTF-8 ]]; then echo "$LOCALE UTF-8"; fi
    } > /etc/locale.gen
    locale-gen -q
    eselect locale set "${LOCALE/UTF-8/utf8}" || eselect locale set "$LOCALE" || true
    env-update >/dev/null
    set +u; source /etc/profile; set -u

    set_kv /etc/conf.d/keymaps keymap "$KEYMAP"
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "${XKB_LAYOUT}"
EndSection
EOF
    ok "Locale $LOCALE, Zeitzone $TIMEZONE"
}

world_update() {
    section "System aktualisieren (Binärpakete werden bevorzugt)"
    "${EMERGE[@]}" --oneshot sys-apps/portage
    "${EMERGE[@]}" --update --deep --newuse @world
    "${EMERGE[@]}" --oneshot sys-apps/sysvinit   # mit INSTALL_MASK neu installieren
    ok "Welt aktuell"
}

install_base() {
    section "Basissystem, Kernel & Bootloader"
    local pkgs=(
        sys-process/runit app-admin/sysklogd sys-auth/elogind sys-apps/dbus
        net-misc/networkmanager net-misc/chrony
        app-admin/sudo dev-vcs/git net-misc/curl sys-fs/dosfstools sys-apps/pciutils
        app-misc/fastfetch sys-boot/grub
    )
    [[ $BOOTMODE == uefi ]] && pkgs+=(sys-boot/efibootmgr)
    "${EMERGE[@]}" --noreplace "${pkgs[@]}"

    # GRUB zuerst, damit installkernel[grub] direkt eine Konfiguration erzeugen kann
    set_kv /etc/default/grub GRUB_DISTRIBUTOR "Darkroot"
    set_kv /etc/default/grub GRUB_CMDLINE_LINUX_DEFAULT "init=/sbin/runit-init quiet"
    set_kv /etc/default/grub GRUB_TIMEOUT "3"
    if [[ $BOOTMODE == uefi ]]; then
        grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Darkroot
        # Fallback-Pfad für zickige UEFI-Firmware
        grub-install --target=x86_64-efi --efi-directory=/efi --removable
    else
        grub-install --target=i386-pc "$DISK"
    fi

    local kpkgs=(sys-kernel/linux-firmware sys-kernel/gentoo-kernel-bin)
    grep -q GenuineIntel /proc/cpuinfo && kpkgs+=(sys-firmware/intel-microcode)
    [[ $GPU == nvidia ]] && kpkgs+=(x11-drivers/nvidia-drivers)
    "${EMERGE[@]}" --noreplace "${kpkgs[@]}"

    grub-mkconfig -o /boot/grub/grub.cfg
    ok "Kernel und GRUB installiert"
}

install_desktop() {
    section "Desktop: KDE Plasma + SDDM + Apps"
    local pkgs=(
        x11-base/xorg-server kde-plasma/plasma-meta x11-misc/sddm
        kde-apps/konsole kde-apps/dolphin kde-apps/kate kde-apps/ark
        kde-apps/spectacle kde-apps/kdialog
        media-video/pipewire media-video/wireplumber
        media-fonts/inter media-fonts/noto media-fonts/noto-emoji
        www-client/firefox-bin
        app-editors/vscode media-sound/spotify
    )
    "${EMERGE[@]}" --noreplace "${pkgs[@]}"
    ok "Desktop installiert"
}

# ---------------------------------------------------------------------
system_config() {
    section "Systemkonfiguration"
    echo "$HOSTNAME_" > /etc/hostname
    set_kv /etc/conf.d/hostname hostname "$HOSTNAME_"
    cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME_}.localdomain ${HOSTNAME_}
EOF

    # fstab
    local root_uuid boot_uuid swap_dev
    root_uuid=$(findmnt -no UUID /)
    {
        echo "# Darkroot Linux – /etc/fstab"
        echo "UUID=${root_uuid}  /     ext4  defaults,noatime  0 1"
        if [[ $BOOTMODE == uefi ]]; then
            boot_uuid=$(findmnt -no UUID /efi)
            echo "UUID=${boot_uuid}  /efi  vfat  umask=0077        0 2"
        fi
        swap_dev=$(awk 'NR>1 && $2=="partition"{print $1; exit}' /proc/swaps)
        if [[ -n $swap_dev ]]; then
            echo "UUID=$(blkid -s UUID -o value "$swap_dev")  none  swap  sw  0 0"
        fi
        echo "tmpfs  /tmp  tmpfs  defaults,nosuid,nodev,mode=1777  0 0"
    } > /etc/fstab

    # Branding
    rm -f /etc/os-release
    cat > /etc/os-release <<EOF
NAME="Darkroot Linux"
PRETTY_NAME="Darkroot Linux"
ID=darkroot
ID_LIKE=gentoo
VERSION_ID="$(date +%Y.%m)"
ANSI_COLOR="1;35"
HOME_URL="https://github.com/Real3rr0r303YT/Darkroot-OS"
EOF
    printf '\n\e[1;35mDarkroot Linux\e[0m \\r (\\l)\n\n' > /etc/issue

    # sudo für wheel
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
    chmod 440 /etc/sudoers.d/10-wheel
    ok "Hostname, fstab, Branding, sudo"
}

create_user() {
    section "Benutzer anlegen"
    local groups=() g
    for g in users wheel audio video input usb plugdev cdrom; do
        getent group "$g" >/dev/null && groups+=("$g")
    done
    id "$USERNAME" &>/dev/null || useradd -m -s /bin/bash -G "$(IFS=,; echo "${groups[*]}")" "$USERNAME"
    info "Passwort für ${C_B}$USERNAME${C_0} festlegen:"
    until passwd "$USERNAME"; do warn "Nochmal versuchen."; done
    info "Passwort für ${C_B}root${C_0} festlegen:"
    until passwd root; do warn "Nochmal versuchen."; done
    ok "Benutzer $USERNAME angelegt"
}

install_runit() {
    section "Darkroot-runit installieren"
    local sbin
    sbin=$(readlink -f /sbin)

    install -d -m755 /etc/runit /etc/sv /etc/runit/runsvdir/default
    install -m755 "$D/runit/1" "$D/runit/2" "$D/runit/3" "$D/runit/ctrlaltdel" /etc/runit/
    install -m644 "$D/runit/functions" /etc/runit/functions
    ln -sfn /run/runit/stopit /etc/runit/stopit
    ln -sfn /run/runit/reboot /etc/runit/reboot

    cp -a "$D/runit/sv/." /etc/sv/
    chmod 755 /etc/sv/*/run
    local t
    for t in tty1 tty2 tty3; do
        install -d "/etc/sv/agetty-$t"
        install -m755 "$D/runit/agetty-run" "/etc/sv/agetty-$t/run"
    done

    ln -sfn default /etc/runit/runsvdir/current
    rm -rf /var/service
    ln -sfn /etc/runit/runsvdir/current /var/service

    install -m755 "$D/runit/dr-sv" /usr/local/bin/dr-sv
    echo 'export SVDIR=/var/service' > /etc/profile.d/runit.sh

    # reboot/poweroff/halt/shutdown -> runit (fallback: openrc)
    for t in reboot poweroff halt shutdown; do
        install -m755 "$D/runit/power-wrapper" "$sbin/$t"
    done

    local svc
    for svc in udevd syslogd dbus elogind NetworkManager chronyd sddm agetty-tty1 agetty-tty2 agetty-tty3; do
        ln -sfn "/etc/sv/$svc" "/etc/runit/runsvdir/default/$svc"
    done
    ok "runit ist das Init-System (Dienste: dr-sv list)"
}

install_sddm_theme() {
    section "Login-Theme (macOS-Stil)"
    install -d /usr/share/sddm/themes
    cp -a "$D/sddm-theme/darkroot-mac" /usr/share/sddm/themes/
    install -d /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/10-darkroot.conf <<'EOF'
[Theme]
Current=darkroot-mac

[General]
Numlock=on

[X11]
MinimumVT=7

[Users]
MaximumUid=60000
EOF
    getent passwd sddm >/dev/null && usermod -aG video sddm
    ok "SDDM-Theme darkroot-mac aktiv"
}

install_firstlogin() {
    section "Willkommens-Assistent"
    install -m755 "$D/firstlogin/darkroot-firstlogin" /usr/local/bin/darkroot-firstlogin
    install -m755 "$D/firstlogin/darkroot-spicetify" /usr/local/bin/darkroot-spicetify
    install -Dm644 "$D/firstlogin/darkroot-firstlogin.desktop" /etc/xdg/autostart/darkroot-firstlogin.desktop

    # Spicetify muss die Spotify-Dateien verändern dürfen
    local sp
    sp=$(find /opt -maxdepth 4 -type f -name spotify -perm -u+x 2>/dev/null | head -n1 || true)
    if [[ -n $sp ]]; then
        sp=$(dirname "$sp")
        chmod a+wr "$sp"
        [[ -d $sp/Apps ]] && chmod -R a+wr "$sp/Apps"
        install -d /etc/darkroot
        echo "$sp" > /etc/darkroot/spotify-path
        ok "Spotify gefunden: $sp"
    else
        warn "Spotify-Verzeichnis nicht gefunden – Spicetify später manuell einrichten."
    fi
}

# ---------------------------------------------------------------------
main() {
    portage_setup
    locale_time
    world_update
    install_base
    install_desktop
    system_config
    create_user
    install_runit
    install_sddm_theme
    install_firstlogin
    ok "Chroot-Teil abgeschlossen"
}

main "$@"

#!/usr/bin/env bash
# =====================================================================
#  Darkroot Linux Installer  –  Gentoo, aber so einfach wie CachyOS.
#  Startet von einer Live-Umgebung (Gentoo Minimal ISO oder jede
#  andere x86_64 Live-Distro) und installiert ein komplettes System:
#    Gentoo + eigenes runit-Init + KDE Plasma (macOS-Look) + SDDM
#    + NetworkManager + VS Code + Spotify/Spicetify + Claude Code
#  Lizenz: GPL-3.0
# =====================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

MNT=/mnt/darkroot
LOG=/tmp/darkroot-install.log
STAGE3_BASE=https://distfiles.gentoo.org/releases/amd64/autobuilds
STAGE3_FLAVOR=stage3-amd64-desktop-openrc

trap 'die "Fehler in Zeile $LINENO. Details im Log: $LOG"' ERR

fetch() {          # fetch URL ZIELDATEI
    if command -v curl >/dev/null; then curl -fL --retry 3 --progress-bar -o "$2" "$1"
    else wget -q --show-progress -O "$2" "$1"; fi
}
fetch_stdout() {   # fetch_stdout URL
    if command -v curl >/dev/null; then curl -fsSL --retry 3 "$1"
    else wget -qO- "$1"; fi
}

# ---------------------------------------------------------------------
preflight() {
    [[ $EUID -eq 0 ]] || die "Bitte als root starten (z.B. 'sudo -i')."
    [[ $(uname -m) == x86_64 ]] || die "Darkroot unterstützt nur x86_64."
    local t
    for t in sfdisk wipefs mkfs.ext4 mkfs.vfat mkswap blkid lsblk tar xz sha512sum chroot; do
        command -v "$t" >/dev/null || die "Benötigtes Werkzeug fehlt in der Live-Umgebung: $t"
    done
    command -v curl >/dev/null || command -v wget >/dev/null || die "curl oder wget wird benötigt."
    info "Prüfe Internetverbindung ..."
    fetch_stdout "$STAGE3_BASE/latest-$STAGE3_FLAVOR.txt" >/dev/null \
        || die "Keine Internetverbindung. Verbinde dich z.B. mit 'nmtui' oder 'net-setup'."
    if [[ -d /sys/firmware/efi ]]; then BOOTMODE=uefi; else BOOTMODE=bios; fi
    ok "Live-Umgebung bereit (Boot-Modus: $BOOTMODE)"
}

# ---------------------------------------------------------------------
configure() {
    section "Festplatte"
    local disks=()
    mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL -e 7,11 | sed 's/  */ /g; s/ *$//')
    ((${#disks[@]})) || die "Keine Festplatte gefunden."
    choose "Auf welche Festplatte soll Darkroot installiert werden? (wird KOMPLETT gelöscht)" "${disks[@]}"
    DISK=${REPLY_CHOICE%% *}

    section "System"
    while :; do
        HOSTNAME_=$(ask "Computername (Hostname)" "darkroot")
        [[ $HOSTNAME_ =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && break
        warn "Nur Buchstaben, Zahlen und '-' erlaubt."
    done
    while :; do
        USERNAME=$(ask "Benutzername" "")
        [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
        warn "Kleinbuchstaben, Zahlen, '_' und '-', beginnend mit einem Buchstaben."
    done
    TIMEZONE=$(ask "Zeitzone" "Europe/Berlin")
    LOCALE=$(ask "Sprache (Locale)" "de_DE.UTF-8")
    KEYMAP=$(ask "Tastatur (Konsole)" "de-latin1")
    XKB_LAYOUT=$(ask "Tastatur (Desktop/Login)" "de")

    local ram_gb
    ram_gb=$(awk '/MemTotal/{printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
    (( ram_gb > 8 )) && ram_gb=8
    while :; do
        SWAP_GB=$(ask "Swap-Größe in GB (0 = kein Swap)" "$ram_gb")
        [[ $SWAP_GB =~ ^[0-9]+$ ]] && break
    done

    section "Grafikkarte"
    choose "Welche Grafikkarte hast du?" "AMD" "Intel" "NVIDIA (proprietärer Treiber)" "Virtuelle Maschine (VirtualBox/QEMU/VMware)"
    case $REPLY_INDEX in
        0) GPU=amd;    VIDEO_CARDS="amdgpu radeonsi" ;;
        1) GPU=intel;  VIDEO_CARDS="intel" ;;
        2) GPU=nvidia; VIDEO_CARDS="nvidia" ;;
        3) GPU=vm;     VIDEO_CARDS="virgl vmware" ;;
    esac

    section "Zusammenfassung"
    cat <<EOF
   Festplatte : $DISK  ${C_R}(alle Daten werden gelöscht!)${C_0}
   Boot-Modus : $BOOTMODE
   Hostname   : $HOSTNAME_
   Benutzer   : $USERNAME
   Zeitzone   : $TIMEZONE
   Sprache    : $LOCALE   Tastatur: $KEYMAP / $XKB_LAYOUT
   Swap       : ${SWAP_GB} GB
   Grafik     : $GPU ($VIDEO_CARDS)
   Init       : Darkroot-runit      Desktop: KDE Plasma (macOS-Look)
   Login      : SDDM "Darkroot Mac"  Netzwerk: NetworkManager
   Apps       : VS Code, Spotify + Spicetify, Claude Code, Firefox
EOF
    echo
    confirm_yes "Wirklich $DISK löschen und Darkroot installieren?" || die "Abgebrochen."
}

# ---------------------------------------------------------------------
partition() {
    section "Partitionierung"
    swapoff -a 2>/dev/null || true
    umount -R "$MNT" 2>/dev/null || true
    wipefs -af "$DISK" >/dev/null

    local p="" n=1
    [[ $DISK =~ [0-9]$ ]] && p=p   # nvme0n1 -> nvme0n1p1

    {
        echo "label: gpt"
        if [[ $BOOTMODE == uefi ]]; then
            echo "size=1GiB, type=U, name=EFI"
        else
            echo "size=1MiB, type=21686148-6449-6E6F-744E-656564454649, name=biosboot"
        fi
        if (( SWAP_GB > 0 )); then echo "size=${SWAP_GB}GiB, type=S, name=swap"; fi
        echo "type=L, name=darkroot"
    } | sfdisk --wipe always --wipe-partitions always "$DISK"

    udevadm settle 2>/dev/null || sleep 3

    BOOTPART=${DISK}${p}${n}; n=$((n + 1))
    SWAPPART=""
    if (( SWAP_GB > 0 )); then SWAPPART=${DISK}${p}${n}; n=$((n + 1)); fi
    ROOTPART=${DISK}${p}${n}

    info "Formatiere ..."
    [[ $BOOTMODE == uefi ]] && mkfs.vfat -F 32 -n EFI "$BOOTPART" >/dev/null
    if [[ -n $SWAPPART ]]; then mkswap -L swap "$SWAPPART" >/dev/null; swapon "$SWAPPART"; fi
    mkfs.ext4 -F -q -L darkroot "$ROOTPART"

    mkdir -p "$MNT"
    mount "$ROOTPART" "$MNT"
    if [[ $BOOTMODE == uefi ]]; then
        mkdir -p "$MNT/efi"
        mount "$BOOTPART" "$MNT/efi"
    fi
    ok "Partitionen erstellt: root=$ROOTPART ${SWAPPART:+swap=$SWAPPART} boot=$BOOTPART"
}

# ---------------------------------------------------------------------
install_stage3() {
    section "Gentoo Stage3 herunterladen"
    local txt path name expected actual
    txt=$(fetch_stdout "$STAGE3_BASE/latest-$STAGE3_FLAVOR.txt")
    path=$(grep -Eo "[0-9TZ]+/${STAGE3_FLAVOR}-[0-9TZ]+\.tar\.xz" <<<"$txt" | head -n1)
    [[ -n $path ]] || die "Konnte die aktuelle Stage3 nicht ermitteln."
    name=${path##*/}
    info "$name"

    fetch "$STAGE3_BASE/$path" "$MNT/$name"
    fetch "$STAGE3_BASE/$path.DIGESTS" "$MNT/$name.DIGESTS"

    expected=$(awk -v f="$name" '/SHA512 HASH/{h=1; next} /HASH/{h=0} h && $2==f {print $1; exit}' "$MNT/$name.DIGESTS")
    actual=$(sha512sum "$MNT/$name" | awk '{print $1}')
    [[ -n $expected && $expected == "$actual" ]] || die "Prüfsumme der Stage3 stimmt nicht!"
    ok "Prüfsumme korrekt"

    info "Entpacke Stage3 (dauert einen Moment) ..."
    tar xpf "$MNT/$name" --xattrs-include='*.*' --numeric-owner -C "$MNT"
    rm -f "$MNT/$name" "$MNT/$name.DIGESTS"
    ok "Basissystem entpackt"
}

# ---------------------------------------------------------------------
enter_chroot() {
    section "Chroot vorbereiten"
    mkdir -p "$MNT/root/darkroot"
    cp -a "$SCRIPT_DIR"/. "$MNT/root/darkroot/"

    local v
    {
        for v in DISK BOOTMODE HOSTNAME_ USERNAME TIMEZONE LOCALE KEYMAP XKB_LAYOUT GPU VIDEO_CARDS; do
            printf '%s=%q\n' "$v" "${!v}"
        done
    } > "$MNT/root/darkroot/install.conf"

    cp --dereference /etc/resolv.conf "$MNT/etc/"
    mount --types proc /proc "$MNT/proc"
    mount --rbind /sys "$MNT/sys";  mount --make-rslave "$MNT/sys"
    mount --rbind /dev "$MNT/dev";  mount --make-rslave "$MNT/dev"
    mount --bind /run "$MNT/run";   mount --make-slave "$MNT/run"

    ok "Wechsle ins neue System ..."
    chroot "$MNT" /bin/bash /root/darkroot/chroot-install.sh
}

finish() {
    section "Fertig"
    rm -rf "$MNT/root/darkroot"
    cp "$LOG" "$MNT/var/log/darkroot-install.log" 2>/dev/null || true
    sync
    umount -l -R "$MNT" 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    printf '\n%s  Darkroot Linux wurde installiert! 🖤%s\n' "$C_G$C_B" "$C_0"
    printf '  Entferne den USB-Stick und starte neu mit:  %sreboot%s\n\n' "$C_B" "$C_0"
}

main() {
    exec > >(tee -a "$LOG") 2>&1
    banner
    preflight
    configure
    partition
    install_stage3
    enter_chroot
    finish
}

main "$@"

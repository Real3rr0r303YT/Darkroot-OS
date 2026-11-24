#!/usr/bin/env bash
# =====================================================================
#  Darkroot OS - text installer
#  The graphical way is the live ISO with Calamares. This script installs
#  the same system from any x86_64 live environment (e.g. the Gentoo
#  minimal ISO):
#      curl -fsSL https://github.com/Real3rr0r303YT/Darkroot-OS/archive/refs/heads/main.tar.gz | tar xz
#      cd Darkroot-OS-main && bash install.sh
#  License: GPL-3.0
# =====================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

MNT=/mnt/darkroot
LOG=/tmp/darkroot-install.log
STAGE3_BASE=https://distfiles.gentoo.org/releases/amd64/autobuilds
STAGE3_FLAVOR=stage3-amd64-desktop-openrc

trap 'die "Error on line $LINENO. Full log: $LOG"' ERR

fetch() {
    if command -v curl >/dev/null; then curl -fL --retry 3 --progress-bar -o "$2" "$1"
    else wget -q --show-progress -O "$2" "$1"; fi
}
fetch_stdout() {
    if command -v curl >/dev/null; then curl -fsSL --retry 3 "$1"
    else wget -qO- "$1"; fi
}

preflight() {
    [[ $EUID -eq 0 ]] || die "Please run as root (e.g. 'sudo -i')."
    [[ $(uname -m) == x86_64 ]] || die "Darkroot OS supports x86_64 only."
    local t
    for t in sfdisk wipefs mkfs.ext4 mkfs.vfat mkswap blkid lsblk tar xz sha512sum chroot; do
        command -v "$t" >/dev/null || die "Missing tool in the live environment: $t"
    done
    command -v curl >/dev/null || command -v wget >/dev/null || die "curl or wget is required."
    info "Checking internet connection ..."
    fetch_stdout "$STAGE3_BASE/latest-$STAGE3_FLAVOR.txt" >/dev/null \
        || die "No internet connection. Connect with 'nmtui' or 'net-setup' first."
    if [[ -d /sys/firmware/efi ]]; then BOOTMODE=uefi; else BOOTMODE=bios; fi
    ok "Live environment ready (boot mode: $BOOTMODE)"
}

configure() {
    section "Disk"
    local disks=()
    mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL -e 7,11 | sed 's/  */ /g; s/ *$//')
    ((${#disks[@]})) || die "No disk found."
    choose "Install Darkroot OS on which disk? (it will be ERASED)" "${disks[@]}"
    DISK=${REPLY_CHOICE%% *}

    section "Edition"
    choose "Which desktop?" "Darkroot Shell - Apple-style Hyprland (recommended)" "GNOME Minimal - debloated GNOME"
    case $REPLY_INDEX in 0) EDITION=shell ;; 1) EDITION=gnome ;; esac
    choose "Enable Hacker Mode (security toolkit + hacker look)?" "No" "Yes"
    HACKER=$REPLY_INDEX

    section "System"
    while :; do
        HOSTNAME_=$(ask "Hostname" "darkroot")
        [[ $HOSTNAME_ =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && break
        warn "Letters, digits and '-' only."
    done
    while :; do
        USERNAME=$(ask "Username" "")
        [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
        warn "Lowercase letters, digits, '_' and '-', starting with a letter."
    done
    TIMEZONE=$(ask "Time zone" "Europe/Berlin")
    LOCALE=$(ask "Locale" "en_US.UTF-8")
    KEYMAP=$(ask "Console keymap" "us")
    XKB_LAYOUT=$(ask "Desktop keyboard layout" "us")

    local ram_gb
    ram_gb=$(awk '/MemTotal/{printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
    (( ram_gb > 8 )) && ram_gb=8
    while :; do
        SWAP_GB=$(ask "Swap size in GB (0 = none)" "$ram_gb")
        [[ $SWAP_GB =~ ^[0-9]+$ ]] && break
    done

    section "Graphics"
    choose "Which GPU do you have?" "AMD" "Intel" "NVIDIA (proprietary driver)" "Virtual machine (VirtualBox/QEMU/VMware)"
    case $REPLY_INDEX in
        0) GPU=amd;    VIDEO_CARDS="amdgpu radeonsi" ;;
        1) GPU=intel;  VIDEO_CARDS="intel" ;;
        2) GPU=nvidia; VIDEO_CARDS="nvidia" ;;
        3) GPU=vm;     VIDEO_CARDS="virgl vmware" ;;
    esac

    section "Summary"
    cat <<EOF
   Disk       : $DISK  ${C_R}(all data will be erased!)${C_0}
   Boot mode  : $BOOTMODE
   Edition    : $EDITION      Hacker Mode: $( ((HACKER)) && echo yes || echo no )
   Hostname   : $HOSTNAME_
   User       : $USERNAME
   Time zone  : $TIMEZONE
   Locale     : $LOCALE   Keyboard: $KEYMAP / $XKB_LAYOUT
   Swap       : ${SWAP_GB} GB
   Graphics   : $GPU ($VIDEO_CARDS)
   Init       : Darkroot runit     Login: SDDM (Darkroot themes)
   Apps       : VS Code, Spotify + Spicetify, Claude Code, Firefox
EOF
    echo
    confirm_yes "Really erase $DISK and install Darkroot OS?" || die "Aborted."
}

partition() {
    section "Partitioning"
    swapoff -a 2>/dev/null || true
    umount -R "$MNT" 2>/dev/null || true
    wipefs -af "$DISK" >/dev/null

    local p="" n=1
    [[ $DISK =~ [0-9]$ ]] && p=p
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

    [[ $BOOTMODE == uefi ]] && mkfs.vfat -F 32 -n EFI "$BOOTPART" >/dev/null
    if [[ -n $SWAPPART ]]; then mkswap -L swap "$SWAPPART" >/dev/null; swapon "$SWAPPART"; fi
    mkfs.ext4 -F -q -L darkroot "$ROOTPART"

    mkdir -p "$MNT"
    mount "$ROOTPART" "$MNT"
    if [[ $BOOTMODE == uefi ]]; then
        mkdir -p "$MNT/efi"
        mount "$BOOTPART" "$MNT/efi"
    fi
    ok "root=$ROOTPART ${SWAPPART:+swap=$SWAPPART} boot=$BOOTPART"
}

install_stage3() {
    section "Gentoo stage3"
    local txt path name expected actual
    txt=$(fetch_stdout "$STAGE3_BASE/latest-$STAGE3_FLAVOR.txt")
    path=$(grep -Eo "[0-9TZ]+/${STAGE3_FLAVOR}-[0-9TZ]+\.tar\.xz" <<<"$txt" | head -n1)
    [[ -n $path ]] || die "Could not determine the latest stage3."
    name=${path##*/}
    info "$name"
    fetch "$STAGE3_BASE/$path" "$MNT/$name"
    fetch "$STAGE3_BASE/$path.DIGESTS" "$MNT/$name.DIGESTS"
    expected=$(awk -v f="$name" '/SHA512 HASH/{h=1; next} /HASH/{h=0} h && $2==f {print $1; exit}' "$MNT/$name.DIGESTS")
    actual=$(sha512sum "$MNT/$name" | awk '{print $1}')
    [[ -n $expected && $expected == "$actual" ]] || die "Stage3 checksum mismatch!"
    ok "checksum verified"
    info "Unpacking ..."
    tar xpf "$MNT/$name" --xattrs-include='*.*' --numeric-owner -C "$MNT"
    rm -f "$MNT/$name" "$MNT/$name.DIGESTS"
}

enter_chroot() {
    section "Entering the new system"
    mkdir -p "$MNT/tmp/darkroot-src"
    cp -a "$SCRIPT_DIR"/. "$MNT/tmp/darkroot-src/"
    local v
    for v in DISK BOOTMODE EDITION HACKER HOSTNAME_ USERNAME TIMEZONE LOCALE KEYMAP XKB_LAYOUT GPU VIDEO_CARDS; do
        printf '%s=%q\n' "$v" "${!v}"
    done > "$MNT/tmp/darkroot-src/install.conf"

    cp --dereference /etc/resolv.conf "$MNT/etc/"
    mount --types proc /proc "$MNT/proc"
    mount --rbind /sys "$MNT/sys";  mount --make-rslave "$MNT/sys"
    mount --rbind /dev "$MNT/dev";  mount --make-rslave "$MNT/dev"
    mount --bind /run "$MNT/run";   mount --make-slave "$MNT/run"
    chroot "$MNT" /bin/bash /tmp/darkroot-src/chroot-install.sh
}

finish() {
    section "Done"
    rm -rf "$MNT/tmp/darkroot-src"
    cp "$LOG" "$MNT/var/log/darkroot-install.log" 2>/dev/null || true
    sync
    umount -l -R "$MNT" 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    printf '\n%s  Darkroot OS is installed!%s\n' "$C_G$C_B" "$C_0"
    printf '  Remove the install media and run:  %sreboot%s\n\n' "$C_B" "$C_0"
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

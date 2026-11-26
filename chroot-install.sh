#!/usr/bin/env bash
# =====================================================================
#  Darkroot OS - text installer, part 2 (runs inside the new system)
# =====================================================================
set -Eeuo pipefail
export DR_SRC=/tmp/darkroot-src
# shellcheck source=lib/ui.sh
source "$DR_SRC/lib/ui.sh"
# shellcheck source=/dev/null
source "$DR_SRC/install.conf"
# shellcheck source=lib/portage.sh
source "$DR_SRC/lib/portage.sh"
# shellcheck source=lib/system.sh
source "$DR_SRC/lib/system.sh"
set +u; source /etc/profile; set -u
trap 'die "Error on line $LINENO (chroot)."' ERR

export VIDEO_CARDS
if [[ $BOOTMODE == uefi ]]; then export GRUB_PLATFORMS="efi-64"; else export GRUB_PLATFORMS="pc"; fi

section "Portage"
dr_portage_setup
dr_portage_sync

section "Language & time"
if [[ -e /usr/share/zoneinfo/$TIMEZONE ]]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
else
    warn "Unknown time zone $TIMEZONE - using UTC."
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi
{
    echo "en_US.UTF-8 UTF-8"
    if [[ $LOCALE != en_US.UTF-8 ]]; then echo "$LOCALE UTF-8"; fi
} > /etc/locale.gen
locale-gen -q
eselect locale set "${LOCALE/UTF-8/utf8}" || true
env-update >/dev/null; set +u; source /etc/profile; set -u
sed -i "s/^keymap=.*/keymap=\"$KEYMAP\"/" /etc/conf.d/keymaps
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "${XKB_LAYOUT}"
EndSection
EOF

section "World update (binary packages preferred)"
dr_emerge --oneshot sys-apps/portage
dr_emerge --update --deep --newuse @world
dr_emerge --oneshot sys-apps/sysvinit

section "Bootloader"
dr_emerge --noreplace sys-boot/grub sys-boot/efibootmgr
dr_branding
if [[ $BOOTMODE == uefi ]]; then
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Darkroot
    grub-install --target=x86_64-efi --efi-directory=/efi --removable
else
    grub-install --target=i386-pc "$DISK"
fi

section "Darkroot packages"
grep -q GenuineIntel /proc/cpuinfo && dr_emerge --noreplace sys-firmware/intel-microcode || true
[[ $GPU == nvidia ]] && dr_emerge --noreplace x11-drivers/nvidia-drivers || true
dr_emerge --noreplace darkroot-base/darkroot-shell

section "Darkroot system"
dr_install_rootfs
dr_setup_runit
dr_install_inter_font
dr_install_macos_look
dr_spotify_perms
install -d /etc/darkroot
echo apple > /etc/darkroot/default-theme
echo "$HOSTNAME_" > /etc/hostname
printf 'hostname="%s"\n' "$HOSTNAME_" > /etc/conf.d/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME_}.localdomain ${HOSTNAME_}
EOF

section "fstab"
{
    echo "# Darkroot OS - /etc/fstab"
    echo "UUID=$(findmnt -no UUID /)  /     ext4  defaults,noatime  0 1"
    [[ $BOOTMODE == uefi ]] && echo "UUID=$(findmnt -no UUID /efi)  /efi  vfat  umask=0077  0 2"
    swap_dev=$(awk 'NR>1 && $2=="partition"{print $1; exit}' /proc/swaps)
    [[ -n $swap_dev ]] && echo "UUID=$(blkid -s UUID -o value "$swap_dev")  none  swap  sw  0 0"
    echo "tmpfs  /tmp  tmpfs  defaults,nosuid,nodev,mode=1777  0 0"
} > /etc/fstab

section "User"
groups=()
for g in users wheel audio video input usb cdrom; do getent group "$g" >/dev/null && groups+=("$g"); done
id "$USERNAME" &>/dev/null || useradd -m -s /bin/bash -G "$(IFS=,; echo "${groups[*]}")" "$USERNAME"
info "Set the password for ${C_B}$USERNAME${C_0}:"
until passwd "$USERNAME"; do warn "Try again."; done
info "Set the password for ${C_B}root${C_0}:"
until passwd root; do warn "Try again."; done

section "Edition: $EDITION"
/usr/local/lib/darkroot/edition.sh "$EDITION" || die "edition setup failed (see /var/log/darkroot-edition.log)"
if (( HACKER )); then
    section "Hacker Mode"
    /usr/local/lib/darkroot/hacker.sh install || warn "some hacker tools failed (see /var/log/darkroot-hacker.log)"
fi
/usr/local/lib/darkroot/finalize.sh
sed -i "s/^\(\s*kb_layout\s*=\).*/\1 $XKB_LAYOUT/" "/home/$USERNAME/.config/hypr/hyprland.conf" 2>/dev/null || true

section "GRUB config"
grub-mkconfig -o /boot/grub/grub.cfg
ok "Chroot part finished"

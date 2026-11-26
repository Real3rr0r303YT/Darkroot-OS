#!/usr/bin/env bash
# Darkroot OS - builds the live system inside the ISO chroot (called by build-iso.sh)
set -Eeuo pipefail
export DR_SRC=/tmp/darkroot-src
# shellcheck source=../lib/ui.sh
source "$DR_SRC/lib/ui.sh"
# shellcheck source=../lib/portage.sh
source "$DR_SRC/lib/portage.sh"
# shellcheck source=../lib/system.sh
source "$DR_SRC/lib/system.sh"
set +u; source /etc/profile; set -u
trap 'die "chroot step failed at line $LINENO"' ERR

export VIDEO_CARDS="amdgpu radeonsi intel nouveau virgl vmware"
export GRUB_PLATFORMS="efi-64 pc"

section "Portage"
dr_portage_setup
dr_portage_sync

section "Locale"
cat > /etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
EOF
locale-gen -q
eselect locale set en_US.utf8 || true
env-update >/dev/null; set +u; source /etc/profile; set -u
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

install -d /boot/grub   # installkernel[grub] writes a grub.cfg here

section "World update (binary packages preferred)"
dr_emerge --oneshot sys-apps/portage
dr_emerge --update --deep --newuse @world
dr_emerge --oneshot sys-apps/sysvinit

section "Darkroot packages"
dr_emerge --noreplace darkroot-base/darkroot-shell
dr_emerge --update --newuse sys-fs/squashfs-tools   # the live squashfs is zstd
dr_emerge --noreplace app-admin/calamares net-misc/rsync sys-fs/lvm2 app-misc/jq
grep -q GenuineIntel /proc/cpuinfo && dr_emerge --noreplace sys-firmware/intel-microcode || true

section "Darkroot system"
dr_install_rootfs
dr_setup_runit
dr_branding
dr_install_inter_font
dr_install_macos_look
source "$DR_SRC/lib/grub-theme.sh"
dr_emerge --oneshot --noreplace media-gfx/imagemagick
dr_grub_theme
dr_spotify_perms
install -d /etc/darkroot
echo apple > /etc/darkroot/default-theme

section "Live session"
echo "darkroot-live" > /etc/hostname
printf 'hostname="darkroot-live"\n' > /etc/conf.d/hostname
printf 'tmpfs  /tmp  tmpfs  defaults,nosuid,nodev,mode=1777  0 0\n' > /etc/fstab
touch /etc/darkroot/live

# The build root is reused between builds: drop files that left the repo and
# give the live user a fresh home from /etc/skel every time.
rm -f /etc/skel/.config/hypr/hyprland.conf /etc/skel/.config/hypr/theme.conf \
      /usr/share/darkroot/themes/*/hypr-theme.conf
id darkroot &>/dev/null || useradd -m -s /bin/bash -c "Darkroot Live" -G users,wheel,audio,video,input darkroot
rm -rf /home/darkroot
install -d -m700 -o darkroot -g darkroot /home/darkroot
cp -a /etc/skel/. /home/darkroot/
chown -R darkroot:darkroot /home/darkroot
passwd -d darkroot >/dev/null
echo "darkroot ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-darkroot-live
chmod 440 /etc/sudoers.d/90-darkroot-live
cat > /etc/sddm.conf.d/20-darkroot-live.conf <<'EOF'
[Autologin]
User=darkroot
Session=darkroot-shell.desktop
Relogin=false
EOF

rm -rf /etc/calamares
install -d /etc/calamares
cp -a "$DR_SRC/calamares/." /etc/calamares/
install -d /usr/share/applications
cat > /usr/share/applications/darkroot-install.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Darkroot OS
Comment=Install Darkroot OS to this computer
Exec=darkroot-install
Icon=darkroot
Categories=System;
EOF

section "Live initramfs"
kver=$(ls /lib/modules | sort -V | tail -n1)
install -d /etc/dracut.conf.d
cat > /etc/dracut.conf.d/90-darkroot-live.conf <<'EOF'
add_dracutmodules+=" dmsquash-live "
omit_dracutmodules+=" plymouth "
hostonly="no"
compress="zstd"
EOF
dracut --force --no-hostonly "/boot/initramfs-live.img" "$kver"

section "Cleanup"
# drop build-only dependencies (rust, cmake, meson, ...) - they are not needed at runtime
emerge --depclean --with-bdeps=n --quiet || warn "depclean skipped"
rm -f /etc/machine-id /var/lib/dbus/machine-id
: > /etc/resolv.conf
rm -rf /var/cache/distfiles/* /var/tmp/portage/* /root/.bash_history
ok "live system done"

# shellcheck shell=bash
# Darkroot OS - Portage configuration shared by the ISO builder and the text installer.
# Expects: $DR_SRC (repo checkout inside the chroot), $VIDEO_CARDS, $GRUB_PLATFORMS

DR_PROFILE="default/linux/amd64/23.0/desktop"

dr_emerge() {
    emerge --quiet-build=y --getbinpkg --with-bdeps=y --jobs=2 \
           --load-average="$(nproc)" --autounmask=y --autounmask-continue=y "$@"
}

dr_portage_setup() {
    local n
    n=$(nproc)
    mkdir -p /etc/portage/{package.use,package.license,package.accept_keywords,package.env,env,repos.conf}

    sed -i '/^# ---- Darkroot OS ----/,$d' /etc/portage/make.conf
    cat >> /etc/portage/make.conf <<EOF
# ---- Darkroot OS ----
MAKEOPTS="-j${n} -l${n}"
FEATURES="\${FEATURES} getbinpkg binpkg-request-signature parallel-fetch"
USE="-systemd elogind dbus networkmanager pipewire pulseaudio dist-kernel X wayland gtk qt6 -kde"
ACCEPT_LICENSE="-* @FREE @BINARY-REDISTRIBUTABLE"
VIDEO_CARDS="${VIDEO_CARDS:-amdgpu radeonsi intel nouveau virgl vmware}"
INPUT_DEVICES="libinput"
GRUB_PLATFORMS="${GRUB_PLATFORMS:-efi-64 pc}"
L10N="en de"
EOF

    cat > /etc/portage/package.use/darkroot <<'EOF'
sys-kernel/installkernel dracut grub
media-video/pipewire sound-server
sys-boot/grub mount
gui-apps/waybar network pulseaudio tray wifi
app-admin/calamares -systemd
EOF
    cat > /etc/portage/package.license/darkroot <<'EOF'
app-editors/vscode Microsoft-vscode
media-sound/spotify Spotify
x11-drivers/nvidia-drivers NVIDIA-r2
darkroot-base/* metapackage
EOF
    cat > /etc/portage/package.accept_keywords/darkroot <<'EOF'
darkroot-base/*
app-editors/vscode
media-sound/spotify
app-admin/calamares
sys-libs/kpmcore
*/*::hyproverlay ~amd64
dev-cpp/sdbus-c++
dev-cpp/tomlplusplus
dev-libs/libliftoff
dev-libs/re2
gui-apps/hyprland-qtutils
dev-db/sqlmap
EOF

    # Darkroot replaces sysvinit's reboot/poweroff/... with runit-aware wrappers
    local m="" b
    for b in reboot halt poweroff shutdown; do m+="/sbin/$b /usr/sbin/$b /bin/$b /usr/bin/$b "; done
    printf 'INSTALL_MASK="%s"\n' "$m" > /etc/portage/env/darkroot-no-sysv-power.conf
    echo "sys-apps/sysvinit darkroot-no-sysv-power.conf" > /etc/portage/package.env/darkroot

    # Darkroot overlay ships inside the system (no sync)
    rm -rf /var/db/repos/darkroot
    cp -a "$DR_SRC/overlay" /var/db/repos/darkroot
    cat > /etc/portage/repos.conf/darkroot.conf <<'EOF'
[darkroot]
location = /var/db/repos/darkroot
auto-sync = no
priority = 100
EOF
}

dr_portage_sync() {
    if [[ ! -d /var/db/repos/gentoo/profiles ]]; then
        emerge-webrsync -q
    fi
    command -v getuto >/dev/null && getuto
    dr_emerge --noreplace --oneshot app-eselect/eselect-repository dev-vcs/git
    eselect repository list -i 2>/dev/null | grep -q hyproverlay || eselect repository enable hyproverlay
    emaint sync -r hyproverlay
    eselect profile set "$DR_PROFILE"
}

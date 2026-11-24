# Copyright 2026 Darkroot OS
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Darkroot OS base system: runit, networking, login manager and core apps"
HOMEPAGE="https://github.com/Real3rr0r303YT/Darkroot-OS"
S="${WORKDIR}"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="amd64 ~amd64"

RDEPEND="
	sys-process/runit
	app-admin/sysklogd
	sys-auth/elogind
	sys-apps/dbus
	net-misc/networkmanager
	net-misc/chrony
	app-admin/sudo
	app-eselect/eselect-repository
	dev-vcs/git
	net-misc/curl
	app-arch/unzip
	sys-fs/dosfstools
	sys-apps/pciutils
	app-misc/fastfetch
	sys-boot/grub
	sys-boot/efibootmgr
	sys-kernel/linux-firmware
	sys-kernel/gentoo-kernel-bin
	x11-base/xorg-server
	gui-apps/sddm
	media-video/pipewire
	media-video/wireplumber
	media-fonts/noto
	media-fonts/noto-emoji
	media-fonts/jetbrains-mono
	media-fonts/fontawesome
	x11-themes/adwaita-icon-theme
	www-client/firefox-bin
	app-editors/vscode
	media-sound/spotify
"

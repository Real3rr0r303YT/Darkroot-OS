# Copyright 2026 Darkroot OS
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Darkroot Shell: debloated Apple-style Hyprland desktop"
HOMEPAGE="https://github.com/Real3rr0r303YT/Darkroot-OS"
S="${WORKDIR}"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="amd64 ~amd64"

# Hyprland, hyprlock, hypridle and the portal come from ::hyproverlay
RDEPEND="
	darkroot-base/darkroot-base
	gui-wm/hyprland
	gui-apps/hyprlock
	gui-apps/hypridle
	gui-libs/xdg-desktop-portal-hyprland
	gui-apps/waybar
	gui-apps/wofi
	gui-apps/foot
	gui-apps/mako
	gui-apps/swaybg
	gui-apps/grim
	gui-apps/slurp
	gui-apps/wl-clipboard
	gnome-extra/nm-applet
	lxqt-base/lxqt-policykit
	xfce-base/thunar
	media-sound/pavucontrol
	media-gfx/imv
	media-sound/playerctl
	x11-libs/libnotify
"

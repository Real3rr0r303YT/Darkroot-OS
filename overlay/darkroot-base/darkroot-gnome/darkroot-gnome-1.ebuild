# Copyright 2026 Darkroot OS
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Darkroot GNOME: GNOME shell with Files, Terminal and Settings only"
HOMEPAGE="https://github.com/Real3rr0r303YT/Darkroot-OS"
S="${WORKDIR}"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="amd64 ~amd64"

RDEPEND="
	darkroot-base/darkroot-base
	gnome-base/gnome-light
	x11-terms/gnome-terminal
"

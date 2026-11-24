# Copyright 2026 Darkroot OS
# Distributed under the terms of the GNU General Public License v3

EAPI=8

DESCRIPTION="Darkroot Hacker Mode: curated security and pentesting toolkit"
HOMEPAGE="https://github.com/Real3rr0r303YT/Darkroot-OS"
S="${WORKDIR}"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="amd64 ~amd64"

RDEPEND="
	net-analyzer/nmap
	net-analyzer/wireshark
	net-analyzer/tcpdump
	net-analyzer/masscan
	net-analyzer/nikto
	net-analyzer/hydra
	net-analyzer/openbsd-netcat
	net-wireless/aircrack-ng
	app-crypt/johntheripper
	app-crypt/hashcat
	dev-db/sqlmap
	dev-util/radare2
	net-proxy/mitmproxy
	app-misc/binwalk
"

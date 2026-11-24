#!/bin/bash
# Darkroot OS - Hacker Mode: install the security toolkit and switch to the hacker look.
#   hacker.sh install   (called by Calamares or darkroot-hacker --install)
set -uo pipefail
LOG=/var/log/darkroot-hacker.log
exec >>"$LOG" 2>&1
echo "=== hacker mode ($(date)) ==="

[[ -d /var/db/repos/gentoo/profiles ]] || emerge-webrsync -q
emerge --quiet-build=y --getbinpkg --with-bdeps=y --jobs=2 --load-average="$(nproc)" \
       --autounmask=y --autounmask-continue=y --keep-going --noreplace \
       darkroot-base/darkroot-hacker-tools

# wireshark capture without root for members of the pcap group
for u in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do
    getent group pcap >/dev/null && usermod -aG pcap "$u"
done

# look & feel: hacker login screen + hacker theme as default for every user
sed -i 's/^Current=.*/Current=darkroot-hacker/' /etc/sddm.conf.d/10-darkroot.conf
install -d /etc/darkroot
echo hacker > /etc/darkroot/default-theme
if [[ -f /etc/dconf/db/local.d/00-darkroot ]]; then
    sed -i "s#darkroot-apple.png#darkroot-hacker.png#g; s#accent-color='purple'#accent-color='green'#" /etc/dconf/db/local.d/00-darkroot
    dconf update || true
fi
echo "=== hacker mode done ==="

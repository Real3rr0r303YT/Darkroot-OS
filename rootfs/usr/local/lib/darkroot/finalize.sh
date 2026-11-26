#!/bin/bash
# Darkroot OS - last step of an installation (runs inside the new system).
# Removes live-session bits, converts Calamares' systemd-style config files to
# Gentoo/runit locations and rebuilds the initramfs.
set -uo pipefail
LOG=/var/log/darkroot-finalize.log
exec >>"$LOG" 2>&1
echo "=== finalize ($(date)) ==="

# --- remove live session --------------------------------------------------
rm -f /etc/sudoers.d/90-darkroot-live \
      /etc/sddm.conf.d/20-darkroot-live.conf \
      /etc/dracut.conf.d/90-darkroot-live.conf \
      /etc/darkroot/live \
      /usr/share/applications/darkroot-install.desktop
rm -rf /etc/calamares

# --- locale / keyboard written by Calamares --------------------------------
if [[ -r /etc/locale.conf ]]; then
    lang=$(sed -n 's/^LANG=//p' /etc/locale.conf | tr -d '"')
    [[ -n $lang ]] && printf 'LANG="%s"\nLC_COLLATE="C.UTF-8"\n' "$lang" > /etc/env.d/02locale
fi
if [[ -r /etc/vconsole.conf ]]; then
    km=$(sed -n 's/^KEYMAP=//p' /etc/vconsole.conf | tr -d '"')
    [[ -n $km ]] && sed -i "s/^keymap=.*/keymap=\"$km\"/" /etc/conf.d/keymaps
fi
xkb=$(sed -n 's/.*"XkbLayout"[[:space:]]*"\([^"]*\)".*/\1/p' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | head -n1)
xkb=${xkb:-us}
for f in /etc/skel/.config/hypr/hyprland.lua /home/*/.config/hypr/hyprland.lua; do
    [[ -f $f ]] && sed -i "s/^\(\s*kb_layout\s*=\s*\)\"[^\"]*\"/\1\"$xkb\"/" "$f"
done
[[ -r /etc/hostname ]] && printf 'hostname="%s"\n' "$(cat /etc/hostname)" > /etc/conf.d/hostname
env-update >/dev/null 2>&1

# --- default theme for every user -------------------------------------------
theme=$(cat /etc/darkroot/default-theme 2>/dev/null || echo apple)
for h in /home/*; do
    [[ -d $h ]] || continue
    u=$(basename "$h")
    install -d -o "$u" -g "$u" "$h/.config/darkroot"
    echo "$theme" > "$h/.config/darkroot/theme"
    chown "$u:$u" "$h/.config/darkroot/theme"
done

# --- package repos were left out of the ISO to keep it small ---------------
if [[ ! -d /var/db/repos/hyproverlay/.git ]]; then
    timeout 600 emaint sync -r hyproverlay || echo "hyproverlay sync skipped (run: sudo emaint sync -a)"
fi

# --- initramfs for the installed system (without dmsquash-live) -----------
kver=$(ls /lib/modules | sort -V | tail -n1)
if [[ -n $kver ]]; then
    dracut --force --hostonly "/boot/initramfs-${kver}.img" "$kver" || dracut --force "/boot/initramfs-${kver}.img" "$kver"
fi
echo "=== finalize done ==="

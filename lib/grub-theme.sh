#!/usr/bin/env bash
# Darkroot OS - GRUB boot menu in the style of a Mac startup picker (no Apple artwork).
# Based on the "gentoo-rice-mac" theme from github.com/Real3rr0r303YT/Gentoo-rice.
# Also enables os-prober so Windows and other Linux systems show up (dual/triple boot).
#   dr_grub_theme            -> /usr/share/grub/themes/darkroot + /etc/default/grub
# Needs: ImageMagick (magick), grub-mkfont (sys-boot/grub USE=truetype), Inter font.

DR_GRUB_THEME_DIR=/usr/share/grub/themes/darkroot

# _dr_slice9 <color> <prefix> <radius> <dir> - rounded box as 9 pieces (GRUB pixmap style)
_dr_slice9() {
    local c=$1 p=$2 r=$3 d=$4 x y i=0 size names=(nw n ne w c e sw s se)
    size=$((r * 3))
    magick -size "${size}x${size}" xc:none -fill "$c" \
        -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" "PNG32:$d/$p-full.png"
    for y in 0 1 2; do
        for x in 0 1 2; do
            magick "$d/$p-full.png" -crop "${r}x${r}+$((x * r))+$((y * r))" +repage "PNG32:$d/${p}_${names[i]}.png"
            i=$((i + 1))
        done
    done
    rm -f "$d/$p-full.png"
}

# _dr_grub_kv <KEY> <VALUE> - set a key in /etc/default/grub (replace, also commented, or append)
_dr_grub_kv() {
    local f=/etc/default/grub
    touch "$f"
    if grep -qE "^#?\s*$1=" "$f"; then sed -i -E "s|^#?\s*$1=.*|$1=\"$2\"|" "$f"
    else printf '%s="%s"\n' "$1" "$2" >> "$f"; fi
}

dr_grub_theme() {
    local d=$DR_GRUB_THEME_DIR bg=/usr/share/backgrounds/darkroot/darkroot-apple.png fr fb sz
    if command -v magick >/dev/null; then
        rm -rf "$d"; install -d "$d"
        if [[ -s $bg ]]; then
            magick "$bg" -resize 1920x1080^ -gravity center -extent 1920x1080 \
                -resize 20% -blur 0x10 -resize 500% \
                \( -size 1920x1080 xc:"rgba(0,0,0,0.55)" \) -composite -alpha off "PNG24:$d/background.png"
        else
            magick -size 1920x1080 gradient:"#2c2c2e-#141416" "PNG24:$d/background.png"
        fi
        _dr_slice9 "rgba(28,28,30,0.88)"    menu      16 "$d"
        _dr_slice9 "rgba(255,255,255,0.07)" item      12 "$d"
        _dr_slice9 "rgba(255,255,255,0.24)" select    12 "$d"
        _dr_slice9 "rgba(255,255,255,0.20)" bar        3 "$d"
        _dr_slice9 "#ffffff"                highlight  3 "$d"

        fr=$(ls /usr/share/fonts/inter/Inter-Regular.ttf 2>/dev/null || fc-match -f '%{file}' 'Inter:style=Regular' 2>/dev/null || true)
        fb=$(ls /usr/share/fonts/inter/Inter-Bold.ttf 2>/dev/null || fc-match -f '%{file}' 'Inter:style=Bold' 2>/dev/null || true)
        [[ -n $fb ]] || fb=$fr
        if command -v grub-mkfont >/dev/null && [[ -n $fr ]]; then
            for sz in 14 16 18; do grub-mkfont -n Mac -s "$sz" -o "$d/mac-$sz.pf2" "$fr" || true; done
            for sz in 18 26; do grub-mkfont -n Mac -b -s "$sz" -o "$d/mac-bold-$sz.pf2" "$fb" || true; done
        else
            warn "grub-mkfont or Inter missing - GRUB uses its default font"
        fi
        cp "$DR_SRC/grub/darkroot/theme.txt" "$d/theme.txt"
        chmod -R a+rX "$d"
        _dr_grub_kv GRUB_THEME "$d/theme.txt"
        _dr_grub_kv GRUB_GFXMODE "1920x1080,1280x720,auto"
        _dr_grub_kv GRUB_GFXPAYLOAD_LINUX "keep"
        _dr_grub_kv GRUB_TERMINAL_OUTPUT "gfxterm"
        ok "GRUB theme: $d"
    else
        warn "ImageMagick missing - GRUB theme skipped"
    fi
    # dual/triple boot: list Windows and other Linux systems in the menu
    _dr_grub_kv GRUB_DISABLE_OS_PROBER "false"
    _dr_grub_kv GRUB_TIMEOUT "5"
    _dr_grub_kv GRUB_TIMEOUT_STYLE "menu"
    _dr_grub_kv GRUB_DISTRIBUTOR "Darkroot OS"
}

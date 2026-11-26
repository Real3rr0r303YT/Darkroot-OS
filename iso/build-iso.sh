#!/usr/bin/env bash
# =====================================================================
#  Darkroot OS - live ISO builder
#  Run as root on a Gentoo (or Darkroot) machine with ~40 GB free space:
#      sudo ./iso/build-iso.sh
#  Output: out/darkroot-<version>-x86_64.iso  (UEFI + BIOS hybrid)
# =====================================================================
set -Eeuo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/ui.sh
source "$SRC/lib/ui.sh"

VERSION=${VERSION:-$(date +%Y.%m)}
WORK=${WORK:-/var/tmp/darkroot-iso}
OUT=${OUT:-$SRC/out}
ROOT="$WORK/rootfs"
ISO="$WORK/iso"
LABEL="DARKROOT"
STAGE3_BASE=https://distfiles.gentoo.org/releases/amd64/autobuilds
STAGE3_FLAVOR=stage3-amd64-desktop-openrc

trap 'die "build failed at line $LINENO"' ERR
[[ $EUID -eq 0 ]] || die "run as root"

# squashfs_has COMPRESSOR -> true if mksquashfs can really use it
squashfs_has() {
    local t rc
    t=$(mktemp -d)
    mkdir "$t/in"; echo darkroot > "$t/in/f"
    mksquashfs "$t/in" "$t/test.sq" -comp "$1" -noappend >/dev/null 2>&1 && rc=0 || rc=1
    rm -rf "$t"
    return $rc
}

host_tools() {
    section "Host tools"
    local need=() t
    command -v mksquashfs  >/dev/null || need+=(sys-fs/squashfs-tools)
    command -v xorriso     >/dev/null || need+=(dev-libs/libisoburn)
    command -v mformat     >/dev/null || need+=(sys-fs/mtools)
    command -v grub-mkrescue >/dev/null || need+=(sys-boot/grub)
    if ((${#need[@]})); then
        command -v emerge >/dev/null || die "missing tools: ${need[*]}"
        emerge --getbinpkg --noreplace "${need[@]}"
    fi
    if ! squashfs_has zstd; then
        info "rebuilding squashfs-tools with zstd support"
        USE="zstd xz lzma lz4" emerge --oneshot sys-fs/squashfs-tools || warn "zstd not available, falling back"
    fi
    if [[ ! -d /usr/lib/grub/i386-pc || ! -d /usr/lib/grub/x86_64-efi ]]; then
        info "rebuilding GRUB for both BIOS and UEFI (hybrid ISO)"
        GRUB_PLATFORMS="efi-64 pc" emerge --getbinpkg --oneshot sys-boot/grub
    fi
    ok "host ready"
}

stage3() {
    section "Stage3"
    if [[ -x $ROOT/bin/bash && -z ${FRESH-} ]]; then
        ok "reusing $ROOT (set FRESH=1 to start over)"; return
    fi
    umount_all
    rm -rf "$ROOT"; mkdir -p "$ROOT"
    local txt path name expected actual
    txt=$(curl -fsSL "$STAGE3_BASE/latest-$STAGE3_FLAVOR.txt")
    path=$(grep -Eo "[0-9TZ]+/${STAGE3_FLAVOR}-[0-9TZ]+\.tar\.xz" <<<"$txt" | head -n1)
    name=${path##*/}
    curl -fL --retry 3 -o "$WORK/$name" "$STAGE3_BASE/$path"
    curl -fsSL -o "$WORK/$name.DIGESTS" "$STAGE3_BASE/$path.DIGESTS"
    expected=$(awk -v f="$name" '/SHA512 HASH/{h=1; next} /HASH/{h=0} h && $2==f {print $1; exit}' "$WORK/$name.DIGESTS")
    actual=$(sha512sum "$WORK/$name" | awk '{print $1}')
    [[ $expected == "$actual" ]] || die "stage3 checksum mismatch"
    tar xpf "$WORK/$name" --xattrs-include='*.*' --numeric-owner -C "$ROOT"
    rm -f "$WORK/$name" "$WORK/$name.DIGESTS"
    ok "$name"
}

mount_chroot() {
    cp --dereference /etc/resolv.conf "$ROOT/etc/"
    mountpoint -q "$ROOT/proc" || mount --types proc /proc "$ROOT/proc"
    mountpoint -q "$ROOT/sys"  || { mount --rbind /sys "$ROOT/sys"; mount --make-rslave "$ROOT/sys"; }
    mountpoint -q "$ROOT/dev"  || { mount --rbind /dev "$ROOT/dev"; mount --make-rslave "$ROOT/dev"; }
    mountpoint -q "$ROOT/run"  || { mount --bind /run "$ROOT/run"; mount --make-slave "$ROOT/run"; }
    mkdir -p "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles"
}

umount_all() {
    local m
    for m in run dev sys proc; do
        mountpoint -q "$ROOT/$m" 2>/dev/null && umount -R -l "$ROOT/$m"
    done
    return 0
}

build_rootfs() {
    section "Live system (chroot)"
    mount_chroot
    rm -rf "$ROOT/tmp/darkroot-src"
    mkdir -p "$ROOT/tmp/darkroot-src"
    cp -a "$SRC/." "$ROOT/tmp/darkroot-src/"
    rm -rf "$ROOT/tmp/darkroot-src/out" "$ROOT/tmp/darkroot-src/.git"
    chroot "$ROOT" /bin/bash /tmp/darkroot-src/iso/chroot-live.sh
    umount_all
    ok "live rootfs ready"
}

make_iso() {
    section "ISO image"
    rm -rf "$ISO"
    mkdir -p "$ISO/LiveOS" "$ISO/boot/grub" "$OUT"
    local kver
    kver=$(ls "$ROOT/lib/modules" | sort -V | tail -n1)
    cp "$ROOT/boot/vmlinuz-$kver" "$ISO/boot/vmlinuz"
    cp "$ROOT/boot/initramfs-live.img" "$ISO/boot/initramfs.img"
    sed "s/@VERSION@/$VERSION/g; s/@LABEL@/$LABEL/g" "$SRC/iso/grub.cfg" > "$ISO/boot/grub/grub.cfg"
    cp "$SRC/assets/logo-512.png" "$ISO/boot/grub/darkroot.png"

    local comp=(-comp gzip -Xcompression-level 9)
    if squashfs_has zstd; then comp=(-comp zstd -Xcompression-level 19)
    elif squashfs_has xz; then comp=(-comp xz)
    fi
    info "squashfs (${comp[1]}) ..."
    # Keep the mount point directories themselves (only drop their content):
    # without /proc, /sys, /dev and /run in the live root, dracut's
    # switch_root cannot move the API filesystems and detaches them instead.
    mksquashfs "$ROOT" "$ISO/LiveOS/squashfs.img" "${comp[@]}" -b 1M -noappend \
        -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'run/*' \
           'proc/.*' 'sys/.*' 'dev/.*' 'run/.*' tmp/darkroot-src \
           var/cache/binpkgs var/cache/distfiles var/cache/binhost var/tmp/portage \
           usr/share/doc usr/share/gtk-doc usr/src \
           var/db/repos/gentoo var/db/repos/hyproverlay \
           boot/initramfs-live.img

    local iso="$OUT/darkroot-$VERSION-x86_64.iso"
    grub-mkrescue -o "$iso" "$ISO" -- -volid "$LABEL"
    (cd "$OUT" && sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256")
    ok "$iso ($(du -h "$iso" | cut -f1))"

    # GitHub release assets are limited to 2 GiB: also provide split parts
    if (( $(stat -c %s "$iso") > 2000000000 )); then
        rm -f "$iso".part-*
        split -b 1900M -d -a 2 "$iso" "$iso.part-"
        ok "split for GitHub: $(cd "$OUT" && ls "$(basename "$iso")".part-* | tr '\n' ' ')"
        info "join with: cat $(basename "$iso").part-* > $(basename "$iso")"
    fi
}

main() {
    mkdir -p "$WORK"
    banner
    host_tools
    stage3
    build_rootfs
    make_iso
}
main "$@"

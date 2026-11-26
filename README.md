<p align="center">
  <img src="assets/logo.svg" width="128" alt="Darkroot OS logo">
</p>

<h1 align="center">Darkroot OS</h1>
<p align="center"><b>Gentoo power. Apple calm.</b><br>
A Gentoo-based Linux distribution with its own runit init, a Calamares installer,<br>
two debloated desktops and a Hacker Mode.</p>

<p align="center">
  <a href="https://real3rr0r303yt.github.io/Darkroot-OS/">Website</a> ·
  <a href="https://github.com/Real3rr0r303YT/Darkroot-OS/releases/latest">Download ISO</a> ·
  <a href="https://www.figma.com/design/MoCl76XVKbHAKoxHiNiZUb">Design (Figma)</a>
</p>

---

## Overview

| | |
|---|---|
| **Base** | Gentoo Linux (`23.0/desktop` profile, prebuilt packages from Gentoo's official binhost) |
| **Init** | **Darkroot runit**: its own stage 1/2/3 scripts, services in `/etc/sv`, the `dr-sv` tool |
| **Installer** | **Calamares** live ISO (UEFI + BIOS), plus a text installer |
| **Editions** | **Darkroot Shell** (Apple-style Hyprland) or **GNOME Minimal** |
| **Hacker Mode** | Optional security toolkit plus a green-on-black theme for login, desktop and terminal |
| **Login** | SDDM with custom themes: `darkroot-mac` and `darkroot-hacker` |
| **Network** | NetworkManager (`nm-applet` in the menu bar) |
| **Apps** | VS Code, Firefox, Spotify + Spicetify, Claude Code |

## Editions

### Darkroot Shell (Hyprland, Apple-style)
- A glassy menu bar at the top (Waybar), a centered dock at the bottom, blur, rounded corners and spring animations
- Debloated: Hyprland, Waybar, wofi, foot, mako, Thunar, and nothing more
- Switch between Apple and Hacker looks at any time with `darkroot-theme apple|hacker` or **SUPER+T**

| Keys | Action |
|---|---|
| `SUPER + Return` | Terminal (foot) |
| `SUPER + Space` | Search / app launcher (wofi) |
| `SUPER + Q` | Close window |
| `SUPER + E` / `B` / `C` | Files / Firefox / VS Code |
| `SUPER + 1…9` | Switch workspace (`+ SHIFT` moves the window) |
| `SUPER + F` / `V` | Fullscreen / float |
| `SUPER + L` | Lock screen |
| `SUPER + T` | Toggle Apple / Hacker theme |
| `SUPER + SHIFT + S` | Screenshot of an area to the clipboard |

### GNOME Minimal
`gnome-light` plus Terminal: only the shell, Files, Settings and Terminal. It comes with a dark theme, the Darkroot wallpaper and window buttons on the left.

### Hacker Mode
Tick it in Calamares, or run `darkroot-hacker --install` later. It installs:
`nmap` · `wireshark` · `tcpdump` · `masscan` · `nikto` · `hydra` · `netcat` · `aircrack-ng` · `john` · `hashcat` · `sqlmap` · `radare2` · `mitmproxy` · `binwalk`

`darkroot-hacker --extras` adds Metasploit, Burp Suite and gobuster from the Pentoo overlay.
Only use these tools on systems you own or are allowed to test.

## Install

### Download

Release **v2026.11** · [github.com/Real3rr0r303YT/Darkroot-OS/releases/latest](https://github.com/Real3rr0r303YT/Darkroot-OS/releases/latest)

GitHub limits release files to 2 GB, so the ISO (3.2 GB) ships in **two parts**.
Download `darkroot-2026.11-x86_64.iso.part-00`, `darkroot-2026.11-x86_64.iso.part-01`
and `darkroot-2026.11-x86_64.iso.sha256`, then join them:

Linux / macOS:
```sh
cat darkroot-2026.11-x86_64.iso.part-* > darkroot-2026.11-x86_64.iso
sha256sum -c darkroot-2026.11-x86_64.iso.sha256
```

Windows (cmd):
```bat
copy /b darkroot-2026.11-x86_64.iso.part-00 + darkroot-2026.11-x86_64.iso.part-01 darkroot-2026.11-x86_64.iso
certutil -hashfile darkroot-2026.11-x86_64.iso SHA256
```

SHA256: `8c831b8d292ff0c08f1cf694deb46b9d261824af211be21aa4acaa90543dbc87`

### Live ISO (recommended)
1. Download and join the ISO as described above.
2. Flash it with Ventoy, balenaEtcher or `dd`:
   ```sh
   sudo dd if=darkroot-2026.11-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
3. Boot it, try the Darkroot Shell, and click the **download icon** in the dock to start Calamares.

### Text installer
From any x86_64 live system (for example the Gentoo minimal ISO):
```sh
curl -fsSL https://github.com/Real3rr0r303YT/Darkroot-OS/archive/refs/heads/main.tar.gz | tar xz
cd Darkroot-OS-main && bash install.sh
```

### Dual boot / triple boot

Darkroot OS can live next to Windows and other Linux systems:

- In the installer, on **Partitions**, pick **Install alongside** (shrinks an existing partition),
  **Replace a partition**, or **Manual partitioning** for full control (e.g. Windows + another distro + Darkroot).
- Reuse the existing EFI system partition; do not format it.
- GRUB runs `os-prober`, so Windows and other Linux installs appear in the boot menu automatically.
  If one is missing after the first boot, run `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- The boot menu uses a Mac-style startup picker theme (based on the `gentoo-rice-mac` theme from
  [Gentoo-rice](https://github.com/Real3rr0r303YT/Gentoo-rice)), with a 5 second timeout.

## Darkroot runit

| Command | What it does |
|---|---|
| `dr-sv list` | List all services and their state |
| `sudo dr-sv enable bluetoothd` | Enable and start a service |
| `sudo dr-sv disable chronyd` | Stop and disable a service |
| `sudo dr-sv restart NetworkManager` | Restart a service |

To add your own service, create `/etc/sv/NAME/run` and then run `sudo dr-sv enable NAME`.
**Fallback:** in GRUB press `e` and replace `init=/sbin/runit-init` with `init=/sbin/openrc-init`.

## Build the ISO yourself

On a Gentoo or Darkroot machine with about 40 GB of free space:
```sh
git clone https://github.com/Real3rr0r303YT/Darkroot-OS.git && cd Darkroot-OS
sudo ./iso/build-iso.sh          # → out/darkroot-YYYY.MM-x86_64.iso
```

## Repository layout

```
install.sh, chroot-install.sh   text installer
iso/                            live ISO builder (stage3 → squashfs → grub-mkrescue)
calamares/                      Calamares settings, modules and branding
overlay/                        Portage overlay with darkroot-base/* meta packages
rootfs/                         files copied into the system: runit, services, SDDM themes,
                                Hyprland/Waybar configs, themes, darkroot-* tools
lib/                            shared shell libraries
docs/                           GitHub Pages website
assets/                         logo
```

## Website (GitHub Pages)
Go to **Settings → Pages → Build and deployment**, choose **Deploy from a branch**, select branch **main** and folder **/docs**, then save.
The site will be live at `https://real3rr0r303yt.github.io/Darkroot-OS/`.

## License
GPL-3.0. Darkroot OS is built on Gentoo Linux and is not affiliated with the Gentoo Foundation.

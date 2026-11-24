# 🖤 Darkroot Linux

**Gentoo, aber so einfach wie CachyOS.** Ein Installer, ein paar Fragen und am Ende steht ein fertiger Desktop.

| | |
|---|---|
| **Basis** | Gentoo Linux (Profil `23.0/desktop/plasma`, Binärpakete vom offiziellen Binhost) |
| **Init** | Darkroot-runit: eigene Stages 1/2/3 und Dienste in `/etc/sv` |
| **Desktop** | KDE Plasma im macOS-Look (WhiteSur, Menüleiste und Dock) |
| **Login** | SDDM mit eigenem Theme **Darkroot Mac** |
| **Netzwerk** | NetworkManager |
| **Apps** | VS Code, Spotify + Spicetify, Claude Code, Firefox, Konsole, Dolphin |
| **Kernel** | `gentoo-kernel-bin` + linux-firmware, GRUB (UEFI und BIOS) |

## Installation

1. Boote die [Gentoo Minimal ISO](https://www.gentoo.org/downloads/) (oder eine andere x86_64 Live-Distro).
2. Verbinde dich mit dem Internet (LAN geht automatisch, für WLAN `net-setup`).
3. Lade den Installer herunter und starte ihn:

```sh
curl -fsSL https://github.com/Real3rr0r303YT/Darkroot-OS/archive/refs/heads/main.tar.gz | tar xz
cd Darkroot-OS-main
bash install.sh
```

Der Installer fragt nach Festplatte, Benutzer, Sprache, Tastatur und Grafikkarte. Danach läuft er von allein durch, nur die Passwörter gibst du noch selbst ein.

> ⚠️ Die ausgewählte Festplatte wird **komplett gelöscht**.

Die meisten Pakete kommen als Binärpakete, trotzdem dauert die Installation je nach Rechner **1–3 Stunden**.

## Nach dem ersten Login

Beim ersten Login öffnet sich automatisch der Willkommens-Assistent. Er:

- installiert den macOS-Look (WhiteSur: Theme, Icons, Cursor, Dock-Layout)
- installiert **Claude Code** (`claude` im Terminal)
- lädt **Spicetify** herunter

Danach Spotify einmal öffnen, anmelden, schließen und anschließend ausführen:

```sh
darkroot-spicetify
```

## Darkroot-runit

| Befehl | Funktion |
|---|---|
| `dr-sv list` | alle Dienste und ihren Status anzeigen |
| `sudo dr-sv enable bluetoothd` | Dienst aktivieren |
| `sudo dr-sv disable chronyd` | Dienst deaktivieren |
| `sudo dr-sv restart NetworkManager` | Dienst neu starten |

Eigene Dienste: Ordner `/etc/sv/NAME/` mit einem ausführbaren `run`-Skript anlegen und anschließend `dr-sv enable NAME` ausführen.

**Fallback:** Falls runit einmal nicht startet, im GRUB-Menü `e` drücken und
`init=/sbin/runit-init` durch `init=/sbin/openrc-init` ersetzen.

## Projektstruktur

```
install.sh              Teil 1: Live-System (Partitionen, Stage3, chroot)
chroot-install.sh       Teil 2: im neuen System (Pakete, Kernel, Konfig)
lib/ui.sh               Farben, Fragen und Auswahlmenüs
runit/                  1, 2, 3, ctrlaltdel, Dienste (sv/), dr-sv
sddm-theme/darkroot-mac SDDM-Login im macOS-Stil (QML)
firstlogin/             Willkommens-Assistent + Spicetify-Helfer
```

## Lizenz

GPL-3.0

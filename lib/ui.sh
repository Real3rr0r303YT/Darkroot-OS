# shellcheck shell=bash
# Darkroot Linux – gemeinsame UI-Funktionen für den Installer

C_0=$'\e[0m'; C_B=$'\e[1m'; C_R=$'\e[31m'; C_G=$'\e[32m'
C_Y=$'\e[33m'; C_P=$'\e[35m'; C_C=$'\e[36m'; C_D=$'\e[2m'

banner() {
    clear 2>/dev/null || true
    printf '%s' "$C_P$C_B"
    cat <<'EOF'
   ____             _                     _
  |  _ \  __ _ _ __| | ___ __ ___   ___ | |_
  | | | |/ _` | '__| |/ / '__/ _ \ / _ \| __|
  | |_| | (_| | |  |   <| | | (_) | (_) | |_
  |____/ \__,_|_|  |_|\_\_|  \___/ \___/ \__|
EOF
    printf '%s           L I N U X   ·   powered by Gentoo%s\n\n' "$C_D" "$C_0"
}

section() { printf '\n%s%s━━ %s ━━%s\n' "$C_P" "$C_B" "$*" "$C_0"; }
info()    { printf '%s==>%s %s\n' "$C_C$C_B" "$C_0" "$*"; }
ok()      { printf '%s ✔ %s %s\n' "$C_G$C_B" "$C_0" "$*"; }
warn()    { printf '%s !  %s%s\n' "$C_Y$C_B" "$*" "$C_0" >&2; }
die()     { printf '%s ✘  %s%s\n' "$C_R$C_B" "$*" "$C_0" >&2; exit 1; }

# ask "Frage" "Standardwert"  -> gibt Antwort auf stdout aus
ask() {
    local prompt=$1 def=${2-} ans
    if [[ -n $def ]]; then
        read -rp "${C_C}?${C_0} ${prompt} ${C_D}[${def}]${C_0}: " ans
    else
        read -rp "${C_C}?${C_0} ${prompt}: " ans
    fi
    printf '%s' "${ans:-$def}"
}

# choose "Frage" option1 option2 ...  -> setzt REPLY_CHOICE / REPLY_INDEX
choose() {
    local prompt=$1; shift
    local i=1 n opt
    printf '%s?%s %s\n' "$C_C" "$C_0" "$prompt" >&2
    for opt in "$@"; do printf '   %s%2d)%s %s\n' "$C_P" "$i" "$C_0" "$opt" >&2; i=$((i + 1)); done
    while :; do
        read -rp "   Auswahl [1]: " n
        n=${n:-1}
        if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= $# )); then
            REPLY_INDEX=$((n - 1))
            REPLY_CHOICE=${!n}
            return 0
        fi
        warn "Bitte eine Zahl zwischen 1 und $# eingeben."
    done
}

confirm_yes() {
    local ans
    read -rp "${C_Y}${C_B}$1${C_0} (tippe ${C_B}JA${C_0}): " ans
    [[ $ans == JA ]]
}

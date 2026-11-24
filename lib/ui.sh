# shellcheck shell=bash
# Darkroot OS - shared UI helpers

C_0=$'\e[0m'; C_B=$'\e[1m'; C_R=$'\e[31m'; C_G=$'\e[32m'
C_Y=$'\e[33m'; C_P=$'\e[35m'; C_C=$'\e[36m'; C_D=$'\e[2m'

banner() {
    clear 2>/dev/null || true
    printf '%s' "$C_P$C_B"
    cat <<'EOF'
       __           __                  __
  ____/ /___ ______/ /__ _________  ____/ /_
 / __  / __ `/ ___/ //_// ___/ __ \/ __  __/
/ /_/ / /_/ / /  / ,<  / /  / /_/ / /_/ /_
\__,_/\__,_/_/  /_/|_|/_/   \____/\____\__/   OS
EOF
    printf '%s           Gentoo power. Apple calm.%s\n\n' "$C_D" "$C_0"
}

section() { printf '\n%s%s== %s ==%s\n' "$C_P" "$C_B" "$*" "$C_0"; }
info()    { printf '%s==>%s %s\n' "$C_C$C_B" "$C_0" "$*"; }
ok()      { printf '%s ok %s %s\n' "$C_G$C_B" "$C_0" "$*"; }
warn()    { printf '%s !  %s%s\n' "$C_Y$C_B" "$*" "$C_0" >&2; }
die()     { printf '%s !! %s%s\n' "$C_R$C_B" "$*" "$C_0" >&2; exit 1; }

# ask "Question" "default"  -> prints the answer on stdout
ask() {
    local prompt=$1 def=${2-} ans
    if [[ -n $def ]]; then
        read -rp "${C_C}?${C_0} ${prompt} ${C_D}[${def}]${C_0}: " ans
    else
        read -rp "${C_C}?${C_0} ${prompt}: " ans
    fi
    printf '%s' "${ans:-$def}"
}

# choose "Question" opt1 opt2 ...  -> sets REPLY_CHOICE / REPLY_INDEX
choose() {
    local prompt=$1; shift
    local i=1 n opt
    printf '%s?%s %s\n' "$C_C" "$C_0" "$prompt" >&2
    for opt in "$@"; do printf '   %s%2d)%s %s\n' "$C_P" "$i" "$C_0" "$opt" >&2; i=$((i + 1)); done
    while :; do
        read -rp "   Choice [1]: " n
        n=${n:-1}
        if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= $# )); then
            REPLY_INDEX=$((n - 1))
            REPLY_CHOICE=${!n}
            return 0
        fi
        warn "Please enter a number between 1 and $#."
    done
}

confirm_yes() {
    local ans
    read -rp "${C_Y}${C_B}$1${C_0} (type ${C_B}YES${C_0}): " ans
    [[ $ans == YES ]]
}

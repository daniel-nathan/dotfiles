#!/usr/bin/env bash
# scripts/backup.sh
# Backup dotfiles + configs + workdirs para Google Drive via restic+rclone.
# Compativel com Fedora e Ubuntu.
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuracao
# ---------------------------------------------------------------------------
REPO="${RESTIC_REPOSITORY:-rclone:gdrive:daniel-backup}"
PASSWORD="${RESTIC_PASSWORD:-}"  # Defina via variavel de ambiente ou prompt

# Paths para backup
BACKUP_PATHS=(
    # Dotfiles (chezmoi source)
    "$HOME/.local/share/chezmoi"

    # Configs de ferramentas (versoes versionadas pelo chezmoi)
    "$HOME/.config/opencode"
    "$HOME/.config/zed"
    "$HOME/.config/remmina"
    "$HOME/.config/glab-cli"
    "$HOME/.config/micro"
    "$HOME/.config/zed"

    # Git
    "$HOME/.gitconfig"
    "$HOME/.config/git"

    # Shell
    "$HOME/.zshrc"
    "$HOME/.zshenv"
    "$HOME/.p10k.zsh"
    "$HOME/.tmux.conf"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.npmrc"

    # Workdirs (excluindo .git, node_modules, vendor)
    "$HOME/work/junta"
    "$HOME/work/projetos"
    "$HOME/work/zanthus"
)

# Exclusoes (glob patterns)
EXCLUDES=(
    "*.git"
    "node_modules"
    "vendor"
    ".stfolder"
    ".stversions"
    "*.pyc"
    "__pycache__"
    "*.log"
    "*.tmp"
    "*.swp"
)

# Politica de retencao
RETAIN_DAILY=7
RETAIN_WEEKLY=4
RETAIN_MONTHLY=6

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m[BACKUP]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[ERR]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Verificacoes
# ---------------------------------------------------------------------------
check_deps() {
    local missing=()
    for cmd in restic rclone; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        fail "Dependencias faltando: ${missing[*]}. Instale com: dnf install restic rclone  (ou apt install restic rclone)"
    fi
}

check_repo() {
    if ! restic -r "$REPO" cat config &>/dev/null; then
        log "Inicializando repositorio restic..."
        if [ -z "$PASSWORD" ]; then
            restic -r "$REPO" init
        else
            echo "$PASSWORD" | restic -r "$REPO" init --password-file=-
        fi
        ok "Repositorio inicializado"
    fi
}

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
run_backup() {
    log "Iniciando backup para $REPO"

    # Montar exclusoes
    local exclude_args=()
    for exc in "${EXCLUDES[@]}"; do
        exclude_args+=(--exclude "$exc")
    done

    # Montar paths existentes
    local existing_paths=()
    for p in "${BACKUP_PATHS[@]}"; do
        if [ -e "$p" ]; then
            existing_paths+=("$p")
        else
            log "Path nao encontrado, ignorando: $p"
        fi
    done

    if [ ${#existing_paths[@]} -eq 0 ]; then
        fail "Nenhum path valido para backup"
    fi

    if [ -n "$PASSWORD" ]; then
        echo "$PASSWORD" | restic -r "$REPO" backup \
            "${exclude_args[@]}" \
            --password-file=- \
            "${existing_paths[@]}"
    else
        restic -r "$REPO" backup \
            "${exclude_args[@]}" \
            "${existing_paths[@]}"
    fi

    ok "Backup concluido"
}

# ---------------------------------------------------------------------------
# Limpeza (retention policy)
# ---------------------------------------------------------------------------
run_forget() {
    log "Aplicando politica de retencao..."

    local forget_args=(
        --keep-daily "$RETAIN_DAILY"
        --keep-weekly "$RETAIN_WEEKLY"
        --keep-monthly "$RETAIN_MONTHLY"
        --prune
    )

    if [ -n "$PASSWORD" ]; then
        echo "$PASSWORD" | restic -r "$REPO" forget \
            --password-file=- \
            "${forget_args[@]}"
    else
        restic -r "$REPO" forget "${forget_args[@]}"
    fi

    ok "Retencao aplicada: daily=$RETAIN_DAILY, weekly=$RETAIN_WEEKLY, monthly=$RETAIN_MONTHLY"
}

# ---------------------------------------------------------------------------
# Listar snapshots
# ---------------------------------------------------------------------------
list_snapshots() {
    log "Snapshots disponiveis:"
    if [ -n "$PASSWORD" ]; then
        echo "$PASSWORD" | restic -r "$REPO" snapshots --password-file=-
    else
        restic -r "$REPO" snapshots
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Uso: $(basename "$0") [comando]

Comandos:
  backup      Rodar backup + limpeza (padrao)
  snapshots   Listar snapshots
  init        Inicializar repositorio restic
  help        Mostrar esta ajuda

Variaveis de ambiente:
  RESTIC_REPOSITORY   Repositorio restic (default: rclone:gdrive:daniel-backup)
  RESTIC_PASSWORD     Senha de criptografia do repo (se nao definida, usa repo sem senha)

Exemplos:
  $(basename "$0")                    # Backup completo
  RESTIC_PASSWORD="minha-senha" $(basename "$0")  # Backup com criptografia
  $(basename "$0") snapshots          # Listar snapshots
EOF
}

main() {
    local cmd="${1:-backup}"

    case "$cmd" in
        backup)
            check_deps
            check_repo
            run_backup
            run_forget
            ;;
        snapshots)
            check_deps
            list_snapshots
            ;;
        init)
            check_deps
            check_repo
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            fail "Comando desconhecido: $cmd. Roda '$(basename "$0") help' para ajuda."
            ;;
    esac
}

main "$@"

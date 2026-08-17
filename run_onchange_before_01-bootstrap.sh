#!/usr/bin/env bash
# run_onchange_before_01-bootstrap.sh
# Instala ferramentas de desenvolvimento no Fedora (dnf) e Ubuntu (apt).
# Roda ANTES do chezmoi apply. Falhas sao reportadas ao final para correcao manual.
# Filosofia: apt/dnf primeiro, flatpak para GUIs, ZERO snaps.
set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
ERRORS=()
WARNINGS=()

log()  { printf '\033[1;34m[BOOT]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[ERR]\033[0m %s\n' "$*" >&2; ERRORS+=("$*"); }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; WARNINGS+=("$*"); }

run() {
    # Roda um comando; se falhar, registra e continua.
    if "$@"; then
        return 0
    else
        fail "Comando falhou: $* (exit $?)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 1. Detectar distro
# ---------------------------------------------------------------------------
detect_distro() {
    if command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
        DISTRO="fedora"
    elif command -v apt-get &>/dev/null; then
        PKG_MGR="apt-get"
        DISTRO="ubuntu"
    else
        fail "Distribuicao nao suportada (nem apt nem dnf encontrado)"
        exit 1
    fi
    log "Distribuicao detectada: $DISTRO ($PKG_MGR)"
}

pkg_update() {
    log "Atualizando repositorios do sistema..."
    if [ "$PKG_MGR" = "dnf" ]; then
        run sudo dnf makecache -q
    else
        run sudo apt-get update -qq
    fi
}

pkg_install() {
    # pkg_install <pacote_fedora> <pacote_ubuntu> [pacote_ubuntu_ppa...]
    local fedora_pkg="$1"
    local ubuntu_pkg="${2:-$1}"
    shift 2

    local pkg
    if [ "$DISTRO" = "fedora" ]; then
        pkg="$fedora_pkg"
    else
        pkg="$ubuntu_pkg"
    fi

    if [ "$PKG_MGR" = "dnf" ]; then
        run sudo dnf install -y -q "$pkg"
    else
        run sudo apt-get install -y -qq "$pkg"
    fi
}

# ---------------------------------------------------------------------------
# 2. Pacotes base do sistema
# ---------------------------------------------------------------------------
install_base() {
    log "=== Pacotes base ==="
    pkg_install "zsh"
    pkg_install "git"
    pkg_install "curl"
    pkg_install "wget"
    pkg_install "tmux"
    pkg_install "fzf"
    pkg_install "tree"
    pkg_install "bat" "bat"
    pkg_install "7zip" "p7zip-full"
    pkg_install "unzip"
    pkg_install "make"
    pkg_install "cmake"
    pkg_install "gcc" "build-essential"
    pkg_install "g++"
    pkg_install "ripgrep"
    pkg_install "jq"
    pkg_install "htop"
    pkg_install "podman"

    # bat e 'batcat' no Ubuntu
    if [ "$DISTRO" = "ubuntu" ] && command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        run sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi
}

# ---------------------------------------------------------------------------
# 3. Docker CE + Compose plugin
# ---------------------------------------------------------------------------
install_docker() {
    log "=== Docker CE ==="

    if [ "$DISTRO" = "fedora" ]; then
        run sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
        run sudo dnf install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        # Ubuntu
        run sudo install -m 0755 -d /etc/apt/keyrings
        run curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc
        run sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg /tmp/docker.asc
        rm -f /tmp/docker.asc
        local codename
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        run sudo apt-get update -qq
        run sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi

    # Habilitar e iniciar Docker
    run sudo systemctl enable --now docker.service docker.socket 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 4. Docker rootless mode
# ---------------------------------------------------------------------------
setup_docker_rootless() {
    log "=== Docker rootless ==="

    # Deps rootless
    if [ "$DISTRO" = "fedora" ]; then
        run sudo dnf install -y -q fuse-overlayfs slirp4netns uidmap
    else
        run sudo apt-get install -y -qq fuse-overlayfs slirp4netns uidmap
    fi

    # Configurar subordinate uid/gid
    local current_user
    current_user="$(whoami)"
    if ! grep -q "^${current_user}:" /etc/subuid 2>/dev/null; then
        echo "${current_user}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
    fi
    if ! grep -q "^${current_user}:" /etc/subgid 2>/dev/null; then
        echo "${current_user}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
    fi

    # Desabilitar daemon rootful se estiver rodando
    sudo systemctl disable --now docker.service docker.socket 2>/dev/null || true

    # Rodar setup rootless
    if command -v dockerd-rootless-setuptool.sh &>/dev/null; then
        run dockerd-rootless-setuptool.sh install
    else
        warn "dockerd-rootless-setuptool.sh nao encontrado. Instale docker-ce-rootless-extras ou configure manualmente."
    fi

    # Habilitar linger para rodar sem login
    run sudo loginctl enable-linger "$current_user"
}

# ---------------------------------------------------------------------------
# 5. VS Code
# ---------------------------------------------------------------------------
install_vscode() {
    log "=== VS Code ==="

    if [ "$DISTRO" = "fedora" ]; then
        run sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
        run sudo dnf install -y -q code
    else
        run wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
            | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        run sudo apt-get update -qq
        run sudo apt-get install -y -qq code
    fi
}

# ---------------------------------------------------------------------------
# 6. Tailscale
# ---------------------------------------------------------------------------
install_tailscale() {
    log "=== Tailscale ==="
    run curl -fsSL https://tailscale.com/install.sh | sh
}

# ---------------------------------------------------------------------------
# 7. PHP + Composer
# ---------------------------------------------------------------------------
install_php() {
    log "=== PHP ==="

    if [ "$DISTRO" = "ubuntu" ]; then
        # PPA ondrej/php para versoes recentes no Ubuntu
        run sudo add-apt-repository ppa:ondrej/php -y
        run sudo apt-get update -qq
        run sudo apt-get install -y -qq php-cli php-mbstring php-xml php-curl php-zip php-tokenizer
    else
        run sudo dnf install -y -q php-cli php-mbstring php-xml php-curl php-zip
    fi

    # Composer
    if ! command -v composer &>/dev/null; then
        log "Instalando Composer..."
        run curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    else
        ok "Composer ja instalado"
    fi
}

# ---------------------------------------------------------------------------
# 8. Remmina
# ---------------------------------------------------------------------------
install_remmina() {
    log "=== Remmina ==="
    pkg_install "remmina"
}

# ---------------------------------------------------------------------------
# 9. NVM + Node.js
# ---------------------------------------------------------------------------
install_node() {
    log "=== NVM + Node.js ==="

    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        log "Instalando NVM..."
        run curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi

    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

    if command -v nvm &>/dev/null; then
        nvm install 26
        nvm alias default 26
        ok "Node.js $(node --version) instalado via NVM"
    else
        warn "NVM nao carregou. Instale Node.js manualmente ou reinicie o shell."
    fi
}

# ---------------------------------------------------------------------------
# 10. Micro editor (binario direto - funciona em qualquer distro)
# ---------------------------------------------------------------------------
install_micro() {
    log "=== Micro editor ==="

    if command -v micro &>/dev/null; then
        ok "Micro ja instalado: $(micro --version 2>&1 | head -1)"
        return
    fi

    local ver="2.0.14"
    local arch
    arch="$(uname -m)"
    local url="https://github.com/zyedidia/micro/releases/download/v${ver}/micro-${ver}-linux64.tgz"

    log "Baixando micro v${ver}..."
    if run curl -fsSL "$url" | tar xz -C /tmp; then
        run sudo mv "/tmp/micro-${ver}/micro" /usr/local/bin/micro
        rm -rf "/tmp/micro-${ver}"
        ok "Micro v${ver} instalado em /usr/local/bin/micro"
    else
        warn "Falha ao baixar micro. Tente manualmente: $url"
    fi
}

# ---------------------------------------------------------------------------
# 11. OpenCode
# ---------------------------------------------------------------------------
install_opencode() {
    log "=== OpenCode ==="

    local bindir="$HOME/.opencode/bin"
    mkdir -p "$bindir"

    if [ -x "$bindir/opencode" ]; then
        ok "OpenCode ja instalado em $bindir"
        return
    fi

    if run curl -fsSL https://get.opencode.ai | sh; then
        ok "OpenCode instalado"
    else
        warn "Falha na instalacao do OpenCode. Instale manualmente."
    fi
}

# ---------------------------------------------------------------------------
# 12. Claude Code (npm global)
# ---------------------------------------------------------------------------
install_claude_code() {
    log "=== Claude Code ==="

    if ! command -v node &>/dev/null; then
        warn "Node.js nao encontrado. Instale Node primeiro para Claude Code."
        return
    fi

    if run npm install -g @anthropic-ai/claude-code; then
        ok "Claude Code instalado"
    else
        warn "Falha ao instalar Claude Code via npm."
    fi
}

# ---------------------------------------------------------------------------
# 13. Flatpaks (GUIs desktop)
# ---------------------------------------------------------------------------
install_flatpaks() {
    log "=== Flatpaks ==="

    if ! command -v flatpak &>/dev/null; then
        warn "Flatpak nao encontrado. Pulando instalacao de GUIs."
        return
    fi

    local apps=(
        com.bitwarden.desktop
        com.spotify.Client
        md.obsidian.Obsidian
        io.dbeaver.DBeaverCommunity
        org.filezillaproject.Filezilla
        io.github.peazip.PeaZip
        io.missioncenter.MissionCenter
        com.github.tchx84.Flatseal
        org.gnome.DejaDup
        com.rtosta.zapzap
        com.todoist.Todoist
        org.nmap.Zenmap
        org.kde.konsole
    )

    for app in "${apps[@]}"; do
        run flatpak install -y --noninteractive flathub "$app" 2>/dev/null || \
            warn "Falha ao instalar flatpak: $app"
    done
}

# ---------------------------------------------------------------------------
# 14. Nerd Fonts
# ---------------------------------------------------------------------------
install_nerd_fonts() {
    log "=== Nerd Fonts ==="

    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    local fonts=(
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.tar.xz"
    )

    for url in "${fonts[@]}"; do
        local name
        name="$(basename "$url" .tar.xz)"
        if ls "$font_dir"/*"$name"* &>/dev/null; then
            ok "Fonte $name ja instalada"
            continue
        fi
        log "Baixando $name..."
        if run curl -fsSL "$url" | tar xJ -C "$font_dir"; then
            ok "Fonte $name instalada"
        else
            warn "Falha ao baixar fonte: $name"
        fi
    done

    # Atualizar cache de fontes
    run fc-cache -f 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 15. Configurar zsh como shell padrao
# ---------------------------------------------------------------------------
setup_zsh() {
    log "=== Configurando zsh ==="

    local zsh_path
    zsh_path="$(command -v zsh)"

    if [ -n "$zsh_path" ]; then
        # Adicionar ao /etc/shells se nao estiver
        grep -q "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null

        if [ "$SHELL" != "$zsh_path" ]; then
            run chsh -s "$zsh_path"
            ok "Zsh configurado como shell padrao"
        else
            ok "Zsh ja e o shell padrao"
        fi
    else
        warn "Zsh nao encontrado no PATH."
    fi
}

# ---------------------------------------------------------------------------
# 16. Chezmoi
# ---------------------------------------------------------------------------
setup_chezmoi() {
    log "=== Chezmoi ==="

    if command -v chezmoi &>/dev/null; then
        ok "Chezmoi ja instalado: $(chezmoi --version)"
    else
        log "Instalando chezmoi..."
        run curl -fsSL get.chezmoi.io | sh
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "============================================"
    log "  Bootstrap — daniel-nathan/dotfiles"
    log "  $(date '+%Y-%m-%d %H:%M:%S')"
    log "============================================"

    detect_distro
    pkg_update
    install_base
    install_docker
    setup_docker_rootless
    install_vscode
    install_tailscale
    install_php
    install_remmina
    install_node
    install_micro
    install_opencode
    install_claude_code
    install_flatpaks
    install_nerd_fonts
    setup_zsh
    setup_chezmoi

    # ---------------------------------------------------------------------------
    # Relatorio final
    # ---------------------------------------------------------------------------
    echo ""
    log "============================================"
    log "  RELATORIO FINAL"
    log "============================================"

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        printf '\033[1;33mWARNINGS (%d):\033[0m\n' "${#WARNINGS[@]}"
        for w in "${WARNINGS[@]}"; do
            printf '  ⚠  %s\n' "$w"
        done
    fi

    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo ""
        printf '\033[1;31mERROS (%d — correcao manual necessaria):\033[0m\n' "${#ERRORS[@]}"
        for e in "${ERRORS[@]}"; do
            printf '  ✗  %s\n' "$e"
        done
        echo ""
        log "Alguns pacotes falharam. Verifique os erros acima e instale manualmente."
        log "O chezmoi apply continuou normalmente para os dotfiles."
    else
        echo ""
        ok "Todas as instalacoes concluidas com sucesso!"
    fi

    echo ""
    log "Proximo passo: abra um novo terminal ou rode 'source ~/.zshenv'"
    log "============================================"
}

main "$@"

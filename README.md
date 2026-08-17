# dotfiles

Ambiente de desenvolvimento gerenciado com [chezmoi](https://www.chezmoi.io). Stack:
zsh4humans (z4h) + Powerlevel10k + plugins do Oh My Zsh carregados sob demanda.
Compativel com **Fedora** e **Ubuntu**, sem snaps (apt/dnf + flatpak).

## Arquivos gerenciados

### Shell

| Arquivo local     | Fonte neste repo   | Descricao |
|--------------------|---------------------|-----------|
| `~/.zshenv`        | `dot_zshenv`        | Bootstrap do zsh4humans |
| `~/.zshrc`         | `dot_zshrc`         | Config interativa: z4h, plugins, PATH, aliases |
| `~/.p10k.zsh`      | `dot_p10k.zsh`      | Tema Powerlevel10k enxuto |
| `~/.tmux.conf`     | `dot_tmux.conf`     | tmux: prefix C-a, vi mode, 100k history |
| `~/.bashrc`        | `dot_bashrc`        | Fallback bash (stock) |
| `~/.bash_profile`  | `dot_bash_profile`  | Fallback bash (stock) |

### Git

| Arquivo local     | Fonte neste repo   | Descricao |
|--------------------|---------------------|-----------|
| `~/.gitconfig`     | `dot_gitconfig`     | Editor, libsecret, autoSetupRemote |
| `~/.config/git/ignore` | `dot_config/git/ignore` | Global gitignore |

### Ferramentas

| Arquivo local     | Fonte neste repo   | Descricao |
|--------------------|---------------------|-----------|
| `~/.npmrc`         | `dot_npmrc`         | Allow-scripts para claude-code |
| `~/.config/opencode/opencode.jsonc` | `dot_config/opencode/opencode.jsonc` | Config opencode |
| `~/.config/opencode/package.json` | `dot_config/opencode/package.json` | Plugin opencode |
| `~/.config/micro/bindings.json` | `dot_config/micro/bindings.json` | Micro editor (defaults) |
| `~/.config/zed/settings.json` | `dot_config/zed/settings.json` | Zed editor |
| `~/.config/glab-cli/aliases.yml` | `dot_config/glab-cli/aliases.yml` | GitLab CLI aliases |

### Desktop

| Arquivo local     | Fonte neste repo   | Descricao |
|--------------------|---------------------|-----------|
| `~/.config/remmina/remmina.pref` | `dot_config/remmina/remmina.pref` | Preferencias Remmina (sem secret) |
| `~/.config/autostart/remmina-applet.desktop` | `dot_config/autostart/remmina-applet.desktop` | Autostart |
| `~/.config/Code/User/settings.json` | `dot_config/Code/User/settings.json.tmpl` | VS Code (template por DE) |

### Scripts

| Arquivo local     | Fonte neste repo   | Descricao |
|--------------------|---------------------|-----------|
| `~/scripts/backup.sh` | `scripts/backup.sh` | Wrapper restic+rclone |

### O que NAO e gerenciado

| Arquivo | Razao |
|---|---|
| `~/.env.zsh` | Segredos (proxy com senha) |
| `~/.git-credentials` | Tokens GitLab plaintext |
| `~/.ssh/*` | Configs e chaves especificas por maquina |
| `~/.codex/auth.json` | Tokens OpenAI |
| `~/.claude.json`, `~/.claude/.credentials.json` | Credenciais Claude Code |
| `~/.config/glab-cli/config.yml` | Tokens GitLab OAuth |
| `~/.config/rclone/rclone.conf` | Token Google Drive OAuth |
| `~/.config/Claude/` | Dados Claude Desktop |
| `~/work/` | Repositorios de trabalho (Syncthing) |

## Uso do dia a dia

```
chezmoi edit ~/.zshrc     # ou: dotcd para abrir a source dir num editor/subshell
chezmoi diff              # ve o que mudou antes de aplicar
chezmoi apply -v          # aplica as mudancas no $HOME
chezmoi cd                # entra na source dir (git normal: add/commit/push)
chezmoi update            # git pull + apply (traz mudancas de outra maquina)
```

Aliases prontos no `.zshrc`: `dot`, `dotd` (diff), `dota` (apply), `dotcd`.

Comandos do z4h: `z4h update` (atualiza framework e plugins — tambem roda sozinho a
cada 14 dias, em background, sem travar o shell), `z4h help` (lista de subcomandos).

**Cuidado com `p10k configure`**: ele reescreve `~/.p10k.zsh` inteiro com o template
padrao gigante, sobrescrevendo o tema enxuto daqui (ja aconteceu uma vez). Se rodar por
curiosidade, depois faca `chezmoi diff` e `chezmoi apply` para restaurar a versao
gerenciada.

## Bootstrap em uma maquina nova

### Instalacao completa (Fedora ou Ubuntu)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply daniel-nathan/dotfiles
```

Isso:
1. Instala o chezmoi (se necessario)
2. Clona este repo
3. Roda `run_onchange_before_01-bootstrap.sh` (instala todas as ferramentas)
4. Aplica os dotfiles no `$HOME`

O script bootstrap detecta a distro automaticamente (Fedora/Ubuntu) e instala:

**Pacotes do sistema** (apt/dnf):
- zsh, git, curl, wget, tmux, fzf, tree, bat, ripgrep, jq, htop
- PHP 8.x + Composer
- Docker CE + Compose plugin + rootless mode
- Podman (alternativa rootless ao Docker)
- VS Code (repo oficial Microsoft)
- Tailscale
- Remmina
- GCC, G++, Make, CMake

**Flatpaks** (GUIs desktop):
- Bitwarden, Spotify, Obsidian, DBeaver, FileZilla
- PeaZip, Mission Center, Flatseal, DejaDup
- ZapZap, Todoist, Zenmap, Konsole

**Manuais**:
- NVM + Node.js 26
- Micro editor (binario GitHub)
- OpenCode (binario)
- Claude Code (npm global)
- Nerd Fonts (JetBrains Mono, Hack)

### Sincronizar uma sessao SSH pontual

`.zshrc` desliga `zstyle ':z4h:ssh:*' enable` (era `yes`, ligado para qualquer host).
Por padrao `ssh` funciona normal, sem nenhum comportamento especial. Quando quiser a
sincronizacao do z4h nessa conexao especifica (control master/multiplexing, agent
forwarding e, se configurado, envio de dotfiles) use o alias `zssh` em vez de `ssh`:

```
zssh usuario@host
```

## Container engines: Docker rootless vs Podman

| Aspecto | Docker CE Rootless | Podman |
|---|---|---|
| Daemon | Sim (user-scoped) | Nao (sem daemon) |
| Raiz padrao | Rootless (via setup) | Rootless (por padrao) |
| Compatibilidade compose | Nativo | `podman compose` |
| Systemd integration | Limitada | Nativa (`podman generate systemd`) |
| Kubernetes/pods | Nao | Pods nativos |
| Dockerfile | Sim | Sim (mesmo syntax) |
| Socket Docker API | `$XDG_RUNTIME_DIR/docker.sock` | `podman system service` |
| Seguranca | Melhor que rootful | Melhor que Docker rootless |

Ambos sao instalados pelo bootstrap. Docker rootless e configurado via
`dockerd-rootless-setuptool.sh`. Podman funciona rootless por padrao.

## Backup

Script `scripts/backup.sh` usa **Restic + Rclone** para backup criptografado e
deduplicado no Google Drive:

```sh
# Backup completo
scripts/backup.sh

# Com criptografia
RESTIC_PASSWORD="minha-senha" scripts/backup.sh

# Listar snapshots
scripts/backup.sh snapshots

# Inicializar repo
scripts/backup.sh init
```

O que e backupado:
- Dotfiles (chezmoi source)
- Configs de ferramentas (opencode, zed, remmina, glab, micro)
- Shell configs (.zshrc, .gitconfig, etc.)
- Workdirs (junta, projetos, zanthus — excluindo .git, node_modules, vendor)

O que NAO e backupado (reinstalado via bootstrap):
- Pacotes do sistema
- Flatpaks
- Tokens/segredos (gerenciados via ferramenta nativa)

## Plugins ativos

`git`, `docker`, `docker-compose`, `sudo`, `extract`, `colored-man-pages`,
`command-not-found` (via Oh My Zsh, carregados pelo z4h). FZF, autosuggestions e
syntax-highlighting vem nativos do z4h — nao precisam de plugin separado.

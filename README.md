# dotfiles

Ambiente zsh gerenciado com [chezmoi](https://www.chezmoi.io). Stack: zsh4humans (z4h)
+ Powerlevel10k + plugins do Oh My Zsh carregados sob demanda pelo z4h (sem clonar o
framework inteiro).

## Arquivos gerenciados

| Arquivo local     | Fonte neste repo   |
|--------------------|---------------------|
| `~/.zshenv`        | `dot_zshenv`        |
| `~/.zshrc`         | `dot_zshrc`         |
| `~/.p10k.zsh`      | `dot_p10k.zsh`       |
| `~/.tmux.conf`     | `dot_tmux.conf`      |

`~/.env.zsh` (segredos/tokens/ajustes exclusivos da maquina) **nao** e gerenciado por
aqui de proposito e nao deve ir para o git.

## Uso do dia a dia

```
chezmoi edit ~/.zshrc     # ou: dotcd para abrir a source dir num editor/subshell
chezmoi diff              # ve o que mudou antes de aplicar
chezmoi apply -v          # aplica as mudancas no $HOME
chezmoi cd                # entra na source dir (git normal: add/commit/push)
chezmoi update             # git pull + apply (traz mudancas de outra maquina)
```

Aliases prontos no `.zshrc`: `dot`, `dotd` (diff), `dota` (apply), `dotcd`.

Comandos do z4h: `z4h update` (atualiza framework e plugins — tambem roda sozinho a
cada 14 dias, em background, sem travar o shell), `z4h help` (lista de subcomandos).

**Cuidado com `p10k configure`**: ele reescreve `~/.p10k.zsh` inteiro com o template
padrao gigante, sobrescrevendo o tema enxuto daqui (ja aconteceu uma vez). Se rodar por
curiosidade, depois faça `chezmoi diff` e `chezmoi apply` para restaurar a versao
gerenciada.

## Bootstrap em uma maquina nova (ex.: desktop Fedora 44 KDE)

Instalar o ambiente inteiro (zsh, tema, plugins, aliases) numa maquina nova e sempre
uma acao explicita, rodada uma vez por maquina — nunca automatica:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Danielnatham/dotfiles
```

Isso instala o chezmoi (se preciso), clona este repo e aplica os dotfiles. Na primeira
vez que abrir o zsh, o `.zshenv` baixa o zsh4humans sozinho. O ambiente nao depende de
distro/DE especifico (testado com GNOME+ptyxis; deve funcionar igual em KDE).

## Sincronizar uma sessao SSH pontual (sem instalar nada permanente)

`.zshrc` desliga `zstyle ':z4h:ssh:*' enable` (era `yes`, ligado para qualquer host).
Por padrao `ssh` funciona normal, sem nenhum comportamento especial. Quando quiser a
sincronizacao do z4h nessa conexao especifica (control master/multiplexing, agent
forwarding e, se configurado, envio de dotfiles) use o alias `zssh` em vez de `ssh`:

```
zssh usuario@host
```

Isso liga o zstyle so para aquele host, so para aquela chamada — nenhuma outra conexao
e afetada e nada fica ligado permanentemente. Pra deixar sempre ligado num host
especifico (ex.: um bastion que voce usa toda hora), adicione no `.zshrc`:

```
zstyle ':z4h:ssh:meu-bastion.exemplo.com' enable 'yes'
```

## Plugins ativos

`git`, `docker`, `docker-compose`, `sudo`, `extract`, `colored-man-pages`,
`command-not-found` (via Oh My Zsh, carregados pelo z4h). FZF, autosuggestions e
syntax-highlighting vem nativos do z4h — nao precisam de plugin separado.

Candidatos para adicionar sob demanda (nao inclusos para manter o startup rapido):

- `kubectl`, `terraform`, `aws`: prefira as completions nativas de cada CLI quando
  estiver instalada, em vez do plugin do Oh My Zsh.
- `direnv`: ambientes por projeto — ative o zstyle em `.zshrc` so depois de instalar e
  auditar os `.envrc` que for usar.
- `zsh-you-should-use`: ensina aliases, mas adiciona overhead a cada comando digitado.

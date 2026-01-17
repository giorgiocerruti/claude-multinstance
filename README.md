# Claude Multi-Instance

Uno script bash per eseguire istanze multiple di Claude CLI in worktree Git separati, organizzati in una finestra tmux 2x2.

## Funzionalità

- Crea 4 worktree Git temporanei dal progetto corrente
- Avvia una finestra tmux con layout 2x2
- Lancia Claude CLI in ogni pane automaticamente
- Cleanup automatico dei worktree e branch temporanei
- UI migliorata con [gum](https://github.com/charmbracelet/gum) (opzionale)

## Requisiti

- **tmux** (devi essere in una sessione tmux attiva)
- **git**
- **claude** CLI
- **gum** (opzionale, per UI migliore)

## Installazione

### Manuale

```bash
chmod +x claude-multi.sh
./claude-multi.sh --install
```

Questo installa lo script in `~/.local/bin/claude-multi`.

### Installazione gum (opzionale)

```bash
# macOS/Linux
brew install gum

# Arch
pacman -S gum

# Debian/Ubuntu (dopo setup repo)
apt install gum
```

## Uso

```bash
# Usa la directory corrente (deve essere un repo git)
claude-multi

# Specifica un progetto
claude-multi ./mio-progetto

# Cleanup worktree e branch temporanei
claude-multi --cleanup
claude-multi -c ./progetto
```

## Opzioni

| Opzione | Descrizione |
|---------|-------------|
| (nessuna) | Usa la directory corrente |
| `<path>` | Usa il progetto specificato |
| `--cleanup`, `-c` | Rimuove worktree e branch temporanei |
| `--install` | Installa lo script globalmente |
| `--uninstall` | Rimuove lo script globale |
| `--help`, `-h` | Mostra l'help |
| `--version`, `-v` | Mostra la versione |

## Come funziona

1. Lo script crea una directory `.worktrees/` nel progetto
2. Genera 4 worktree Git (`wt-1`, `wt-2`, `wt-3`, `wt-4`) con branch temporanei
3. Apre una nuova finestra tmux con layout 2x2
4. Avvia `claude` in ogni pane

Ogni worktree è una copia indipendente del repository, permettendo a ogni istanza di Claude di lavorare su modifiche separate senza conflitti.

## Cleanup

Per rimuovere i worktree e branch temporanei:

```bash
claude-multi --cleanup
```

Questo rimuove:
- I worktree in `.worktrees/`
- I branch `claude-wt-*` creati dallo script

## Licenza

MIT

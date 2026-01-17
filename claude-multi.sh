#!/bin/bash
set -e

# === Configurazione ===
WORKTREE_DIR=".worktrees"
NUM_PANES=4
VERSION="1.0.0"

# === Colori (fallback se gum non disponibile) ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# === Utility ===

# Verifica se gum è installato
has_gum() {
    command -v gum &>/dev/null
}

# Verifica se fzf è installato
has_fzf() {
    command -v fzf &>/dev/null
}

# Mostra messaggio di errore
error() {
    if has_gum; then
        gum style --foreground 196 "✖ Errore: $1"
    else
        echo -e "${RED}✖ Errore: $1${NC}" >&2
    fi
    exit 1
}

# Mostra messaggio di successo
success() {
    if has_gum; then
        gum style --foreground 46 "✔ $1"
    else
        echo -e "${GREEN}✔ $1${NC}"
    fi
}

# Mostra messaggio informativo
info() {
    if has_gum; then
        gum style --foreground 33 "ℹ $1"
    else
        echo -e "${BLUE}ℹ $1${NC}"
    fi
}

# Mostra warning
warn() {
    if has_gum; then
        gum style --foreground 214 "⚠ $1"
    else
        echo -e "${YELLOW}⚠ $1${NC}"
    fi
}

# Titolo stilizzato
title() {
    if has_gum; then
        gum style \
            --border double \
            --border-foreground 212 \
            --padding "0 2" \
            --margin "1 0" \
            --bold \
            "$1"
    else
        echo ""
        echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════${NC}"
        echo -e "${MAGENTA}${BOLD}  $1${NC}"
        echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════${NC}"
        echo ""
    fi
}

# Spinner per operazioni lunghe
spin() {
    local message="$1"
    shift
    if has_gum; then
        gum spin --spinner dot --title "$message" -- "$@"
    else
        echo -e "${CYAN}⏳ $message${NC}"
        "$@"
    fi
}

# Conferma utente
confirm() {
    local message="$1"
    if has_gum; then
        gum confirm "$message"
    else
        read -p "$message [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# === Funzioni Principali ===

# Mostra help
show_help() {
    if has_gum; then
        gum style \
            --border rounded \
            --border-foreground 99 \
            --padding "1 2" \
            --margin "1" \
            "$(cat << 'EOF'
🎭 CLAUDE-MULTI

Crea istanze multiple di Claude in worktree Git separati,
organizzati in una finestra tmux 2x2.

USO:
  claude-multi [opzioni] [progetto]

OPZIONI:
  (nessuna)              Usa la directory corrente
  <path>                 Usa il progetto specificato
  --cleanup, -c          Rimuove worktree e branch temporanei
  --install              Installa lo script globalmente
  --uninstall            Rimuove lo script globale
  --help, -h             Mostra questo messaggio
  --version, -v          Mostra la versione

ESEMPI:
  claude-multi                    # Usa directory corrente
  claude-multi ./mio-progetto     # Specifica progetto
  claude-multi --cleanup          # Cleanup directory corrente
  claude-multi -c ./progetto      # Cleanup progetto specifico

REQUISITI:
  • tmux (devi essere in una sessione tmux)
  • git
  • claude CLI
  • gum (opzionale, per UI migliore)

INSTALLAZIONE GUM:
  brew install gum                # macOS/Linux
  pacman -S gum                   # Arch
  apt install gum                 # Debian/Ubuntu (dopo setup repo)
EOF
)"
    else
        cat << 'EOF'

🎭 CLAUDE-MULTI
═══════════════════════════════════════════════════════════

Crea istanze multiple di Claude in worktree Git separati,
organizzati in una finestra tmux 2x2.

USO:
  claude-multi [opzioni] [progetto]

OPZIONI:
  (nessuna)              Usa la directory corrente
  <path>                 Usa il progetto specificato
  --cleanup, -c          Rimuove worktree e branch temporanei
  --install              Installa lo script globalmente
  --uninstall            Rimuove lo script globale
  --help, -h             Mostra questo messaggio
  --version, -v          Mostra la versione

ESEMPI:
  claude-multi                    # Usa directory corrente
  claude-multi ./mio-progetto     # Specifica progetto
  claude-multi --cleanup          # Cleanup directory corrente
  claude-multi -c ./progetto      # Cleanup progetto specifico

REQUISITI:
  • tmux (devi essere in una sessione tmux)
  • git
  • claude CLI
  • gum (opzionale, per UI migliore)

INSTALLAZIONE GUM:
  brew install gum                # macOS/Linux
  pacman -S gum                   # Arch
  apt install gum                 # Debian/Ubuntu (dopo setup repo)

═══════════════════════════════════════════════════════════
EOF
    fi
}

# Mostra versione
show_version() {
    if has_gum; then
        gum style --foreground 212 "claude-multi v$VERSION"
    else
        echo -e "${MAGENTA}claude-multi v$VERSION${NC}"
    fi
}

# Selezione interattiva del progetto
select_project() {
    local dirs=()

    # Trova directory che sono repo git
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir/.git" ]] || git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
            dirs+=("$(basename "$dir")")
        fi
    done < <(find . -maxdepth 1 -type d ! -name "." -print0 2>/dev/null)

    [[ ${#dirs[@]} -eq 0 ]] && error "Nessun repository git trovato nella directory corrente"

    if has_gum; then
        gum choose --header "📁 Seleziona un progetto:" "${dirs[@]}"
    elif has_fzf; then
        printf '%s\n' "${dirs[@]}" | fzf --prompt="Seleziona progetto: "
    else
        echo "Seleziona un progetto:" >&2
        select project in "${dirs[@]}"; do
            [[ -n "$project" ]] && echo "$project" && break
        done
    fi
}

# Verifica che sia un repo git valido
validate_git_repo() {
    local project="$1"

    [[ -d "$project" ]] || error "Directory '$project' non trovata"

    if ! git -C "$project" rev-parse --git-dir &>/dev/null 2>&1; then
        error "'$project' non è un repository git valido"
    fi
}

# Crea 4 worktree in .worktrees/
create_worktrees() {
    local project="$1"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local worktree_base="$project/$WORKTREE_DIR"

    title "🌳 Creazione Worktree"

    # Crea directory base se non esiste
    mkdir -p "$worktree_base"

    info "Directory: $worktree_base"
    echo ""

    for i in $(seq 1 $NUM_PANES); do
        local wt_path="$worktree_base/wt-$i"
        local branch_name="claude-wt-$i-$timestamp"

        if [[ -d "$wt_path" ]]; then
            warn "Worktree wt-$i già esiste, salto"
            continue
        fi

        if has_gum; then
            gum spin --spinner dot --title "Creo worktree wt-$i..." -- \
                git -C "$project" worktree add -b "$branch_name" "$WORKTREE_DIR/wt-$i" HEAD
            success "Worktree wt-$i creato (branch: $branch_name)"
        else
            echo -e "${CYAN}⏳ Creo worktree wt-$i...${NC}"
            git -C "$project" worktree add -b "$branch_name" "$WORKTREE_DIR/wt-$i" HEAD
            success "Worktree wt-$i creato"
        fi
    done

    echo ""
    success "Tutti i worktree sono pronti!"
}

# Apre finestra tmux + 4 pane + claude
setup_tmux() {
    local project="$1"
    local project_name
    project_name=$(basename "$(realpath "$project")")
    local window_name="claude-$project_name"
    local worktree_base
    worktree_base=$(realpath "$project/$WORKTREE_DIR")

    title "🖥️  Setup Tmux"

    # Verifica che tmux sia in esecuzione
    if [[ -z "$TMUX" ]]; then
        error "Devi essere all'interno di una sessione tmux"
    fi

    info "Creo finestra '$window_name' con 4 pane..."
    echo ""

    # Crea nuova finestra con primo pane
    local wt1="$worktree_base/wt-1"
    tmux new-window -n "$window_name" -c "$wt1"

    # Split per creare layout 2x2
    tmux split-window -h -c "$worktree_base/wt-2"
    tmux select-pane -t 0
    tmux split-window -v -c "$worktree_base/wt-3"
    tmux select-pane -t 2
    tmux split-window -v -c "$worktree_base/wt-4"

    # Avvia claude in ogni pane
    for i in $(seq 0 3); do
        tmux send-keys -t "$window_name.$i" "claude" Enter
    done

    # Seleziona il primo pane
    tmux select-pane -t 0

    echo ""
    success "Finestra tmux pronta!"

    if has_gum; then
        gum style \
            --border rounded \
            --border-foreground 46 \
            --padding "0 1" \
            --margin "1 0" \
            "🎉 4 istanze Claude avviate in $window_name"
    else
        echo ""
        echo -e "${GREEN}${BOLD}🎉 4 istanze Claude avviate in $window_name${NC}"
    fi
}

# Rimuove worktree e branch temporanei
cleanup_worktrees() {
    local project="$1"

    validate_git_repo "$project"

    local worktree_base="$project/$WORKTREE_DIR"

    title "🧹 Cleanup Worktree"

    if [[ ! -d "$worktree_base" ]]; then
        warn "Nessun worktree trovato in $worktree_base"
        return 0
    fi

    info "Directory: $worktree_base"
    echo ""

    # Chiedi conferma
    if ! confirm "Vuoi rimuovere tutti i worktree e branch temporanei?"; then
        info "Operazione annullata"
        return 0
    fi

    echo ""

    # Lista e rimuovi ogni worktree
    for i in $(seq 1 $NUM_PANES); do
        local wt_path="$worktree_base/wt-$i"

        if [[ -d "$wt_path" ]]; then
            # Trova il nome del branch associato
            local branch_name
            branch_name=$(git -C "$project" worktree list --porcelain | grep -A2 "worktree.*wt-$i$" | grep "branch" | sed 's|branch refs/heads/||' || true)

            if has_gum; then
                gum spin --spinner dot --title "Rimuovo worktree wt-$i..." -- \
                    bash -c "git -C '$project' worktree remove --force '$WORKTREE_DIR/wt-$i' 2>/dev/null || rm -rf '$wt_path'"
            else
                echo -e "${CYAN}⏳ Rimuovo worktree wt-$i...${NC}"
                git -C "$project" worktree remove --force "$WORKTREE_DIR/wt-$i" 2>/dev/null || rm -rf "$wt_path"
            fi

            success "Worktree wt-$i rimosso"

            # Elimina il branch temporaneo
            if [[ -n "$branch_name" && "$branch_name" == claude-wt-* ]]; then
                git -C "$project" branch -D "$branch_name" 2>/dev/null || true
                info "  Branch $branch_name eliminato"
            fi
        fi
    done

    # Rimuovi directory base se vuota
    rmdir "$worktree_base" 2>/dev/null || true

    # Pulizia worktree orfani
    git -C "$project" worktree prune

    echo ""
    success "Cleanup completato!"
}

# Installa lo script globalmente
install_global() {
    title "📦 Installazione Globale"

    local install_dir="$HOME/.local/bin"
    local script_path="$install_dir/claude-multi"

    # Crea directory se non esiste
    mkdir -p "$install_dir"

    # Copia script
    local source_script
    source_script="$(realpath "$0")"

    if has_gum; then
        gum spin --spinner dot --title "Installo in $install_dir..." -- \
            cp "$source_script" "$script_path"
    else
        cp "$source_script" "$script_path"
    fi

    chmod +x "$script_path"

    success "Script installato in $script_path"
    echo ""

    # Verifica PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        warn "$install_dir non è nel PATH"
        echo ""
        info "Aggiungi questa riga al tuo ~/.bashrc o ~/.zshrc:"
        echo ""
        if has_gum; then
            gum style --foreground 226 'export PATH="$HOME/.local/bin:$PATH"'
        else
            echo -e "${YELLOW}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        fi
        echo ""
        info "Poi esegui: source ~/.bashrc (o ~/.zshrc)"
    else
        success "Puoi ora usare 'claude-multi' da qualsiasi directory!"
    fi
}

# Disinstalla lo script
uninstall_global() {
    title "🗑️  Disinstallazione"

    local script_path="$HOME/.local/bin/claude-multi"

    if [[ ! -f "$script_path" ]]; then
        warn "Script non trovato in $script_path"
        return 0
    fi

    if confirm "Vuoi rimuovere claude-multi da $script_path?"; then
        rm -f "$script_path"
        success "Script rimosso!"
    else
        info "Operazione annullata"
    fi
}

# === Main ===

main() {
    local project=""
    local action="run"

    # Parse argomenti
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --cleanup|-c)
                action="cleanup"
                shift
                ;;
            --install)
                install_global
                exit 0
                ;;
            --uninstall)
                uninstall_global
                exit 0
                ;;
            -*)
                error "Opzione sconosciuta: $1\nUsa --help per vedere le opzioni disponibili"
                ;;
            *)
                project="$1"
                shift
                ;;
        esac
        shift 2>/dev/null || true
    done

    # Default: usa directory corrente
    if [[ -z "$project" ]]; then
        project="."
    fi

    # Esegui azione
    case "$action" in
        cleanup)
            cleanup_worktrees "$project"
            ;;
        run)
            title "🎭 Claude Multi-Instance"
            validate_git_repo "$project"
            create_worktrees "$project"
            setup_tmux "$project"
            ;;
    esac
}

main "$@"

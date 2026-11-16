# ============================================================
# .zshrc - Interactive Shell Configuration
# Executed for every new terminal session, after .zshenv (and
# .zprofile in login shells). Contains aliases, functions,
# completions, and interactive shell settings.
# ============================================================

# ============================================================
# SHELL BEHAVIOR
# Core zsh settings and completion system
# ============================================================

# Suppress insecure directory warnings for completion
export ZSH_DISABLE_COMPFIX=true

# Homebrew share dir for zsh plugins (sourced below). HOMEBREW_PREFIX is
# exported by brew shellenv in .zshenv (Apple Silicon: /opt/homebrew).
ZSH_PLUGIN_DIR="${HOMEBREW_PREFIX:-/opt/homebrew}/share"

# Completion system. fzf-tab replaces zsh's default completion menu with an
# fzf picker, so initialize compinit and disable the built-in menu.
# (zsh-autocomplete was tried but dropped: its real-time popup wouldn't render
# in this terminal; fzf-tab gives a reliable fuzzy menu on Tab instead.)
autoload -U compinit && compinit -u
zstyle ':completion:*' menu no                                  # let fzf-tab take over
[ -n "$LS_COLORS" ] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:*' switch-group ',' '.'                        # , / . switch completion groups
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always $realpath'

# fzf-tab: fuzzy Tab completion. Must load AFTER compinit and BEFORE
# autosuggestions / the highlighter (both sourced at the end of this file).
[ -r "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.zsh" ] && \
  source "$ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.zsh"

# ============================================================
# TOOL INITIALIZATION
# Load and configure external tools (order matters)
# ============================================================

# fzf - Fuzzy finder
# Provides Ctrl+T (file search) and Alt+C (cd to dir); Ctrl+R belongs to atuin below
eval "$(fzf --zsh)"

# zoxide - Smart directory jumper
# Tracks visited directories and enables fuzzy jumping with `z <partial-name>`
# Example: `z proj` jumps to ~/code/projects if you've been there before
eval "$(zoxide init zsh)"

# atuin - searchable shell history database
# Takes over Ctrl+R (must load after fzf); fzf keeps Ctrl+T and Alt+C
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# ============================================================
# SHARED ALIASES & FUNCTIONS
# Loaded from ~/.aliases (managed via `stow aliases`)
# ============================================================
[ -f ~/.aliases ] && . ~/.aliases

# ============================================================
# PROMPT & STARTUP
# Visual customization and session initialization
# ============================================================

# Starship - cross-shell prompt with git integration, language versions, etc.
# Configuration in ~/.config/starship.toml
eval "$(starship init zsh)"

# Fastfetch - display system info once per boot (temp file lock)
if [[ ! -f /tmp/fastfetch-done ]] && command -v fastfetch >/dev/null; then
  touch /tmp/fastfetch-done
  fastfetch
fi

# ============================================================
# ZSH PLUGINS (load last, after compinit/fzf-tab and all widgets)
# autosuggestions first, then the highlighter last.
# ============================================================
[ -r "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -r "$ZSH_PLUGIN_DIR/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ] && \
  source "$ZSH_PLUGIN_DIR/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

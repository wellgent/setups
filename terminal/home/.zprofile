# ============================================================
# .zprofile - Login Shell Configuration
# Executed once when logging in, after .zshenv and before .zshrc.
# Re-asserts PATH and sources the host's login env. EDITOR and
# locale live in .zshenv so non-login shells get them too.
# ============================================================

# ------------------------------------------------------------
# PATH Re-assert
# macOS path_helper (/etc/zprofile) runs between .zshenv and
# .zprofile and rebuilds PATH with system dirs first - put user
# dirs back in front (typeset -U in .zshenv dedupes). Harmless on
# Linux (no path_helper); brew prefix auto-detected either way.
# ------------------------------------------------------------
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi
path=("$HOME/.local/bin" $path "$HOME/.bun/bin")

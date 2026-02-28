# fzf
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

# nvm (interactive)
[ -n "$NVM_DIR" ] && [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Extra completions (optional)
[ -f "/home/ifq/.zsh/completion/_zkstack.zsh" ] && source "/home/ifq/.zsh/completion/_zkstack.zsh"
[ -f "/home/ifq/.openclaw/completions/openclaw.zsh" ] && source "/home/ifq/.openclaw/completions/openclaw.zsh"

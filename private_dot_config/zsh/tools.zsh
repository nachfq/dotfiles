# fzf
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

# nvm (interactive)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" # Extra completions (optional)

[ -f "/home/$USER/.zsh/completion/_zkstack.zsh" ] && source "/home/$USER/.zsh/completion/_zkstack.zsh"
[ -f "/home/$USER/.openclaw/completions/openclaw.zsh" ] && source "/home/$USER/.openclaw/completions/openclaw.zsh"

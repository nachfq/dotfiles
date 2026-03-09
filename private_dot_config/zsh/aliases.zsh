### Alias
alias ealias="nvim ~/.config/zsh/aliases.zsh && source ~/.config/zsh/aliases.zsh"
alias ralias="cat ~/.config/zsh/aliases.zsh"

### Envs
alias eenv="nvim ~/.zshenv && source ~/.zshenv"

### Program Configs

alias ealacritty="nvim ~/.config/alacritty/alacritty.toml"
alias ezshrc="nvim ~/.zshrc && source ~/.zshrc"
alias envim="cd ~/.config/nvim && nvim"

## ls colors
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'

### Programs
alias docker-compose="docker compose"
alias python=python3
alias nv=nvim

### Utils
alias cpy="xclip -sel clip"

### Shortcuts

alias fcat='f(){ 
  fd -HI -tf --follow . "${1:-.}" --print0 \
  | xargs -0 -r -I{} sh -c '\''printf "\n========== %s ==========\n" "$1"; cat "$1"'\'' _ {}; 
}; f'

alias cheats='fcat ~/.config/cheatsheets'

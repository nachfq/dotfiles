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

### OpenClaw
alias oc_ssh_tunnel="ssh -L 18789:127.0.0.1:18789 nacho@192.168.1.46"
alias oc_rdp="xfreerdp /v:192.168.1.46:3389 /u:nacho"

### Utils
alias cpy="xclip -sel clip"


### Projects
BASE_IFQ_REPOS="/media/ifq/storage-linux/ifq/repos"
BASE_COB_REPOS="/media/ifq/storage-linux/cobuilders.xyz/repos"
alias stampr="cd $BASE_IFQ_REPOS/stampr"
alias hhs="cd $BASE_COB_REPOS/hardhat-plugin-research/hardhat-arbitrum-stylus"

### Shortcuts
alias fcat='f(){ fd -HI -tf --follow --print0 "$1" "${2:-.}" | xargs -0 -r -I{} sh -c '\''printf "\n========== %s ==========\n" "$1"; cat "$1"'\'' _ {}; }; f'

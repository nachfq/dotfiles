# Prompt (green dir + cream $)
if [[ -n "$SSH_CONNECTION" ]]; then
  PROMPT='%F{240}%m%f %F{green}[%1~]%f%F{229}$%f  '
else
  PROMPT='%F{green}[%1~]%f%F{229}$%f  '
fi

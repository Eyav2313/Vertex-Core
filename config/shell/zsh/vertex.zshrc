# VertexOS zsh profile.

export EDITOR="${EDITOR:-nvim}"
export PAGER="${PAGER:-less}"
export LESS="-R"
export PATH="$HOME/.local/bin:$PATH"

setopt prompt_subst
setopt autocd
setopt extended_glob
setopt hist_ignore_all_dups
setopt share_history
setopt inc_append_history

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000

autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{cyan}git:%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{yellow}git:%b|%a%f'

precmd() {
    vcs_info
}

vertex_exit_status() {
    local code="$?"
    if [ "$code" -ne 0 ]; then
        printf "%%F{red}x%s%%f " "$code"
    fi
}

vertex_venv() {
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        printf "%%F{green}(%s)%%f " "${VIRTUAL_ENV:t}"
    fi
}

PROMPT='$(vertex_exit_status)$(vertex_venv)%F{cyan}%n%f@%F{blue}%m%f %F{white}%~%f${vcs_info_msg_0_}
%F{green}vertex%f %# '

alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias cls='clear'
alias ports='ss -tulpn'
alias update='sudo apt update && sudo apt full-upgrade'

if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first'
    alias ll='eza -lah --group-directories-first --git'
fi

if command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --paging=never'
elif command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi

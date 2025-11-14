[ -f ~/.fzf.bash ] && source ~/.fzf.bash
eval "$(starship init bash)"

alias ll="eza --icons=always -lFx --group-directories-first"
alias ls="eza --icons=always -x --group-directories-first"
alias ed="setsid kwrite >/dev/null 2>&1"
alias cat='f(){ for f in "$@"; do file --mime-type "$f" | grep -q "image/" && chafa "$f" || command cat "$f"; done; }; f'
alias clbin="curl -F 'clbin=<-' https://clbin.com/"
alias sudo="sudo -S"

center() {
    cols=$(tput cols)

    # regex usuwający sekwencje ANSI
    strip_ansi='s/\x1B\[[0-9;]*[A-Za-z]//g'

    while IFS= read -r line; do
        clean=$(printf "%s" "$line" | sed -E "$strip_ansi")
        pad=$(( (cols - ${#clean}) / 2 ))
        printf "%*s%s\n" "$pad" "" "$line"
    done
}

chafa --format=symbols --symbols=block+half+hhalf+quad+sextant+vhalf --scale=max AYBABTU.png 2>/dev/null && echo "" && toilet --metal --termwidth -f smblock "ALL YOUR BASE ARE BELONG TO US" | center

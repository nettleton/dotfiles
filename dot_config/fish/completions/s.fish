# Complete `s <name>` as if typing `cd $SANDBOX/<name>`
function __s_complete_sandbox
    set -l token (commandline -ct)
    complete -C "cd $SANDBOX/$token" | string replace -- "$SANDBOX/" ''
end

complete -c s -f
# first arg: directories under $SANDBOX (or `n` for the network sandbox)
complete -c s -n '__fish_is_nth_token 1' -a '(__s_complete_sandbox)'
complete -c s -n '__fish_is_nth_token 1' -a n -d 'network sandbox'
# second arg: `n` for the network sandbox
complete -c s -n '__fish_is_nth_token 2' -a n -d 'network sandbox'

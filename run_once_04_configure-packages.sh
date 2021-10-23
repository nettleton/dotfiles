#!/usr/local/bin/fish

mkdir -p $HOME/sandbox/go/bin
set -x -U GOPATH $HOME/sandbox/go
echo $fish_user_paths | grep -q "$GOPATH"; or set -U fish_user_paths $fish_user_paths "$GOPATH/bin"
go get -u github.com/jstemmer/gotags

npm install -g vmd tern uuid js-beautify eslint http-server serverless remark remark-cli remark-stringify remark-frontmatter wcwidth prettier javascript-typescript-langserver bash-language-server yarn dockerfile-language-server-nodejs typescript webpack neovim npm-check-updates

set pylatest (pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*\$" | tail -1)
pyenv install "$pylatest"
pyenv global "$pylatest"

set -Ux PYENV_ROOT $HOME/.pyenv
echo $fish_user_paths | grep -q "$PYENV_ROOT/bin"; or set -U fish_user_paths $fish_user_paths "$PYENV_ROOT/bin"

set pipbin "$HOME/.local/bin"
mkdir -p "$pipbin"
echo $fish_user_paths | grep -q "$pipbin"; or set -U fish_user_paths $fish_user_paths "$pipbin"

pip3 install --user --upgrade neovim-remote

podman machine init
podman machine start

ln -sfn (which podman) /usr/local/bin/docker

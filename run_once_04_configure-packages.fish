#!/usr/bin/env fish
mkdir -p "$HOME/.cache"
touch "$HOME/.cache/locatedb"

mkdir -p "$HOME/sandbox/go/bin"
set -x -U GOPATH "$HOME/sandbox/go"
echo $fish_user_paths | grep -q "$GOPATH"; or set -U fish_user_paths $fish_user_paths "$GOPATH/bin"

go install github.com/rhysd/vim-startuptime@latest

npm outdated -g neovim; or npm install -g neovim

set pylatest (pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*\$" | tail -1 | string trim)
pyenv install "$pylatest"
pyenv global "$pylatest"

set -Ux PYENV_ROOT $HOME/.pyenv
set -Ux PYENV_VERSION "$pylatest"
echo $fish_user_paths | grep -q "$PYENV_ROOT/bin"; or set -U fish_user_paths $fish_user_paths "$PYENV_ROOT/bin"

set pipbin "$HOME/.local/bin"
mkdir -p "$pipbin"
echo $fish_user_paths | grep -q "$pipbin"; or set -U fish_user_paths $fish_user_paths "$pipbin"

pip3 install --user --upgrade neovim neovim-remote pynvim

set sysPy3bin "$HOME/Library/Python/3.9/bin"
echo $fish_user_paths | grep -q "$sysPy3bin"; or set -U fish_user_paths $fish_user_paths "$sysPy3bin"

if test (podman machine list --noheading | wc -l) -eq 1
  echo "podman machine installed; not reinstalling"
else
  podman machine init
  podman machine start
end

gh auth login

echo "execute 'loaddb' in a new shell"
echo "execute ':GoInstallBinaries in nvim"

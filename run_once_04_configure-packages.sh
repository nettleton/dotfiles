#!/usr/bin/env fish

mkdir -p $HOME/sandbox/go/bin
set -x -U GOPATH $HOME/sandbox/go
echo $fish_user_paths | grep -q "$GOPATH"; or set -U fish_user_paths $fish_user_paths "$GOPATH/bin"

npm install -g tern uuid js-beautify eslint http-server remark remark-cli remark-stringify remark-frontmatter wcwidth prettier javascript-typescript-langserver bash-language-server dockerfile-language-server-nodejs typescript webpack neovim npm-check-updates

set pylatest (pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*\$" | tail -1 | string trim)
pyenv install "$pylatest"
pyenv global "$pylatest"

set -Ux PYENV_ROOT $HOME/.pyenv
set -Ux PYENV_VERSION "$pylatest"
echo $fish_user_paths | grep -q "$PYENV_ROOT/bin"; or set -U fish_user_paths $fish_user_paths "$PYENV_ROOT/bin"

set pipbin "$HOME/.local/bin"
mkdir -p "$pipbin"
echo $fish_user_paths | grep -q "$pipbin"; or set -U fish_user_paths $fish_user_paths "$pipbin"

pip3 install --user --upgrade neovim-remote pynvim

set sysPy3bin "$HOME/Library/Python/3.9/bin"
echo $fish_user_paths | grep -q "$sysPy3bin"; or set -U fish_user_paths $fish_user_paths "$sysPy3bin"

if test (podman machine list --noheading | wc -l) -eq 1
  echo "podman machine installed; not reinstalling"
else
  podman machine init
  podman machine start
end

echo "execute :CocInstall coc-snippets in neovim"

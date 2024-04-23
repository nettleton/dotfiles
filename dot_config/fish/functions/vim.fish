#!/usr/bin/env fish

function vim
  set activeTabTitle (kitty @ --to unix:/tmp/kitty ls | jq -r '.[] | select(.is_active == true) | .tabs[] | select(.is_active == true) | .title')

  set fullPathToFile "$PWD/$argv"
  if string match -rq '^/.*' (dirname "$argv")
    set fullPathToFile "$argv"
  end

  switch $activeTabTitle
    case scratch
      nvim --server /tmp/scratch_editor --remote-silent "$fullPathToFile"
      kitty @ --to unix:/tmp/kitty focus-window --match 'title:scratch'
    case notes
      nvim --server /tmp/notes_spacevim_nvim_server --remote-silent "$fullPathToFile"
      kitty @ --to unix:/tmp/kitty focus-window --match 'title:notes'
    case '*'
      echo "$argv[1]" | grep -iq 'Documents/Notes' ; and nvim --listen /tmp/notes_spacevim_nvim_server "$fullPathToFile" ; or nvim "$fullPathToFile"
  end
end

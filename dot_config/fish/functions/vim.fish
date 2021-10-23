#!/usr/bin/env fish

function vim
  echo "$argv[1]" | grep -iq 'Documents/Notes' ; and nvr -s --servername /tmp/notes_spacevim_nvim_server $argv ; or nvr $argv 
end

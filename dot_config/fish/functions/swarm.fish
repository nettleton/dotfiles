function swarm -a 'FILE_NAME' -d 'generate swarm link'
  set ff (realpath $FILE_NAME)
  set ffa (string split / "$ff")
  # TODO: not everything is under //team/wit or in apps
  set endpath (string join / $ffa[8..-1])
  set link "https://swarm.***REMOVED***/files/team/wit/apps/$ffa[7]/$ffa[6]/$endpath"
  echo "$link"
end

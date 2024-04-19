function wmcp -d "Copy files from work machine to local"
  scp "$WORK_USER@$WORK_MAC_STUDIO:$argv[1]" "$argv[2]"
end

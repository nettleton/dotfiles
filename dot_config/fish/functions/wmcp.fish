function wmcp -a SRC,DEST -d "Copy files from work machine to local"
  scp "$WORK_USER@$WORK_MAC:$SRC" "$DEST"
end

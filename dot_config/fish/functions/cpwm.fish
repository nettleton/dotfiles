function cpwm -a SRC,DEST -d "Copy files from local to work machine"
  scp "$SRC" "$WORK_USER@$WORK_MAC:$DEST"
end

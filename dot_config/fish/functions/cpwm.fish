function cpwm -d "Copy files from local to work machine"
  scp "$argv[1]" "$WORK_USER@$WORK_MAC_STUDIO:$argv[2]"
end

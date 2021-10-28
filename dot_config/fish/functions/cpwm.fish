function cpwm -d "Copy files from local to work machine"
  scp "$argv[1]" "$WORK_USER@$WORK_MAC:$argv[2]"
end

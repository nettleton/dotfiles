function s -a 'SB_NAME' -a 'SB_LOCATION' -d 'go to sandbox (use n for the network sandbox'
  set DEST "$SANDBOX"
  # set unspecified variables to empty string
  if test -z $SB_NAME
    set SB_NAME ""
  end
  if test -z $SB_LOCATION
    set SB_LOCATION ""
  end
  # Check for network sandboxes
  if test \( $SB_NAME = "n" \) -o \( $SB_LOCATION = "n" \)
    set DEST "$NETWORK_SANDBOX"
  end
  # append sandbox name if it was provided
  if test -n $SB_NAME
    set DEST "$DEST/$SB_NAME"
  end
  # cd to sandbox
  if test -d "$DEST"
    cd "$DEST"
  end
  if test -d "main"
    cd main
  end
end

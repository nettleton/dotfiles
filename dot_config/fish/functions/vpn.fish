function vpn
  switch $argv[1]
    case status
      /opt/cisco/anyconnect/bin/vpn state | grep -q "state: connected" ; and echo "connected"; or echo "disconnected"
    case connect
      op get item ***REMOVED*** --fields username > /dev/null ; or set -Ux OP_SESSION_$OP_ACCOUNT (op signin $OP_ACCOUNT --raw)
      if test $status -gt 0
        printf "Unable to connect.  Did you enter the correct password?"
      else
        printf %s\n%s\ny $WORK_USER (op get item ***REMOVED*** --fields password) | /opt/cisco/anyconnect/bin/vpn -s connect zakim2.***REMOVED***
      end
    case disconnect
      /opt/cisco/anyconnect/bin/vpn disconnect
    case '*' 
      echo "Unrecognized option $argv[1]"
  end
end

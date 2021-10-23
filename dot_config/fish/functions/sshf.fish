function sshf
  ssh -t -p 22 -i $argv[1] $argv[2]@$argv[3] 'exec fish'
end

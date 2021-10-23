function moshf
  mosh --ssh="ssh -i $argv[1]" $argv[2]@$argv[3] -- 'fish'
end

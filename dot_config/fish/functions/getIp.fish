function getIp -a HOST -d 'Get IP for host'
  dig $HOST +nocomments +noquestion +noauthority +noadditional +nostats | grep -v ';' | grep -o '[[:digit:].]\+$'
end

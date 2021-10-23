function d
  switch (echo $argv[1])
    case rma
      podman rm (podman ps -aq)
    case rmit
      podman rmi (podman images | grep "^<none>" | tr -s " " | cut -d' ' -f3)
    case psa
      podman ps -a
    case '*'
      podman $argv
  end
end

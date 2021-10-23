function st

  # Requires npm install -g uuid

  set output (docker run --rm -v $HOME/.ssh:/root/.ssh:ro -v $HOME/.aws:/root/.aws:ro $USER/awscli stack $argv)
  echo "$output"

  set ssh_cmd (echo "$output" | grep -o "ssh.*-i.*")
  if [ $ssh_cmd ]
    set uuid (uuid)
    set script "/tmp/$uuid"
    echo "Writing SSH cmd to $script"
    echo "$ssh_cmd" > "$script"
    source "$script"
    rm "$script"
  else
    echo "No host found for arguments: $argv"
  end
end

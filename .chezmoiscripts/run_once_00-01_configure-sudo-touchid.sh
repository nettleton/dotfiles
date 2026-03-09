#!/bin/bash

if [ -f /etc/pam.d/sudo_local ]; then
  echo "sudo_local already exists, doing nothing"
else
  echo "creating sudo_local"
  sudo -A cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
  sudo -A sed -i '' 's/#auth/auth/g' /etc/pam.d/sudo_local
fi

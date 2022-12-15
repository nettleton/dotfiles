#!/bin/bash

NUM_SIGNATURES=$(/usr/libexec/PlistBuddy -c "Print :" ~/Library/Application\ Support/MailMate/Signatures.plist | grep -c uuid)

for idx in 0 $(($NUM_SIGNATURES - 1)); do
  SIG_NAME=$(/usr/libexec/PlistBuddy -c "Print :signatures:$idx:name" "$HOME/Library/Application Support/MailMate/Signatures.plist")
  if [ "$SIG_NAME" == "Default" ]; then
    UUID=$(/usr/libexec/PlistBuddy -c "Print :signatures:$idx:uuid" "$HOME/Library/Application Support/MailMate/Signatures.plist")
  fi
done

echo "$UUID"

function cleanOldNotes -d "Clean up old notes; arg of --dry-run skips deletion; just prints"
  contains -- --dry-run $argv; and set dryRun "true"
  echo "dryRun: '$dryRun'"

  set daystr (date +"%Y-%m-%d")
  echo "Looking for empty diary entries before $daystr"

  find $NOTES/diary \( -not -name "$daystr*" -not -name "\.*" -not -name "alfred.json" -not -name "diary.md" -not -type d \) -exec grep -l '\-\-\-' {} \; | while read -l fileName
    if sed '1,/---/d' "$fileName" | grep -iq '[a-z]'
      # echo "non-empty body in $fileName"
    else
      if test -n "$dryRun"
        echo "would delete $fileName, but in dry run"
      else
        rm -f "$fileName"
        echo "deleted $fileName"
      end
    end
  end
end

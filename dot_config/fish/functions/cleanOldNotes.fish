function cleanOldNotes -d "Clean up old notes; arg of --dry-run skips deletion; just prints"
  contains -- --dry-run $argv; and set dryRun "true"
  echo "dryRun: '$dryRun'"

  set templateNumLines (wc -l $HOME/.config/nvim/templates/skeleton.md | tr -s ' ' | cut -f2 -d' ')
  echo "Num lines that indicate an empty file: $templateNumLines"

  set daystr (date +"%Y-%m-%d")
  echo "Looking for empty diary entries before $daystr"

  find $NOTES/diary \( -not -name "$daystr*" -not -name "\.*" -not -name "alfred.json" -not -name "diary.md" -not -type d \) | while read -l fileName

    set originalWcl (wc -l "$fileName" | tr -s ' ' | cut -f2 -d' ')

    set fileNumLines (sed '/^$/d' "$fileName" | wc -l | tr -s ' ')

    set lastNonEmptyLine (sed '/^$/d' "$fileName" | tail -n 1)


    if [ "$fileNumLines" -le "$templateNumLines" -a "$lastNonEmptyLine" = "---" ]
      if test -n "$dryRun"
        # echo "Processing $fileName: origNumLines: $originalWcl, trimmedNumLines: $fileNumLines"
        # echo "    lastLine: '$lastNonEmptyLine' ?==? ---"
        echo "would delete $fileName, but in dry run"
      else
        rm -f "$fileName"
        echo "deleted $fileName"
      end
    end

  end
end

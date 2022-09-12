function generateDiaryIndex -d "generate diary index"

  set INDEX "$NOTES/diary/diary.md"

  set MONTHS "January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"

  echo "# Diary" > "$INDEX"

  echo "<!-- vale Vale.Spelling = NO -->" >> "$INDEX"
  echo "<!-- vale Microsoft.Dashes = NO -->" >> "$INDEX"
  echo "<!-- vale Microsoft.AMPM = NO -->" >> "$INDEX"
  echo "<!-- vale Microsoft.Acronyms = NO -->" >> "$INDEX"

  set writtenHeaders ""

  for fn in (find $NOTES/diary -name "[0-9]*\.md" | sort -r);
    set bn (basename "$fn")
    set YMD (string split -f1 _ "$bn" | string split -)

    set yearHeader "## $YMD[1]"
    set monthHeader "### $MONTHS[$YMD[2]] $YMD[1]"

    if not contains "$yearHeader" $writtenHeaders
      echo "" >> "$INDEX"
      echo "$yearHeader" >> "$INDEX"
      set writtenHeaders $writtenHeaders "$yearHeader"
    end

    if not contains "$monthHeader" $writtenHeaders
      echo "" >> "$INDEX"
      echo "$monthHeader" >> "$INDEX"
      echo "" >> "$INDEX"
      set writtenHeaders $writtenHeaders "$monthHeader"
    end

    echo "- [$bn](./$bn)" >> "$INDEX"
  end
end

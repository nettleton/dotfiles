function extractRemindersFromNotes -d "Extract reminders from diary notes"
  echo "extracting reminders"
  grep -ri '\- \[ \]' $NOTES/diary | while read -l task
    echo "Derived Reminder:"
    set originalNote (echo "$task" | cut -f1 -d':')
    set reminderRawText (echo "$task" | sed -e 's/.*\- \[ \][[:space:]]*//' | sed 's/ *$//g')
    echo "  originalNote: '$originalNote'"
    echo "  raw text      '$reminderRawText'"

    # for:[slug](path) signals this is an agenda topic for the file at $path
    string match -raq 'for:\[(?<agendaSlug>[^\]]*)\]\((?<agendaPath>[^\)]*)\)' "$reminderRawText"
    set numelAgendaLinks (count $agendaSlug)
    set reminderText "$reminderRawText"
    if test $numelAgendaLinks -ge 1
      # found a running agenda topic, write to that file
      for i in (seq 1 $numelAgendaLinks)
        set slug $agendaSlug[$i]
        set path $agendaPath[$i]
        # echo "  Found agenda link $i with slug '$slug' and path '$path'"
        set reminderText (echo "- [ ] $reminderRawText" | sed "s!for:\[$slug\]($path)!!")
        # echo "    reminderText: '$reminderText'"
        set agendaFile (echo "$NOTES/diary/$path" | sed 's#\.\.\\/diary/##')
        # echo "    fileToWrite: $agendaFile"
        if test -e "$agendaFile"
          # echo "  $agendaFile exists"
        else
          echo "  Creating $agendaFile"
          echo "## Running Agenda" > "$agendaFile"
        end
        echo "    Writing reminder to '$agendaFile': '$reminderText'"
        sed -i '' "s!## Running Agenda!## Running Agenda\n$reminderText!" "$agendaFile"
        echo "    Clearing open reminders in $originalNote"
        sed -i '' "s/\- \[ \]/\- \[X\]/g" "$originalNote" # this is greedy in the case of multiple todos, but we should eventually convert them all
      end
    else
      # if no running agenda topic is found, then it is a reminder for me.  Default due date 1 week out
      echo "  Creating a reminder for myself"
      set reminderListName (echo "$reminderRawText" | sed -rn 's/.*(@[^ ]*).*/\1/p')
      test -z "$reminderListName" && set reminderListName "@work"
      # echo "   reminderListName: $reminderListName"
      set reminderSentence (echo "$reminderRawText" | sed "s/$reminderListName//g" | sed 's/ *$//g')
      # echo "   reminderSentence: $reminderSentence"
      set defaultDueDate (date -v +7d +"%Y-%m-%d_09:00:00AM")
      set derivedDueDate (echo "$reminderRawText" | sed -rn 's/.*due:([^ ]*).*/\1/p')
      # echo "   original derivedDueDate: $derivedDueDate"
      set reminderSentence (echo "$reminderSentence" | sed "s/due:$derivedDueDate//g")
      # echo "   reminderSentence: $reminderSentence"
      test -z "$derivedDueDate" && set derivedDueDate "$defaultDueDate"
      # echo "   dueDate: $derivedDueDate"
      set dateAndTimeMatch (string match "*_*" "$derivedDueDate")
      test -z "$dateAndTimeMatch" && set derivedDueDate $derivedDueDate"_09:00:00AM"
      set dueDateYMD (echo "$derivedDueDate" | sed 's/_.*$//')
      # echo "   dueDateYMD: $dueDateYMD"
      set derivedDueDate (echo "$derivedDueDate" | sed 's/_/\ /')
      # echo "   dueDateAndTime: $derivedDueDate"

      set sentence "task $reminderSentence due $derivedDueDate /$reminderListName"
      # echo "   sentence: $sentence"
      set urlEncodedSentence (echo "$sentence" | python3 -c "import urllib.parse;print(urllib.parse.quote(input()))")
      # echo "   urlEncoded sentence: $urlEncodedSentence"
      set urlEncodedNote (echo "file://$originalNote" | python3 -c "import urllib.parse;print(urllib.parse.quote(input()))")
      set fantasticalUrl "x-fantastical3://parse?add=1&s=$urlEncodedSentence&n=$urlEncodedNote"
      echo "   fantastical url: $fantasticalUrl"
      open "$fantasticalUrl"
      sleep 30

      echo "  modifying $originalNote"
      sed -i '' -e "s/\[ \][ ]*$reminderRawText/\[$reminderRawText\]\(x-fantastical3:\/\/show\/calendar\/$dueDateYMD\)/" "$originalNote"
    end
  end
end

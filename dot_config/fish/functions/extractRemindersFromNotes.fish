function extractRemindersFromNotes -d "Extract reminders from diary notes"
  echo "extracting reminders"
  grep -ri '@todo' $NOTES/diary | cut -f1 -d':' | sort | uniq |  while read -l diaryWithTodo
    echo "Extracting reminders from $diaryWithTodo"
    extractReminders "$diaryWithTodo"
  end
end

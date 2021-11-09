function cleanupNotes -d "Generate snippets, extract reminders, cleanup notes, and regenerate index"
  generateNotesSnippets
  extractRemindersFromNotes
  echo "Listing empty old notes that are candidates for cleanup"
  cleanOldNotes --dry-run
  set shouldDelete (read -P "Delete listed notes [Y/n]? " | string lower )
  if [ "$shouldDelete" = "y" ]
    echo "deleting notes"
    cleanOldNotes
  else
    echo "not deleting notes.  You can run 'cleanOldNotes' at any time do to this on your own"
  end
  generateDiaryIndex
end

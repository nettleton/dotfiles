function extractReminders -d "Extract reminders from diary notes"
  for line in (cat $argv[1])
    # echo "'$line'"
    # if a line starts with '-' (like a bulleted list in md), string match interprets it as an option
    if string match -rq "@todo.*\w" "#LINESTART#$line"
      set line (echo "$line" | string replace -r ".*@todo" "")
      set originalTodo "@todo$line"

      set listName (echo "$line" | rg -o "@list\((?P<listName>[^\)]+)\)" -r '$listName')
      string length -q "$listName"; or set listName "@work"
      # echo "list name: $listName"
      set line (echo "$line" | string replace -r "@list\([^\)]+\)" "")

      set dueDate (echo "$line" | rg -o "@due\((?P<dueDate>[^\)]+)\)" -r '$dueDate')
      string length -q "$dueDate"; or set dueDate (date -v +7d +"%Y-%m-%dT09:00:00-0500")
      # echo "due date: $dueDate"
      set line (echo "$line" | string replace -r "@due\([^\)]+\)" "")

      set priorityVal (echo "$line" | rg -o "@priority\((?P<priority>[^\)]+)\)" -r '$priority')
      # echo "priority: $priority"

      set title (echo "$line" | string replace -r "@priority\([^\)]+\)" "" | string trim)

      if string length -q "$priorityVal"
        # echo "$HOME/sandbox/reminders-cli/.build/apple/Products/Release/reminders add $listName \"$title\" --due-date \"$dueDate\" --priority $priorityVal"
        set id ($HOME/sandbox/reminders-cli/.build/apple/Products/Release/reminders add "$listName" "$title" --due-date "$dueDate" --priority "$priorityVal" -f json | jq -r '.externalId')
      else
        # echo "$HOME/sandbox/reminders-cli/.build/apple/Products/Release/reminders add $listName \"$title\" --due-date \"$dueDate\""
        set id ($HOME/sandbox/reminders-cli/.build/apple/Products/Release/reminders add "$listName" "$title" --due-date "$dueDate" -f json | jq -r '.externalId')
      end
      # echo "id: $id"

      sed -i '' "s#$originalTodo#[$title](x-apple-reminderkit://REMCDReminder/$id)#" "$argv[1]"
      # echo ""
    end
  end
end

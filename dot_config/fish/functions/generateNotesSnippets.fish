function generateNotesSnippets -d "Generate ultisnips from frontmatter"
  set dest "$HOME/.config/nvim/snips/extracted-from-notes.json"
  # First, clean existing ultisnips
  echo '{' > "$dest"

  # Find all notes with a non-empty Snippet: tag
  grep -r -e 'Snippet:[[:space:]]\+[^ ].*' $NOTES | while read -l snippetLine
    set filepath (echo "$snippetLine" | cut -f1 -d':' )
    set filename (basename "$filepath")
    set snippetDefinition (echo "$snippetLine" | sed 's/.*Snippet:[[:space:]]*//')
    set tabtrigger (echo "$snippetDefinition" | cut -f1 -d'#' | sed 's/:/_/')
    set name (echo "$tabtrigger" | cut -f2 -d'_')
    set snippetDescription (echo "$snippetDefinition" | cut -f2 -d'#')
    set snippetSlug (echo "$snippetDefinition" | cut -f3 -d'#')
    echo "Found non-empty snippet in file $filename: tab trigger: '$tabtrigger' description: '$snippetDescription' slug: '$snippetSlug'"

    set snippetString "
  \"$name\": {
    \"prefix\": \"$tabtrigger\",
    \"body\": [
      \"[$snippetSlug](../$filename)\"
    ]
  },"
    echo "$snippetString" >> "$dest"
  end

  sed -i '' '$ s/.$//' "$dest"
  echo "}" >> "$dest"
end

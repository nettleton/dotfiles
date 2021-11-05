function generateNotesSnippets -d "Generate ultisnips from frontmatter"
  # First, clean existing ultisnips
  cp $HOME/.config/nvim/snips/snippets.template $HOME/.config/nvim/snips/markdown.snippets

  # Find all notes with a non-empty Snippet: tag
  grep -r -e 'Snippet:[[:space:]]\+[^ ].*' $NOTES | while read -l snippetLine
    set filepath (echo "$snippetLine" | cut -f1 -d':' )
    set filename (basename "$filepath")
    set snippetDefinition (echo "$snippetLine" | sed 's/.*Snippet:[[:space:]]*//')
    set tabtrigger (echo "$snippetDefinition" | cut -f1 -d'#')
    set snippetDescription (echo "$snippetDefinition" | cut -f2 -d'#')
    set snippetSlug (echo "$snippetDefinition" | cut -f3 -d'#')
    echo "Found non-empty snippet in file $filename: tab trigger: '$tabtrigger' description: '$snippetDescription' slug: '$snippetSlug'"

    set snippetString "
snippet $tabtrigger \"$snippetDescription\" w
[$snippetSlug](../$filename)
endsnippet"

    echo "$snippetString" >> $HOME/.config/nvim/snips/markdown.snippets
  end
end

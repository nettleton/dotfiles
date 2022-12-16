on alfred_script(q)
	tell application "kitty" to activate
    -- 1. Open new OS window
		  -- do shell script "/Applications/Kitty.app/Contents/MacOS/kitty @ --to unix:/tmp/kitty launch --type os-window --title alfred"  
    -- 2. Make existing window active 
      -- do shell script "/Applications/Kitty.app/Contents/MacOS/kitty @ --to unix:/tmp/kitty focus-window --match 'title:notes_terminal'"
		
    tell application "System Events" to keystroke q
		tell application "System Events" 
			key code 36 --enter key
	end tell
end alfred_script

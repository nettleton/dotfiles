#!/bin/bash
# Claude Code status line: model, cwd (~-relative), and a color-coded
# context-window usage bar. Reads the session JSON on stdin and prints one
# line. See https://code.claude.com/docs/en/statusline for the input schema.
#
# Managed by chezmoi (dot_claude/executable_statusline.sh -> ~/.claude/
# statusline.sh, 0755). The statusLine config that points here lives in
# dot_claude/private_settings.json. Personal machines only: work machines'
# ~/.claude/settings.json is owned by the corporate devai tool and is
# chezmoi-ignored, so this never takes effect there.
#
# context_window.used_percentage is input-tokens-only and is null before the
# first API response and again after /compact until the next call, so we
# default it to 0. Changing the statusLine command re-runs it immediately
# (no 300ms debounce), which makes tweaking easy.

input=$(cat)

# One jq pass, tab-separated so spaces in the model name or path survive the
# read. `// 0` / `// ""` guard the nullable fields; floor turns a float
# percentage (e.g. 23.5) into an int for the shell arithmetic below.
IFS=$'\t' read -r MODEL PCT RAWDIR < <(
  printf '%s' "$input" | jq -r '
    [ (.model.display_name // "?")
    , (.context_window.used_percentage // 0 | floor)
    , (.workspace.current_dir // .cwd // "")
    ] | @tsv'
)

# Guard against a non-numeric PCT (e.g. jq missing); fall back to 0.
case "$PCT" in
  ''|*[!0-9]*) PCT=0 ;;
esac
[ "$PCT" -gt 100 ] && PCT=100

# Current git branch, resolved against the real path (RAWDIR) so it doesn't
# depend on the script's own cwd. --abbrev-ref gives the branch name, or the
# literal "HEAD" on a detached checkout, which we swap for a short SHA. A
# non-repo makes rev-parse fail quietly and BRANCH stays empty (segment omitted).
BRANCH=""
if [ -n "$RAWDIR" ]; then
  BRANCH=$(git -C "$RAWDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$BRANCH" = HEAD ] && BRANCH=$(git -C "$RAWDIR" rev-parse --short HEAD 2>/dev/null)
fi

# ~-relativise the directory for a shorter, familiar display.
DIR="$RAWDIR"
case "$DIR" in
  "$HOME")   DIR='~' ;;
  "$HOME"/*) DIR="~${DIR#"$HOME"}" ;;
esac

# Color the bar + percentage by usage: green < 50, yellow < 80, red >= 80.
if   [ "$PCT" -ge 80 ]; then COLOR=$'\033[31m'   # red
elif [ "$PCT" -ge 50 ]; then COLOR=$'\033[33m'   # yellow
else                         COLOR=$'\033[32m'   # green
fi
DIM=$'\033[2m'
RESET=$'\033[0m'

# 10-cell bar: ▓ filled, ░ empty (printf -v makes a run of spaces, then the
# ${var// /x} expansion rewrites each space as the block glyph).
WIDTH=10
FILLED=$(( PCT * WIDTH / 100 ))
EMPTY=$(( WIDTH - FILLED ))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v F "%${FILLED}s" && BAR="${F// /▓}"
[ "$EMPTY"  -gt 0 ] && printf -v E "%${EMPTY}s"  && BAR="${BAR}${E// /░}"

# Keep the context bar visible on a narrow window. Claude Code captures our
# output (so tput can't read the size) but exports COLUMNS as the terminal
# width. The model, branch and bar are fixed-cost and take priority; the
# directory absorbs the overflow — truncated to its tail with a leading … so
# you still see where you are. COLUMNS unset/garbage -> no truncation.
case "$COLUMNS" in
  ''|*[!0-9]*) COLS=0 ;;
  *)           COLS=$COLUMNS ;;
esac
if [ "$COLS" -gt 0 ]; then
  PCTSTR="${PCT}%"
  BRANCH_PLAIN=""
  [ -n "$BRANCH" ] && BRANCH_PLAIN=" ($BRANCH)"
  # Fixed chars around the dir: "[" "]" " " "  " " " = 6, plus the model,
  # the branch text, the WIDTH-cell bar, and the "NN%" string.
  FIXED=$(( 6 + ${#MODEL} + ${#BRANCH_PLAIN} + WIDTH + ${#PCTSTR} ))
  AVAIL=$(( COLS - FIXED ))
  if [ "${#DIR}" -gt "$AVAIL" ]; then
    if   [ "$AVAIL" -le 0 ]; then DIR=""
    elif [ "$AVAIL" -eq 1 ]; then DIR="…"
    else                          DIR="…${DIR: -$((AVAIL - 1))}"
    fi
  fi
fi

# Branch segment: dim parens after the path, only when we found a branch/SHA.
BRANCHSEG=""
[ -n "$BRANCH" ] && BRANCHSEG=" ${DIM}(${BRANCH})${RESET}"

printf '%s\n' "${DIM}[${RESET}${MODEL}${DIM}]${RESET} ${DIM}${DIR}${RESET}${BRANCHSEG}  ${COLOR}${BAR} ${PCT}%${RESET}"

# kitty custom-hints handler: grab a command the agent printed and send it to
# the coding-session *terminal* pane (the shell pane that code-session.fish
# creates), rather than into the agent pane the hints kitten was invoked from.
#
# How it works: you pick ANY ONE line of the command with a single-line hint
# (so plain Enter confirms — no --multiple, no Esc). The handler then reads the
# agent pane's screen, finds that line, and expands the selection up and down to
# the surrounding boundaries, so a multi-line command is grabbed whole from a
# single pick.
#
# Nothing here assumes a specific indent WIDTH. The block is "the indented run
# of lines around your pick": expansion stops at a blank line, a Claude Code
# marker (⏺ bullet / ⎿ tool-result / … truncation), or any flush-left (indent 0)
# line — the margin, whatever the indent happens to be. The leading indent is
# then removed with textwrap.dedent, which measures the common prefix itself
# rather than trimming a hardcoded number of spaces. Soft-wrapped rows are
# rejoined first. If the agent ever stops indenting blocks, this degrades
# safely to grabbing just the picked line rather than over-grabbing.
#
# Wire it up in kitty.conf:
#   # paste the whole command block into the session terminal (review, then Enter):
#   map ctrl+shift+opt+cmd+y kitten hints --type line --customize-processing send_to_session_terminal.py
#   # same, but run it immediately:
#   map ctrl+shift+opt+cmd+r kitten hints --type line --customize-processing send_to_session_terminal.py -- --run
#
# NOTE: the Python handler module is loaded by the kitty process. Opening a new
# kitty OS window is enough to pick up edits; a full restart always works.
#
# DIAGNOSTICS: set DEBUG = True below to append a trace of every invocation
# (which panes it saw, the block it built, and whether paste/focus succeeded) to
# /tmp/send_to_session_terminal.log. Off by default; the instrumentation stays
# in the code so it can be flipped back on if an edge case turns up.

import datetime
import textwrap
import traceback

DEBUG = False  # set True to append a diagnostics trace to LOG
LOG = '/tmp/send_to_session_terminal.log'

SHELLS = {
    'fish', 'zsh', 'bash', 'sh', 'dash', 'tcsh', 'ksh',
    '-fish', '-zsh', '-bash', '-sh',
}

# Lines that bound a block: blank, or a Claude Code marker (bullet / tool-result
# hook / truncation ellipsis). Expansion stops *before* these.
_MARKER_CHARS = '⏺⎿…└╰'  # ⏺ ⎿ … └ ╰


def _log(msg):
    if not DEBUG:
        return
    try:
        with open(LOG, 'a') as f:
            f.write('%s %s\n' % (
                datetime.datetime.now().strftime('%H:%M:%S'), msg))
    except Exception:
        pass


def _basename(p):
    if not p:
        return ''
    return p.rsplit('/', 1)[-1]


def _exe(win):
    try:
        return win.get_exe_of_child()
    except Exception as e:
        return '<err:%s>' % e


def _cmdlines(win):
    out = []
    child = getattr(win, 'child', None)
    procs = getattr(child, 'foreground_processes', None) if child is not None else None
    if procs:
        try:
            for p in procs:
                cl = p.get('cmdline') if isinstance(p, dict) else getattr(p, 'cmdline', None)
                if cl:
                    out.append(list(cl))
        except Exception as e:
            out.append('<err:%s>' % e)
    return out


def _basenames(cmdlines):
    return [_basename(cl[0]) for cl in cmdlines if isinstance(cl, list) and cl]


def _is_nvim(win):
    if _basename(_exe(win)).startswith('nvim'):
        return True
    return any(b.startswith('nvim') for b in _basenames(_cmdlines(win)))


def _is_shell(win):
    if _basename(_exe(win)) in SHELLS:
        return True
    bns = _basenames(_cmdlines(win))
    return bool(bns) and all(b in SHELLS for b in bns)


def _pick_terminal_window(tab, invoking_id):
    """Pick the coding-session terminal pane within this tab: a non-nvim pane,
    preferring one that is not the invoking (agent) pane and is at a shell."""
    best, best_score = None, -1
    for win in tab:
        nvim, shell = _is_nvim(win), _is_shell(win)
        score = -1
        if not nvim:
            score = 0
            if win.id != invoking_id:
                score += 2
            if shell:
                score += 1
        _log('  win id=%s exe=%r nvim=%s shell=%s score=%s%s' % (
            win.id, _exe(win), nvim, shell, score,
            ' (invoking)' if win.id == invoking_id else ''))
        if score > best_score:
            best, best_score = win, score
    return best


def _screen_lines(win):
    """Visible screen of win as logical lines (soft-wrapped rows rejoined)."""
    raw = None
    try:
        raw = win.as_text(add_wrap_markers=True)
    except Exception as e:
        _log('  as_text(wrap) FAILED: %s' % e)
        try:
            raw = win.as_text()
        except Exception as e2:
            _log('  as_text() FAILED: %s' % e2)
            return None
    # Soft-wrap marker is '\r'; real row breaks are '\n'. Drop '\r' to rejoin
    # wrapped rows into their logical line, then split on newlines.
    return raw.replace('\r', '').split('\n')


def _leading_ws(line):
    return len(line) - len(line.lstrip())


def _is_boundary(line):
    # A block boundary is: a blank line, a Claude Code marker line, or a
    # flush-left line (indent 0). The last is width-agnostic — it treats the
    # left margin as the edge of the indented block, without caring whether the
    # indent is 2, 4, or a tab. A line that is itself at indent 0 (e.g. the
    # picked line, if the agent were not indenting) makes neighbouring indent-0
    # lines boundaries too, so expansion collapses to the single line.
    s = line.strip()
    if s == '':
        return True
    if s[0] in _MARKER_CHARS:
        return True
    if _leading_ws(line) == 0:
        return True
    return False


def _find_line(lines, needle):
    if not needle:
        return None
    for i, ln in enumerate(lines):
        if needle in ln:
            return i
    # Looser: the picked text may be a wrapped fragment that is longer than one
    # stored row, or vice versa — match either containment.
    for i, ln in enumerate(lines):
        s = ln.strip()
        if s and s in needle:
            return i
    return None


def _expand(lines, idx):
    start = idx
    while start > 0 and not _is_boundary(lines[start - 1]):
        start -= 1
    end = idx
    while end < len(lines) - 1 and not _is_boundary(lines[end + 1]):
        end += 1
    return start, end


def _finish(block_lines):
    """Dedent the agent's block indent and trim surrounding/edge whitespace."""
    text = textwrap.dedent('\n'.join(block_lines))
    out = [ln.rstrip() for ln in text.split('\n')]
    while out and out[0] == '':
        out.pop(0)
    while out and out[-1] == '':
        out.pop()
    return '\n'.join(out)


def _build_body(win, picks):
    # Honor an explicit multi-pick as-is; a single pick expands to its block.
    if len(picks) > 1:
        return _finish(picks)
    needle = picks[0].strip()
    lines = _screen_lines(win)
    if lines is None:
        return _finish([picks[0]])
    idx = _find_line(lines, needle)
    _log('  block match idx=%s of %d lines' % (idx, len(lines)))
    if idx is None:
        return _finish([picks[0]])
    start, end = _expand(lines, idx)
    _log('  block rows %d..%d' % (start, end))
    return _finish(lines[start:end + 1])


def handle_result(args, data, target_window_id, boss, extra_cli_args=None, *a):
    try:
        _log('--- invoked: target=%s extra=%r' % (target_window_id, extra_cli_args))
        if not isinstance(data, dict):
            _log('  data not a dict: %r' % (type(data),))
            return
        picks = [m for m in (data.get('match') or []) if m and m.strip()]
        _log('  picks=%r' % (picks,))
        if not picks:
            return
        run = '--run' in (extra_cli_args or [])

        invoking = boss.window_id_map.get(target_window_id)
        _log('  invoking resolved=%s' % (invoking is not None,))
        if invoking is None:
            return
        tab = invoking.tabref()
        _log('  tab resolved=%s' % (tab is not None,))
        if tab is None:
            return

        body = _build_body(invoking, picks)
        _log('  body=%r' % (body,))
        if not body:
            return

        term = _pick_terminal_window(tab, target_window_id)
        _log('  chosen terminal id=%s' % (term.id if term is not None else None,))
        if term is None:
            return

        try:
            term.paste_text(body)
            _log('  paste_text OK (%d chars)' % len(body))
        except Exception as e:
            _log('  paste_text FAILED: %s; send-text' % e)
            boss.call_remote_control(
                term, ('send-text', '--match=id:%d' % term.id, body))

        if run:
            try:
                term.write_to_child('\r')
                _log('  CR OK')
            except Exception as e:
                _log('  CR FAILED: %s' % e)
                boss.call_remote_control(
                    term, ('send-text', '--match=id:%d' % term.id, '\r'))

        # Focus the terminal so the paste is visible (immediate + a short
        # deferred re-focus, since closing the hints overlay otherwise restores
        # focus to the invoking agent pane).
        tid = term.id

        def _focus():
            try:
                boss.set_active_window(tid, switch_os_window_if_needed=True)
                return True
            except Exception as e:
                _log('  set_active_window FAILED: %s' % e)
                return False

        _log('  focus immediate OK=%s' % _focus())
        try:
            from kitty.fast_data_types import add_timer

            def _deferred(timer_id):
                _log('  focus deferred OK=%s' % _focus())

            add_timer(_deferred, 0.05, False)
            _log('  deferred focus scheduled')
        except Exception as e:
            _log('  add_timer unavailable: %s' % e)
    except Exception:
        _log('EXCEPTION:\n' + traceback.format_exc())

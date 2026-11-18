function code-session-close -d "Tear down the current coding session: nvim, agent, and all three kitty panes"
    # 1. Only act inside a kitty window; if we can't talk to kitty there is nothing to do.
    if test -z "$KITTY_WINDOW_ID"
        return 0
    end

    # Gather the current tab's structure in one kitty call. The helper locates the
    # tab containing $KITTY_WINDOW_ID and prints, for each of its windows, whether
    # it is nvim, whether it has a non-shell (job) foreground process, its nvim
    # listen socket, the job's name, and the job's foreground pids.
    set -l info (kitty @ ls 2>/dev/null | python3 -c '
import json, sys

wid = int(sys.argv[1])
SHELLS = {"fish", "zsh", "bash", "sh", "dash", "-fish", "-zsh", "-bash", "-sh"}

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(3)

def base(p):
    return p.rsplit("/", 1)[-1]

tab = oswid = None
for osw in data:
    for t in osw.get("tabs", []):
        for w in t.get("windows", []):
            if w.get("id") == wid:
                tab, oswid = t, osw.get("id")
                break
        if tab:
            break
    if tab:
        break

if not tab:
    sys.exit(3)

print("TITLE\t" + tab.get("title", ""))
for w in tab.get("windows", []):
    procs = w.get("foreground_processes", [])
    is_nvim = 0
    job = 0
    sock = "-"
    name = "-"
    pids = []
    for p in procs:
        cl = p.get("cmdline") or []
        if not cl:
            continue
        b = base(cl[0])
        if b == "nvim" or b.startswith("nvim"):
            is_nvim = 1
            for i, a in enumerate(cl):
                if a == "--listen" and i + 1 < len(cl):
                    sock = cl[i + 1]
        elif b not in SHELLS:
            job = 1
            if name == "-":
                name = b
            if p.get("pid"):
                pids.append(str(p["pid"]))
    if is_nvim and sock == "-":
        sock = "/tmp/nvim-%s-%s.sock" % (oswid, tab.get("id"))
    cur = 1 if w.get("id") == wid else 0
    print("WIN\t%d\t%d\t%d\t%d\t%s\t%s\t%s" % (
        w.get("id"), cur, is_nvim, job, sock, name, ",".join(pids) or "-"))
' $KITTY_WINDOW_ID)

    # Could not read the tab (no remote control, not in kitty, etc.) -> do nothing.
    if test (count $info) -eq 0
        return 0
    end

    # Parse the helper output.
    set -l title ""
    set -l nvim_socks
    set -l all_window_ids
    set -l current_id
    set -l job_windows   # non-current, non-nvim windows with a running job: "id|name|pids"
    for line in $info
        set -l f (string split \t -- $line)
        switch $f[1]
            case TITLE
                set title $f[2]
            case WIN
                set -l id $f[2]
                set -l cur $f[3]
                set -l is_nvim $f[4]
                set -l job $f[5]
                set -l sock $f[6]
                set -l pname $f[7]
                set -l pids $f[8]
                set -a all_window_ids $id
                test "$cur" = 1; and set current_id $id
                test "$is_nvim" = 1; and set -a nvim_socks $sock
                if test "$job" = 1; and test "$cur" != 1
                    set -a job_windows "$id|$pname|$pids"
                end
        end
    end

    # 1 (cont). If this isn't a coding session, do nothing.
    if not string match -q "Coding Session:*" -- $title; and test (count $nvim_socks) -eq 0
        return 0
    end

    # 3 (gated first, before anything is torn down). The agent is fine to close when
    # idle; only warn if it's actively working. Both claude and codex show an
    # "esc to interrupt" hint on screen while a turn is in flight.
    for w in $job_windows
        set -l p (string split '|' -- $w)
        set -l screen (kitty @ get-text --match id:$p[1] --extent screen 2>/dev/null)
        if string match -qr -- '(?i)esc to interrupt' $screen
            set -l who (test "$p[2]" != "-"; and echo $p[2]; or echo "the agent")
            read -l -P "$who appears to be working. Close anyway? [y/N]: " ans
            if not string match -qr '^[yY]' -- "$ans"
                echo "Cancelled. Session left open."
                return 1
            end
            break
        end
    end

    echo "Tearing down coding session: $title"

    # 2. Safely quit nvim: for every modified, named buffer prompt save / discard /
    #    cancel; save the chosen ones, then let nvim quit itself (qall!) and wait for
    #    it to exit before its pane is removed.
    for sock in $nvim_socks
        # Skip sockets that don't answer (nvim already gone).
        if not nvim --server "$sock" --remote-expr '1' >/dev/null 2>&1
            continue
        end

        set -l modjson (nvim --server "$sock" --remote-expr 'luaeval("vim.json.encode((function() local t={} for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified and vim.bo[b].buftype==[[]] then t[#t+1]={b,vim.api.nvim_buf_get_name(b)} end end return t end)())")' 2>/dev/null)

        set -l mods (printf '%s' "$modjson" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = []
for e in d:
    print(str(e[0]) + chr(9) + (e[1] or ""))
' 2>/dev/null)

        for m in $mods
            set -l parts (string split \t -- $m)
            set -l bufnr $parts[1]
            set -l name $parts[2]
            if test -n "$name"
                read -l -P "Save changes to '$name'? [Y]es / [n]o (discard) / [c]ancel: " ans
            else
                read -l -P "Unnamed buffer #$bufnr has unsaved changes. [d]iscard / [c]ancel: " ans
                set ans (test -n "$ans"; and echo $ans; or echo c)
            end
            switch (string lower -- "$ans")
                case c cancel
                    echo "Cancelled. Session left open."
                    return 1
                case n no d discard
                    # leave it; qall! will discard
                case '*'
                    # default / yes -> save (named buffers only)
                    if test -n "$name"
                        nvim --server "$sock" --remote-expr "execute('lua vim.api.nvim_buf_call($bufnr, function() vim.cmd[[write]] end)')" >/dev/null 2>&1
                    end
            end
        end

        # Everything the user wanted saved is written; let nvim quit itself.
        nvim --server "$sock" --remote-send ':qall!<CR>' >/dev/null 2>&1
        # Wait (up to ~3s) for nvim to finish shutting down.
        for i in (seq 1 15)
            nvim --server "$sock" --remote-expr '1' >/dev/null 2>&1; or break
            sleep 0.2
        end
    end

    # 4. Gracefully stop the agent (and any other pane job) with SIGTERM — claude and
    #    codex both run a clean shutdown on it — then wait for them to exit, so the
    #    window close only ever lands on an idle shell rather than killing live work.
    for w in $job_windows
        set -l p (string split '|' -- $w)
        for pid in (string split ',' -- $p[3])
            test -n "$pid"; and test "$pid" != "-"; and kill -TERM $pid 2>/dev/null
        end
    end
    for i in (seq 1 15)
        set -l alive 0
        for w in $job_windows
            set -l p (string split '|' -- $w)
            for pid in (string split ',' -- $p[3])
                test -n "$pid"; and test "$pid" != "-"; and kill -0 $pid 2>/dev/null; and set alive 1
            end
        end
        test $alive -eq 0; and break
        sleep 0.2
    end

    # Close every pane. Do the window we're sitting in last, since that ends this shell.
    for id in $all_window_ids
        test "$id" = "$current_id"; and continue
        kitty @ close-window --match id:$id >/dev/null 2>&1
    end
    if test -n "$current_id"
        kitty @ close-window --match id:$current_id >/dev/null 2>&1
    end
end

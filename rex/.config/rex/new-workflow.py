#!/usr/bin/env python3
"""One-screen form for the Rex "new_workflow" action (init.lua).

Four fields: host, session, directory, and name. The action fills them from the
pane you came from. Enter goes to the next field and submits on the last one.
Cmd+Enter (init.lua sends Ctrl+S) or Ctrl+S submits from any field.

    new-workflow.py --client ID --session ID --cwd DIR

The directory field matches like zoxide: words in order, and the last word must
match the last folder name. Text that starts with / ~ or . completes as a path.
Remote hosts are read through Rex, so nothing needs to be installed on them.
"""

import argparse
import curses
import json
import locale
import os
import shutil
import subprocess
import threading

LOCAL = "local"
NEW_SESSION = "+ new session"
TERMINAL = "com.superlogical.terminal"
FIELDS = ["host", "session", "dir", "name"]
SUBMIT_KEYS = ("\x13",)  # Ctrl+S. init.lua writes it for Cmd+Enter.

# A Rex action starts this without reading .zshrc, so add the nanobrew tools here.
if "/opt/nanobrew/prefix/bin" not in os.environ.get("PATH", "").split(":"):
    os.environ["PATH"] = os.environ.get("PATH", "") + ":/opt/nanobrew/prefix/bin"


class RexError(Exception):
    pass


def rex(host, *args, timeout=8.0):
    cmd = ["rex"] + ([] if host == LOCAL else ["-S", host]) + list(args)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RexError("rex timed out: " + " ".join(args[:2]))
    if r.returncode != 0:
        raise RexError((r.stderr or r.stdout).strip().splitlines()[-1] if (r.stderr or r.stdout).strip() else "rex failed")
    return r.stdout


def rex_json(host, *args, **kw):
    return json.loads(rex(host, *(list(args) + ["--json"]), **kw) or "{}")


# Data for one host. Remote reads go through a pane on that host.
class Host:
    def __init__(self, name):
        self.name = name
        self.sessions = []  # [(label, session_id)]
        self.home = os.path.expanduser("~") if name == LOCAL else None
        self.probe = None  # (session_id, block_id) of a terminal to list folders through
        self.zoxide = []  # absolute paths, best first
        self.loading = True
        self.error = ""
        self.dir_cache = {}
        self.lock = threading.Lock()

    def load(self):
        try:
            data = rex_json(self.name, "--timeout", "5s", "ls")
            self.sessions = [(s.get("label") or s["session_id"][-6:], s["session_id"]) for s in data.get("sessions", [])]
            if self.name == LOCAL:
                self.zoxide = local_zoxide()
            else:
                self.load_remote()
        except (RexError, ValueError) as e:
            self.error = str(e)
        self.loading = False

    def load_remote(self):
        for _, sid in self.sessions:
            blocks = rex_json(self.name, "block", "ls", "-s", sid).get("blocks", [])
            terms = [b["block_id"] for b in blocks if b.get("creator_name") == TERMINAL and b.get("placement") == "placed"]
            if terms:
                self.probe = (sid, terms[0])
                break
        if not self.probe:
            self.error = "No session on this host to read folders through. Type a path."
            return
        listing = self.list_dir("~")
        self.home = (listing or {}).get("home")
        self.zoxide = remote_zoxide(self.name, self.probe[0])

    def list_dir(self, path):
        with self.lock:
            if path in self.dir_cache:
                return self.dir_cache[path]
        if self.name == LOCAL:
            try:
                full = os.path.expanduser(path)
                names = sorted((e.name for e in os.scandir(full) if e.is_dir()), key=str.lower)
                result = {"path": full, "home": self.home, "entries": [{"name": n} for n in names]}
            except OSError:
                result = None
        elif self.probe:
            sid, bid = self.probe
            try:
                result = json.loads(rex(self.name, "block", "call", "-s", sid, "-b", bid, "list_dir", json.dumps({"path": path})))
                if result.get("status") != "ok":
                    result = None
            except (RexError, ValueError):
                result = None
        else:
            result = None
        with self.lock:
            self.dir_cache[path] = result
        return result


def local_zoxide():
    if not shutil.which("zoxide"):
        return []
    r = subprocess.run(["zoxide", "query", "-l"], capture_output=True, text=True)
    return [line for line in r.stdout.splitlines() if line]


def remote_zoxide(host, session_id):
    """Run zoxide in a hidden pane on the host, read what it printed, then close the pane."""
    opts = {"command": ["sh", "-lc", "zoxide query -l 2>/dev/null; echo __rex_wf_end__"], "exit": {"on_completion": False}}
    try:
        out = json.loads(rex(host, "api", "call", "session.new_block", json.dumps({
            "session_id": session_id, "flavor": TERMINAL + ".shell", "label": "new-workflow-probe", "options": opts})))
        bid = out.get("block_id") or (out.get("block_ids") or [None])[0]
    except (RexError, ValueError):
        return []
    try:
        try:
            rex(host, "wait", "-s", session_id, bid, "--for", "5s", timeout=8)
        except RexError:
            pass
        text = rex(host, "capture", "-s", session_id, "-b", bid, "--trim", "--unwrap")
        lines = []
        for line in text.splitlines():
            if line.strip() == "__rex_wf_end__":
                break
            if line.startswith("/"):
                lines.append(line.rstrip())
        return lines
    except RexError:
        return []
    finally:
        try:
            rex(host, "block", "close", "-s", session_id, bid)
        except RexError:
            pass


def zoxide_match(path, words):
    """zoxide's rule: each word appears in order, and the last word is in the last folder name."""
    p = path.lower()
    i = 0
    for w in words:
        j = p.find(w, i)
        if j < 0:
            return False
        i = j + len(w)
    last = words[-1]
    return "/" in last or last in p.rstrip("/").rsplit("/", 1)[-1]


def fuzzy(text, options):
    t = text.lower()
    starts = [o for o in options if o.lower().startswith(t)]
    has = [o for o in options if t in o.lower() and o not in starts]
    return starts + has


class Form:
    def __init__(self, args):
        self.client = args.client
        self.origin_session = args.session
        self.origin_cwd = args.cwd or os.path.expanduser("~")
        self.hosts = {LOCAL: Host(LOCAL)}
        self.host_names = [LOCAL]
        try:
            for h in rex_json(LOCAL, "hosts").get("hosts", []):
                label = h.get("host", {}).get("label")
                if label:
                    self.host_names.append(label)
        except (RexError, ValueError):
            pass
        self.values = {"host": LOCAL, "session": NEW_SESSION, "dir": self.origin_cwd, "name": ""}
        self.name_edited = False
        self.status = ""
        self.load_host(LOCAL)
        self.focus = 0
        self.enter_field()

    # Hosts load in the background so the screen never waits on the network.
    def load_host(self, name):
        if name not in self.hosts:
            self.hosts[name] = Host(name)
        h = self.hosts[name]
        if name == LOCAL:
            h.load()
        else:
            threading.Thread(target=h.load, daemon=True).start()

    @property
    def host(self):
        return self.hosts[self.values["host"]]

    def session_options(self):
        return [NEW_SESSION] + [label for label, _ in self.host.sessions]

    def session_id(self):
        for label, sid in self.host.sessions:
            if label == self.values["session"]:
                return sid
        return None

    def default_session(self):
        if self.values["host"] == LOCAL:
            for label, sid in self.host.sessions:
                if sid == self.origin_session:
                    return label
        return NEW_SESSION

    def name_default(self):
        d = self.values["dir"].rstrip("/") or "/"
        if d == "~" or d == self.host.home:
            return "home"
        return os.path.basename(d) or d

    def name_value(self):
        return self.values["name"] if self.name_edited else self.name_default()

    # Show paths under the host's home folder as ~/...
    def short(self, path):
        home = self.host.home
        if home and (path == home or path.startswith(home + "/")):
            return "~" + path[len(home):]
        return path

    def expand(self, path):
        home = self.host.home
        if home and (path == "~" or path.startswith("~/")):
            return home + path[1:]
        return path

    # Field editing. A field you move into is "selected": typing replaces it.
    def enter_field(self):
        f = FIELDS[self.focus]
        value = self.name_value() if f == "name" else self.values[f]
        self.text = self.short(value) if f == "dir" else value
        self.cursor = len(self.text)
        self.touched = False
        self.hl = None
        self.scroll = 0

    def suggestions(self):
        f = FIELDS[self.focus]
        if f == "host":
            return fuzzy(self.text, self.host_names) if self.touched else self.host_names
        if f == "session":
            opts = self.session_options()
            return fuzzy(self.text, opts) if self.touched else opts
        if f == "dir":
            return self.dir_suggestions()
        return []

    def dir_suggestions(self):
        h = self.host
        text = self.text if self.touched else ""
        if text.startswith(("/", "~", ".")):
            parent, part = (text, "") if text.endswith("/") else (os.path.dirname(text) or ".", os.path.basename(text))
            if parent.startswith("."):
                parent = os.path.join(self.short(self.values["dir"]), parent)
            listing = h.list_dir(parent if parent else "/")
            if not listing:
                return []
            base = parent if parent.endswith("/") else parent + "/"
            names = [e["name"] for e in listing.get("entries", []) if not e.get("file")]
            if not part.startswith("."):
                names = [n for n in names if not n.startswith(".")]
            out = [base + n for n in fuzzy(part, names)] if part else [base + n for n in names]
            if text.endswith("/") and len(text) > 1:
                out.insert(0, text.rstrip("/"))
            return out
        words = text.lower().split()
        paths = h.zoxide
        if words:
            paths = [p for p in paths if zoxide_match(p, words)]
        return [self.short(p) for p in paths]

    def commit(self):
        """Store the focused field's value. Return False when it is not valid."""
        f = FIELDS[self.focus]
        sugg = self.suggestions()
        pick = sugg[self.hl] if self.hl is not None and self.hl < len(sugg) else None
        if f in ("host", "session"):
            if pick is None and self.touched and sugg:
                pick = sugg[0]
            if pick is None:
                return True
            if f == "host" and pick != self.values["host"]:
                self.values["host"] = pick
                self.load_host(pick)
                self.values["session"] = self.default_session()
                self.values["dir"] = self.origin_cwd if pick == LOCAL else "~"
            elif f == "session":
                self.values["session"] = pick
            return True
        if f == "dir":
            value = pick if pick is not None else self.text
            value = value.strip() or "~"
            if not value.startswith(("/", "~")):
                # Words with no match and no path: keep the old directory.
                self.status = "No directory matches '%s'." % value
                return False
            self.values["dir"] = self.expand(value.rstrip("/") or "/")
            return True
        if f == "name":
            if self.touched:
                self.values["name"] = self.text.strip()
                self.name_edited = bool(self.values["name"])
            return True
        return True

    def move(self, step):
        if self.commit():
            self.focus = max(0, min(len(FIELDS) - 1, self.focus + step))
            self.enter_field()

    def type_char(self, ch):
        if not self.touched:
            self.text, self.cursor, self.touched = "", 0, True
        self.text = self.text[: self.cursor] + ch + self.text[self.cursor:]
        self.cursor += len(ch)
        self.hl = 0
        self.scroll = 0
        self.status = ""

    def backspace(self, word=False):
        if not self.touched:
            self.text, self.cursor, self.touched = "", 0, True
        elif word:
            left = self.text[: self.cursor].rstrip("/ ")
            cut = max(left.rfind("/"), left.rfind(" ")) + 1
            self.text, self.cursor = self.text[:cut] + self.text[self.cursor:], cut
        elif self.cursor > 0:
            self.text = self.text[: self.cursor - 1] + self.text[self.cursor:]
            self.cursor -= 1
        self.hl = 0

    def complete(self):
        """Tab in the directory field: put the chosen folder in the text and keep going."""
        sugg = self.suggestions()
        if not sugg:
            return
        pick = sugg[self.hl or 0]
        self.text = pick.rstrip("/") + "/"
        self.cursor = len(self.text)
        self.touched = True
        self.hl = 0

    def submit(self):
        if not self.commit():
            self.enter_field()
            return None
        host = self.values["host"]
        name = self.name_value() or "shell"
        directory = self.values["dir"]
        cwd_args = ["-c", directory]
        if directory.startswith("~"):
            if self.host.home:
                cwd_args = ["-c", self.expand(directory)]
            elif directory == "~":
                cwd_args = []  # A new pane starts in the home folder anyway.
            else:
                self.status = "Unknown home folder on %s. Type an absolute path." % host
                self.enter_field()
                return None
        sid = self.session_id()
        try:
            if sid:
                created = rex_json(host, "window", "new", "-s", sid, name, *cwd_args)
                wid = created.get("window_id")
            else:
                created = rex_json(host, "new", name, *cwd_args, "--window", name)
                sid = created.get("session_id")
                wid = ((created.get("initial_windows") or [{}])[0]).get("window_id")
        except (RexError, ValueError) as e:
            self.status = str(e)
            self.enter_field()
            return None
        if self.client:
            args = ["-C", self.client, "do", "session.select", "session_id=" + sid] + (["window_id=" + wid] if wid else [])
            try:
                subprocess.run(["rex"] + args, capture_output=True, timeout=8)
            except subprocess.TimeoutExpired:
                pass
        return True

    # Drawing
    def draw(self, scr):
        scr.erase()
        rows, cols = scr.getmaxyx()
        w = max(10, cols - 4)

        def put(y, x, s, attr=0):
            if 0 <= y < rows and x < cols:
                try:
                    scr.addnstr(y, x, s, max(0, cols - x - 1), attr)
                except curses.error:
                    pass

        put(1, 2, "New tab or session", curses.A_BOLD)
        sid = self.session_id()
        labels = {"host": "Host", "session": "Session", "dir": "Directory", "name": "Tab name" if sid else "Session name"}
        cursor_pos = None
        for i, f in enumerate(FIELDS):
            y = 3 + i
            focused = i == self.focus
            put(y, 2, ("› " if focused else "  ") + labels[f].ljust(13), curses.A_BOLD if focused else curses.A_DIM)
            x = 17
            if focused:
                attr = curses.A_REVERSE if not self.touched and self.text else curses.A_UNDERLINE
                put(y, x, self.text or " ", attr)
                cursor_pos = (y, x + self.cursor)
            else:
                value = self.name_value() if f == "name" else (self.short(self.values[f]) if f == "dir" else self.values[f])
                put(y, x, value)
            if f == "host" and self.host.loading:
                put(y, x + len(self.values["host"]) + 2, "loading…", curses.A_DIM)

        top = 8
        put(top, 2, "─" * w, curses.A_DIM)
        sugg = self.suggestions()
        room = max(1, rows - top - 4)
        hl = self.hl if self.hl is not None else -1
        if hl >= self.scroll + room:
            self.scroll = hl - room + 1
        if 0 <= hl < self.scroll:
            self.scroll = hl
        for k, s in enumerate(sugg[self.scroll: self.scroll + room]):
            idx = self.scroll + k
            put(top + 1 + k, 2, ("› " if idx == hl else "  ") + s, curses.A_REVERSE if idx == hl else 0)
        if not sugg and FIELDS[self.focus] == "dir" and self.host.loading:
            put(top + 1, 4, "Reading directories…", curses.A_DIM)

        msg = self.status or self.host.error
        if msg:
            put(rows - 3, 2, msg)
        keys = "↵ next  ⇧⇥ back  ↑↓ choose  ⇥ complete  ⌘↵ open  esc cancel"
        put(rows - 2, 2, keys, curses.A_DIM)
        if cursor_pos:
            try:
                scr.move(*cursor_pos)
            except curses.error:
                pass
        scr.refresh()

    def run(self, scr):
        curses.use_default_colors()
        # Raw mode turns off flow control, so Ctrl+S (the submit key) reaches the form.
        curses.raw()
        try:
            curses.curs_set(1)
        except curses.error:
            pass
        scr.keypad(True)
        scr.timeout(150)
        while True:
            self.draw(scr)
            try:
                key = scr.get_wch()
            except curses.error:
                continue  # Timeout: redraw, so background loads show up.
            if key in SUBMIT_KEYS:
                if self.submit():
                    return
            elif key in ("\n", "\r", curses.KEY_ENTER):
                if self.focus == len(FIELDS) - 1:
                    if self.submit():
                        return
                else:
                    self.move(1)
            elif key in ("\x1b", "\x03"):  # Esc or Ctrl+C
                return
            elif key == "\t":
                if FIELDS[self.focus] == "dir":
                    self.complete()
                else:
                    self.move(1)
            elif key == curses.KEY_BTAB:
                self.move(-1)
            elif key in (curses.KEY_DOWN, "\x0e"):  # Down or Ctrl+N
                n = len(self.suggestions())
                if n:
                    self.hl = 0 if self.hl is None else min(n - 1, self.hl + 1)
            elif key in (curses.KEY_UP, "\x10"):  # Up or Ctrl+P
                if self.hl:
                    self.hl -= 1
            elif key in (curses.KEY_BACKSPACE, "\x7f", "\x08"):
                self.backspace()
            elif key == "\x17":  # Ctrl+W
                self.backspace(word=True)
            elif key == "\x15":  # Ctrl+U
                self.text, self.cursor, self.touched, self.hl = "", 0, True, 0
            elif key == curses.KEY_LEFT:
                self.touched = True
                self.cursor = max(0, self.cursor - 1)
            elif key == curses.KEY_RIGHT:
                self.touched = True
                self.cursor = min(len(self.text), self.cursor + 1)
            elif isinstance(key, str) and key.isprintable():
                self.type_char(key)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--client", default="")
    p.add_argument("--session", default="")
    p.add_argument("--cwd", default="")
    args = p.parse_args()
    os.environ.setdefault("ESCDELAY", "25")
    # A Rex action may start this with no locale. Curses needs UTF-8 to draw the arrows.
    for loc in ("", "en_US.UTF-8", "C.UTF-8"):
        try:
            locale.setlocale(locale.LC_ALL, loc)
        except locale.Error:
            continue
        if "utf" in (locale.getpreferredencoding(False) or "").lower():
            break
    form = Form(args)
    form.values["session"] = form.default_session()
    form.enter_field()
    curses.wrapper(form.run)


if __name__ == "__main__":
    main()

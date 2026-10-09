# Session Notes

## 2026-09-24 — Milestone 1: Capture (refactor + cleanup)

**Current shape of `lc-gtd-capture.el`** (top to bottom)
- `lc-gtd-directory`: where the GTD files live.
- `lc-gtd-capture--template`: entry into inbox.org, with
  `:after-finalize #'lc-gtd-capture--delete-frame`.
- Commands: `lc-gtd-capture-schedule-today` (F7) and `lc-gtd-capture-done`
  (F8). F8 refiles to org-gtd-tasks.org if scheduled, then
  `org-capture-finalize`. The helper `lc-gtd-capture--refile-to-file` saves
  the destination.
- `lc-gtd-capture-mode-map` (F5 cancel, F6 schedule, F7 today, F8 done) and
  `lc-gtd-capture-mode`: sets the header line via `substitute-command-keys`.
- Mode hook that calls `evil-emacs-state`.
- `lc-gtd-capture--frame-name` (defconst), `lc-gtd-capture--delete-frame`,
  and the entry point `lc-gtd-capture`, which opens the dedicated frame.

**What changed and why**
- Reordered forms bottom-up (building blocks first, entry point last). The
  keymap must come before `define-minor-mode`.
- Header line: replaced `map-keymap` + key-label alist with
  `substitute-command-keys` (same approach as org-capture and
  org-gtd-clarify). The old one depended on the keymap's internal order,
  tied labels to keys instead of commands, and broke on multi-key bindings.
  Uses `concat` so auto-indent can't add whitespace inside the string.
  Header save/restore was dropped: the buffer dies with the capture.
- Bug fix: F8 never called finalize, which left a `CAPTURE-inbox.org` buffer
  behind (it refiled inbox→inbox just to get a save). F8 now refiles only
  if scheduled, then finalizes. Finalize saves inbox.org itself.
  - Chose refile-then-finalize over org-capture-refile's pattern (finalize,
    then refile via a marker). Simpler; it relies on finalize handling an
    empty capture region, which is fine for this template.
- Frame closing: replaced the buffer-local owning-frame variable and the
  `:around` advice on `org-capture-kill` and on our own command with the
  template's `:after-finalize`. F5 and F8 both go through finalize, so this
  covers both, and it only fires for our template. The frame recognizes
  itself by name.
  - NOT using the template `:hook` to turn on the mode: it runs before
    `org-capture-mode`, which then overwrites `header-line-format`.
- Renames: one `lc-gtd-` prefix. `--` only on private helpers; interactive
  commands are public (`lc-gtd-capture-done`, `-schedule-today`); the entry
  point is `lc-gtd-capture` (was `lc-org-gtd-capture-frame`). The frame
  name string is still "lc-org-gtd-capture".
- Docstrings on all functions; `M-x checkdoc` is clean apart from the file
  header/footer.
- `~/.emacs.d/init.el`: backup (`~`), auto-save (`#..#`) and lock (`.#`)
  files now go to `~/.emacs.d/backups/` and `~/.emacs.d/auto-saves/`. Old
  ones were deleted from this project.

**Elisp concepts covered**
- Load order: top-level forms run in sequence; `defvar` before use.
- `defvar`/`defvar-keymap` don't reassign on re-eval, but `defconst` does.
  After changing bindings: `(makunbound 'lc-gtd-capture-mode-map)` then
  `eval-buffer`, or restart. Advice survives re-eval (`advice-remove`).
- `substitute-command-keys`: `\\<map>` picks the keymap and `\\[cmd]`
  becomes that command's key. Without `\\<map>` it searches every active
  map.
- `define-minor-mode`: keywords must come before the body; it creates
  `-hook`/`-on-hook`/`-off-hook`. Code you own goes in the body, and hooks
  are for others.
- Quoting: `'(f ...)` is data, never called. Backquote + comma evaluate one
  piece of an otherwise-quoted list.
- `if` (single THEN form) vs `when` (implicit progn); `prog1`, `apply`,
  `&rest`; `:around` advice.
- Plists (template properties), markers, indirect buffers.
- Strings: backslash-newline is a continuation, and `"\ "` is dropped.
- Docstring conventions (imperative first line, ARGS in caps,
  `` `sym' `` links).

**Next steps**
- Proposed, not applied: file header/footer
  (`-*- lexical-binding: t; -*-`, `;;; Commentary:`, `;;; Code:`,
  `(require 'org)`, `(require 'org-capture)`, `(provide 'lc-gtd-capture)`).
- Guard `evil-emacs-state` with `fboundp`, or move that hook into
  use-package.
- Cosmetic: tab on the template's `:after-finalize` line; double blank line
  after the minor mode.
- Open question: `with-selected-frame` vs `select-frame-set-input-focus`
  (why was the latter commented out?).
- Maybe rename the frame name string (check window-manager rules first).
- Pending user decisions: `#sample-task.org#` has an unsaved
  `TODO`→`DONE` edit (save it or discard it). Old top-level backups in
  `~/.emacs.d` (`init.el~`, `lc-theme.el~`, `lc-clisp-ide.el~`,
  `bookmarks~`).
- Later (Milestones 2/3): move `--refile-to-file` to a shared file as
  `lc-gtd--refile-to-file`.
- Milestone 1 is working end to end. Once the items above are settled, move
  to Milestone 2 (inbox processing).

## 2026-09-24 — Milestone 2: Inbox processing (design start)

**Decision**
- Inbox processing = a minor mode (`lc-gtd-inbox-mode`) that opens inbox.org
  and adds custom commands. Chosen over org-gtd's approach (copy each item
  into a separate clarify buffer + continuation loop) for simplicity.
- Started `lc-gtd-inbox.el` (keymap + mode + header line). It reuses
  commands from capture, so the next step is a shared `lc-gtd-utils.el`.

**Next step**
- Agree on the refactor (utils file contents, shared parent keymap,
  require/provide + load-path), then do it before building the inbox mode.

## 2026-09-25 — Milestone 2: utils refactor + inbox mode (working)

**Current shape**
- `lc-gtd-utils.el`: `lc-gtd-directory`; file-name defvars
  `lc-gtd-inbox-file` / `-tasks-file` / `-archive-file`; `lc-gtd--path`;
  `lc-gtd-schedule-today`; `lc-gtd-refile-to-file` (refile to top level of
  FILE, save FILE). Capture and inbox load it with `(load-file "./...")`,
  which only works when evaluated from this directory.
- `lc-gtd-inbox.el`: `lc-gtd-inbox--move-to` (refile + save inbox);
  commands `lc-gtd-inbox-trash` (F5: CNCL → archive), `-maybe` (F6:
  unscheduled → tasks), `-schedule` (F7: prompt date → tasks),
  `-schedule-today` (F8: today → tasks); `lc-gtd-inbox-mode` (header line,
  evil Emacs state); `lc-gtd-process-inbox` (new frame, inbox.org, mode on).
- Capture uses the utils constants; `:init-value nil` removed from both
  modes (it's the default).
- init.el: `org-todo-keywords` = TODO | DONE CNCL.
- Manual happy-path tests (capture C1-C4, inbox I1-I9) passed. Nothing
  committed yet.

**Decisions**
- Destination commands save inbox.org themselves; the refile helper only
  saves the destination (capture's buffer is indirect, can't be saved).
- Mode stays on in the inbox.org buffer after the frame closes. Rejected:
  indirect buffer per frame, `menu-item :filter` bindings.
- User's choices (don't re-suggest): inbox keys differ from capture; evil
  hook stays per file; no trash confirmation; header not cleared on mode
  off.

**Elisp concepts**
- Macro bodies: `(with-selected-frame frame)` with no body does nothing.
- Stale `defvar-keymap`: `C-M-x` on the defvar form (then on the
  `define-minor-mode`) re-assigns it; check with `C-h k`.
- Buffers outlive frames; minor modes are buffer-local.
- Org copies `org-todo-keywords` into buffer-locals: `M-x org-mode-restart`.
- `load-file` vs `load` vs `require`/`provide`/`load-path`.
- Minor mode from Lisp: no arg = on, -1 = off. `:init-value` only reflects
  the initial state, it doesn't run the mode.
- Commands need `(interactive)`; args before `&optional` are required
  (`(org-schedule nil)`, not `(org-schedule)`).
- `org-refile` works in the target buffer and returns to the source, so
  `(save-buffer)` afterwards saves the inbox.

**Open question (start of Milestone 3): separate scheduled from
unscheduled in org-gtd-tasks.org**
- A (recommended): `* Calendar` / `* Someday/Maybe` headings; helper gets
  `&optional heading`, position via `(org-find-olp (list path heading))`
  as RFLOC pos. Headings must exist; move existing items once by hand.
- B: one file per list (just new defvars).
- C: keep flat, separate at view time (agenda, `org-sort`, sparse tree).
- Trade-off: A/B need moving items when they change category; C doesn't.
- Also undecided: F6 = Someday/Maybe only, or add a Next Actions section
  and key (GTD treats them as different lists).
- User said "that's fine" for now; revisit at start of next session.

**Deferred by user**
- Whitespace/tabs cleanup; `require`/`provide` + `load-path` +
  `lexical-binding` headers.
- Stray `#lc-gtd-inbox.el#`, `.#lc-gtd-inbox.el`, `lc-gtd-inbox.el~` in
  the repo: init.el backup redirect not active yet (restart Emacs);
  consider a `.gitignore`.

## 2026-09-26 — Milestone 3: agenda "done" command (working)

**What changed**
- `lc-gtd-utils.el`: new `lc-gtd-move-to` (refile to FILE + save current
  buffer), moved from `lc-gtd-inbox--move-to`. Inbox commands call it.
- New `lc-gtd-agenda.el`: `lc-gtd-agenda-done` (F8 in agenda). Jumps to
  the entry via `org-hd-marker`, sets it to DONE, moves it to the archive
  (saves both files), then `org-agenda-redo`. Non-task lines get
  `org-agenda-error`.
- `~/.emacs.d/init.el`: `use-package org-agenda` now only loads utils +
  agenda files (`:init`) and binds F8. `org-agenda-files` (tasks file only,
  via `lc-gtd--path`) and `org-log-done 'time` moved to `use-package org`.
- Batch-tested: agenda F8 (archive gets DONE + CLOSED, both files saved,
  line gone from agenda), F8 on the date header (user-error), and inbox
  trash via the shared helper.

**Decisions**
- The old version called `org-todo`/`org-refile` in the `*Org Agenda*`
  buffer, which fails with "Before first headline". Fix: act at the marker.
  Chose `org-todo` inside `org-with-point-at` + `org-agenda-redo` over
  org-gtd's `org-agenda-todo` (it updates lines in place, but we remove
  the item anyway).
- Replaced the COMPLETED property (active `<...>` stamp, which would show
  up in the agenda) with the built-in `org-log-done 'time` → `CLOSED:
  [...]`. It also stamps inbox trash (CNCL is a done state).
- `org-agenda-files` = tasks file only. The directory form pulled in inbox,
  archive, and sandbox, so archived items would still show up.
- `lc-gtd-agenda.el` doesn't load utils itself: `(load-file "./...")` is
  relative to `default-directory`, so it breaks when loaded from init.el.
  The deferred require/provide + load-path cleanup would fix this.

**Elisp concepts**
- Agenda lines carry text properties (`org-hd-marker`, `org-marker`)
  pointing at the real heading; `org-get-at-bol` reads them.
- `org-with-point-at MARKER body`: runs body in the marker's buffer at its
  position; `save-buffer` inside it saves that buffer.
- use-package: keyword order in the source doesn't matter (runs `:preface`
  → `:init` → load → `:config`); `:bind` implies `:defer t`, and `:map`
  bindings wait for the package to load.
- Active `<...>` timestamps create agenda entries; inactive `[...]` don't.

**Open questions / next step**
- Still undecided (from 2026-09-25): split org-gtd-tasks.org into
  `* Calendar` / `* Someday/Maybe`, one file per list, or keep it flat?
- Repeating tasks: `org-todo "DONE"` on a `+1w` repeater resets it to
  TODO and shifts the date, and F8 would then archive it. Handle this if
  you start using repeaters.
- Restart Emacs (or eval the two use-package forms) to pick up init.el.

## 2026-10-08 — Projects (brainstorm only, nothing decided or written)

**User's draft AC for `lc-gtd-projects`** (project = TODO with subtasks)
- Capture adds statistic cookies to the parent; parent blocked until
  children are done; completing a subtask prompts to schedule the next;
  subtasks are archived only with the whole project.

**Gaps raised in review (all open)**
- Existing commands act on the heading at point, so they split projects:
  `lc-gtd-capture-done` (scheduled check + refile at point),
  the inbox F5-F8 commands, `lc-gtd-agenda-done` (archives the lone
  subtask). Inbox trash would also be refused once the parent is blocked.
- Projects can also be born in the inbox or in the tasks file, not only in
  capture: wants one shared, idempotent "make this a project" helper.
- "Next item" implies sequential projects (`:ORDERED:`); parallel ones?
- End of project: who marks the parent DONE and archives the subtree?
- Aborted prompt leaves a project with no scheduled subtask. Under
  "unscheduled = someday/maybe" a stuck project, a someday project, and
  the waiting subtasks of an active one all look the same.
- Trigger: only in `lc-gtd-agenda-done`, or a hook that catches every
  `org-todo`?
- Built-ins to look at: `org-enforce-todo-dependencies` (needs
  `setopt`/`:custom`, plain `setq` after load does nothing),
  `org-agenda-dim-blocked-tasks`, `org-after-todo-statistics-hook`,
  `org-stuck-projects`, `%b` in `org-agenda-prefix-format`.
- Ties into the open tasks-file layout question (2026-09-25): projects
  don't fit `* Calendar` / `* Someday/Maybe` headings.
- "Note 2" in the user's draft wasn't in what was pasted.

**Next step**
- User picks answers for the gaps above, then we agree on an approach
  before any code. Projects aren't in the CLAUDE.md milestone list yet.

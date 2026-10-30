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

## 2026-10-09 — Projects: statistics cookie on capture and inbox

**What changed**
- `lc-gtd-utils.el`: `lc-gtd--is-project` (climb to the top heading, then
  `org-goto-first-child`) and `lc-gtd-insert-statistics` (adds ` [/]` to
  the top heading if it's a project). `lc-gtd-move-to` calls it before
  refiling. `lc-gtd-projects.el` is now just a comment.
- `lc-gtd-capture.el`: `lc-gtd-capture-done` calls it before the scheduled
  check, and the template has `:before-finalize #'lc-gtd-insert-statistics`.

**Decisions**
- `org-capture-finalize` runs `org-update-checkbox-count`, which rewrites
  the cookie to `[0/0]` on unscheduled projects (no checkboxes). Fix: run
  the helper again from the template's `:before-finalize`, which runs after
  that recount. Rejected `:COOKIE_DATA: todo` (user: the drawer clutters
  entries) and "cookie only when filing into tasks" (a parent-scheduled
  project with point on a subtask wasn't refiled).
- The helper has no `save-excursion` on purpose: leaving point on the
  project heading is what makes the inbox commands move the whole project.
- User's style choices (don't re-suggest): `lc-gtd--is-project` name,
  docstring wording, cookie regexp without the `%` form.

**Elisp concepts**
- `save-excursion`; `while` with an empty body (`org-up-heading-safe`);
  `string-match-p` and doubled backslashes in regexps;
  `org-edit-headline`; capture template hooks and their order
  (recount → `:before-finalize` → save → `:after-finalize`).

**Open / next step**
- Done: the recount now sits outside the `unless` in
  `lc-gtd-insert-statistics`. Batch-tested 20 capture/inbox/agenda cases;
  every project gets one correct cookie, lone tasks get none.
- Inbox F5 on a subtask marks only that subtask CNCL but archives the
  whole project (same cause as the agenda item below).
- Agenda F8 on a project subtask now archives the whole project (point
  moves to the parent inside `lc-gtd-move-to`). Decide what F8 should do
  for subtasks; simplest fix is calling the helper from the inbox commands
  instead of `lc-gtd-move-to`.
- Capture F8 with only a subtask scheduled leaves the project in the
  inbox (the scheduled check reads the project heading).
- `(load-file "./lc-gtd-utils.el")` is uncommented in `lc-gtd-capture.el`;
  init.el loads that file, so the relative path depends on where Emacs
  started.

**Later the same day: agenda F8 and projects**
- Rule (user): completing a subtask doesn't archive it; the project is
  archived only when the parent is complete.
- `lc-gtd-agenda-done` now marks DONE, climbs to the top heading, and
  archives only if that heading is done. A lone task is its own top
  heading, so it still archives. This replaces the "agenda F8 archives the
  whole project" item above.
- User chose manual parent completion (F8 on the parent) over
  auto-completing it after the last subtask. Catch: an unscheduled parent
  never shows in the agenda. `lc-gtd--children-done-p` (in
  `lc-gtd-agenda.el`) is written but unused; it's the piece for the
  automatic version.
- The not-archived path does `(save-buffer)`, so completing a subtask
  saves the tasks file. Batch-tested 5 cases, all pass with enforcement on.
- Relies on `org-enforce-todo-dependencies` being active: without it, F8
  on a parent with an open child marks it DONE and archives it. `org-todo`
  called from Lisp doesn't signal when blocked, it just messages.
- `load-file` → `require`/`provide` + `load-path` (+ optional umbrella
  `lc-gtd.el`) was proposed and deferred by the user.
  `lc-gtd-agenda.el` now also has a relative `load-file` line.
- New concepts: `progn`, `org-goto-sibling`, `org-entry-is-done-p`,
  `org-entry-blocked-p`, `org-after-todo-statistics-hook`.

**Schedule the next subtask (written by Claude at user's request, pending
user review)**
- `lc-gtd-agenda.el`: new `lc-gtd-agenda--schedule-next`, called in
  `lc-gtd-agenda-done` right after `(org-todo "DONE")`. From the completed
  subtask it goes to the parent, finds the first open child from the top,
  and prompts with `org-read-date` ("Schedule next: NAME"), then
  `org-schedule`.
- Decisions: "next" = first open subtask from the top (not the sibling
  after the completed one); no prompt if it already has a date; trigger
  only in `lc-gtd-agenda-done` (org-gtd uses
  `org-after-todo-state-change-hook`, which would also fire on inbox
  trash); C-g is caught with `condition-case ... (quit nil)` so the DONE
  is still saved and the agenda refreshed.
- Batch-tested 9 cases with `org-read-date` stubbed; the real calendar
  prompt has not been tried interactively yet.
- `org-enforce-todo-dependencies` works with `setq` only because nothing
  loads Org before that line in init.el; `setopt` is the order-proof form.
  Matters once lc-gtd files `(require 'org)`. User asked about loading
  lc-gtd from org-agenda's `:config`; advised against (capture/inbox would
  not exist until the agenda is first opened).
- Refactor candidate: the "first open child" walk could become a shared
  `lc-gtd--goto-first-open-child`.
- New concepts: `condition-case` and the `quit` signal, `org-read-date`,
  `format`, defcustom `:set` functions and `setopt`, use-package `:init`
  vs `:config` on a deferred package.

## 2026-10-13 — Milestone 4: Weekly cleanup (written by Claude, working)

**Context**
- User asked for `lc-gtd-cleanup.el` to be vibe coded. Claude proposed,
  the user picked the list buffer and "only F5-F8, there is no F9", then
  Claude wrote it.
- Code vs notes: `lc-gtd-agenda.el` has no `lc-gtd-agenda--schedule-next`
  or `lc-gtd--children-done-p` (both described on 2026-10-09), and the
  project test is now named `lc-gtd--is-project-p`.

**What changed**
- New `lc-gtd-cleanup.el` (300 lines). `M-x lc-gtd-cleanup` opens a frame
  with a generated read-only list (`lc-gtd-cleanup-mode`, a major mode
  derived from `special-mode`). Sections: inbox count, Overdue, Projects
  with no next step, Finished projects, Someday/maybe, Done not archived.
  Each line carries two text properties: `lc-gtd-marker` (its heading) and
  `lc-gtd-target` (the heading to schedule).
- Keys: F5 trash, F6 maybe (drop the date), F7 schedule, F8 done, RET open
  the entry, i inbox, g refresh, q quit, n/p move.
- `~/.emacs.d/init.el`: one more `load-file` line, after the capture one.

**Decisions**
- Four F-keys for five actions: "today" was folded into F7. It calls
  `org-read-date` itself so the prompt defaults to today, also on an
  overdue task (plain `org-schedule` would default to the old date). So
  F7 RET = today. F8 is done, as in capture and the agenda; in the inbox
  F8 is still "today". Claude's call, not yet confirmed by the user.
- A subtask is "ready" when it is open and has no open subtask of its own.
  A project has no next step when no ready subtask has a date, and F7 on
  that line schedules the first ready one.
- Done and trash on a subtask line only close that subtask. The tree is
  archived once the top heading is done (same rule as
  `lc-gtd-agenda-done`). Trash on a project cancels its open subtasks
  first, bottom-up, so Org doesn't block the parent. F8 on a project with
  open subtasks is refused with a message.
- Helpers stay private in the cleanup file (`--close`,
  `--cancel-subtasks`): the user didn't answer the "share them in utils"
  question, so the inbox and agenda files are untouched.
- No `lexical-binding` cookie, to match the other files (still deferred).
  The file was tested both with and without one.
- Rejected: block agenda + minor mode (`org-agenda-mode` runs
  `kill-all-local-variables` on every rebuild, which turns the minor mode
  off); `org-stuck-projects` (only one open keyword, and a `SCHEDULED:`
  regexp also matches finished subtasks, which keep that line); org-gtd's
  one-at-a-time someday review (queue state, temp buffers, LOGBOOK
  "Reviewed" lines).

**Testing**
- Batch only, on a scratch GTD directory: 54 checks covering every key in
  every section, the real date prompt, Evil (list starts in Emacs state),
  and loading before Org as init.el does. Not yet tried in a real frame.

**Open / next step**
- Bug, still there: `lc-gtd-inbox-trash` on a project with open subtasks.
  `org-todo "CNCL"` on the parent is blocked by
  `org-enforce-todo-dependencies`, but the move still runs, so the project
  lands in the archive as `TODO Proj [0/2]`.
- Refactor candidates: `lc-gtd-cleanup--close` repeats the body of
  `lc-gtd-agenda-done`; `lc-gtd-inbox-trash` could become
  `--cancel-subtasks` + `--close`, which fixes the bug above. Both belong
  in `lc-gtd-utils.el`.
- User to try it in a real frame and confirm the F7/F8 mapping.
- Left out: "Completed this week" section (optional, from the archive).

**Elisp concepts**
- Major vs minor mode; `define-derived-mode` and `special-mode`
  (read-only, `g` calls `revert-buffer-function`).
- Text properties: `propertize` to attach a marker to a line,
  `get-text-property` to read it back.
- Passing a function as an argument (`#'org-entry-is-todo-p`) and calling
  it with `funcall`; `apply` to spread a list over a function's arguments.
- `push` onto `(alist-get KEY ALIST)`, which creates the key when missing.
- Raw prefix argument from Lisp: `(org-schedule '(4))` is `C-u C-c C-s`.
- `with-eval-after-load` to run code once another package is loaded.
- `&rest _` for arguments a function has to accept but doesn't use.

## 2026-10-18 — Milestone 4: install + UI study guide for cleanup

**What changed**
- No code changes. Wrote a Claude Doc, "lc-gtd-cleanup: install and UI
  guide" (https://claude.ai/code/artifact/f1429e0d-edf0-4fc5-a652-a73ef9b76e55):
  prerequisites, install steps, smoke test, how the UI is built, org-gtd
  comparison, troubleshooting.

**Findings**
- init.el currently has all five lc-gtd `load-file` lines commented out.
- Needs Emacs 29.1+ (`defvar-keymap`, `pos-bol`) and Org 9.6+
  (`org-fold-show-context`); machine has 30.2 / 9.7.11.
- Batch smoke test with `-Q` (no Evil) passed: all six sections fill, F8
  on a done item creates org-gtd-archive.org. Real frame still untested.
- `evil-set-initial-state` is not autoloaded, so the
  `with-eval-after-load 'evil` wrapper is required.
- `lc-gtd-capture.el`'s `(load-file "./lc-gtd-utils.el")` fails when
  loaded from init.el outside the project dir.
- Inbox hook calls `evil-emacs-state` unguarded (breaks `i` without Evil).

**Refactor candidates raised**
- Shared dedicated-frame open/close helpers (capture, inbox, cleanup).
- `lc-gtd--map-subtree` for the three subtree walks in cleanup
  (`org-map-entries` scope `tree` also visits the heading itself).

**Open / next step**
- User to pick: key binding in init.el (guessed `C-c g r`) vs WM shortcut.
- Try the list in a real frame; confirm the F7/F8 mapping (still open).

## 2026-10-19 — Packaging: load with `require`

**What changed**
- New `lc-gtd.el`: umbrella file that requires the five modules and
  `(provide 'lc-gtd)`. init.el now only needs `(add-to-list 'load-path
  "~/dev/lc-gtd")` + `(require 'lc-gtd)` (already in init.el).
- Every module ends in `(provide 'lc-gtd-NAME)`. The `load-file` lines (live
  in capture, commented in inbox/agenda) became `(require 'lc-gtd-utils)`;
  cleanup also requires `lc-gtd-inbox` (its `i` key). The "init.el loads
  X first" comments were dropped: each file now states its own deps.
- Batch-tested with `-Q` from another directory: all six features load,
  utils loads once, the four entry commands exist, cleanup list renders.

**Decisions**
- No `(require 'org)` in our files. Org loads lazily (autoloads, or
  opening an .org file). Reason: init.el sets `org-enforce-todo-dependencies`
  with `setq` *after* `(require 'lc-gtd)`; if we loaded Org first, that
  `setq` would skip the defcustom's `:set` and enforcement would silently
  stay off. Alternative: require Org and switch init.el to `setopt`.
- Still no `lexical-binding` cookie / `;;; Code:` headers (deferred).

**Elisp concepts**
- `provide` registers a feature name in `features`; `require` loads
  FEATURE.el from `load-path` only if the feature isn't there yet (so
  utils loads once no matter how many files require it). `load-file`
  reloads every time and resolves `./` against `default-directory`.
- The file name must match the feature name for `require` to find it.

**Open / next step**
- init.el no longer binds F8 to `lc-gtd-agenda-done` in the agenda
  (notes from 2026-09-26 said it did); re-add under `use-package
  org-agenda` `:bind (:map org-agenda-mode-map ...)` if wanted.
- Previous open items still stand (inbox-trash bug on projects, F7/F8
  mapping, frame helpers refactor).

## 2026-10-19 — Whole-project quality review (no code changes)

**Scope**: every file except `lc-gtd-cleanup.el` (user is reviewing it by
hand). Findings were batch-checked where marked.

**Bugs / friction**
- Confirmed: inbox F5 on a project with open subtasks archives it as
  `TODO Proj [0/2]` (`org-todo` from Lisp fails silently when blocked).
- `org-agenda-files` isn't set anywhere in init.el (it used to be), and
  F8 isn't bound in the agenda, so Milestone 3 isn't wired up right now.
- Inbox frame has no quit key and no "inbox empty" ending.
- Hidden problem, confirmed: with a `lexical-binding: t` cookie,
  `lc-gtd-capture`'s `let` on `org-capture-templates` errors on the first
  call ("Defining as dynamic an already lexical var"). A bare
  `(defvar org-capture-templates)` fixes it without loading org-capture
  (verified).
- Capture: C-c C-c skips F8's "scheduled → tasks" move (`<remap>` fix).
- Inbox F6 "maybe" keeps any date the item already has.
- Resolved: agenda F8 on a `+1w` repeater resets it and doesn't archive
  (the `org-entry-is-done-p` check handles it). Verified.

**Refactor candidates**
- Shared close/archive rule in utils (`lc-gtd--close`,
  `lc-gtd--cancel-subtasks`, already private in cleanup): agenda-done and
  inbox-trash use it; fixes the trash bug.
- `lc-gtd--goto-top` for the repeated `(while (org-up-heading-safe))`;
  make the climb explicit in `lc-gtd-move-to` instead of a side effect of
  `lc-gtd-insert-statistics` (capture-done also relies on it).
- Shared dedicated-frame helpers (open + close-if-ours).
- Optional: header-line builder; named + `fboundp`-guarded Evil hook.

**Next step**: user picks which items to tackle and in what order.

**Later: "require doesn't work, can't capture"**
- Cause: the `emacs --daemon` started at 02:29 had loaded an older layout
  (`lc-gtd-core.el`, `lc-gtd-review.el`, a stub `lc-gtd-capture.el` with
  only requires). Those features stay in `features`, so `(require 'lc-gtd)`
  is a no-op and `lc-gtd-capture` (the Ctrl+Insert shortcut) is void.
  A fresh init loads everything (batch-checked); the code is fine.
- Fix: restart the daemon, or `delq` the stale features from `features`
  and `(require 'lc-gtd)` again (tested in batch).
- Concept: `require` loads once per session; while developing, reload a
  changed file with `load-file` / `eval-buffer`.

**Later: hide mode-only commands from M-x (written by Claude at user's
request)**
- Commands tagged with their mode via `(interactive nil MODE)`: inbox
  F5-F8 → `lc-gtd-inbox-mode`; `lc-gtd-capture-done` →
  `lc-gtd-capture-mode`; `lc-gtd-agenda-done` → `org-agenda-mode`;
  `lc-gtd-schedule-today` → `org-mode` (it's capture's F7).
- Both minor modes got `:interactive nil` (no longer commands; the entry
  points still turn them on). Catch: no M-x to turn the inbox mode off in
  inbox.org; use `M-: (lc-gtd-inbox-mode -1)` until a quit key exists.
- init.el: vertico `:custom` sets `read-extended-command-predicate` to
  `command-completion-default-include-p`; without it the tags don't filter
  M-x (`M-X` filters regardless).
- Batch-checked: outside our modes M-x offers only `lc-gtd-capture` and
  `lc-gtd-process-inbox` (+ `lc-gtd-schedule-today` in Org buffers); each
  mode adds its own keys; inbox F5/F6/F8 still work.
- Not done: cleanup (user's manual pass); `--` renames of utils helpers
  (cleanup calls `lc-gtd-move-to`).
- Concepts: `command-modes`, `read-extended-command-predicate`,
  `define-minor-mode :interactive`.

**Later: projects redesign (proposal only, waiting on user)**
- Problem: capture, inbox, agenda and cleanup each decide "is this project
  active / what does schedule act on / how to trash" differently. Verified:
  with init.el's `org-agenda-dim-blocked-tasks 'invisible`, a project
  scheduled on its parent is hidden from the agenda (blocked by its open
  subtasks). Capture F8 only files a project if the parent has the date.
  Real files have no projects yet (5 tasks, 0 subtasks): no migration.
- Proposed model: dates live on actions, never on the project heading;
  next action = first open leaf from the top; states derived (active /
  stuck / finished); one close/archive rule. One `lc-gtd-project.el`
  module that all four files use.
- org-gtd v4 for contrast: ORG_GTD/ID properties, NEXT keyword set by a
  state-change hook, dependency graph, and its own computed cookie text
  `[2/5][40%]` instead of Org's `[/]`.
- Open for user: (1) dates only on actions? (2) ask "close project?" after
  the last subtask, or keep fully manual? (3) someday projects: `:someday:`
  tag vs. stuck = someday. (4) cookie only when filed into tasks?

**Later: projects, user's decisions**
- Parents never get a date. Subtasks are done in order. A custom agenda
  view will show a parent (undated) once all its subtasks are done; agenda
  F8 on it already closes and archives it.
- Proposed (not applied yet): `lc-gtd--schedule-next` in utils, called
  from `lc-gtd-agenda-done` right after `(org-todo "DONE")`. Goes to the
  parent, walks children with `org-goto-first-child`/`org-goto-sibling` to
  the first open one, and if it has no date prompts "Next: NAME" via
  `org-read-date` + `org-schedule`. `condition-case ... (quit nil)` so C-g
  still saves the DONE. Explicit call rather than
  `org-after-todo-state-change-hook` (simpler; C-c C-t won't prompt).
  Batch-tested 6 cases (next undated, next dated, last step, lone task,
  out of order, C-g): all pass.
- Next: user writes/approves it, then the finished-parents agenda block.

**Later: schedule-next, user's simpler version**
- User proposed: if project, `org-goto-sibling`, then `y-or-n-p`, then
  `org-schedule`. Adopted, with two guards (batch-tested):
  `(> (org-current-level) 1)` instead of `lc-gtd--is-project-p` (on a
  parent, is-project-p is t, so it jumped to the next top-level task,
  scheduled it, and left the finished project unarchived), and
  `(org-entry-is-todo-p)` so a DONE/CNCL next sibling isn't scheduled.
- Accepted limits: only the immediate next sibling (a CNCL one stops it;
  weekly review shows the project as stuck); C-g in a prompt leaves the
  DONE unsaved until the next save. No `condition-case` (`n` is the skip).

**Later: schedule-next applied (Claude fixed the user's draft)**
- `lc-gtd-utils.el`: `lc-gtd--schedule-next` is now one
  `(when (and LEVEL>1 SIBLING OPEN Y/N) (org-schedule nil))`. The draft
  had the checks in the `when` body, so they ran but didn't gate anything
  (`n` still scheduled; CNCL siblings got dated).
- `lc-gtd-agenda.el`: `lc-gtd-agenda-done` calls it right after
  `(org-todo "DONE")`; docstring updated.
- Batch-tested 6 cases (y, n, CNCL sibling, last subtask, finished
  parent archived, lone task archived): all pass.
- Concept: `when` = `if` + `progn`; only the first form is the test.
- Next: custom agenda block for finished parents.

**Later: GTD agenda view (written by Claude at user's request)**
- User restored `(> (org-current-level) 1)` in `lc-gtd--schedule-next`.
- `lc-gtd-agenda.el`: `M-x lc-gtd-agenda` runs a block agenda from
  `lc-gtd-agenda--view` (let-bound into `org-agenda-custom-commands`, same
  trick as capture's templates). Blocks: TODAY (`agenda`, span day,
  overdue shows as "Sched. Nx", done ones skipped), SCHEDULED (open items
  dated after today, `scheduled-up`), PROJECTS (top-level headings with
  subtasks; `org-agenda-dim-blocked-tasks nil` for this block, otherwise
  init.el's `'invisible` hides every unfinished parent), MAYBE (undated
  lone tasks). `%b` breadcrumbs show "Proj / TODO step".
- The view sets `org-agenda-files` itself (shared settings), so it works
  without init.el and survives `org-agenda-redo`.
- F8 is bound in `org-agenda-mode-map` from the library
  (`with-eval-after-load 'org-agenda`), so it applies to every agenda.
- Skip functions: one helper `lc-gtd-agenda--skip-unless` (nil = keep,
  position = skip to next heading) + three predicates.
- Gotcha found: `ts-up` sorts by plain TIMESTAMP, not SCHEDULED; use
  `scheduled-up`.
- Batch-tested: layout, nothing hidden, F8 on header errors, F8 on a
  finished project archives it, F8 on a subtask offers the next one and
  it moves to SCHEDULED, redo works outside the let.
- Same lexical-binding trap as capture: if the cookie is added, the file
  needs `(defvar org-agenda-custom-commands)`.

**Later: bug, capture F6 moved the task to tasks without a date (fixed)**
- Cause: `org-capture` builds its buffer with `make-indirect-buffer ...
  'clone`, which copies inbox.org's buffer-local state, including
  `lc-gtd-inbox-mode` (left on after processing the inbox). The inbox map
  sits earlier in `minor-mode-map-alist` than the capture map, so F5-F8
  ran the inbox commands (F6 = inbox-maybe). The capture never finalized,
  leaving empty CAPTURE-*inbox.org buffers. Confirmed in the daemon.
- Fix: `lc-gtd-capture` turns `lc-gtd-inbox-mode` off in the capture
  buffer (only that buffer; inbox.org keeps it) before turning
  `lc-gtd-capture-mode` on. Batch-tested before/after; F6+F8, F7+F8, F8
  all work, no capture buffers left.
- An inbox quit key alone wouldn't fix it: capturing while the inbox frame
  is open has the same problem.
- Concepts: indirect/clone buffers, minor-mode keymap precedence.

**Later: M-x hiding reverted (user's request)**
- User didn't like `read-extended-command-predicate`. Removed it from
  init.el (vertico back to just `:init (vertico-mode 1)`), and removed the
  rest of that refactor: every `(interactive nil MODE)` is `(interactive)`
  again, and both minor modes lost `:interactive nil` (they're commands
  again). Don't re-suggest the predicate.
- Kept: the capture fix that turns `lc-gtd-inbox-mode` off in the capture
  buffer (unrelated; it's about keymaps, not M-x).

**Later: "Org's default keys are gone"**
- Not caused by the revert. `org-mode-map` is intact; init.el's Evil
  `:bind` puts `("C-c" . kill-ring-save)` in `evil-emacs-state-map` (and
  insert/visual). Evil state maps sit in `emulation-mode-map-alists`, above
  every mode map, and Org buffers start in Emacs state, so the whole C-c
  prefix (C-c C-t, C-c C-s, C-c C-c in capture...) is shadowed. The line
  is in the 02:27 init.el backup too. Options offered, user to pick.
- Follow-up: compared every `C-c` binding in the daemon's `org-mode-map`
  with `emacs -Q`: none missing (`C-c C-o` → `org-open-at-point` is
  there). A restart wouldn't help; the shadow comes from init.el.

**Later: header line in the GTD agenda view**
- `lc-gtd-agenda--set-header` on `org-agenda-finalize-hook` (added in the
  same `with-eval-after-load 'org-agenda` as the F8 binding). Shows
  "<f8>: done   RET: open   g: refresh   q: quit".
- Why a hook: every agenda build/refresh runs `org-agenda-mode`, which
  kills buffer-local variables, so a header set once disappears on `g` or
  after F8. The finalize hook runs at the end of each build.
- Only our view: checks `org-agenda-name` against the view's description
  (`(nth 1 lc-gtd-agenda--view)`, "GTD"); Org sets that name after the
  mode reset. Batch-tested: shown on build, kept after F8 + refresh, not
  shown in a plain `org-agenda-list`.

**Later: agenda F-keys (F5 refresh, F6 cancel, F7 schedule, F8 done)**
- `lc-gtd-agenda.el`: `lc-gtd-agenda-done` became a wrapper around new
  `lc-gtd-agenda--close KEYWORD` (close, offer next subtask, archive the
  tree once the top heading is closed, save, redo). New
  `lc-gtd-agenda-cancel` (cancels a project's open subtasks first, then
  `--close "CNCL"`) and `lc-gtd-agenda-schedule` (prompt names the
  heading; on a project it schedules the first open subtask instead;
  user-error if none). F5 = `org-agenda-redo-all`.
- `lc-gtd-utils.el`: new `lc-gtd--cancel-subtasks` (one level, walks
  children with `org-goto-first-child`/`org-goto-sibling`).
- Header: F5 shown with the literal-key syntax ``\\`<f5>'`` because
  `\\[org-agenda-redo-all]` picks `g` (substitute-command-keys prefers
  plain-character keys).
- Batch-tested: F7 on maybe item / stuck project / finished project
  (error), F6 on lone task / subtask (offers next) / project (whole tree
  CNCL + archived), F8 on finished project, F5.
- Follow-ups: inbox F5 bug can now use `lc-gtd--cancel-subtasks`;
  cleanup still has its own `--cancel-subtasks` copy.

**Later: TODAY [done/total] counter and DONE section**
- Order now TODAY [n/m], SCHEDULED, DONE, PROJECTS, MAYBE.
- DONE block: `todo "DONE"` over tasks + archive (block-local
  `org-agenda-files` from `lc-gtd-agenda--done-files`, which drops files
  that don't exist so Org never prompts), skip unless CLOSED today.
  Two files because closed lone tasks/projects are archived but closed
  subtasks of open projects stay in the tasks file.
- Counter: the header setting is a form, `(lc-gtd-agenda--today-header)`,
  re-evaluated on every build. done = DONE entries closed today (both
  files), total = done + open TODOs scheduled today or earlier. Counted
  with `org-map-entries` (match "/DONE", "/TODO") via
  `lc-gtd-agenda--count`. CNCL counts in neither.
- Depends on `org-log-done 'time` (init.el) for the CLOSED stamp.
- Batch-tested: [2/5] → F8, F8, F6 → [4/4]; yesterday's and CNCL items
  excluded; works with no archive file.
- Then removed the counter (user: rely on the DONE section). TODAY's
  header is plain "TODAY" again; `--today-header`, `--count` and `--due-p`
  deleted. DONE section unchanged.

**2026-10-20 (Milestone 3): reuse the agenda frame**
- `lc-gtd-agenda.el`: new `lc-gtd-agenda--frame` finds a live frame
  named `lc-gtd-agenda--frame-name` (`seq-find` over `frame-list`,
  comparing `(frame-parameter f 'name)`). `lc-gtd-agenda` now focuses
  `(or (lc-gtd-agenda--frame) (make-frame ...))` with
  `select-frame-set-input-focus`, then always rebuilds the view.
- Why rebuild instead of only focusing: after `q` the frame can be left
  showing another buffer; rebuilding also refreshes it.
  `with-selected-frame` dropped: the frame is already selected, and the
  macro would switch back to the old frame afterwards.
- Concepts: `seq-find`, `frame-parameter`, `or` as "first non-nil",
  `if-let*` (discussed as the alternative).

**2026-10-21 (Milestone 3): only clear windows in a new agenda frame**
- `lc-gtd-agenda`: binds `existing` to `(lc-gtd-agenda--frame)` before
  focusing, and only calls `delete-other-windows` `(unless existing)`.
  Merged both bindings into one `let`.
- Why: a reused frame keeps the user's layout. `org-agenda-prepare-window`
  just selects the agenda window if it's already shown, so no extra split.
  Edge case: if that frame now shows another buffer, the default
  `reorganize-frame` will split it. Alternative if that's annoying: check
  whether the agenda buffer is visible instead of whether the frame existed.
- Concepts: capture a value before `or` loses which branch produced it;
  `unless`.

**2026-10-21 (Milestone 3): focus a newly made agenda frame**
- Bug: calling `lc-gtd-agenda` from another frame made the new frame but
  didn't focus it (GNOME Wayland, X11 Emacs via XWayland).
- Cause: `make-frame` waits only `x-wait-for-event-timeout` (0.1 s) for
  MapNotify; the frame isn't marked visible yet, and `x_ewmh_activate_frame`
  (xterm.c) only sends the focus request for visible frames.
- Fix: let-bind `x-wait-for-event-timeout` to 1.0 around `make-frame`
  (an upper bound, not a fixed delay).
- Fallback if it still fails: Mutter focus-stealing prevention.
- Concepts: `let` on a special variable = dynamic binding, also seen by C
  code called inside it.
- Reverted the same day at the user's request: the
  `x-wait-for-event-timeout` binding is gone, so a new agenda frame may
  again not get focus. Diagnosis above still applies if we revisit it.

**2026-10-26 (Milestone 3): save the tasks file before archiving**
- `lc-gtd-agenda--close`: `(save-buffer)` now runs right after
  `lc-gtd--schedule-next`, before the move. The `if`'s else-branch save
  was then redundant, so it became a `when`. `lc-gtd-move-to` still saves
  after the refile (the refile removes the entry again).
- Batch-tested: on a lone task, the file on disk already has DONE when the
  refile starts.
- Not done: `C-g` at the "Schedule …?" prompt quits and skips the save
  (true before too). Fix if needed: also save before `--schedule-next`.
  `lc-gtd-cleanup.el` has the same close/archive shape and was left as is;
  could share a helper in utils.
- Concepts: forms in a body run in order, and a `nil` return doesn't stop
  them (only non-local exits do); `if` vs `when`.

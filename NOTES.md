# Session Notes

## 2026-09-24 — Milestone 1: Capture

**What changed**
- `lc-gtd-capture.el`: reordered top-level forms only (no code edits). Order is
  now: config → capture template → capture-buffer commands → minor mode
  (keymap, labels, header line, mode, hooks) → dedicated frame (owning-frame
  var, advice, `lc-org-gtd-capture-frame` entry point).
- Created this `NOTES.md` (didn't exist yet).

**Design decisions**
- Bottom-up order (building blocks first, entry point last), grouped by
  concern. Alternative considered: entry point at top for top-down reading;
  rejected because Elisp convention and the byte-compiler prefer variables
  defined before use.
- The keymap must stay above `define-minor-mode`: `:keymap` with a symbol
  reads that variable's value when the mode is defined.

**Elisp concepts**
- Load order: top-level forms run in sequence when the file loads; function
  calls are resolved at call time, but `defvar`s should precede their users.

**Open questions / next steps**
- Suggested (not applied): `lexical-binding` cookie, `require`/`provide`,
  single source of truth for keys + labels, calling frame-close directly
  instead of advising our own function, named hook functions, look at
  `org-capture-refile`.

## 2026-09-24 (cont.) — Milestone 1: header line

**What changed**
- `lc-gtd-capture-mode` now sets `header-line-format` once, on enable, from
  `substitute-command-keys` instead of `(:eval (lc-gtd-capture-mode--header-line))`.

**Design decisions**
- `substitute-command-keys` (same approach as org-capture and
  org-gtd-clarify) over `map-keymap` + key-label alist. The old version
  depended on how keymaps store bindings internally for its display order,
  tied labels to keys instead of commands, and broke on multi-key bindings.
  A single data list driving both the keymap and the header was rejected as
  overkill for four keys.

**Elisp concepts**
- `\\<map>` / `\\[command]` in `substitute-command-keys`; without `\\<map>`
  it searches every active keymap (it found org-capture's `C-c C-k`).
- `define-minor-mode` keyword args must come before any body form.
- A quoted form `'(f ...)` is data and is never called.
- Backslash-newline in a string is a line continuation.

**Next steps**
- Delete the now-unused `lc-gtd-capture-mode--key-labels` and
  `lc-gtd-capture-mode--header-line`.
- Add an `fboundp` guard for `evil-emacs-state`.

## 2026-09-24 (cont.) — Milestone 1: finishing captures and closing the frame

**What changed**
- `lc-gtd-capture--process-item` (F8): refiles only when the item is scheduled,
  then always calls `org-capture-finalize`.
- Template gained `:after-finalize #'lc-gtd-capture--delete-frame`. The new
  helper deletes the selected frame if it's named "lc-org-gtd-capture".
- Removed: the `--owning-frame` buffer-local, the `--close-owning-frame`
  `:around` advice, both `advice-add`s, and the setq in the entry point.
- Header save/restore dropped: the buffer dies with the capture, so the
  mode is never turned off on a live buffer.

**Design decisions**
- Bug found: the old F8 never finalized, so it left a `CAPTURE-inbox.org`
  buffer behind. It had also refiled inbox→inbox just to get a save.
- Refile *before* finalize (not the finalize-then-refile-by-marker pattern
  `org-capture-refile` uses). It's simpler, and finalize then saves inbox.org
  with the item already removed. The catch: it depends on finalize coping
  with an empty capture region, which is fine for this template.
- Close the frame from the template's `:after-finalize` rather than with
  advice or the global `org-capture-after-finalize-hook`. F5
  (`org-capture-kill`) and F8 both go through finalize, and this only fires
  for our template.
- Template `:hook` is NOT used to turn on the mode: it runs before
  `org-capture-mode`, which then overwrites `header-line-format`.

**Elisp concepts**
- `:around` advice, `&rest`, `apply`, `prog1`; advice persists across
  `defun` re-evaluation (use `advice-remove`).
- Plists (template properties), markers, indirect buffers.
- `if` (one THEN form) vs `when` (implicit progn).
- `concat` vs backslash-newline for long strings (auto-indent safety).

**Next steps**
- `defconst` for the frame name (appears twice).
- Docstrings on the helper/command functions.
- `fboundp` guard for `evil-emacs-state`.
- Decide `with-selected-frame` vs `select-frame-set-input-focus`.

## 2026-09-24 (cont.) — Milestone 1: renames

- Added `lc-gtd-capture--frame-name` (`defconst`), used by `make-frame` via
  backquote and by `--delete-frame`.
- Renamed: `lc-org-directory` → `lc-gtd-directory`,
  `lc-gtd-capture-template` → `lc-gtd-capture--template`,
  `lc-gtd-capture--process-item` → `lc-gtd-capture-done`,
  `lc-gtd-capture--schedule-today` → `lc-gtd-capture-schedule-today`,
  `lc-org-gtd-capture-frame` → `lc-gtd-capture` (entry point).
- Why: one `lc-gtd-` prefix; `--` only for private helpers; interactive
  commands are public so they can be found with `M-x` and rebound.
- Frame name string left as "lc-org-gtd-capture" (window-manager rules may
  match on it).
- Concepts: `defconst` vs `defvar`; backquote/comma to evaluate one piece of
  an otherwise-quoted list.

## 2026-09-24 (cont.) — Milestone 1: docstrings, stale keymap

**What changed**
- Docstrings added to `lc-gtd-directory`, `lc-gtd-capture-schedule-today`,
  `lc-gtd-capture--refile-to-file`, `lc-gtd-capture-done`,
  `lc-gtd-capture--delete-frame`. `org-capture` is now quoted in the
  `lc-gtd-capture` docstring (checkdoc).
- Removed the `;; public function to call` comment (no `--` already means
  public).

**Stale keymap after the renames**
- Symptom: the header showed `M-x lc-gtd-capture-schedule-today` instead of
  `<f7>`.
- Cause: `defvar-keymap` is a `defvar`, so re-evaluating the file keeps the
  old keymap (still bound to the old command names). The code was fine; a
  fresh Emacs shows the right header.
- Fix: `(makunbound 'lc-gtd-capture-mode-map)` then `M-x eval-buffer`, or
  restart. Needed whenever `defvar-keymap` bindings change. Same rule for
  any `defvar`; `defconst` always reassigns.

**Elisp concepts**
- Docstring conventions: imperative first line, ARGS in caps,
  `` `symbol' `` for links. `M-x checkdoc` lints them.
- `defvar` doesn't reassign on re-eval; `makunbound` clears a value;
  advice survives re-eval too (`advice-remove`).

**Next steps (proposed, not applied)**
- File header/footer (the remaining checkdoc warnings): `;;; lc-gtd-capture.el
  --- ... -*- lexical-binding: t; -*-`, `;;; Commentary:`, `;;; Code:`,
  `(require 'org)`, `(require 'org-capture)`, `(provide 'lc-gtd-capture)`.
- `fboundp` guard for `evil-emacs-state` (or move it to use-package).
- Cosmetic: tab on line 9 (template `:after-finalize`), double blank line
  after the minor mode.
- Open question: `with-selected-frame` vs `select-frame-set-input-focus`
  (why was the latter commented out?).
- Maybe rename the frame name string "lc-org-gtd-capture" (check window-
  manager rules first).
- Later (Milestones 2/3): move `--refile-to-file` to a shared file as
  `lc-gtd--refile-to-file`.

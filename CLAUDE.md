## Project Overview

A simplified reimplementation of org-gtd, written as a way for me to learn
Emacs Lisp. The original is at /home/luis/dev/org-gtd.el. Use it as a
reference only and never modify it.

## Learning Mode
I'm learning Elisp, so:
- Explain new Elisp concepts (macros, lexical scope, org-element API, etc.)
  when they first come up
- Propose an approach and wait for my OK before writing code
- Prefer guiding me to write the code myself; when you do write code,
  keep it small and explain it
- When relevant, point me to how org-gtd does it and explain the differences

## Milestones
1. Capture: quickly add an item to the inbox
2. Inbox processing: go through inbox items one at a time and clarify each
3. Destinations for clarified items:
   - Next Actions (single actions, no date)
   - Projects (multi-step outcomes, each with a next action)
   - Waiting For (delegated)
   - Calendar (date/time-specific)
   - Someday/Maybe
   - Reference
   - Trash
4. Weekly Review: walk through lists to prune, update, and reorganize

Work on one milestone at a time, in order. The user may also specify what they're working on to refocus.

As the project is being developed we'll come across areas where we can refactor to reuse behavior,
in those cases point them out and suggest any refactors.

## Session Notes
Keep a running log in `NOTES.md` so the next session can pick up where this one left off.
- Read `NOTES.md` at the start of every session before doing anything else
- At the end of each session, or after any significant decision, append an entry with:
  - Date and milestone being worked on
  - What changed (files, functions added or modified)
  - Design decisions made and *why*, including alternatives considered
  - Elisp concepts I learned or struggled with
  - Open questions and the next step to take
- Keep entries brief; this is a log, not documentation
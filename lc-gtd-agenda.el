(require 'lc-gtd-utils)

(defun lc-gtd-agenda--close (keyword)
  "Set the agenda item at point to KEYWORD and move it to the archive file.
A subtask stays until its project is closed; on a subtask, offer to
schedule the next one.  Saves the tasks and archive files, then
refreshes the agenda."
  (org-with-point-at (or (org-get-at-bol 'org-hd-marker)
			 (org-agenda-error))
    (org-todo keyword)
    (lc-gtd--schedule-next)
    (save-buffer)
    (while (org-up-heading-safe))
    (when (org-entry-is-done-p)
      (lc-gtd-move-to lc-gtd-archive-file)))
  (org-agenda-redo))

(defun lc-gtd-agenda-done ()
  "Mark the agenda item at point DONE; see `lc-gtd-agenda--close'."
  (interactive)
  (lc-gtd-agenda--close "DONE"))

(defun lc-gtd-agenda-cancel ()
  "Mark the agenda item at point CNCL; see `lc-gtd-agenda--close'.
On a project, its open subtasks are cancelled first."
  (interactive)
  (org-with-point-at (or (org-get-at-bol 'org-hd-marker)
			 (org-agenda-error))
    (lc-gtd--cancel-subtasks))
  (lc-gtd-agenda--close "CNCL"))

(defun lc-gtd-agenda-schedule ()
  "Prompt for a date for the agenda item at point, save, and refresh.
Projects don't get dates, so on a project this schedules its first open
subtask instead."
  (interactive)
  (org-with-point-at (or (org-get-at-bol 'org-hd-marker)
			 (org-agenda-error))
    (when (and (= (org-current-level) 1)
	       (org-goto-first-child))
      (while (and (not (org-entry-is-todo-p))
		  (org-goto-sibling)))
      (unless (org-entry-is-todo-p)
	(user-error "This project has no open subtask to schedule")))
    (org-schedule nil (org-read-date
		       nil nil nil
		       (format "Schedule \"%s\": " (org-get-heading t t t t))))
    (save-buffer))
  (org-agenda-redo))

;;; The GTD view

(defun lc-gtd-agenda--skip-unless (keep)
  "Return nil if KEEP is non-nil, else the position of the next heading.
That is what an agenda skip function returns: nil shows the entry at
point, and a position makes the agenda skip ahead to it."
  (unless keep
    (save-excursion (or (outline-next-heading) (point-max)))))

(defun lc-gtd-agenda--skip-unless-upcoming ()
  "Skip entries that aren't scheduled after today."
  (let ((date (org-get-scheduled-time (point))))
    (lc-gtd-agenda--skip-unless
     (and date (> (time-to-days date) (org-today))))))

(defun lc-gtd-agenda--skip-unless-project ()
  "Skip entries that aren't project headings."
  (lc-gtd-agenda--skip-unless
   (and (= (org-current-level) 1) (lc-gtd--is-project-p))))

(defun lc-gtd-agenda--skip-unless-maybe ()
  "Skip entries that aren't lone tasks without a date."
  (lc-gtd-agenda--skip-unless
   (and (= (org-current-level) 1)
	(not (lc-gtd--is-project-p))
	(not (org-get-scheduled-time (point))))))

(defun lc-gtd-agenda--date ()
  "Return the scheduled date of the entry at point, like \"Tue 20 Oct\"."
  (format-time-string "%a %d %b" (org-get-scheduled-time (point))))

(defun lc-gtd-agenda--closed-today-p ()
  "Return non-nil if the entry at point was closed today.
Reads the CLOSED: [...] stamp that `org-log-done' writes."
  (let ((closed (org-entry-get nil "CLOSED")))
    (and closed (= (org-time-string-to-absolute closed) (org-today)))))

(defun lc-gtd-agenda--skip-unless-closed-today ()
  "Skip entries that weren't closed today."
  (lc-gtd-agenda--skip-unless (lc-gtd-agenda--closed-today-p)))

(defun lc-gtd-agenda--done-files ()
  "Return the files that can hold items closed today.
Closed tasks and projects go to the archive, but closed subtasks of an
open project stay in the tasks file."
  (seq-filter #'file-exists-p
	      (list (lc-gtd--path lc-gtd-tasks-file)
		    (lc-gtd--path lc-gtd-archive-file))))

(defconst lc-gtd-agenda--view
  '("g" "GTD"
    ((agenda "" ((org-agenda-overriding-header "TODAY")
		 (org-agenda-span 'day)
		 (org-agenda-skip-scheduled-if-done t)
		 (org-agenda-prefix-format "  %?-12t% s%b")))
     (todo "TODO" ((org-agenda-overriding-header "SCHEDULED")
		   (org-agenda-skip-function #'lc-gtd-agenda--skip-unless-upcoming)
		   (org-agenda-sorting-strategy '(scheduled-up))
		   (org-agenda-prefix-format "  %-12(lc-gtd-agenda--date)%b")))
     (todo "DONE" ((org-agenda-overriding-header "DONE")
		   (org-agenda-files (lc-gtd-agenda--done-files))
		   (org-agenda-skip-function #'lc-gtd-agenda--skip-unless-closed-today)
		   (org-agenda-prefix-format "  %b")))
     (todo "TODO" ((org-agenda-overriding-header "PROJECTS")
		   (org-agenda-skip-function #'lc-gtd-agenda--skip-unless-project)
		   (org-agenda-dim-blocked-tasks nil)
		   (org-agenda-prefix-format "  ")))
     (todo "TODO" ((org-agenda-overriding-header "MAYBE")
		   (org-agenda-skip-function #'lc-gtd-agenda--skip-unless-maybe)
		   (org-agenda-prefix-format "  "))))
    ((org-agenda-files (list (lc-gtd--path lc-gtd-tasks-file)))
     (org-agenda-breadcrumbs-separator " / ")))
  "The GTD view, in the format of an `org-agenda-custom-commands' entry.
Each setting is a (VARIABLE VALUE) pair, and VALUE is evaluated when the
view is built, like the bindings of a `let'.  The last list holds the
settings shared by every block.")

(defconst lc-gtd-agenda--frame-name "lc-org-gtd-agenda"
  "Name of the dedicated agenda frame.")

(defun lc-gtd-agenda--frame ()
  "Return the live agenda frame, or nil if there isn't one."
  (seq-find (lambda (frame)
	      (equal (frame-parameter frame 'name) lc-gtd-agenda--frame-name))
	    (frame-list)))

(defun lc-gtd-agenda ()
  "Show the GTD agenda: today, upcoming, done today, projects, and maybe.
Reuse the agenda frame if one is open, otherwise make a new one."
  (interactive)
  (let ((existing (lc-gtd-agenda--frame))
	(org-agenda-custom-commands (list lc-gtd-agenda--view)))
    (select-frame-set-input-focus
     (or existing
	 (make-frame `((name . ,lc-gtd-agenda--frame-name)
		       (width . 95)
		       (height . 45)))))
    (org-agenda nil "g")
    (unless existing
      (delete-other-windows))))

(defun lc-gtd-agenda--set-header ()
  "Show the GTD view's keys in the header line.
Runs from `org-agenda-finalize-hook' after every build and refresh,
because each rebuild resets the agenda buffer's local variables.  Other
agenda views are left alone."
  (when (equal org-agenda-name (nth 1 lc-gtd-agenda--view))
    (setq header-line-format
	  (substitute-command-keys
	   ;; F5 runs Org's own refresh, which `g' runs too, and
	   ;; \\[...] would show `g'; \\`KEY' shows a literal key instead.
	   (concat "\\<org-agenda-mode-map>"
		   "\\`<f5>': refresh   "
		   "\\[lc-gtd-agenda-cancel]: cancel   "
		   "\\[lc-gtd-agenda-schedule]: schedule   "
		   "\\[lc-gtd-agenda-done]: done")))))

(with-eval-after-load 'org-agenda
  (keymap-set org-agenda-mode-map "<f5>" #'org-agenda-redo-all)
  (keymap-set org-agenda-mode-map "<f6>" #'lc-gtd-agenda-cancel)
  (keymap-set org-agenda-mode-map "<f7>" #'lc-gtd-agenda-schedule)
  (keymap-set org-agenda-mode-map "<f8>" #'lc-gtd-agenda-done)
  (add-hook 'org-agenda-finalize-hook #'lc-gtd-agenda--set-header))

(provide 'lc-gtd-agenda)

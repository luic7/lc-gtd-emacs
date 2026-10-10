;; Weekly cleanup: one buffer listing every task that needs a decision.

(require 'lc-gtd-utils)
(require 'lc-gtd-inbox)    ; for `lc-gtd-process-inbox' (the i key)

;;; Reading the tasks file

(defun lc-gtd-cleanup--subtask-p (pred)
  "Return non-nil if PRED is true for a subtask of the heading at point.
PRED is called with point on each heading below this one, at any depth."
  (let ((end (save-excursion (org-end-of-subtree t)))
        found)
    (save-excursion
      (while (and (not found) (outline-next-heading) (< (point) end))
        (setq found (funcall pred))))
    found))

(defun lc-gtd-cleanup--next-steps ()
  "Return markers for the subtasks of the heading at point that are ready.
A subtask is ready when it is open and has no open subtask of its own."
  (let ((end (save-excursion (org-end-of-subtree t)))
        steps)
    (save-excursion
      (while (and (outline-next-heading) (< (point) end))
        (when (and (org-entry-is-todo-p)
                   (not (lc-gtd-cleanup--subtask-p #'org-entry-is-todo-p)))
          (push (point-marker) steps))))
    (nreverse steps)))

(defun lc-gtd-cleanup--label ()
  "Return the text to show for the heading at point.
A subtask is shown with its project, as PROJECT / SUBTASK."
  (if (= (org-current-level) 1)
      (substring-no-properties (org-get-heading t t t t))
    (string-join (org-get-outline-path t) " / ")))

(defun lc-gtd-cleanup--days (n)
  "Return N days as a phrase, like \"1 day\" or \"3 days\"."
  (format "%d day%s" n (if (= n 1) "" "s")))

(defun lc-gtd-cleanup--captured-note ()
  "Return \"captured N days ago\" for the entry at point, or nil.
Reads the CAPTURED line that the capture template writes."
  (save-excursion
    (when (re-search-forward "^CAPTURED: \\(\\[[^]\n]+\\]\\)"
                             (save-excursion (outline-next-heading) (point))
                             t)
      (format "captured %s ago"
              (lc-gtd-cleanup--days
               (- (org-today)
                  (org-time-string-to-absolute (match-string 1))))))))

(defun lc-gtd-cleanup--overdue-entry (marker)
  "Return an `overdue' list entry for the heading at MARKER, or nil.
A heading is overdue when its scheduled date is before today."
  (let ((scheduled (org-get-scheduled-time marker)))
    (when (and scheduled (< (time-to-days scheduled) (org-today)))
      (list 'overdue marker
            (org-with-point-at marker (lc-gtd-cleanup--label))
            (concat (lc-gtd-cleanup--days
                     (- (org-today) (time-to-days scheduled)))
                    " late")))))

(defun lc-gtd-cleanup--classify ()
  "Return the list entries for the top-level heading at point.
Each entry is (SECTION MARKER LABEL NOTE TARGET): SECTION is a key of
`lc-gtd-cleanup--sections' and the rest are the arguments of
`lc-gtd-cleanup--insert-item'.  Return nil if nothing needs a decision."
  (let ((top (point-marker))
        (label (lc-gtd-cleanup--label)))
    (cond
     ((org-entry-is-done-p)
      (list (list 'done top label (org-get-todo-state))))
     ((not (org-entry-is-todo-p))
      nil)
     ;; A project with work left: its ready subtasks decide where it goes.
     ((lc-gtd-cleanup--subtask-p #'org-entry-is-todo-p)
      (let ((steps (lc-gtd-cleanup--next-steps)))
        (if (seq-some #'org-get-scheduled-time steps)
            (delq nil (mapcar #'lc-gtd-cleanup--overdue-entry steps))
          (list (list 'stuck top label
                      (concat "next: "
                              (org-with-point-at (car steps)
                                (org-get-heading t t t t)))
                      (car steps))))))
     ((lc-gtd-cleanup--subtask-p #'org-entry-is-done-p)
      (list (list 'finished top label)))
     ((org-get-scheduled-time top)
      (when-let ((late (lc-gtd-cleanup--overdue-entry top)))
        (list late)))
     (t
      (list (list 'someday top label (lc-gtd-cleanup--captured-note)))))))

(defconst lc-gtd-cleanup--sections
  '((overdue . "Overdue")
    (stuck . "Projects with no next step")
    (finished . "Finished projects")
    (someday . "Someday/maybe")
    (done . "Done, not archived"))
  "Sections of the cleanup list in display order, as (KEY . TITLE).")

(defun lc-gtd-cleanup--collect ()
  "Scan the tasks file and return what needs a decision, by section.
The result is an alist of (SECTION . ITEMS), each ITEMS list in reverse
file order.  See `lc-gtd-cleanup--classify' for what an item holds."
  (let (found)
    (with-current-buffer (find-file-noselect (lc-gtd--path lc-gtd-tasks-file))
      (org-with-wide-buffer
       (goto-char (point-min))
       (while (re-search-forward "^\\* " nil t)
         (save-excursion
           (beginning-of-line)
           (dolist (entry (lc-gtd-cleanup--classify))
             (push (cdr entry) (alist-get (car entry) found)))))))
    found))

(defun lc-gtd-cleanup--inbox-count ()
  "Return the number of top-level headings in the inbox file."
  (with-current-buffer (find-file-noselect (lc-gtd--path lc-gtd-inbox-file))
    (org-with-wide-buffer
     (goto-char (point-min))
     (how-many "^\\* "))))

;;; Drawing the list

(defun lc-gtd-cleanup--insert-item (marker label &optional note target)
  "Insert a line showing LABEL, and NOTE if there is one.
The line remembers MARKER, the heading it stands for, and TARGET, the
heading to schedule.  TARGET defaults to MARKER."
  (let ((label (truncate-string-to-width label 50 nil nil t)))
    (insert (propertize (concat "  "
                                (if note
                                    (format "%-50s  %s" label
                                            (propertize note 'face 'shadow))
                                  label)
                                "\n")
                        'lc-gtd-marker marker
                        'lc-gtd-target (or target marker)))))

(defun lc-gtd-cleanup--refresh (&rest _)
  "Rebuild the list from the GTD files, keeping point on the same line.
Also serves as `revert-buffer-function', which passes arguments that
are ignored here."
  (let ((line (line-number-at-pos))
        (found (lc-gtd-cleanup--collect))
        (inhibit-read-only t))
    (erase-buffer)
    (insert (propertize (format "Inbox (%d)\n" (lc-gtd-cleanup--inbox-count))
                        'face 'bold))
    (dolist (section lc-gtd-cleanup--sections)
      (let ((items (reverse (alist-get (car section) found))))
        (insert "\n"
                (propertize (format "%s (%d)\n" (cdr section) (length items))
                            'face 'bold))
        (dolist (item items)
          (apply #'lc-gtd-cleanup--insert-item item))))
    (goto-char (point-min))
    (forward-line (1- line))))

;;; Acting on the task at point

(defun lc-gtd-cleanup--marker (&optional property)
  "Return the heading marker stored on the current line.
PROPERTY is the text property to read; it defaults to `lc-gtd-marker'."
  (let ((marker (get-text-property (pos-bol) (or property 'lc-gtd-marker))))
    (unless (and marker (marker-buffer marker))
      (user-error "No task on this line"))
    marker))

(defun lc-gtd-cleanup--cancel-subtasks ()
  "Mark every open subtask of the heading at point CNCL.
Works from the bottom up, because Org refuses to close a heading that
still has an open subtask."
  (let ((end (save-excursion (org-end-of-subtree t)))
        open)
    (save-excursion
      (while (and (outline-next-heading) (< (point) end))
        (when (org-entry-is-todo-p)
          (push (point-marker) open))))
    (dolist (marker open)
      (org-with-point-at marker
        (org-todo "CNCL")))))

(defun lc-gtd-cleanup--close (keyword)
  "Set the heading at point to KEYWORD, unless it is already done.
Then archive the whole tree if its top heading is done, the same rule
as `lc-gtd-agenda-done'.  Otherwise only save the file."
  (unless (org-entry-is-done-p)
    (org-todo keyword))
  (while (org-up-heading-safe))
  (if (org-entry-is-done-p)
      (lc-gtd-move-to lc-gtd-archive-file)
    (save-buffer)))

(defun lc-gtd-cleanup-trash ()
  "Mark the task on this line CNCL; archive it once its top heading is done.
On a project line the open subtasks are cancelled as well."
  (interactive)
  (org-with-point-at (lc-gtd-cleanup--marker)
    (lc-gtd-cleanup--cancel-subtasks)
    (lc-gtd-cleanup--close "CNCL"))
  (lc-gtd-cleanup--refresh))

(defun lc-gtd-cleanup-maybe ()
  "Remove the scheduled date from the task on this line.
Tasks without a date count as someday/maybe."
  (interactive)
  (org-with-point-at (lc-gtd-cleanup--marker)
    (org-schedule '(4))
    (save-buffer))
  (lc-gtd-cleanup--refresh))

(defun lc-gtd-cleanup-schedule ()
  "Prompt for a date and schedule the task on this line; RET means today.
On a project with no next step this schedules its first ready subtask."
  (interactive)
  (org-with-point-at (lc-gtd-cleanup--marker 'lc-gtd-target)
    (org-schedule nil (org-read-date
                       nil nil nil
                       (format "Schedule \"%s\"" (org-get-heading t t t t))))
    (save-buffer))
  (lc-gtd-cleanup--refresh))

(defun lc-gtd-cleanup-done ()
  "Mark the task on this line DONE; archive it once its top heading is done.
A task that is already done or cancelled is archived as it is."
  (interactive)
  (org-with-point-at (lc-gtd-cleanup--marker)
    (when (lc-gtd-cleanup--subtask-p #'org-entry-is-todo-p)
      (user-error "This project still has open subtasks"))
    (lc-gtd-cleanup--close "DONE"))
  (lc-gtd-cleanup--refresh))

(defun lc-gtd-cleanup-open ()
  "Show the task on this line in the other window, ready to edit.
Refresh the list afterwards to pick up the edits."
  (interactive)
  (let ((marker (lc-gtd-cleanup--marker)))
    (pop-to-buffer (marker-buffer marker))
    (widen)
    (goto-char marker)
    (org-fold-show-context)
    (org-fold-show-subtree)))

(defconst lc-gtd-cleanup--frame-name "lc-org-gtd-cleanup"
  "Name of the dedicated cleanup frame; used to recognize it when closing.")

(defun lc-gtd-cleanup-quit ()
  "Close the cleanup list, and its frame if it is the dedicated one."
  (interactive)
  (let ((dedicated (equal (frame-parameter nil 'name)
                          lc-gtd-cleanup--frame-name)))
    (kill-buffer)
    (when dedicated
      (delete-frame))))

;;; Mode and entry point

(defvar-keymap lc-gtd-cleanup-mode-map
  :doc "Keymap for `lc-gtd-cleanup-mode'."
  "<f8>" #'lc-gtd-cleanup-done
  "<f7>" #'lc-gtd-cleanup-schedule
  "<f6>" #'lc-gtd-cleanup-maybe
  "<f5>" #'lc-gtd-cleanup-trash
  "RET" #'lc-gtd-cleanup-open
  "i" #'lc-gtd-process-inbox
  "n" #'next-line
  "p" #'previous-line
  "q" #'lc-gtd-cleanup-quit)

(define-derived-mode lc-gtd-cleanup-mode special-mode "gtd-cleanup"
  "Major mode for the weekly GTD cleanup list.
Each line stands for a heading in the tasks file, and the keys act on
that heading."
  (buffer-disable-undo)
  (setq truncate-lines t)
  (setq-local revert-buffer-function #'lc-gtd-cleanup--refresh)
  (setq header-line-format
        (substitute-command-keys
         (concat "\\<lc-gtd-cleanup-mode-map>"
                 "\\[lc-gtd-cleanup-trash]: trash   "
                 "\\[lc-gtd-cleanup-maybe]: maybe   "
                 "\\[lc-gtd-cleanup-schedule]: schedule   "
                 "\\[lc-gtd-cleanup-done]: done   "
                 "\\[lc-gtd-cleanup-open]: open   "
                 "\\[lc-gtd-process-inbox]: inbox   "
                 "\\[revert-buffer]: refresh   "
                 "\\[lc-gtd-cleanup-quit]: quit"))))

;; init.el loads Evil after this file, so wait for it before registering.
(with-eval-after-load 'evil
  (evil-set-initial-state 'lc-gtd-cleanup-mode 'emacs))

(defun lc-gtd-cleanup ()
  "Open the weekly cleanup list in a dedicated frame."
  (interactive)
  (let ((frame (make-frame `((name . ,lc-gtd-cleanup--frame-name)))))
    (with-selected-frame frame
      (switch-to-buffer (get-buffer-create "*lc-gtd cleanup*"))
      (delete-other-windows)
      (lc-gtd-cleanup-mode)
      (lc-gtd-cleanup--refresh))))

(provide 'lc-gtd-cleanup)

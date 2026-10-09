;; (load-file "./lc-gtd-utils.el")

(defvar-keymap lc-gtd-inbox-mode-map
  :doc "Keymap for `lc-gtd-inbox-mode'."
  "<f8>" #'lc-gtd-inbox-schedule-today
  "<f7>" #'lc-gtd-inbox-schedule
  "<f6>" #'lc-gtd-inbox-maybe
  "<f5>" #'lc-gtd-inbox-trash)

(defun lc-gtd-inbox-schedule-today ()
  "Schedule the heading at point for today and move it to the tasks file."
  (interactive)
  (lc-gtd-schedule-today)
  (lc-gtd-move-to lc-gtd-tasks-file))

(defun lc-gtd-inbox-schedule ()
  "Prompt for a date, schedule the heading at point, and move it to tasks."
  (interactive)
  (org-schedule nil)
  (lc-gtd-move-to lc-gtd-tasks-file))

(defun lc-gtd-inbox-maybe ()
  "Move the heading at point to the tasks file without a date.
Items without a scheduled date count as someday/maybe."
  (interactive)
  (lc-gtd-move-to lc-gtd-tasks-file))

(defun lc-gtd-inbox-trash ()
  "Mark the heading at point CNCL and move it to the archive file."
  (interactive)
  (org-todo "CNCL")
  (lc-gtd-move-to lc-gtd-archive-file))

(define-minor-mode lc-gtd-inbox-mode
  "Minor mode for processing GTD inbox items."
  :lighter " gtd-i"
  :keymap lc-gtd-inbox-mode-map
  (when lc-gtd-inbox-mode
    (setq header-line-format
	  (substitute-command-keys
	   (concat "\\<lc-gtd-inbox-mode-map>"
                   "\\[lc-gtd-inbox-trash]: trash   "
                   "\\[lc-gtd-inbox-maybe]: maybe   "
                   "\\[lc-gtd-inbox-schedule]: schedule   "
                   "\\[lc-gtd-inbox-schedule-today]: today   ")))))

(add-hook 'lc-gtd-inbox-mode-hook
          (lambda ()
            (when lc-gtd-inbox-mode
              (evil-emacs-state))))

(defconst lc-gtd-inbox--frame-name "lc-org-gtd-inbox"
  "Name of the dedicated inbox processing frame.")

(defun lc-gtd-process-inbox ()
  "Open the inbox in a dedicated frame with `lc-gtd-inbox-mode' on."
  (interactive)
  (let ((frame (make-frame `((name . ,lc-gtd-inbox--frame-name)))))
    (with-selected-frame frame
      (find-file (lc-gtd--path lc-gtd-inbox-file))
      (delete-other-windows)
      (lc-gtd-inbox-mode))))

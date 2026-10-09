;; Needs lc-gtd-utils.el loaded first; init.el loads both.

(defun lc-gtd-agenda-done ()
  "Mark the agenda item at point DONE and move it to the archive file.
Saves the tasks and archive files, then refreshes the agenda."
  (interactive)
  (org-with-point-at (or (org-get-at-bol 'org-hd-marker)
                         (org-agenda-error))
    (org-todo "DONE")
    (lc-gtd-move-to lc-gtd-archive-file))
  (org-agenda-redo))

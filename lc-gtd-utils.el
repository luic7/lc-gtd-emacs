
(defvar lc-gtd-directory "~/lc-gtd/"
  "Directory holding the GTD files (inbox.org, org-gtd-tasks.org, ...).")

(defvar lc-gtd-inbox-file "inbox.org"
  "Inbox file, relative to `lc-gtd-directory'.")

(defvar lc-gtd-tasks-file "org-gtd-tasks.org"
  "Tasks file, relative to `lc-gtd-directory'.")

(defvar lc-gtd-archive-file "org-gtd-archive.org"
  "Archive file for trashed items, relative to `lc-gtd-directory'.")

(defun lc-gtd--path (file)
  "Return the absolute path of FILE inside `lc-gtd-directory'."
  (expand-file-name file lc-gtd-directory))

(defun lc-gtd--is-project ()
  "Checks if an entry is a project"
  (save-excursion
    (while (org-up-heading-safe))
    (org-goto-first-child)))

(defun lc-gtd-schedule-today ()
  "Schedule the heading at point for today."
  (interactive)
  (org-schedule nil "+0"))

(defun lc-gtd-refile-to-file (file)
  "Refile the heading at point to the top level of FILE, then save FILE.
FILE is relative to `lc-gtd-directory'."
  (let ((path (lc-gtd--path file)))
    (org-refile nil nil (list file path nil nil))
    (when-let ((buf (find-buffer-visiting path)))
      (with-current-buffer buf (save-buffer)))))

(defun lc-gtd-insert-statistics ()
  "Inserts statitics if it's a projects"
  (when (lc-gtd--is-project)
    (while (org-up-heading-safe))
    (unless (string-match-p "\\[[0-9]*/[0-9]*\\]" (org-get-heading t t t t))
      (org-edit-headline (concat (org-get-heading t t t t) " [/]")))
    (org-update-statistics-cookies nil)))

(defun lc-gtd-move-to (file)
  "Refile the heading at point to FILE, then save the current buffer.
Saves both ends of the move.  FILE is relative to `lc-gtd-directory'."
  (lc-gtd-insert-statistics)
  (lc-gtd-refile-to-file file)
  (save-buffer))


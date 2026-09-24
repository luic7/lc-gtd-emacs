(defvar lc-gtd-directory "~/lc-gtd/"
  "Directory holding the GTD files (inbox.org, org-gtd-tasks.org, ...).")

(defun lc-gtd-capture--template ()
  "Bare capture template: no fixed text, just a heading, filed into inbox.org."
  (list "g" "GTD capture" 'entry
        (list 'file (expand-file-name "inbox.org" lc-gtd-directory))
        "* TODO %?"
	:after-finalize #'lc-gtd-capture--delete-frame))

(defun lc-gtd-capture-schedule-today ()
  "Schedule the item being captured for today."
  (interactive)
  (org-schedule nil "+0"))

(defun lc-gtd-capture--refile-to-file (file)
  "Refile the heading at point to the top level of FILE, then save FILE.
FILE is relative to `lc-gtd-directory'."
  (let ((path (expand-file-name file lc-gtd-directory)))
    (org-refile nil nil (list file path nil nil))
    (when-let ((buf (find-buffer-visiting path)))
      (with-current-buffer buf (save-buffer)))))

(defun lc-gtd-capture-done ()
  "Finish the capture; move it to org-gtd-tasks.org if it is scheduled.
Unscheduled items stay in inbox.org."
  (interactive)
  (when (org-get-scheduled-time (point))
    (lc-gtd-capture--refile-to-file "org-gtd-tasks.org"))
  (org-capture-finalize))

(defvar-keymap lc-gtd-capture-mode-map
  :doc "Keymap for `lc-gtd-capture-mode'."
  "<f8>" #'lc-gtd-capture-done
  "<f7>" #'lc-gtd-capture-schedule-today
  "<f6>" #'org-schedule
  "<f5>" #'org-capture-kill)

(define-minor-mode lc-gtd-capture-mode
  "Minor mode for processing GTD capture items."
  :init-value nil
  :lighter " gtd-c"
  :keymap lc-gtd-capture-mode-map
  (when lc-gtd-capture-mode
    (setq header-line-format
          (substitute-command-keys
           (concat "\\<lc-gtd-capture-mode-map>"
                   "\\[org-capture-kill]: cancel   "
                   "\\[org-schedule]: schedule   "
                   "\\[lc-gtd-capture-schedule-today]: today   "
                   "\\[lc-gtd-capture-done]: done")))))


;; this would ideally be placed inside a use-package entry, for now it's fine
(add-hook 'lc-gtd-capture-mode-hook
          (lambda ()
            (when lc-gtd-capture-mode
              (evil-emacs-state))))

(defconst lc-gtd-capture--frame-name "lc-org-gtd-capture"
  "Name of the dedicated capture frame; used to recognize it when closing.")

(defun lc-gtd-capture--delete-frame ()
  "Delete the selected frame if it is the dedicated capture frame.
Runs from the capture template's `:after-finalize'."
  (when (equal (frame-parameter nil 'name) lc-gtd-capture--frame-name)
    (delete-frame)))

(defun lc-gtd-capture ()
  "Open `org-capture' in a dedicated frame; F8/F5 close it once you're done."
  (interactive)
  (let ((frame (make-frame `((name . ,lc-gtd-capture--frame-name))))
        (org-capture-templates (list (lc-gtd-capture--template))))
    (with-selected-frame frame
      (org-capture nil "g")
      (delete-other-windows)
      (lc-gtd-capture-mode))))

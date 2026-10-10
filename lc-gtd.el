;; Entry point: (require 'lc-gtd) loads every part of lc-gtd.
;; Org itself is not required here; it loads the first time a command runs.

(require 'lc-gtd-utils)
(require 'lc-gtd-capture)
(require 'lc-gtd-inbox)
(require 'lc-gtd-agenda)
(require 'lc-gtd-cleanup)

(provide 'lc-gtd)

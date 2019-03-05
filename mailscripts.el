;;; mailscripts.el --- functions to access tools in the mailscripts package

;; Author: Sean Whitton <spwhitton@spwhitton.name>
;; Version: 0.5
;; Package-Requires: (notmuch)

;; Copyright (C) 2018 Sean Whitton

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'notmuch)

;;;###autoload
(defun notmuch-slurp-debbug (bug &optional no-open)
  "Slurp Debian bug with bug number BUG and open the thread in notmuch.

If NO-OPEN, don't open the thread."
  (interactive "sBug number: ")
  (call-process-shell-command (concat "notmuch-slurp-debbug " bug))
  (unless no-open
    (notmuch-show (concat "Bug#" bug))))

;;;###autoload
(defun notmuch-slurp-this-debbug ()
  "When viewing a Debian bug in notmuch, download any missing messages."
  (interactive)
  (let ((subject (notmuch-show-get-subject)))
    (when (string-match "Bug#\\([0-9]+\\):" subject)
      (notmuch-slurp-debbug (match-string 1 subject) t))
    (notmuch-refresh-this-buffer)))

;;;###autoload
(defun notmuch-extract-thread-patches (repo branch)
  "Extract patch series in current thread to new branch BRANCH in repo REPO.

See notmuch-extract-patch(1) manpage for limitations: in
particular, this Emacs Lisp function supports passing only entire
threads to the notmuch-extract-patch(1) command."
  (interactive "Dgit repo: \nsnew branch name: ")
  (let ((thread-id notmuch-show-thread-id)
        (default-directory (expand-file-name repo)))
    (call-process-shell-command
     (format "git checkout -b %s"
             (shell-quote-argument branch)))
    (shell-command
     (format "notmuch-extract-patch %s | git am"
             (shell-quote-argument thread-id))
     "*notmuch-apply-thread-series*")))

(provide 'mailscripts)

;;; mailscripts.el ends here

;;; mailscripts.el --- functions to access tools in the mailscripts package  -*- lexical-binding: t; -*-

;; Author: Sean Whitton <spwhitton@spwhitton.name>
;; Version: 0.23
;; Package-Requires: (notmuch)

;; Copyright (C) 2018, 2019, 2020, 2022 Sean Whitton

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)
(require 'notmuch)
(require 'thingatpt)

(defgroup mailscripts nil
  "Customisation of functions in the mailscripts package.")

(defcustom mailscripts-extract-patches-branch-prefix nil
  "Prefix for git branches created by functions which extract patch series.

E.g. `email/'."
  :type 'string
  :group 'mailscripts)

(defcustom mailscripts-detach-head-from-existing-branch nil
  "Whether to detach HEAD before applying patches to an existing branch.

This is useful if you want to manually review the result of
applying patches before updating any of your existing branches,
or for quick, ad hoc testing of a patch series.

Note that this does not prevent the creation of new branches."
  :type '(choice (const :tag "Always detach" t)
		 (const :tag "Never detach" nil)
		 (const :tag "Ask whether to detach" ask))
  :group 'mailscripts)

(defcustom mailscripts-project-library 'projectile
  "Which project management library to use to choose from known projects.

Some mailscripts functions allow selecting the repository to
which patches will be applied from the list of projects already
known to Emacs.  There is more than one popular library for
maintaining a list of known projects, however, so this variable
must be set to the one you use.

Once there is a more fully-featured version of project.el
included in the latest stable release of GNU Emacs, the default
value of this variable may change, so if you wish to continue
using Projectile, you should explicitly customize this."
  :type '(choice (const :tag "project.el" project)
		 (const :tag "Projectile" projectile))
  :group 'mailscripts)

;;;###autoload
(defun notmuch-slurp-debbug (bug &optional no-open)
  "Slurp Debian bug with bug number BUG and open the thread in notmuch.

If NO-OPEN, don't open the thread."
  (interactive "sBug number: ")
  (call-process-shell-command (concat "notmuch-slurp-debbug " bug))
  (unless no-open
    (let* ((search (concat "Bug#" bug))
           (thread-id (car (process-lines notmuch-command
                                          "search"
                                          "--output=threads"
                                          "--limit=1"
                                          "--format=text"
                                          "--format-version=4" search))))
      (notmuch-search search t thread-id))))

;;;###autoload
(defun notmuch-slurp-debbug-at-point ()
  "Slurp Debian bug with bug number at point and open the thread in notmuch."
  (interactive)
  (save-excursion
    ;; the bug number might be prefixed with a # or 'Bug#'; try
    ;; skipping over those to see if there's a number afterwards
    (skip-chars-forward "#bBug" (+ 4 (point)))
    (notmuch-slurp-debbug (number-to-string (number-at-point)))))

;;;###autoload
(defun notmuch-slurp-this-debbug ()
  "When viewing a Debian bug in notmuch, download any missing messages."
  (interactive)
  (let ((subject (notmuch-show-get-subject)))
    (notmuch-slurp-debbug
     (if (string-match "Bug#\\([0-9]+\\):" subject)
         (match-string 1 subject)
       (read-string "Bug number: ")) t)
    (notmuch-refresh-this-buffer)))

;;;###autoload
(defun notmuch-extract-thread-patches (repo branch &optional reroll-count)
  "Extract patch series in current thread to branch BRANCH in repo REPO.

The target branch may or may not already exist.

With an optional prefix numeric argument REROLL-COUNT, try to
extract the nth revision of a series.  See the --reroll-count
option detailed in mbox-extract-patch(1).

See notmuch-extract-patch(1) manpage for limitations: in
particular, this Emacs Lisp function supports passing only entire
threads to the notmuch-extract-patch(1) command."
  (interactive
   "Dgit repo: \nsnew branch name (or leave blank to apply to current HEAD): \nP")
  (let ((thread-id
         ;; If `notmuch-show' was called with a notmuch query rather
         ;; than a thread ID, as `org-notmuch-follow-link' in
         ;; org-notmuch.el does, then `notmuch-show-thread-id' might
         ;; be an arbitrary notmuch query instead of a thread ID.  We
         ;; need to wrap such a query in thread:{} before passing it
         ;; to notmuch-extract-patch(1), or we might not get a whole
         ;; thread extracted (e.g. if the query is just id:foo)
         (if (string= (substring notmuch-show-thread-id 0 7) "thread:")
             notmuch-show-thread-id
           (concat "thread:{" notmuch-show-thread-id "}")))
        (default-directory (expand-file-name repo)))
    (mailscripts--check-out-branch branch)
    (shell-command
     (if reroll-count
         (format "notmuch-extract-patch -v%d %s | git am"
                 (prefix-numeric-value reroll-count)
                 (shell-quote-argument thread-id))
       (format "notmuch-extract-patch %s | git am"
               (shell-quote-argument thread-id)))
     "*notmuch-apply-thread-series*")))

;;;###autoload
(define-obsolete-function-alias
  'notmuch-extract-thread-patches-projectile
  'notmuch-extract-thread-patches-to-project
  "mailscripts 0.22")

;;;###autoload
(defun notmuch-extract-thread-patches-to-project ()
  "Like `notmuch-extract-thread-patches', but choose repo from known projects."
  (interactive)
  (mailscripts--project-repo-and-branch
   'notmuch-extract-thread-patches
   (when current-prefix-arg
     (prefix-numeric-value current-prefix-arg))))

;;;###autoload
(defun notmuch-extract-message-patches (repo branch)
  "Extract patches attached to current message to branch BRANCH in repo REPO.

The target branch may or may not already exist.

Patches are applied using git-am(1), so we only consider
attachments with filenames which look like they were generated by
git-format-patch(1)."
  (interactive
   "Dgit repo: \nsnew branch name (or leave blank to apply to current HEAD): ")
  (with-current-notmuch-show-message
   (let ((default-directory (expand-file-name repo))
         (mm-handle (mm-dissect-buffer t)))
     (mailscripts--check-out-branch branch)
     (notmuch-foreach-mime-part
      (lambda (p)
        (let* ((disposition (mm-handle-disposition p))
               (filename (cdr (assq 'filename disposition))))
          (and filename
               (string-match "^\\(v?[0-9]+\\)-.+\\.\\(patch\\|diff\\|txt\\)$"
                             filename)
               (mm-pipe-part p "git am"))))
      mm-handle))))

;;;###autoload
(define-obsolete-function-alias
  'notmuch-extract-message-patches-projectile
  'notmuch-extract-message-patches-to-project
  "mailscripts 0.22")

;;;###autoload
(defun notmuch-extract-message-patches-to-project ()
  "Like `notmuch-extract-message-patches', but choose repo from known projects."
  (interactive)
  (mailscripts--project-repo-and-branch 'notmuch-extract-message-patches))

(defun mailscripts--check-out-branch (branch)
  (if (string= branch "")
      (when (or (eq mailscripts-detach-head-from-existing-branch t)
		(and (eq mailscripts-detach-head-from-existing-branch 'ask)
		     (yes-or-no-p "Detach HEAD before applying patches?")))
        (call-process-shell-command "git checkout --detach"))
    (call-process-shell-command
     (format "git checkout -b %s"
             (shell-quote-argument
              (if mailscripts-extract-patches-branch-prefix
                  (concat mailscripts-extract-patches-branch-prefix branch)
                branch))))))

(defun mailscripts--project-repo-and-branch (f &rest args)
  (let ((repo (cl-case mailscripts-project-library
		('project
		 (require 'project)
		 (project-prompt-project-dir))
		('projectile
		 (require 'projectile)
		 (projectile-completing-read
		  "Select Projectile project: " projectile-known-projects))
		(nil
		 (user-error
		  "Please customize variable `mailscripts-project-library'."))))
        (branch (read-from-minibuffer
                 "Branch name (or leave blank to apply to current HEAD): ")))
    (apply f repo branch args)))

(provide 'mailscripts)

;;; mailscripts.el ends here

;;; guix-emacs.el --- Emacs packages installed with Guix

;; Copyright © 2014, 2015, 2016, 2017 Alex Kost <alezost@gmail.com>
;; Copyright © 2017 Kyle Meyer <kyle@kyleam.com>
;; Copyright © 2019 Maxim Cournoyer <maxim.cournoyer@gmail.com>

;; This file is part of GNU Guix.

;; GNU Guix is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Guix is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This file provides auxiliary code to autoload Emacs packages
;; installed with Guix.

;;; Code:
(require 'seq)

(defvar guix-emacs-autoloads-regexp
  (rx (* any) "-autoloads.el" (zero-or-one "c") string-end)
  "Regexp to match Emacs 'autoloads' file.")

(defun guix-emacs-find-autoloads (directory)
  "Return a list of Emacs 'autoloads' files in DIRECTORY.
The files in the list do not have extensions (.el, .elc)."
  ;; `directory-files' doesn't honor group in regexp.
  (delete-dups (mapcar #'file-name-sans-extension
                       (directory-files directory 'full-name
                                        guix-emacs-autoloads-regexp))))

;;;###autoload
(defun guix-emacs-autoload-packages ()
  "Autoload Emacs packages found in EMACSLOADPATH.

'Autoload' means to load the 'autoloads' files matching
`guix-emacs-autoloads-regexp'."
  (interactive)
  (let* ((emacs-non-core-load-path-directories
          ;; Filter out core Elisp directories, which are already autoloaded
          ;; by Emacs.
          (seq-filter (lambda (dir)
                        (string-match-p "/share/emacs/site-lisp" dir))
                      load-path))
         (autoloads (mapcan #'guix-emacs-find-autoloads
                            emacs-non-core-load-path-directories)))
    (mapc (lambda (f)
            (load f 'noerror))
          autoloads)))

(provide 'guix-emacs)

;;; guix-emacs.el ends here
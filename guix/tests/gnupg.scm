;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2020 Ludovic Courtès <ludo@gnu.org>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (guix tests gnupg)
  #:use-module (guix utils)
  #:use-module (guix build utils)
  #:use-module (ice-9 match)
  #:export (gpg-command
            gpgconf-command
            with-fresh-gnupg-setup))

(define gpg-command
  (make-parameter "gpg"))

(define gpgconf-command
  (make-parameter "gpgconf"))

(define (call-with-fresh-gnupg-setup imported thunk)
  (call-with-temporary-directory
   (lambda (home)
     (with-environment-variables `(("GNUPGHOME" ,home))
       (dynamic-wind
         (lambda ()
           (for-each (lambda (file)
                       (invoke (gpg-command) "--import" file))
                     imported))
         thunk
         (lambda ()
           ;; Terminate 'gpg-agent' & co.
           (invoke (gpgconf-command) "--kill" "all")))))))

(define-syntax-rule (with-fresh-gnupg-setup imported exp ...)
  "Evaluate EXP in the context of a fresh GnuPG setup where all the files
listed in IMPORTED, and only them, have been imported.  This sets 'GNUPGHOME'
such that the user's real GnuPG files are left untouched.  The 'gpg-agent'
process is terminated afterwards."
  (call-with-fresh-gnupg-setup imported (lambda () exp ...)))

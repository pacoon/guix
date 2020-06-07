;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2012, 2013, 2014, 2015, 2016, 2018, 2019 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2017 Caleb Ristvedt <caleb.ristvedt@cune.org>
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

(define-module (guix config)
  #:export (%guix-package-name
            %guix-version
            %guix-bug-report-address
            %guix-home-page-url

            %storedir
            %localstatedir
            %sysconfdir

            %store-directory
            %state-directory
            %store-database-directory
            %config-directory

            %system
            %libz
            %liblz
            %gzip
            %bzip2
            %xz))

;;; Commentary:
;;;
;;; Compile-time configuration of Guix.  When adding a substitution variable
;;; here, make sure to equip (guix scripts pull) to substitute it.
;;;
;;; Code:

(define %guix-package-name
  "GNU Guix")

(define %guix-version
  "1.0.1.17089-7e269")

(define %guix-bug-report-address
  "bug-guix@gnu.org")

(define %guix-home-page-url
  "https://www.gnu.org/software/guix/")

(define %storedir
  "/gnu/store")

(define %localstatedir
  "/var")

(define %sysconfdir
  "/usr/local/etc")

(define %store-directory
  (or (and=> (getenv "NIX_STORE_DIR") canonicalize-path)
      %storedir))

(define %state-directory
  ;; This must match `NIX_STATE_DIR' as defined in `nix/local.mk'.
  (or (getenv "GUIX_STATE_DIRECTORY")
      (string-append %localstatedir "/guix")))

(define %store-database-directory
  (or (getenv "GUIX_DATABASE_DIRECTORY")
      (string-append %state-directory "/db")))

(define %config-directory
  ;; This must match `GUIX_CONFIGURATION_DIRECTORY' as defined in `nix/local.mk'.
  (or (getenv "GUIX_CONFIGURATION_DIRECTORY")
      (string-append %sysconfdir "/guix")))

(define %system
  "x86_64-linux")

(define %libz
  "/gnu/store/rykm237xkmq7rl1p0nwass01p090p88x-zlib-1.2.11/lib/libz")

(define %liblz
  "/gnu/store/9jpb6shw9a9adl8x9s36gayr0v1z9fmw-profile/lib/liblz")

(define %gzip
  "/gnu/store/9jpb6shw9a9adl8x9s36gayr0v1z9fmw-profile/bin/gzip")

(define %bzip2
  "/gnu/store/9jpb6shw9a9adl8x9s36gayr0v1z9fmw-profile/bin/bzip2")

(define %xz
  "/gnu/store/9jpb6shw9a9adl8x9s36gayr0v1z9fmw-profile/bin/xz")

;;; config.scm ends here

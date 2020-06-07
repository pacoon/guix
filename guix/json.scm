;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2018, 2019 Ludovic Courtès <ludo@gnu.org>
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

(define-module (guix json)
  #:use-module (json)
  #:use-module (srfi srfi-9)
  #:export (define-json-mapping))

;;; Commentary:
;;;
;;; Helpers to map JSON objects to SRFI-9 records.  Taken from (guix swh).
;;;
;;; Code:

(define-syntax-rule (define-json-reader json->record ctor spec ...)
  "Define JSON->RECORD as a procedure that converts a JSON representation,
read from a port, string, or hash table, into a record created by CTOR and
following SPEC, a series of field specifications."
  (define (json->record input)
    (let ((table (cond ((port? input)
                        (json->scm input))
                       ((string? input)
                        (json-string->scm input))
                       ((or (null? input) (pair? input))
                        input))))
      (let-syntax ((extract-field (syntax-rules ()
                                    ((_ table (field key json->value))
                                     (json->value (assoc-ref table key)))
                                    ((_ table (field key))
                                     (assoc-ref table key))
                                    ((_ table (field))
                                     (assoc-ref table
                                                (symbol->string 'field))))))
        (ctor (extract-field table spec) ...)))))

(define-syntax-rule (define-json-mapping rtd ctor pred json->record
                      (field getter spec ...) ...)
  "Define RTD as a record type with the given FIELDs and GETTERs, à la SRFI-9,
and define JSON->RECORD as a conversion from JSON to a record of this type."
  (begin
    (define-record-type rtd
      (ctor field ...)
      pred
      (field getter) ...)

    (define-json-reader json->record ctor
      (field spec ...) ...)))

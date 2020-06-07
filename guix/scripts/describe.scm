;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2018, 2019, 2020 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2018 Oleg Pykhalov <go.wigust@gmail.com>
;;; Copyright © 2020 Ekaitz Zarraga <ekaitz@elenq.tech>
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

(define-module (guix scripts describe)
  #:use-module ((guix config) #:select (%guix-version))
  #:use-module ((guix ui) #:hide (display-profile-content))
  #:use-module ((guix utils) #:select (string-replace-substring))
  #:use-module (guix channels)
  #:use-module (guix scripts)
  #:use-module (guix describe)
  #:use-module (guix profiles)
  #:use-module (git)
  #:use-module (json)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-37)
  #:use-module (ice-9 match)
  #:autoload   (ice-9 pretty-print) (pretty-print)
  #:use-module (web uri)
  #:export (display-profile-content
            channel-commit-hyperlink

            guix-describe))


;;;
;;; Command-line options.
;;;
(define %available-formats '("human" "channels" "json" "recutils"))

(define (list-formats)
  (display (G_ "The available formats are:\n"))
  (newline)
  (for-each (lambda (f)
              (format #t "  - ~a~%" f))
            %available-formats))

(define %options
  ;; Specifications of the command-line options.
  (list (option '(#\f "format") #t #f
                (lambda (opt name arg result)
                  (unless (member arg %available-formats)
                    (leave (G_ "~a: unsupported output format~%") arg))
                  (alist-cons 'format (string->symbol arg) result)))
        (option '("list-formats") #f #f
                (lambda (opt name arg result)
                  (list-formats)
                  (exit 0)))
        (option '(#\p "profile") #t #f
                (lambda (opt name arg result)
                  (alist-cons 'profile (canonicalize-profile arg)
                              result)))
        (option '(#\h "help") #f #f
                (lambda args
                  (show-help)
                  (exit 0)))
        (option '(#\V "version") #f #f
                (lambda args
                  (show-version-and-exit "guix describe")))))

(define %default-options
  ;; Alist of default option values.
  '((format . human)))

(define (show-help)
  (display (G_ "Usage: guix describe [OPTION]...
Display information about the channels currently in use.\n"))
  (display (G_ "
  -f, --format=FORMAT    display information in the given FORMAT"))
  (display (G_ "
      --list-formats     display available formats"))
  (display (G_ "
  -p, --profile=PROFILE  display information about PROFILE"))
  (newline)
  (display (G_ "
  -h, --help             display this help and exit"))
  (display (G_ "
  -V, --version          display version information and exit"))
  (newline)
  (show-bug-report-information))

(define (display-package-search-path fmt)
  "Display GUIX_PACKAGE_PATH, if it is set, according to FMT."
  (match (getenv "GUIX_PACKAGE_PATH")
    (#f #t)
    (string
     (match fmt
       ('human
        (format #t "~%GUIX_PACKAGE_PATH=\"~a\"~%" string))
       ('channels
        (format #t (G_ "~%;; warning: GUIX_PACKAGE_PATH=\"~a\"~%")
                string))
       (_
        (warning (G_ "'GUIX_PACKAGE_PATH' is set but it is not captured~%")))))))

(define (channel->sexp channel)
  `(channel
    (name ',(channel-name channel))
    (url ,(channel-url channel))
    (commit ,(channel-commit channel))))

(define (channel->json channel)
  (scm->json-string `((name . ,(channel-name channel))
                      (url . ,(channel-url channel))
                      (commit . ,(channel-commit channel)))))

(define (channel->recutils channel port)
  (format port "name: ~a~%" (channel-name channel))
  (format port "url: ~a~%" (channel-url channel))
  (format port "commit: ~a~%" (channel-commit channel)))

(define (display-checkout-info fmt)
  "Display information about the current checkout according to FMT, a symbol
denoting the requested format.  Exit if the current directory does not lie
within a Git checkout."
  (let* ((program    (car (command-line)))
         (directory  (catch 'git-error
                       (lambda ()
                         (repository-discover (dirname program)))
                       (lambda (key err)
                         (report-error (G_ "failed to determine origin~%"))
                         (display-hint (format #f (G_ "Perhaps this
@command{guix} command was not obtained with @command{guix pull}?  Its version
string is ~a.~%")
                                               %guix-version))
                         (exit 1))))
         (repository (repository-open directory))
         (head       (repository-head repository))
         (commit     (oid->string (reference-target head))))
    (match fmt
      ('human
       (format #t (G_ "Git checkout:~%"))
       (format #t (G_ "  repository: ~a~%") (dirname directory))
       (format #t (G_ "  branch: ~a~%") (reference-shorthand head))
       (format #t (G_ "  commit: ~a~%") commit))
      ('channels
       (pretty-print `(list ,(channel->sexp (channel (name 'guix)
                                                     (url (dirname directory))
                                                     (commit commit))))))
      ('json
       (display (channel->json (channel (name 'guix)
                                        (url (dirname directory))
                                        (commit commit))))
       (newline))
      ('recutils
       (channel->recutils (channel (name 'guix)
                                   (url (dirname directory))
                                   (commit commit))
                          (current-output-port))))
    (display-package-search-path fmt)))

(define (display-profile-info profile fmt)
  "Display information about PROFILE, a profile as created by (guix channels),
in the format specified by FMT."
  (define number
    (generation-number profile))

  (define channels
    (profile-channels (if (zero? number)
                          profile
                          (generation-file-name profile number))))

  (match fmt
    ('human
     (display-profile-content profile number))
    ('channels
     (pretty-print `(list ,@(map channel->sexp channels))))
    ('json
     (format #t "[~a]~%" (string-join (map channel->json channels) ",")))
    ('recutils
     (format #t "~{~a~%~}"
             (map (lambda (channel)
                    (with-output-to-string
                      (lambda ()
                        (channel->recutils channel (current-output-port)))))
                  channels))))
  (display-package-search-path fmt))

(define (display-profile-content profile number)
  "Display the packages in PROFILE, generation NUMBER, in a human-readable
way and displaying details about the channel's source code."
  (display-generation profile number)
  (for-each (lambda (entry)
              (format #t "  ~a ~a~%"
                      (manifest-entry-name entry)
                      (manifest-entry-version entry))
              (match (assq 'source (manifest-entry-properties entry))
                (('source ('repository ('version 0)
                                       ('url url)
                                       ('branch branch)
                                       ('commit commit)
                                       _ ...))
                 (let ((channel (channel (name 'nameless)
                                         (url url)
                                         (branch branch)
                                         (commit commit))))
                   (format #t (G_ "    repository URL: ~a~%") url)
                   (when branch
                     (format #t (G_ "    branch: ~a~%") branch))
                   (format #t (G_ "    commit: ~a~%")
                           (if (supports-hyperlinks?)
                               (channel-commit-hyperlink channel commit)
                               commit))))
                (_ #f)))

            ;; Show most recently installed packages last.
            (reverse
             (manifest-entries
              (profile-manifest (if (zero? number)
                                    profile
                                    (generation-file-name profile number)))))))

(define %vcs-web-views
  ;; Hard-coded list of host names and corresponding web view URL templates.
  ;; TODO: Allow '.guix-channel' files to specify a URL template.
  (let ((labhub-url (lambda (repository-url commit)
                      (string-append
                       (if (string-suffix? ".git" repository-url)
                           (string-drop-right repository-url 4)
                           repository-url)
                       "/commit/" commit))))
    `(("git.savannah.gnu.org"
       ,(lambda (repository-url commit)
          (string-append (string-replace-substring repository-url
                                                   "/git/" "/cgit/")
                         "/commit/?id=" commit)))
      ("notabug.org" ,labhub-url)
      ("framagit.org" ,labhub-url)
      ("gitlab.com" ,labhub-url)
      ("gitlab.inria.fr" ,labhub-url)
      ("github.com" ,labhub-url))))

(define* (channel-commit-hyperlink channel
                                   #:optional
                                   (commit (channel-commit channel)))
  "Return a hyperlink for COMMIT in CHANNEL, using COMMIT as the hyperlink's
text.  The hyperlink links to a web view of COMMIT, when available."
  (let* ((url  (channel-url channel))
         (uri  (string->uri url))
         (host (and uri (uri-host uri))))
    (if host
        (match (assoc host %vcs-web-views)
          (#f
           commit)
          ((_ template)
           (hyperlink (template url commit) commit)))
        commit)))


;;;
;;; Entry point.
;;;

(define (guix-describe . args)
  (let* ((opts    (args-fold* args %options
                              (lambda (opt name arg result)
                                (leave (G_ "~A: unrecognized option~%")
                                       name))
                              cons
                              %default-options))
         (format  (assq-ref opts 'format))
         (profile (or (assq-ref opts 'profile) (current-profile))))
    (with-error-handling
      (match profile
        (#f
         (display-checkout-info format))
        (profile
         (display-profile-info (canonicalize-profile profile) format))))))

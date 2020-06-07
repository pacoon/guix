;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017, 2020 Mathieu Othacehe <m.othacehe@gmail.com>
;;; Copyright © 2018, 2019, 2020 Ludovic Courtès <ludo@gnu.org>
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

(define-module (guix git)
  #:use-module (git)
  #:use-module (git object)
  #:use-module (guix i18n)
  #:use-module (guix base32)
  #:use-module (gcrypt hash)
  #:use-module ((guix build utils) #:select (mkdir-p))
  #:use-module (guix store)
  #:use-module (guix utils)
  #:use-module (guix records)
  #:use-module (guix gexp)
  #:use-module (guix sets)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-34)
  #:use-module (srfi srfi-35)
  #:export (%repository-cache-directory
            honor-system-x509-certificates!

            with-repository
            update-cached-checkout
            url+commit->name
            latest-repository-commit
            commit-difference
            commit-relation

            git-checkout
            git-checkout?
            git-checkout-url
            git-checkout-branch
            git-checkout-commit
            git-checkout-recursive?))

(define %repository-cache-directory
  (make-parameter (string-append (cache-directory #:ensure? #f)
                                 "/checkouts")))

(define (honor-system-x509-certificates!)
  "Use the system's X.509 certificates for Git checkouts over HTTPS.  Honor
the 'SSL_CERT_FILE' and 'SSL_CERT_DIR' environment variables."
  ;; On distros such as CentOS 7, /etc/ssl/certs contains only a couple of
  ;; files (instead of all the certificates) among which "ca-bundle.crt".  On
  ;; other distros /etc/ssl/certs usually contains the whole set of
  ;; certificates along with "ca-certificates.crt".  Try to choose the right
  ;; one.
  (let ((file      (letrec-syntax ((choose
                                    (syntax-rules ()
                                      ((_ file rest ...)
                                       (let ((f file))
                                         (if (and f (file-exists? f))
                                             f
                                             (choose rest ...))))
                                      ((_)
                                       #f))))
                     (choose (getenv "SSL_CERT_FILE")
                             "/etc/ssl/certs/ca-certificates.crt"
                             "/etc/ssl/certs/ca-bundle.crt")))
        (directory (or (getenv "SSL_CERT_DIR") "/etc/ssl/certs")))
    (and (or file
             (and=> (stat directory #f)
                    (lambda (st)
                      (> (stat:nlink st) 2))))
         (begin
           (set-tls-certificate-locations! directory file)
           #t))))

(define %certificates-initialized?
  ;; Whether 'honor-system-x509-certificates!' has already been called.
  #f)

(define-syntax-rule (with-libgit2 thunk ...)
  (begin
    ;; XXX: The right thing to do would be to call (libgit2-shutdown) here,
    ;; but pointer finalizers used in guile-git may be called after shutdown,
    ;; resulting in a segfault. Hence, let's skip shutdown call for now.
    (libgit2-init!)
    (unless %certificates-initialized?
      (honor-system-x509-certificates!)
      (set! %certificates-initialized? #t))
    thunk ...))

(define* (url-cache-directory url
                              #:optional (cache-directory
                                          (%repository-cache-directory))
                              #:key recursive?)
  "Return the directory associated to URL in %repository-cache-directory."
  (string-append
   cache-directory "/"
   (bytevector->base32-string
    (sha256 (string->utf8 (if recursive?
                              (string-append "R:" url)
                              url))))))

;; Authentication appeared in Guile-Git 0.3.0, check if it is available.
(define auth-supported?
  (false-if-exception (resolve-interface '(git auth))))

(define (clone* url directory)
  "Clone git repository at URL into DIRECTORY.  Upon failure,
make sure no empty directory is left behind."
  (with-throw-handler #t
    (lambda ()
      (mkdir-p directory)

      ;; Note: Explicitly pass options to work around the invalid default
      ;; value in Guile-Git: <https://bugs.gnu.org/29238>.
      (if (module-defined? (resolve-interface '(git))
                           'clone-init-options)
          (let ((auth-method (and auth-supported?
                                  (%make-auth-ssh-agent))))
            (clone url directory
                   (if auth-supported?
                       (make-clone-options
                        #:fetch-options (make-fetch-options auth-method))
                       (clone-init-options))))
          (clone url directory)))
    (lambda _
      (false-if-exception (rmdir directory)))))

(define (url+commit->name url sha1)
  "Return the string \"<REPO-NAME>-<SHA1:7>\" where REPO-NAME is the name of
the git repository, extracted from URL and SHA1:7 the seven first digits
of SHA1 string."
  (string-append
   (string-replace-substring
    (last (string-split url #\/)) ".git" "")
   "-" (string-take sha1 7)))

(define (switch-to-ref repository ref)
  "Switch to REPOSITORY's branch, commit or tag specified by REF.  Return the
OID (roughly the commit hash) corresponding to REF."
  (define obj
    (let resolve ((ref ref))
      (match ref
        (('branch . branch)
         (let ((oid (reference-target
                     (branch-lookup repository branch BRANCH-REMOTE))))
           (object-lookup repository oid)))
        (('commit . commit)
         (let ((len (string-length commit)))
           ;; 'object-lookup-prefix' appeared in Guile-Git in Mar. 2018, so we
           ;; can't be sure it's available.  Furthermore, 'string->oid' used to
           ;; read out-of-bounds when passed a string shorter than 40 chars,
           ;; which is why we delay calls to it below.
           (if (< len 40)
               (if (module-defined? (resolve-interface '(git object))
                                    'object-lookup-prefix)
                   (object-lookup-prefix repository (string->oid commit) len)
                   (raise (condition
                           (&message
                            (message "long Git object ID is required")))))
               (object-lookup repository (string->oid commit)))))
        (('tag-or-commit . str)
         (if (or (> (string-length str) 40)
                 (not (string-every char-set:hex-digit str)))
             (resolve `(tag . ,str))              ;definitely a tag
             (catch 'git-error
               (lambda ()
                 (resolve `(tag . ,str)))
               (lambda _
                 ;; There's no such tag, so it must be a commit ID.
                 (resolve `(commit . ,str))))))
        (('tag    . tag)
         (let ((oid (reference-name->oid repository
                                         (string-append "refs/tags/" tag))))
           ;; OID may point to a "tag" object, but it can also point directly
           ;; to a "commit" object, as surprising as it may seem.  Return that
           ;; object, whatever that is.
           (object-lookup repository oid))))))

  (reset repository obj RESET_HARD)
  (object-id obj))

(define (call-with-repository directory proc)
  (let ((repository #f))
   (dynamic-wind
     (lambda ()
       (set! repository (repository-open directory)))
     (lambda ()
       (proc repository))
     (lambda ()
       (repository-close! repository)))))

(define-syntax-rule (with-repository directory repository exp ...)
  "Open the repository at DIRECTORY and bind REPOSITORY to it within the
dynamic extent of EXP."
  (call-with-repository directory
                        (lambda (repository) exp ...)))

(define (load-git-submodules)
  "Attempt to load (git submodules), which was missing until Guile-Git 0.2.0.
Return true on success, false on failure."
  (match (false-if-exception (resolve-interface '(git submodule)))
    (#f
     (set! load-git-submodules (const #f))
     #f)
    (iface
     (module-use! (resolve-module '(guix git)) iface)
     (set! load-git-submodules (const #t))
     #t)))

(define* (update-submodules repository
                            #:key (log-port (current-error-port)))
  "Update the submodules of REPOSITORY, a Git repository object."
  ;; Guile-Git < 0.2.0 did not have (git submodule).
  (if (load-git-submodules)
      (for-each (lambda (name)
                  (let ((submodule (submodule-lookup repository name)))
                    (format log-port (G_ "updating submodule '~a'...~%")
                            name)
                    (submodule-update submodule)

                    ;; Recurse in SUBMODULE.
                    (let ((directory (string-append
                                      (repository-working-directory repository)
                                      "/" (submodule-path submodule))))
                      (with-repository directory repository
                        (update-submodules repository
                                           #:log-port log-port)))))
                (repository-submodules repository))
      (format (current-error-port)
              (G_ "Support for submodules is missing; \
please upgrade Guile-Git.~%"))))

(define (reference-available? repository ref)
  "Return true if REF, a reference such as '(commit . \"cabba9e\"), is
definitely available in REPOSITORY, false otherwise."
  (match ref
    (('commit . commit)
     (catch 'git-error
       (lambda ()
         (->bool (commit-lookup repository (string->oid commit))))
       (lambda (key error . rest)
         (if (= GIT_ENOTFOUND (git-error-code error))
             #f
             (apply throw key error rest)))))
    (_
     #f)))

(define* (update-cached-checkout url
                                 #:key
                                 (ref '(branch . "master"))
                                 recursive?
                                 starting-commit
                                 (log-port (%make-void-port "w"))
                                 (cache-directory
                                  (url-cache-directory
                                   url (%repository-cache-directory)
                                   #:recursive? recursive?)))
  "Update the cached checkout of URL to REF in CACHE-DIRECTORY.  Return three
values: the cache directory name, and the SHA1 commit (a string) corresponding
to REF, and the relation of the new commit relative to STARTING-COMMIT (if
provided) as returned by 'commit-relation'.

REF is pair whose key is [branch | commit | tag | tag-or-commit ] and value
the associated data: [<branch name> | <sha1> | <tag name> | <string>].

When RECURSIVE? is true, check out submodules as well, if any."
  (define canonical-ref
    ;; We used to require callers to specify "origin/" for each branch, which
    ;; made little sense since the cache should be transparent to them.  So
    ;; here we append "origin/" if it's missing and otherwise keep it.
    (match ref
      (('branch . branch)
       `(branch . ,(if (string-prefix? "origin/" branch)
                       branch
                       (string-append "origin/" branch))))
      (_ ref)))

  (with-libgit2
   (let* ((cache-exists? (openable-repository? cache-directory))
          (repository    (if cache-exists?
                             (repository-open cache-directory)
                             (clone* url cache-directory))))
     ;; Only fetch remote if it has not been cloned just before.
     (when (and cache-exists?
                (not (reference-available? repository ref)))
       (if auth-supported?
           (let ((auth-method (and auth-supported?
                                   (%make-auth-ssh-agent))))
             (remote-fetch (remote-lookup repository "origin")
                           #:fetch-options (make-fetch-options auth-method)))
           (remote-fetch (remote-lookup repository "origin"))))
     (when recursive?
       (update-submodules repository #:log-port log-port))

     ;; Note: call 'commit-relation' from here because it's more efficient
     ;; than letting users re-open the checkout later on.
     (let* ((oid      (switch-to-ref repository canonical-ref))
            (new      (and starting-commit
                           (commit-lookup repository oid)))
            (old      (and starting-commit
                           (commit-lookup repository
                                          (string->oid starting-commit))))
            (relation (and starting-commit
                           (commit-relation old new))))

       ;; Reclaim file descriptors and memory mappings associated with
       ;; REPOSITORY as soon as possible.
       (when (module-defined? (resolve-interface '(git repository))
                              'repository-close!)
         (repository-close! repository))

       (values cache-directory (oid->string oid) relation)))))

(define* (latest-repository-commit store url
                                   #:key
                                   recursive?
                                   (log-port (%make-void-port "w"))
                                   (cache-directory
                                    (%repository-cache-directory))
                                   (ref '(branch . "master")))
  "Return two values: the content of the git repository at URL copied into a
store directory and the sha1 of the top level commit in this directory.  The
reference to be checkout, once the repository is fetched, is specified by REF.
REF is pair whose key is [branch | commit | tag] and value the associated
data, respectively [<branch name> | <sha1> | <tag name>].

When RECURSIVE? is true, check out submodules as well, if any.

Git repositories are kept in the cache directory specified by
%repository-cache-directory parameter.

Log progress and checkout info to LOG-PORT."
  (define (dot-git? file stat)
    (and (string=? (basename file) ".git")
         (or (eq? 'directory (stat:type stat))

             ;; Submodule checkouts end up with a '.git' regular file that
             ;; contains metadata about where their actual '.git' directory
             ;; lives.
             (and recursive?
                  (eq? 'regular (stat:type stat))))))

  (format log-port "updating checkout of '~a'...~%" url)
  (let*-values
      (((checkout commit _)
        (update-cached-checkout url
                                #:recursive? recursive?
                                #:ref ref
                                #:cache-directory
                                (url-cache-directory url cache-directory
                                                     #:recursive?
                                                     recursive?)
                                #:log-port log-port))
       ((name)
        (url+commit->name url commit)))
    (format log-port "retrieved commit ~a~%" commit)
    (values (add-to-store store name #t "sha256" checkout
                          #:select? (negate dot-git?))
            commit)))

(define (print-git-error port key args default-printer)
  (match args
    (((? git-error? error) . _)
     (format port (G_ "Git error: ~a~%")
             (git-error-message error)))))

(set-exception-printer! 'git-error print-git-error)


;;;
;;; Commit difference.
;;;

(define* (commit-closure commit #:optional (visited (setq)))
  "Return the closure of COMMIT as a set.  Skip commits contained in VISITED,
a set, and adjoin VISITED to the result."
  (let loop ((commits (list commit))
             (visited visited))
    (match commits
      (()
       visited)
      ((head . tail)
       (if (set-contains? visited head)
           (loop tail visited)
           (loop (append (commit-parents head) tail)
                 (set-insert head visited)))))))

(define* (commit-difference new old #:optional (excluded '()))
  "Return the list of commits between NEW and OLD, where OLD is assumed to be
an ancestor of NEW.  Exclude all the commits listed in EXCLUDED along with
their ancestors.

Essentially, this computes the set difference between the closure of NEW and
that of OLD."
  (let loop ((commits (list new))
             (result '())
             (visited (commit-closure old (list->setq excluded))))
    (match commits
      (()
       (reverse result))
      ((head . tail)
       (if (set-contains? visited head)
           (loop tail result visited)
           (loop (append (commit-parents head) tail)
                 (cons head result)
                 (set-insert head visited)))))))

(define (commit-relation old new)
  "Return a symbol denoting the relation between OLD and NEW, two commit
objects: 'ancestor (meaning that OLD is an ancestor of NEW), 'descendant, or
'unrelated, or 'self (OLD and NEW are the same commit)."
  (if (eq? old new)
      'self
      (let ((newest (commit-closure new)))
        (if (set-contains? newest old)
            'ancestor
            (let* ((seen   (list->setq (commit-parents new)))
                   (oldest (commit-closure old seen)))
              (if (set-contains? oldest new)
                  'descendant
                  'unrelated))))))


;;;
;;; Checkouts.
;;;

;; Representation of the "latest" checkout of a branch or a specific commit.
(define-record-type* <git-checkout>
  git-checkout make-git-checkout
  git-checkout?
  (url     git-checkout-url)
  (branch  git-checkout-branch (default "master"))
  (commit  git-checkout-commit (default #f))      ;#f | tag | commit
  (recursive? git-checkout-recursive? (default #f)))

(define* (latest-repository-commit* url #:key ref recursive? log-port)
  ;; Monadic variant of 'latest-repository-commit'.
  (lambda (store)
    ;; The caller--e.g., (guix scripts build)--may not handle 'git-error' so
    ;; translate it into '&message' conditions that we know will be properly
    ;; handled.
    (catch 'git-error
      (lambda ()
        (values (latest-repository-commit store url
                                          #:ref ref
                                          #:recursive? recursive?
                                          #:log-port log-port)
                store))
      (lambda (key error . _)
        (raise (condition
                (&message
                 (message
                  (match ref
                    (('commit . commit)
                     (format #f (G_ "cannot fetch commit ~a from ~a: ~a")
                             commit url (git-error-message error)))
                    (('branch . branch)
                     (format #f (G_ "cannot fetch branch '~a' from ~a: ~a")
                             branch url (git-error-message error)))
                    (_
                     (format #f (G_ "Git failure while fetching ~a: ~a")
                             url (git-error-message error))))))))))))

(define-gexp-compiler (git-checkout-compiler (checkout <git-checkout>)
                                             system target)
  ;; "Compile" CHECKOUT by updating the local checkout and adding it to the
  ;; store.
  (match checkout
    (($ <git-checkout> url branch commit recursive?)
     (latest-repository-commit* url
                                #:ref (if commit
                                          `(tag-or-commit . ,commit)
                                          `(branch . ,branch))
                                #:recursive? recursive?
                                #:log-port (current-error-port)))))

;; Local Variables:
;; eval: (put 'with-repository 'scheme-indent-function 2)
;; End:

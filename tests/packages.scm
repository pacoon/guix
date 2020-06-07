;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
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

(define-module (test-packages)
  #:use-module (guix tests)
  #:use-module (guix store)
  #:use-module (guix monads)
  #:use-module (guix grafts)
  #:use-module ((guix gexp) #:select (local-file local-file-file))
  #:use-module ((guix utils)
                ;; Rename the 'location' binding to allow proper syntax
                ;; matching when setting the 'location' field of a package.
                #:renamer (lambda (name)
                            (cond ((eq? name 'location) 'make-location)
                                  (else name))))
  #:use-module ((gcrypt hash) #:prefix gcrypt:)
  #:use-module (guix derivations)
  #:use-module (guix packages)
  #:use-module (guix grafts)
  #:use-module (guix search-paths)
  #:use-module (guix build-system)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system gnu)
  #:use-module (guix memoization)
  #:use-module (guix profiles)
  #:use-module (guix scripts package)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages bootstrap)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages xml)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-34)
  #:use-module (srfi srfi-35)
  #:use-module (srfi srfi-64)
  #:use-module (rnrs bytevectors)
  #:use-module (rnrs io ports)
  #:use-module (ice-9 vlist)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 match))

;; Test the high-level packaging layer.

(define %store
  (open-connection-for-tests))

;; Globally disable grafting to avoid rebuilding the world ('graft-derivation'
;; can trigger builds early.)
(%graft? #f)


(test-begin "packages")

(test-assert "printer with location"
  (string-match "^#<package foo@0 foo.scm:42 [[:xdigit:]]+>$"
                (with-output-to-string
                  (lambda ()
                    (write
                     (dummy-package "foo"
                       (location (make-location "foo.scm" 42 7))))))))

(test-assert "printer without location"
  (string-match "^#<package foo@0 [[:xdigit:]]+>$"
                (with-output-to-string
                  (lambda ()
                    (write
                     (dummy-package "foo" (location #f)))))))

(test-assert "hidden-package"
  (and (hidden-package? (hidden-package (dummy-package "foo")))
       (not (hidden-package? (dummy-package "foo")))))

(test-assert "package-superseded"
  (let* ((new (dummy-package "bar"))
         (old (deprecated-package "foo" new)))
    (and (eq? (package-superseded old) new)
         (mock ((gnu packages) find-best-packages-by-name (const (list old)))
               (specification->package "foo")
               (and (eq? new (specification->package "foo"))
                    (eq? new (specification->package+output "foo")))))))

(test-assert "transaction-upgrade-entry, zero upgrades"
  (let* ((old (dummy-package "foo" (version "1")))
         (tx  (mock ((gnu packages) find-best-packages-by-name
                     (const '()))
                    (transaction-upgrade-entry
                     #f                           ;no store access needed
                     (manifest-entry
                       (inherit (package->manifest-entry old))
                       (item (string-append (%store-prefix) "/"
                                            (make-string 32 #\e) "-foo-1")))
                     (manifest-transaction)))))
    (manifest-transaction-null? tx)))

(test-assert "transaction-upgrade-entry, zero upgrades, equivalent package"
  (let* ((old (dummy-package "foo" (version "1")))
         (drv (package-derivation %store old))
         (tx  (mock ((gnu packages) find-best-packages-by-name
                     (const (list old)))
                    (transaction-upgrade-entry
                     %store
                     (manifest-entry
                       (inherit (package->manifest-entry old))
                       (item (derivation->output-path drv)))
                     (manifest-transaction)))))
    (manifest-transaction-null? tx)))

(test-assert "transaction-upgrade-entry, zero upgrades, propagated inputs"
  ;; Properly detect equivalent packages even when they have propagated
  ;; inputs.  See <https://bugs.gnu.org/35872>.
  (let* ((dep (dummy-package "dep" (version "2")))
         (old (dummy-package "foo" (version "1")
                             (propagated-inputs `(("dep" ,dep)))))
         (drv (package-derivation %store old))
         (tx  (mock ((gnu packages) find-best-packages-by-name
                     (const (list old)))
                    (transaction-upgrade-entry
                     %store
                     (manifest-entry
                       (inherit (package->manifest-entry old))
                       (item (derivation->output-path drv))
                       (dependencies
                        (list (manifest-entry
                                (inherit (package->manifest-entry dep))
                                (item (derivation->output-path
                                       (package-derivation %store dep)))))))
                     (manifest-transaction)))))
    (manifest-transaction-null? tx)))

(test-assert "transaction-upgrade-entry, one upgrade"
  (let* ((old (dummy-package "foo" (version "1")))
         (new (dummy-package "foo" (version "2")))
         (tx  (mock ((gnu packages) find-best-packages-by-name
                     (const (list new)))
                    (transaction-upgrade-entry
                     #f                           ;no store access needed
                     (manifest-entry
                       (inherit (package->manifest-entry old))
                       (item (string-append (%store-prefix) "/"
                                            (make-string 32 #\e) "-foo-1")))
                     (manifest-transaction)))))
    (and (match (manifest-transaction-install tx)
           ((($ <manifest-entry> "foo" "2" "out" item))
            (eq? item new)))
         (null? (manifest-transaction-remove tx)))))

(test-assert "transaction-upgrade-entry, superseded package"
  (let* ((old (dummy-package "foo" (version "1")))
         (new (dummy-package "bar" (version "2")))
         (dep (deprecated-package "foo" new))
         (tx  (mock ((gnu packages) find-best-packages-by-name
                     (const (list dep)))
                    (transaction-upgrade-entry
                     #f                           ;no store access needed
                     (manifest-entry
                       (inherit (package->manifest-entry old))
                       (item (string-append (%store-prefix) "/"
                                            (make-string 32 #\e) "-foo-1")))
                     (manifest-transaction)))))
    (and (match (manifest-transaction-install tx)
           ((($ <manifest-entry> "bar" "2" "out" item))
            (eq? item new)))
         (match (manifest-transaction-remove tx)
           (((? manifest-pattern? pattern))
            (and (string=? (manifest-pattern-name pattern) "foo")
                 (string=? (manifest-pattern-version pattern) "1")
                 (string=? (manifest-pattern-output pattern) "out")))))))

(test-assert "transaction-upgrade-entry, grafts"
  ;; Ensure that, when grafts are enabled, 'transaction-upgrade-entry' doesn't
  ;; try to build stuff.
  (with-build-handler (const 'failed!)
    (parameterize ((%graft? #t))
      (let* ((old (dummy-package "foo" (version "1")))
             (bar (dummy-package "bar" (version "0")
                                 (replacement old)))
             (new (dummy-package "foo" (version "1")
                                 (inputs `(("bar" ,bar)))))
             (tx  (mock ((gnu packages) find-best-packages-by-name
                         (const (list new)))
                        (transaction-upgrade-entry
                         %store
                         (manifest-entry
                           (inherit (package->manifest-entry old))
                           (item (string-append (%store-prefix) "/"
                                                (make-string 32 #\e) "-foo-1")))
                         (manifest-transaction)))))
        (and (match (manifest-transaction-install tx)
               ((($ <manifest-entry> "foo" "1" "out" item))
                (eq? item new)))
             (null? (manifest-transaction-remove tx)))))))

(test-assert "package-field-location"
  (let ()
    (define (goto port line column)
      (unless (and (= (port-column port) (- column 1))
                   (= (port-line port) (- line 1)))
        (unless (eof-object? (get-char port))
          (goto port line column))))

    (define read-at
      (match-lambda
       (($ <location> file line column)
        (call-with-input-file (search-path %load-path file)
          (lambda (port)
            (goto port line column)
            (read port))))))

    ;; Until Guile 2.0.6 included, source properties were added only to pairs.
    ;; Thus, check against both VALUE and (FIELD VALUE).
    (and (member (read-at (package-field-location %bootstrap-guile 'name))
                 (let ((name (package-name %bootstrap-guile)))
                   (list name `(name ,name))))
         (member (read-at (package-field-location %bootstrap-guile 'version))
                 (let ((version (package-version %bootstrap-guile)))
                   (list version `(version ,version))))
         (not (package-field-location %bootstrap-guile 'does-not-exist)))))

;; Make sure we don't change the file name to an absolute file name.
(test-equal "package-field-location, relative file name"
  (location-file (package-location %bootstrap-guile))
  (with-fluids ((%file-port-name-canonicalization 'absolute))
    (location-file (package-field-location %bootstrap-guile 'version))))

(test-assert "package-transitive-inputs"
  (let* ((a (dummy-package "a"))
         (b (dummy-package "b"
              (propagated-inputs `(("a" ,a)))))
         (c (dummy-package "c"
              (inputs `(("a" ,a)))))
         (d (dummy-package "d"
              (propagated-inputs `(("x" "something.drv")))))
         (e (dummy-package "e"
              (inputs `(("b" ,b) ("c" ,c) ("d" ,d))))))
    (and (null? (package-transitive-inputs a))
         (equal? `(("a" ,a)) (package-transitive-inputs b))
         (equal? `(("a" ,a)) (package-transitive-inputs c))
         (equal? (package-propagated-inputs d)
                 (package-transitive-inputs d))
         (equal? `(("b" ,b) ("c" ,c) ("d" ,d)
                   ("a" ,a) ("x" "something.drv"))
                 (pk 'x (package-transitive-inputs e))))))

(test-assert "package-transitive-inputs, no duplicates"
  (let* ((a (dummy-package "a"))
         (b (dummy-package "b"
              (inputs `(("a+" ,a)))
              (native-inputs `(("a*" ,a)))
              (propagated-inputs `(("a" ,a)))))
         (c (dummy-package "c"
              (propagated-inputs `(("b" ,b)))))
         (d (dummy-package "d"
              (inputs `(("a" ,a) ("c" ,c)))))
         (e (dummy-package "e"
              (inputs `(("b" ,b) ("c" ,c))))))
    (and (null? (package-transitive-inputs a))
         (equal? `(("a*" ,a) ("a+" ,a) ("a" ,a))   ;here duplicates are kept
                 (package-transitive-inputs b))
         (equal? `(("b" ,b) ("a" ,a))
                 (package-transitive-inputs c))
         (equal? `(("a" ,a) ("c" ,c) ("b" ,b))     ;duplicate A removed
                 (package-transitive-inputs d))
         (equal? `(("b" ,b) ("c" ,c) ("a" ,a))
                 (package-transitive-inputs e))))) ;ditto

(test-equal "package-transitive-supported-systems"
  '(("x" "y" "z")                                 ;a
    ("x" "y")                                     ;b
    ("y")                                         ;c
    ("y")                                         ;d
    ("y"))                                        ;e
  ;; Use TRIVIAL-BUILD-SYSTEM because it doesn't add implicit inputs and thus
  ;; doesn't restrict the set of supported systems.
  (let* ((a (dummy-package "a"
              (build-system trivial-build-system)
              (supported-systems '("x" "y" "z"))))
         (b (dummy-package "b"
              (build-system trivial-build-system)
              (supported-systems '("x" "y"))
              (inputs `(("a" ,a)))))
         (c (dummy-package "c"
              (build-system trivial-build-system)
              (supported-systems '("y" "z"))
              (inputs `(("b" ,b)))))
         (d (dummy-package "d"
              (build-system trivial-build-system)
              (supported-systems '("x" "y" "z"))
              (inputs `(("b" ,b) ("c" ,c)))))
         (e (dummy-package "e"
              (build-system trivial-build-system)
              (supported-systems '("x" "y" "z"))
              (inputs `(("d" ,d))))))
    (list (package-transitive-supported-systems a)
          (package-transitive-supported-systems b)
          (package-transitive-supported-systems c)
          (package-transitive-supported-systems d)
          (package-transitive-supported-systems e))))

(test-assert "package-closure"
  (let-syntax ((dummy-package/no-implicit
                (syntax-rules ()
                  ((_ name rest ...)
                   (package
                     (inherit (dummy-package name rest ...))
                     (build-system trivial-build-system))))))
    (let* ((a (dummy-package/no-implicit "a"))
           (b (dummy-package/no-implicit "b"
                (propagated-inputs `(("a" ,a)))))
           (c (dummy-package/no-implicit "c"
                (inputs `(("a" ,a)))))
           (d (dummy-package/no-implicit "d"
                (native-inputs `(("b" ,b)))))
           (e (dummy-package/no-implicit "e"
                (inputs `(("c" ,c) ("d" ,d))))))
      (lset= eq?
             (list a b c d e)
             (package-closure (list e))
             (package-closure (list e d))
             (package-closure (list e c b))))))

(test-equal "origin-actual-file-name"
  "foo-1.tar.gz"
  (let ((o (dummy-origin (uri "http://www.example.com/foo-1.tar.gz"))))
    (origin-actual-file-name o)))

(test-equal "origin-actual-file-name, file-name"
  "foo-1.tar.gz"
  (let ((o (dummy-origin
            (uri "http://www.example.com/tarball")
            (file-name "foo-1.tar.gz"))))
    (origin-actual-file-name o)))

(let* ((o (dummy-origin))
       (u (dummy-origin))
       (i (dummy-origin))
       (a (dummy-package "a"))
       (b (dummy-package "b"
            (inputs `(("a" ,a) ("i" ,i)))))
       (c (package (inherit b) (source o)))
       (d (dummy-package "d"
            (build-system trivial-build-system)
            (source u) (inputs `(("c" ,c))))))
  (test-assert "package-direct-sources, no source"
    (null? (package-direct-sources a)))
  (test-equal "package-direct-sources, #f source"
    (list i)
    (package-direct-sources b))
  (test-equal "package-direct-sources, not input source"
    (list u)
    (package-direct-sources d))
  (test-assert "package-direct-sources"
    (let ((s (package-direct-sources c)))
      (and (= (length (pk 's-sources s)) 2)
           (member o s)
           (member i s))))
  (test-assert "package-transitive-sources"
    (let ((s (package-transitive-sources d)))
      (and (= (length (pk 'd-sources s)) 3)
           (member o s)
           (member i s)
           (member u s)))))

(test-assert "transitive-input-references"
  (let* ((a (dummy-package "a"))
         (b (dummy-package "b"))
         (c (dummy-package "c"
              (inputs `(("a" ,a)))
              (propagated-inputs `(("boo" ,b)))))
         (d (dummy-package "d"
              (inputs `(("c*" ,c)))))
         (keys (map (match-lambda
                      (('assoc-ref 'l key)
                       key))
                    (pk 'refs (transitive-input-references
                               'l (package-inputs d))))))
    (and (= (length keys) 2)
         (member "c*" keys)
         (member "boo" keys))))

(test-equal "package-transitive-supported-systems, implicit inputs"
  %supported-systems

  ;; Here GNU-BUILD-SYSTEM adds implicit inputs that build only on
  ;; %SUPPORTED-SYSTEMS.  Thus the others must be ignored.
  (let ((p (dummy-package "foo"
               (build-system gnu-build-system)
               (supported-systems
                `("does-not-exist" "foobar" ,@%supported-systems)))))
    (parameterize ((%current-system "armhf-linux")) ; a traditionally-bootstrapped architecture
      (package-transitive-supported-systems p))))

(test-equal "package-transitive-supported-systems: reduced binary seed, implicit inputs"
  '("x86_64-linux" "i686-linux")

  ;; Here GNU-BUILD-SYSTEM adds implicit inputs that build only on
  ;; %SUPPORTED-SYSTEMS.  Thus the others must be ignored.
  (let ((p (dummy-package "foo"
             (build-system gnu-build-system)
             (supported-systems
              `("does-not-exist" "foobar" ,@%supported-systems)))))
    (parameterize ((%current-system "x86_64-linux"))
      (package-transitive-supported-systems p))))

(test-assert "supported-package?"
  (let* ((d (dummy-package "dep"
              (build-system trivial-build-system)
              (supported-systems '("x86_64-linux"))))
         (p (dummy-package "foo"
              (build-system gnu-build-system)
              (inputs `(("d" ,d)))
              (supported-systems '("x86_64-linux" "armhf-linux")))))
    (and (supported-package? p "x86_64-linux")
         (not (supported-package? p "i686-linux"))
         (not (supported-package? p "armhf-linux")))))

(test-assert "supported-package? vs. system-dependent graph"
  ;; The inputs of a package can depend on (%current-system).  Thus,
  ;; 'supported-package?' must make sure that it binds (%current-system)
  ;; appropriately before traversing the dependency graph.  In the example
  ;; below, 'supported-package?' must thus return true for both systems.
  (let* ((p0a (dummy-package "foo-arm"
                (build-system trivial-build-system)
                (supported-systems '("armhf-linux"))))
         (p0b (dummy-package "foo-x86_64"
                (build-system trivial-build-system)
                (supported-systems '("x86_64-linux"))))
         (p   (dummy-package "bar"
                (build-system trivial-build-system)
                (inputs
                 (if (string=? (%current-system) "armhf-linux")
                     `(("foo" ,p0a))
                     `(("foo" ,p0b)))))))
    (and (supported-package? p "x86_64-linux")
         (supported-package? p "armhf-linux"))))

(test-skip (if (not %store) 8 0))

(test-assert "package-source-derivation, file"
  (let* ((file    (search-path %load-path "guix.scm"))
         (package (package (inherit (dummy-package "p"))
                    (source file)))
         (source  (package-source-derivation %store
                                             (package-source package))))
    (and (store-path? source)
         (valid-path? %store source)
         (equal? (call-with-input-file source get-bytevector-all)
                 (call-with-input-file file get-bytevector-all)))))

(test-assert "package-source-derivation, store path"
  (let* ((file    (add-to-store %store "guix.scm" #t "sha256"
                                (search-path %load-path "guix.scm")))
         (package (package (inherit (dummy-package "p"))
                    (source file)))
         (source  (package-source-derivation %store
                                             (package-source package))))
    (string=? file source)))

(test-assert "package-source-derivation, indirect store path"
  (let* ((dir     (add-to-store %store "guix-build" #t "sha256"
                                (dirname (search-path %load-path
                                                      "guix/build/utils.scm"))))
         (package (package (inherit (dummy-package "p"))
                    (source (string-append dir "/utils.scm"))))
         (source  (package-source-derivation %store
                                             (package-source package))))
    (and (direct-store-path? source)
         (string-suffix? "utils.scm" source))))

(test-assert "package-source-derivation, local-file"
  (let* ((file    (local-file "../guix/base32.scm"))
         (package (package (inherit (dummy-package "p"))
                    (source file)))
         (source  (package-source-derivation %store
                                             (package-source package))))
    (and (store-path? source)
         (string-suffix? "base32.scm" source)
         (valid-path? %store source)
         (equal? (call-with-input-file source get-bytevector-all)
                 (call-with-input-file
                     (search-path %load-path "guix/base32.scm")
                   get-bytevector-all)))))

(test-equal "package-source-derivation, origin, sha512"
  "hello"
  (let* ((bash    (search-bootstrap-binary "bash" (%current-system)))
         (builder (add-text-to-store %store "my-fixed-builder.sh"
                                     "echo -n hello > $out" '()))
         (method  (lambda* (url hash-algo hash #:optional name
                                #:rest rest)
                    (and (eq? hash-algo 'sha512)
                         (raw-derivation name bash (list builder)
                                         #:sources (list builder)
                                         #:hash hash
                                         #:hash-algo hash-algo))))
         (source  (origin
                    (method method)
                    (uri "unused://")
                    (file-name "origin-sha512")
                    (hash (content-hash
                           (gcrypt:bytevector-hash (string->utf8 "hello")
                                                   (gcrypt:lookup-hash-algorithm
                                                    'sha512))
                           sha512))))
         (drv    (package-source-derivation %store source))
         (output (derivation->output-path drv)))
    (build-derivations %store (list drv))
    (call-with-input-file output get-string-all)))

(unless (network-reachable?) (test-skip 1))
(test-equal "package-source-derivation, snippet"
  "OK"
  (let* ((source (bootstrap-origin
                  (origin
                    (inherit (bootstrap-guile-origin (%current-system)))
                    (patch-inputs
                     `(("tar" ,%bootstrap-coreutils&co)
                       ("xz" ,%bootstrap-coreutils&co)
                       ("patch" ,%bootstrap-coreutils&co)))
                    (patch-guile %bootstrap-guile)
                    (modules '((guix build utils)))
                    (snippet '(begin
                                ;; We end up in 'bin', because it's the first
                                ;; directory, alphabetically.  Not a very good
                                ;; example but hey.
                                (chmod "." #o777)
                                (symlink "guile" "guile-rocks")
                                (copy-recursively "../share/guile/2.0/scripts"
                                                  "scripts")

                                ;; Make sure '.file_list' can be created.
                                (chmod ".." #o777))))))
         (package (package (inherit (dummy-package "with-snippet"))
                    (source source)
                    (build-system trivial-build-system)
                    (inputs
                     `(("tar" ,(search-bootstrap-binary "tar"
                                                        (%current-system)))
                       ("xz"  ,(search-bootstrap-binary "xz"
                                                        (%current-system)))))
                    (arguments
                     `(#:guile ,%bootstrap-guile
                       #:modules ((guix build utils))
                       #:builder
                       (begin
                         (use-modules (guix build utils))
                         (let ((tar    (assoc-ref %build-inputs "tar"))
                               (xz     (assoc-ref %build-inputs "xz"))
                               (source (assoc-ref %build-inputs "source")))
                           (invoke tar "xvf" source
                                   "--use-compress-program" xz)
                           (unless (and (string=? "guile" (readlink "bin/guile-rocks"))
                                        (file-exists? "bin/scripts/compile.scm"))
                             (error "the snippet apparently failed"))
                           (let ((out (assoc-ref %outputs "out")))
                             (call-with-output-file out
                               (lambda (p)
                                 (display "OK" p))))
                           #t))))))
         (drv    (package-derivation %store package))
         (out    (derivation->output-path drv)))
    (and (build-derivations %store (list (pk 'snippet-drv drv)))
         (call-with-input-file out get-string-all))))

(test-assert "return value"
  (let ((drv (package-derivation %store (dummy-package "p"))))
    (and (derivation? drv)
         (file-exists? (derivation-file-name drv)))))

(test-assert "package-output"
  (let* ((package  (dummy-package "p"))
         (drv      (package-derivation %store package)))
    (and (derivation? drv)
         (string=? (derivation->output-path drv)
                   (package-output %store package "out")))))

(test-assert "patch not found yields a run-time error"
  (guard (c ((condition-has-type? c &message)
             (and (string-contains (condition-message c)
                                   "does-not-exist.patch")
                  (string-contains (condition-message c)
                                   "not found"))))
    (let ((p (package
               (inherit (dummy-package "p"))
               (source (origin
                         (method (const #f))
                         (uri "http://whatever")
                         (patches
                          (list (search-patch "does-not-exist.patch")))
                         (sha256
                          (base32
                           "0amn0bbwqvsvvsh6drfwz20ydc2czk374lzw5kksbh6bf78k4ks4")))))))
      (package-derivation %store p)
      #f)))

(let ((dummy (dummy-package "foo" (inputs `(("x" ,(current-module)))))))
  (test-equal "&package-input-error"
    (list dummy (current-module))
    (guard (c ((package-input-error? c)
               (list (package-error-package c)
                     (package-error-invalid-input c))))
      (package-derivation %store dummy))))

(test-assert "reference to non-existent output"
  ;; See <http://bugs.gnu.org/19630>.
  (parameterize ((%graft? #f))
    (let* ((dep (dummy-package "dep"))
           (p   (dummy-package "p"
                  (inputs `(("dep" ,dep "non-existent"))))))
      (guard (c ((derivation-missing-output-error? c)
                 (and (string=? (derivation-missing-output c) "non-existent")
                      (equal? (package-derivation %store dep)
                              (derivation-error-derivation c)))))
        (package-derivation %store p)))))

(test-assert "trivial"
  (let* ((p (package (inherit (dummy-package "trivial"))
              (build-system trivial-build-system)
              (source #f)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:builder
                 (begin
                   (mkdir %output)
                   (call-with-output-file (string-append %output "/test")
                     (lambda (p)
                       (display '(hello guix) p)))
                   #t)))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (pk 'drv d (derivation->output-path d))))
           (equal? '(hello guix)
                   (call-with-input-file (string-append p "/test") read))))))

(test-assert "trivial with local file as input"
  (let* ((i (search-path %load-path "ice-9/boot-9.scm"))
         (p (package (inherit (dummy-package "trivial-with-input-file"))
              (build-system trivial-build-system)
              (source #f)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:builder (begin
                             (copy-file (assoc-ref %build-inputs "input")
                                        %output)
                             #t)))
              (inputs `(("input" ,i)))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (pk 'drv d (derivation->output-path d))))
           (equal? (call-with-input-file p get-bytevector-all)
                   (call-with-input-file i get-bytevector-all))))))

(test-assert "trivial with source"
  (let* ((i (search-path %load-path "ice-9/boot-9.scm"))
         (p (package (inherit (dummy-package "trivial-with-source"))
              (build-system trivial-build-system)
              (source i)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:builder (begin
                             (copy-file (assoc-ref %build-inputs "source")
                                        %output)
                             #t)))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (derivation->output-path d)))
           (equal? (call-with-input-file p get-bytevector-all)
                   (call-with-input-file i get-bytevector-all))))))

(test-assert "trivial with system-dependent input"
  (let* ((p (package (inherit (dummy-package "trivial-system-dependent-input"))
              (build-system trivial-build-system)
              (source #f)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:modules ((guix build utils))
                 #:builder
                 (begin
                   (use-modules (guix build utils))
                   (let ((out  (assoc-ref %outputs "out"))
                         (bash (assoc-ref %build-inputs "bash")))
                     (invoke bash "-c"
                             (format #f "echo hello > ~a" out))))))
              (inputs `(("bash" ,(search-bootstrap-binary "bash"
                                                          (%current-system)))))))
         (d (package-derivation %store p)))
    (and (build-derivations %store (list d))
         (let ((p (pk 'drv d (derivation->output-path d))))
           (eq? 'hello (call-with-input-file p read))))))

(test-assert "trivial with #:allowed-references"
  (let* ((p (package
              (inherit (dummy-package "trivial"))
              (build-system trivial-build-system)
              (arguments
               `(#:guile ,%bootstrap-guile
                 #:allowed-references (,%bootstrap-guile)
                 #:builder
                 (begin
                   (mkdir %output)
                   ;; The reference to itself isn't allowed so building it
                   ;; should fail.
                   (symlink %output (string-append %output "/self"))
                   #t)))))
         (d (package-derivation %store p)))
    (guard (c ((store-protocol-error? c) #t))
      (build-derivations %store (list d))
      #f)))

(test-assert "search paths"
  (let* ((p (make-prompt-tag "return-search-paths"))
         (s (build-system
             (name 'raw)
             (description "Raw build system with direct store access")
             (lower (lambda* (name #:key source inputs system target
                                   #:allow-other-keys)
                      (bag
                        (name name)
                        (system system) (target target)
                        (build-inputs inputs)
                        (build
                         (lambda* (store name inputs
                                         #:key outputs system search-paths)
                           search-paths)))))))
         (x (list (search-path-specification
                   (variable "GUILE_LOAD_PATH")
                   (files '("share/guile/site/2.0")))
                  (search-path-specification
                   (variable "GUILE_LOAD_COMPILED_PATH")
                   (files '("share/guile/site/2.0")))))
         (a (package (inherit (dummy-package "guile"))
              (build-system s)
              (native-search-paths x)))
         (b (package (inherit (dummy-package "guile-foo"))
              (build-system s)
              (inputs `(("guile" ,a)))))
         (c (package (inherit (dummy-package "guile-bar"))
              (build-system s)
              (inputs `(("guile" ,a)
                        ("guile-foo" ,b))))))
    (let-syntax ((collect (syntax-rules ()
                            ((_ body ...)
                             (call-with-prompt p
                               (lambda ()
                                 body ...)
                               (lambda (k search-paths)
                                 search-paths))))))
      (and (null? (collect (package-derivation %store a)))
           (equal? x (collect (package-derivation %store b)))
           (equal? x (collect (package-derivation %store c)))))))

(test-assert "package-transitive-native-search-paths"
  (let* ((sp (lambda (name)
               (list (search-path-specification
                      (variable name)
                      (files '("foo/bar"))))))
         (p0 (dummy-package "p0" (native-search-paths (sp "PATH0"))))
         (p1 (dummy-package "p1" (native-search-paths (sp "PATH1"))))
         (p2 (dummy-package "p2"
               (native-search-paths (sp "PATH2"))
               (inputs `(("p0" ,p0)))
               (propagated-inputs `(("p1" ,p1)))))
         (p3 (dummy-package "p3"
               (native-search-paths (sp "PATH3"))
               (native-inputs `(("p0" ,p0)))
               (propagated-inputs `(("p2" ,p2))))))
    (lset= string=?
           '("PATH1" "PATH2" "PATH3")
           (map search-path-specification-variable
                (package-transitive-native-search-paths p3)))))

(test-assert "package-cross-derivation"
  (let ((drv (package-cross-derivation %store (dummy-package "p")
                                       "mips64el-linux-gnu")))
    (and (derivation? drv)
         (file-exists? (derivation-file-name drv)))))

(test-assert "package-cross-derivation, trivial-build-system"
  (let ((p (package (inherit (dummy-package "p"))
             (build-system trivial-build-system)
             (arguments '(#:builder (exit 1))))))
    (let ((drv (package-cross-derivation %store p "mips64el-linux-gnu")))
      (derivation? drv))))

(test-assert "package-cross-derivation, no cross builder"
  (let* ((b (build-system (inherit trivial-build-system)
              (lower (const #f))))
         (p (package (inherit (dummy-package "p"))
              (build-system b))))
    (guard (c ((package-cross-build-system-error? c)
               (eq? (package-error-package c) p)))
      (package-cross-derivation %store p "mips64el-linux-gnu")
      #f)))

;; XXX: The next two tests can trigger builds when the distro defines
;; replacements on core packages, so they're disable for lack of a better
;; solution.

;; (test-equal "package-derivation, direct graft"
;;   (package-derivation %store gnu-make #:graft? #f)
;;   (let ((p (package (inherit coreutils)
;;              (replacement gnu-make))))
;;     (package-derivation %store p #:graft? #t)))

;; (test-equal "package-cross-derivation, direct graft"
;;   (package-cross-derivation %store gnu-make "mips64el-linux-gnu"
;;                             #:graft? #f)
;;   (let ((p (package (inherit coreutils)
;;              (replacement gnu-make))))
;;     (package-cross-derivation %store p "mips64el-linux-gnu"
;;                               #:graft? #t)))

(test-assert "package-grafts, indirect grafts"
  (let* ((new   (dummy-package "dep"
                  (arguments '(#:implicit-inputs? #f))))
         (dep   (package (inherit new) (version "0.0")))
         (dep*  (package (inherit dep) (replacement new)))
         (dummy (dummy-package "dummy"
                  (arguments '(#:implicit-inputs? #f))
                  (inputs `(("dep" ,dep*))))))
    (equal? (package-grafts %store dummy)
            (list (graft
                    (origin (package-derivation %store dep))
                    (replacement (package-derivation %store new)))))))

;; XXX: This test would require building the cross toolchain just to see if it
;; needs grafting, which is obviously too expensive, and thus disabled.
;;
;; (test-assert "package-grafts, indirect grafts, cross"
;;   (let* ((new    (dummy-package "dep"
;;                    (arguments '(#:implicit-inputs? #f))))
;;          (dep    (package (inherit new) (version "0.0")))
;;          (dep*   (package (inherit dep) (replacement new)))
;;          (dummy  (dummy-package "dummy"
;;                    (arguments '(#:implicit-inputs? #f))
;;                    (inputs `(("dep" ,dep*)))))
;;          (target "mips64el-linux-gnu"))
;;     ;; XXX: There might be additional grafts, for instance if the distro
;;     ;; defines replacements for core packages like Perl.
;;     (member (graft
;;               (origin (package-cross-derivation %store dep target))
;;               (replacement
;;                (package-cross-derivation %store new target)))
;;             (package-grafts %store dummy #:target target))))

(test-assert "package-grafts, indirect grafts, propagated inputs"
  (let* ((new   (dummy-package "dep"
                  (arguments '(#:implicit-inputs? #f))))
         (dep   (package (inherit new) (version "0.0")))
         (dep*  (package (inherit dep) (replacement new)))
         (prop  (dummy-package "propagated"
                  (propagated-inputs `(("dep" ,dep*)))
                  (arguments '(#:implicit-inputs? #f))))
         (dummy (dummy-package "dummy"
                  (arguments '(#:implicit-inputs? #f))
                  (inputs `(("prop" ,prop))))))
    (equal? (package-grafts %store dummy)
            (list (graft
                    (origin (package-derivation %store dep))
                    (replacement (package-derivation %store new)))))))

(test-assert "package-grafts, same replacement twice"
  (let* ((new  (dummy-package "dep"
                 (version "1")
                 (arguments '(#:implicit-inputs? #f))))
         (dep  (package (inherit new) (version "0") (replacement new)))
         (p1   (dummy-package "intermediate1"
                 (arguments '(#:implicit-inputs? #f))
                 (inputs `(("dep" ,dep)))))
         (p2   (dummy-package "intermediate2"
                 (arguments '(#:implicit-inputs? #f))
                 ;; Here we copy DEP to have an equivalent package that is not
                 ;; 'eq?' to DEP.  This is similar to what happens with
                 ;; 'package-with-explicit-inputs' & co.
                 (inputs `(("dep" ,(package (inherit dep)))))))
         (p3   (dummy-package "final"
                 (arguments '(#:implicit-inputs? #f))
                 (inputs `(("p1" ,p1) ("p2" ,p2))))))
    (equal? (package-grafts %store p3)
            (list (graft
                    (origin (package-derivation %store
                                                (package (inherit dep)
                                                         (replacement #f))))
                    (replacement (package-derivation %store new)))))))

(test-assert "replacement also grafted"
  ;; We build a DAG as below, where dotted arrows represent replacements and
  ;; solid arrows represent dependencies:
  ;;
  ;;  P1  ·············>  P1R
  ;;  |\__________________.
  ;;  v                   v
  ;;  P2  ·············>  P2R
  ;;  |
  ;;  v
  ;;  P3
  ;;
  ;; We want to make sure that:
  ;;   grafts(P3) = (P1,P1R) + (P2, grafted(P2R, (P1,P1R)))
  ;; where:
  ;;   (A,B) is a graft to replace A by B
  ;;   grafted(DRV,G) denoted DRV with graft G applied
  (let* ((p1r (dummy-package "P1"
                (build-system trivial-build-system)
                (arguments
                 `(#:guile ,%bootstrap-guile
                   #:builder (let ((out (assoc-ref %outputs "out")))
                               (mkdir out)
                               (call-with-output-file
                                   (string-append out "/replacement")
                                 (const #t)))))))
         (p1  (package
                (inherit p1r) (name "p1") (replacement p1r)
                (arguments
                 `(#:guile ,%bootstrap-guile
                   #:builder (begin
                               (mkdir (assoc-ref %outputs "out"))
                               #t)))))
         (p2r (dummy-package "P2"
                (build-system trivial-build-system)
                (inputs `(("p1" ,p1)))
                (arguments
                 `(#:guile ,%bootstrap-guile
                   #:builder (let ((out (assoc-ref %outputs "out")))
                               (mkdir out)
                               (chdir out)
                               (symlink (assoc-ref %build-inputs "p1") "p1")
                               (call-with-output-file (string-append out "/replacement")
                                 (const #t)))))))
         (p2  (package
                (inherit p2r) (name "p2") (replacement p2r)
                (arguments
                 `(#:guile ,%bootstrap-guile
                   #:builder (let ((out (assoc-ref %outputs "out")))
                               (mkdir out)
                               (chdir out)
                               (symlink (assoc-ref %build-inputs "p1")
                                        "p1")
                               #t)))))
         (p3  (dummy-package "p3"
                (build-system trivial-build-system)
                (inputs `(("p2" ,p2)))
                (arguments
                 `(#:guile ,%bootstrap-guile
                   #:builder (let ((out (assoc-ref %outputs "out")))
                               (mkdir out)
                               (chdir out)
                               (symlink (assoc-ref %build-inputs "p2")
                                        "p2")
                               #t))))))
    (lset= equal?
           (package-grafts %store p3)
           (list (graft
                   (origin (package-derivation %store p1 #:graft? #f))
                   (replacement (package-derivation %store p1r)))
                 (graft
                   (origin (package-derivation %store p2 #:graft? #f))
                   (replacement
                    (package-derivation %store p2r #:graft? #t)))))))

;;; XXX: Nowadays 'graft-derivation' needs to build derivations beforehand to
;;; find out about their run-time dependencies, so this test is no longer
;;; applicable since it would trigger a full rebuild.
;;
;; (test-assert "package-derivation, indirect grafts"
;;   (let* ((new   (dummy-package "dep"
;;                   (arguments '(#:implicit-inputs? #f))))
;;          (dep   (package (inherit new) (version "0.0")))
;;          (dep*  (package (inherit dep) (replacement new)))
;;          (dummy (dummy-package "dummy"
;;                   (arguments '(#:implicit-inputs? #f))
;;                   (inputs `(("dep" ,dep*)))))
;;          (guile (package-derivation %store (canonical-package guile-2.0)
;;                                     #:graft? #f)))
;;     (equal? (package-derivation %store dummy)
;;             (graft-derivation %store
;;                               (package-derivation %store dummy #:graft? #f)
;;                               (package-grafts %store dummy)

;;                               ;; Use the same Guile as 'package-derivation'.
;;                               #:guile guile))))

(test-equal "package->bag"
  `("foo86-hurd" #f (,(package-source gnu-make))
    (,(canonical-package glibc)) (,(canonical-package coreutils)))
  (let ((bag (package->bag gnu-make "foo86-hurd")))
    (list (bag-system bag) (bag-target bag)
          (assoc-ref (bag-build-inputs bag) "source")
          (assoc-ref (bag-build-inputs bag) "libc")
          (assoc-ref (bag-build-inputs bag) "coreutils"))))

(test-assert "package->bag, sensitivity to %current-target-system"
  ;; https://bugs.gnu.org/41713
  (let* ((lower (lambda* (name #:key system target inputs native-inputs
                               #:allow-other-keys)
                  (and (not target)
                       (bag (name name) (system system) (target target)
                            (build-inputs native-inputs)
                            (host-inputs inputs)
                            (build (lambda* (store name inputs
                                                   #:key system target
                                                   #:allow-other-keys)
                                     (build-expression->derivation
                                      store "foo" '(mkdir %output))))))))
         (bs    (build-system
                  (name 'build-system-without-cross-compilation)
                  (description "Does not support cross compilation.")
                  (lower lower)))
         (dep   (dummy-package "dep" (build-system bs)))
         (pkg   (dummy-package "example"
                  (native-inputs `(("dep" ,dep)))))
         (do-not-build (lambda (continue store lst . _) lst)))
    (equal? (with-build-handler do-not-build
              (parameterize ((%current-target-system "powerpc64le-linux-gnu")
                             (%graft? #t))
                (package-cross-derivation %store pkg
                                          (%current-target-system)
                                          #:graft? #t)))
            (with-build-handler do-not-build
              (package-cross-derivation %store
                                        (package (inherit pkg))
                                        "powerpc64le-linux-gnu"
                                        #:graft? #t)))))

(test-equal "package->bag, cross-compilation"
  `(,(%current-system) "foo86-hurd"
    (,(package-source gnu-make))
    (,(canonical-package glibc)) (,(canonical-package coreutils)))
  (let ((bag (package->bag gnu-make (%current-system) "foo86-hurd")))
    (list (bag-system bag) (bag-target bag)
          (assoc-ref (bag-build-inputs bag) "source")
          (assoc-ref (bag-build-inputs bag) "libc")
          (assoc-ref (bag-build-inputs bag) "coreutils"))))

(test-assert "package->bag, propagated inputs"
  (let* ((dep    (dummy-package "dep"))
         (prop   (dummy-package "prop"
                   (propagated-inputs `(("dep" ,dep)))))
         (dummy  (dummy-package "dummy"
                   (inputs `(("prop" ,prop)))))
         (inputs (bag-transitive-inputs (package->bag dummy #:graft? #f))))
    (match (assoc "dep" inputs)
      (("dep" package)
       (eq? package dep)))))

(test-assert "package->bag, sensitivity to %current-target-system"
  (let* ((dep (dummy-package "dep"
                (propagated-inputs (if (%current-target-system)
                                       `(("libxml2" ,libxml2))
                                       '()))))
         (pkg (dummy-package "foo"
                (native-inputs `(("dep" ,dep)))))
         (bag (package->bag pkg (%current-system) "foo86-hurd")))
    (equal? (parameterize ((%current-target-system "foo64-gnu"))
              (bag-transitive-inputs bag))
            (parameterize ((%current-target-system #f))
              (bag-transitive-inputs bag)))))

(test-assert "bag->derivation"
  (parameterize ((%graft? #f))
    (let ((bag (package->bag gnu-make))
          (drv (package-derivation %store gnu-make)))
      (parameterize ((%current-system "foox86-hurd")) ;should have no effect
        (equal? drv (bag->derivation %store bag))))))

(test-assert "bag->derivation, cross-compilation"
  (parameterize ((%graft? #f))
    (let* ((target "mips64el-linux-gnu")
           (bag    (package->bag gnu-make (%current-system) target))
           (drv    (package-cross-derivation %store gnu-make target)))
      (parameterize ((%current-system "foox86-hurd") ;should have no effect
                     (%current-target-system "foo64-linux-gnu"))
        (equal? drv (bag->derivation %store bag))))))

(when (or (not (network-reachable?)) (shebang-too-long?))
  (test-skip 1))
(test-assert "GNU Make, bootstrap"
  ;; GNU-MAKE-FOR-TESTS can be built cheaply; we choose it here so that the
  ;; test doesn't last for too long.
  (let ((gnu-make gnu-make-for-tests))
    (and (package? gnu-make)
         (or (location? (package-location gnu-make))
             (not (package-location gnu-make)))
         (let* ((drv (package-derivation %store gnu-make))
                (out (derivation->output-path drv)))
           (and (build-derivations %store (list drv))
                (file-exists? (string-append out "/bin/make")))))))

(test-equal "package-mapping"
  42
  (let* ((dep       (dummy-package "chbouib"
                      (native-inputs `(("x" ,grep)))))
         (p0        (dummy-package "example"
                      (inputs `(("foo" ,coreutils)
                                ("bar" ,grep)
                                ("baz" ,dep)))))
         (transform (lambda (p)
                      (package (inherit p) (source 42))))
         (rewrite   (package-mapping transform))
         (p1        (rewrite p0)))
    (and (eq? p1 (rewrite p0))
         (eqv? 42 (package-source p1))
         (match (package-inputs p1)
           ((("foo" dep1) ("bar" dep2) ("baz" dep3))
            (and (eq? dep1 (rewrite coreutils))   ;memoization
                 (eq? dep2 (rewrite grep))
                 (eq? dep3 (rewrite dep))
                 (eqv? 42
                       (package-source dep1) (package-source dep2)
                       (package-source dep3))
                 (match (package-native-inputs dep3)
                   ((("x" dep))
                    (and (eq? dep (rewrite grep))
                         (package-source dep))))))))))

(test-assert "package-input-rewriting"
  (let* ((dep     (dummy-package "chbouib"
                    (native-inputs `(("x" ,grep)))))
         (p0      (dummy-package "example"
                    (inputs `(("foo" ,coreutils)
                              ("bar" ,grep)
                              ("baz" ,dep)))))
         (rewrite (package-input-rewriting `((,coreutils . ,sed)
                                             (,grep . ,findutils))
                                           (cut string-append "r-" <>)))
         (p1      (rewrite p0))
         (p2      (rewrite p0)))
    (and (not (eq? p1 p0))
         (eq? p1 p2)                              ;memoization
         (string=? "r-example" (package-name p1))
         (match (package-inputs p1)
           ((("foo" dep1) ("bar" dep2) ("baz" dep3))
            (and (eq? dep1 sed)
                 (eq? dep2 findutils)
                 (string=? (package-name dep3) "r-chbouib")
                 (eq? dep3 (rewrite dep))         ;memoization
                 (match (package-native-inputs dep3)
                   ((("x" dep))
                    (eq? dep findutils)))))))))

(test-assert "package-input-rewriting/spec"
  (let* ((dep     (dummy-package "chbouib"
                    (native-inputs `(("x" ,grep)))))
         (p0      (dummy-package "example"
                    (inputs `(("foo" ,coreutils)
                              ("bar" ,grep)
                              ("baz" ,dep)))))
         (rewrite (package-input-rewriting/spec
                   `(("coreutils" . ,(const sed))
                     ("grep" . ,(const findutils)))))
         (p1      (rewrite p0))
         (p2      (rewrite p0)))
    (and (not (eq? p1 p0))
         (eq? p1 p2)                              ;memoization
         (string=? "example" (package-name p1))
         (match (package-inputs p1)
           ((("foo" dep1) ("bar" dep2) ("baz" dep3))
            (and (string=? (package-full-name dep1)
                           (package-full-name sed))
                 (string=? (package-full-name dep2)
                           (package-full-name findutils))
                 (string=? (package-name dep3) "chbouib")
                 (eq? dep3 (rewrite dep))         ;memoization
                 (match (package-native-inputs dep3)
                   ((("x" dep))
                    (string=? (package-full-name dep)
                              (package-full-name findutils))))))))))

(test-assert "package-input-rewriting/spec, partial match"
  (let* ((dep     (dummy-package "chbouib"
                    (version "1")
                    (native-inputs `(("x" ,grep)))))
         (p0      (dummy-package "example"
                    (inputs `(("foo" ,coreutils)
                              ("bar" ,dep)))))
         (rewrite (package-input-rewriting/spec
                   `(("chbouib@123" . ,(const sed)) ;not matched
                     ("grep" . ,(const findutils)))))
         (p1      (rewrite p0)))
    (and (not (eq? p1 p0))
         (string=? "example" (package-name p1))
         (match (package-inputs p1)
           ((("foo" dep1) ("bar" dep2))
            (and (string=? (package-full-name dep1)
                           (package-full-name coreutils))
                 (eq? dep2 (rewrite dep))         ;memoization
                 (match (package-native-inputs dep2)
                   ((("x" dep))
                    (string=? (package-full-name dep)
                              (package-full-name findutils))))))))))

(test-equal "package-patched-vulnerabilities"
  '(("CVE-2015-1234")
    ("CVE-2016-1234" "CVE-2018-4567")
    ())
  (let ((p1 (dummy-package "pi"
              (source (dummy-origin
                       (patches (list "/a/b/pi-CVE-2015-1234.patch"))))))
        (p2 (dummy-package "pi"
              (source (dummy-origin
                       (patches (list
                                 "/a/b/pi-CVE-2016-1234-CVE-2018-4567.patch"))))))
        (p3 (dummy-package "pi" (source (dummy-origin)))))
    (map package-patched-vulnerabilities
         (list p1 p2 p3))))

(test-eq "fold-packages" hello
  (fold-packages (lambda (p r)
                   (if (string=? (package-name p) "hello")
                       p
                       r))
                 #f))

(test-assert "fold-packages, hidden package"
  ;; There are two public variables providing "guile@2.0" ('guile-final' in
  ;; commencement.scm and 'guile-2.0' in guile.scm), but only the latter
  ;; should show up.
  (match (fold-packages (lambda (p r)
                          (if (and (string=? (package-name p) "guile")
                                   (string-prefix? "2.0"
                                                   (package-version p)))
                              (cons p r)
                              r))
                        '())
    ((one)
     (eq? one guile-2.0))))

(test-assert "fold-available-packages with/without cache"
  (let ()
    (define no-cache
      (fold-available-packages (lambda* (name version result #:rest rest)
                                 (cons (cons* name version rest)
                                       result))
                               '()))

    (define from-cache
      (call-with-temporary-directory
       (lambda (cache)
         (generate-package-cache cache)
         (mock ((guix describe) current-profile (const cache))
               (mock ((gnu packages) cache-is-authoritative? (const #t))
                     (fold-available-packages (lambda* (name version result
                                                             #:rest rest)
                                                (cons (cons* name version rest)
                                                      result))
                                              '()))))))

    (and (equal? (delete-duplicates from-cache) from-cache)
         (lset= equal? no-cache from-cache))))

(test-assert "find-packages-by-name"
  (match (find-packages-by-name "hello")
    (((? (cut eq? hello <>))) #t)
    (wrong (pk 'find-packages-by-name wrong #f))))

(test-assert "find-packages-by-name with version"
  (match (find-packages-by-name "hello" (package-version hello))
    (((? (cut eq? hello <>))) #t)
    (wrong (pk 'find-packages-by-name wrong #f))))

(test-equal "find-packages-by-name with cache"
  (find-packages-by-name "guile")
  (call-with-temporary-directory
   (lambda (cache)
     (generate-package-cache cache)
     (mock ((guix describe) current-profile (const cache))
           (mock ((gnu packages) cache-is-authoritative? (const #t))
                 (find-packages-by-name "guile"))))))

(test-equal "find-packages-by-name + version, with cache"
  (find-packages-by-name "guile" "2")
  (call-with-temporary-directory
   (lambda (cache)
     (generate-package-cache cache)
     (mock ((guix describe) current-profile (const cache))
           (mock ((gnu packages) cache-is-authoritative? (const #t))
                 (find-packages-by-name "guile" "2"))))))

(test-assert "--search-paths with pattern"
  ;; Make sure 'guix package --search-paths' correctly reports environment
  ;; variables when file patterns are used (in particular, it must follow
  ;; symlinks when looking for 'catalog.xml'.)  To do that, we rely on the
  ;; libxml2 package specification, which contains such a definition.
  (let* ((p1 (package
               (name "foo") (version "0") (source #f)
               (build-system trivial-build-system)
               (arguments
                `(#:guile ,%bootstrap-guile
                  #:modules ((guix build utils))
                  #:builder (begin
                              (use-modules (guix build utils))
                              (let ((out (assoc-ref %outputs "out")))
                                (mkdir-p (string-append out "/xml/bar/baz"))
                                (call-with-output-file
                                    (string-append out "/xml/bar/baz/catalog.xml")
                                  (lambda (port)
                                    (display "xml? wat?!" port)))
                                #t))))
               (synopsis #f) (description #f)
               (home-page #f) (license #f)))
         (p2 (package
               ;; Provide a fake libxml2 to avoid building the real one.  This
               ;; is OK because 'guix package' gets search path specifications
               ;; from the same-named package found in the distro.
               (name "libxml2") (version "0.0.0") (source #f)
               (build-system trivial-build-system)
               (arguments
                `(#:guile ,%bootstrap-guile
                  #:builder (begin
                              (mkdir (assoc-ref %outputs "out"))
                              #t)))
               (native-search-paths (package-native-search-paths libxml2))
               (synopsis #f) (description #f)
               (home-page #f) (license #f)))
         (prof (run-with-store %store
                 (profile-derivation
                  (manifest (map package->manifest-entry
                                 (list p1 p2)))
                  #:hooks '()
                  #:locales? #f)
                 #:guile-for-build (%guile-for-build))))
    (build-derivations %store (list prof))
    (string-match (format #f "^export XML_CATALOG_FILES=\"~a/xml/+bar/baz/catalog\\.xml\"\n"
                          (regexp-quote (derivation->output-path prof)))
                  (with-output-to-string
                    (lambda ()
                      (guix-package "-p" (derivation->output-path prof)
                                    "--search-paths"))))))

(test-assert "--search-paths with single-item search path"
  ;; Make sure 'guix package --search-paths' correctly reports environment
  ;; variables for things like 'GIT_SSL_CAINFO' that have #f as their
  ;; separator, meaning that the first match wins.
  (let* ((p1 (dummy-package "foo"
               (build-system trivial-build-system)
               (arguments
                `(#:guile ,%bootstrap-guile
                  #:modules ((guix build utils))
                  #:builder (begin
                              (use-modules (guix build utils))
                              (let ((out (assoc-ref %outputs "out")))
                                (mkdir-p (string-append out "/etc/ssl/certs"))
                                (call-with-output-file
                                    (string-append
                                     out "/etc/ssl/certs/ca-certificates.crt")
                                  (const #t))))))))
         (p2 (package (inherit p1) (name "bar")))
         (p3 (dummy-package "git"
               ;; Provide a fake Git to avoid building the real one.
               (build-system trivial-build-system)
               (arguments
                `(#:guile ,%bootstrap-guile
                  #:builder (begin
                              (mkdir (assoc-ref %outputs "out"))
                              #t)))
               (native-search-paths (package-native-search-paths git))))
         (prof1 (run-with-store %store
                  (profile-derivation
                   (packages->manifest (list p1 p3))
                   #:hooks '()
                   #:locales? #f)
                  #:guile-for-build (%guile-for-build)))
         (prof2 (run-with-store %store
                  (profile-derivation
                   (packages->manifest (list p2 p3))
                   #:hooks '()
                   #:locales? #f)
                  #:guile-for-build (%guile-for-build))))
    (build-derivations %store (list prof1 prof2))
    (string-match (format #f "^export GIT_SSL_CAINFO=\"~a/etc/ssl/certs/ca-certificates.crt"
                          (regexp-quote (derivation->output-path prof1)))
                  (with-output-to-string
                    (lambda ()
                      (guix-package "-p" (derivation->output-path prof1)
                                    "-p" (derivation->output-path prof2)
                                    "--search-paths"))))))

(test-equal "specification->package when not found"
  'quit
  (catch 'quit
    (lambda ()
      ;; This should call 'leave', producing an error message.
      (specification->package "this-package-does-not-exist"))
    (lambda (key . args)
      key)))

(test-equal "specification->package+output"
  `((,coreutils "out") (,coreutils "debug"))
  (list (call-with-values (lambda ()
                            (specification->package+output "coreutils"))
          list)
        (call-with-values (lambda ()
                            (specification->package+output "coreutils:debug"))
          list)))

(test-equal "specification->package+output invalid output"
  'error
  (catch 'quit
    (lambda ()
      (specification->package+output "coreutils:does-not-exist"))
    (lambda _
      'error)))

(test-equal "specification->package+output no default output"
  `(,coreutils #f)
  (call-with-values
    (lambda ()
      (specification->package+output "coreutils" #f))
    list))

(test-equal "specification->package+output invalid output, no default"
  'error
  (catch 'quit
    (lambda ()
      (specification->package+output "coreutils:does-not-exist" #f))
    (lambda _
      'error)))

(test-equal "find-package-locations"
  (map (lambda (package)
         (cons (package-version package)
               (package-location package)))
       (find-packages-by-name "guile"))
  (find-package-locations "guile"))

(test-equal "find-package-locations with cache"
  (map (lambda (package)
         (cons (package-version package)
               (package-location package)))
       (find-packages-by-name "guile"))
  (call-with-temporary-directory
   (lambda (cache)
     (generate-package-cache cache)
     (mock ((guix describe) current-profile (const cache))
           (mock ((gnu packages) cache-is-authoritative? (const #t))
                 (find-package-locations "guile"))))))

(test-equal "specification->location"
  (package-location (specification->package "guile@2"))
  (specification->location "guile@2"))

(test-end "packages")

;;; Local Variables:
;;; eval: (put 'dummy-package 'scheme-indent-function 1)
;;; eval: (put 'dummy-package/no-implicit 'scheme-indent-function 1)
;;; End:

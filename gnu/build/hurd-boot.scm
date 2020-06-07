;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2020 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2020 Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
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

(define-module (gnu build hurd-boot)
  #:use-module (system repl error-handling)
  #:autoload   (system repl repl) (start-repl)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 match)
  #:use-module (guix build utils)
  #:use-module ((guix build syscalls)
                #:hide (file-system-type))
  #:export (make-hurd-device-nodes
            boot-hurd-system))

;;; Commentary:
;;;
;;; Utility procedures useful to boot a Hurd system.
;;;
;;; Code:

;; XXX FIXME c&p from linux-boot.scm
(define (find-long-option option arguments)
  "Find OPTION among ARGUMENTS, where OPTION is something like \"--load\".
Return the value associated with OPTION, or #f on failure."
  (let ((opt (string-append option "=")))
    (and=> (find (cut string-prefix? opt <>)
                 arguments)
           (lambda (arg)
             (substring arg (+ 1 (string-index arg #\=)))))))

;; XXX FIXME c&p from guix/utils.scm
(define (readlink* file)
  "Call 'readlink' until the result is not a symlink."
  (define %max-symlink-depth 50)

  (let loop ((file  file)
             (depth 0))
    (define (absolute target)
      (if (absolute-file-name? target)
          target
          (string-append (dirname file) "/" target)))

    (if (>= depth %max-symlink-depth)
        file
        (call-with-values
            (lambda ()
              (catch 'system-error
                (lambda ()
                  (values #t (readlink file)))
                (lambda args
                  (let ((errno (system-error-errno args)))
                    (if (or (= errno EINVAL))
                        (values #f file)
                        (apply throw args))))))
          (lambda (success? target)
            (if success?
                (loop (absolute target) (+ depth 1))
                file))))))

(define* (make-hurd-device-nodes #:optional (root "/"))
  "Make some of the nodes needed on GNU/Hurd."
  (define (scope dir)
    (string-append root (if (string-suffix? "/" root) "" "/") dir))

  (mkdir (scope "dev"))
  ;; Don't create /dev/null etc just yet; the store
  ;; messes-up the permission bits.
  ;; Don't create /dev/console, /dev/vcs, etc.: they are created by
  ;; console-run on first boot.

  (mkdir (scope "servers"))
  (for-each (lambda (file)
              (call-with-output-file (scope (string-append "servers/" file))
                (lambda (port)
                  (display file port)   ;avoid hard-linking
                  (chmod port #o444))))
            '("startup"
              "exec"
              "proc"
              "password"
              "default-pager"
              "crash-dump-core"
              "kill"
              "suspend"))

  (mkdir (scope "servers/socket"))
  ;; Don't create /servers/socket/1 & co: runsystem does that on first boot.

  ;; TODO: Set the 'gnu.translator' extended attribute for passive translator
  ;; settings?
  )

(define (translated? file-name)
  "Return true if a translator is installed on FILE-NAME."
  (false-if-exception
   (not (string-null? (getxattr file-name "gnu.translator")))))

(define* (setup-translator file-name command #:optional (mode #o600))
  "Setup translator COMMAND on FILE-NAME."
  (unless (translated? file-name)
    (let ((dir (dirname file-name)))
      (unless (directory-exists? dir)
        (mkdir-p dir))
      (unless (file-exists? file-name)
        (call-with-output-file file-name
          (lambda (port)
            (display file-name port)  ;avoid hard-linking
            (chmod port mode)))))
    (catch 'system-error
      (lambda _
        (setxattr file-name "gnu.translator" (string-join command "\0" 'suffix)))
      (lambda (key . args)
        (let ((errno (system-error-errno (cons key args))))
          (format (current-error-port) "~a: ~a\n"
                  (strerror errno) file-name)
          (format (current-error-port) "Ignoring...Good Luck!\n"))))))

(define* (set-hurd-device-translators #:optional (root "/"))
  "Make some of the device nodes needed on GNU/Hurd."

  (define (scope dir)
    (string-append root (if (string-suffix? "/" root) "" "/") dir))

  (define scope-setup-translator
    (match-lambda
      ((file-name command)
       (scope-setup-translator (list file-name command #o600)))
      ((file-name command mode)
       (let ((mount-point (scope file-name)))
         (setup-translator mount-point command mode)))))

  (define servers
    '(("servers/crash-dump-core" ("/hurd/crash" "--dump-core"))
      ("servers/crash-kill"      ("/hurd/crash" "--kill"))
      ("servers/crash-suspend"   ("/hurd/crash" "--suspend"))
      ("servers/password"        ("/hurd/password"))
      ;;
      ;;("servers/socket/1"        ("/hurd/pflocal"))
      ("servers/socket/2"        ("/hurd/pfinet"
                                  "--interface" "eth0"
                                  "--address"
                                  "10.0.2.15" ;the default QEMU guest IP
                                  "--netmask" "255.255.255.0"
                                  "--gateway" "10.0.2.2"
                                  "--ipv6" "/servers/socket/16"))))

  (define devices
    '(("dev/full"    ("/hurd/null"     "--full")            #o666)
      ("dev/null"    ("/hurd/null")                         #o666)
      ("dev/random"  ("/hurd/random"   "--seed-file" "/var/lib/random-seed")
                                                            #o644)
      ("dev/zero"    ("/hurd/storeio"  "--store-type=zero") #o666)

      ("dev/console" ("/hurd/term"     "/dev/consosle" "device" "console"))
      ("dev/klog"    ("/hurd/streamio" "kmsg"))
      ("dev/mem"     ("/hurd/storeio"  "--no-cache" "mem")  #o660)
      ("dev/shm"     ("/hurd/tmpfs"    "--mode=1777" "50%") #o644)
      ("dev/time"    ("/hurd/storeio"  "--no-cache" "time") #o644)

      ("dev/tty"     ("/hurd/magic"    "tty")               #o666)
      ("dev/vcs"     ("/hurd/console"))

      ("dev/tty1"    ("/hurd/term"     "/dev/tty1" "hurdio" "/dev/vcs/1/console")
                                                            #o666)
      ("dev/tty2"    ("/hurd/term"     "/dev/tty2" "hurdio" "/dev/vcs/2/console")
                                                            #o666)
      ("dev/tty3"    ("/hurd/term"     "/dev/tty3" "hurdio" "/dev/vcs/3/console")
                                                            #o666)

      ("dev/ptyp0"   ("/hurd/term"     "/dev/ptyp0" "pty-master" "/dev/ttyp0")
                                                            #o666)
      ("dev/ptyp1"   ("/hurd/term"     "/dev/ptyp1" "pty-master" "/dev/ttyp1")
                                                            #o666)
      ("dev/ptyp2"   ("/hurd/term"     "/dev/ptyp2" "pty-master" "/dev/ttyp2")
                                                            #o666)

      ("dev/ttyp0"   ("/hurd/term"     "/dev/ttyp0" "pty-slave" "/dev/ptyp0")
                                                            #o666)
      ("dev/ttyp1"   ("/hurd/term"     "/dev/ttyp1" "pty-slave" "/dev/ptyp1")
                                                            #o666)
      ("dev/ttyp2"   ("/hurd/term"     "/dev/ttyp2" "pty-slave" "/dev/ptyp2")
                                                            #o666)))

  (for-each scope-setup-translator servers)
  (mkdir-p (scope "dev/vcs/1"))
  (mkdir-p (scope "dev/vcs/2"))
  (mkdir-p (scope "dev/vcs/3"))
  (for-each scope-setup-translator devices)

  (false-if-exception (symlink "/dev/random" "/dev/urandom"))
  (mkdir-p "/dev/fd")
  (false-if-exception (symlink "/dev/fd/0"   "/dev/stdin"))
  (false-if-exception (symlink "/dev/fd/1"   "/dev/stdout"))
  (false-if-exception (symlink "/dev/fd/2"   "/dev/stderr")))


(define* (boot-hurd-system #:key (on-error 'debug))
  "This procedure is meant to be called from an early RC script.

Install the relevant passive translators on the first boot.  Then, run system
activation by using the kernel command-line options '--system' and '--load';
starting the Shepherd.

XXX TODO: see linux-boot.scm:boot-system.
XXX TODO: add proper file-system checking, mounting
XXX TODO: move bits to (new?) (hurd?) (activation?) services
XXX TODO: use Linux xattr/setxattr to remove (settrans in) /libexec/RUNSYSTEM

"

  (display "Welcome, this is GNU's early boot Guile.\n")
  (display "Use '--repl' for an initrd REPL.\n\n")

  (call-with-error-handling
   (lambda ()

     (format #t "Setting-up essential translators...\n")
     (set-hurd-device-translators)

     (let* ((args    (command-line))
            (system  (find-long-option "--system" args))
            (to-load (find-long-option "--load" args)))

       (false-if-exception (delete-file "/hurd"))
       (let ((hurd/hurd (readlink* (string-append system "/profile/hurd"))))
         (symlink hurd/hurd "/hurd"))

       (format #t "Starting pager...\n")
       (unless (zero? (system* "/hurd/mach-defpager"))
         (format #t "FAILED...Good luck!\n"))

       (cond ((member "--repl" args)
              (format #t "Starting repl...\n")
              (start-repl))
             (to-load
              (format #t "loading '~a'...\n" to-load)
              (primitive-load to-load)
              (format (current-error-port)
                      "boot program '~a' terminated, rebooting~%"
                      to-load)
              (sleep 2)
              (reboot))
             (else
              (display "no boot file passed via '--load'\n")
              (display "entering a warm and cozy REPL\n")
              (start-repl)))))
   #:on-error on-error))

;;; hurd-boot.scm ends here

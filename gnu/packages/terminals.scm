;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2015, 2016, 2017, 2018, 2019, 2020 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2016 Mckinley Olsen <mck.olsen@gmail.com>
;;; Copyright © 2016, 2017, 2019 Alex Griffin <a@ajgrf.com>
;;; Copyright © 2016 David Craven <david@craven.ch>
;;; Copyright © 2016, 2017, 2019, 2020 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2016, 2017 José Miguel Sánchez García <jmi2k@openmailbox.org>
;;; Copyright © 2017, 2018, 2019, 2020 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2017 Kei Kebreau <kkebreau@posteo.net>
;;; Copyright © 2017, 2018, 2019 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2017 Petter <petter@mykolab.ch>
;;; Copyright © 2018 Hartmut Goebel <h.goebel@crazy-compilers.com>
;;; Copyright © 2018 Arun Isaac <arunisaac@systemreboot.net>
;;; Copyright © 2018 Gabriel Hondet <gabrielhondet@gmail.com>
;;; Copyright © 2019 Rutger Helling <rhelling@mykolab.com>
;;; Copyright © 2018, 2019 Eric Bavier <bavier@member.fsf.org>
;;; Copyright © 2019 Julien Lepiller <julien@lepiller.eu>
;;; Copyright © 2019 Pierre Langlois <pierre.langlois@gmx.com>
;;; Copyright © 2019 Brett Gilio <brettg@gnu.org>
;;; Copyright © 2020 Jakub Kądziołka <kuba@kadziolka.net>
;;; Copyright © 2020 Valentin Ignatev <valentignatev@gmail.com>
;;; Copyright © 2020 Michael Rohleder <mike@rohleder.de>
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

(define-module (gnu packages terminals)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system glib-or-gtk)
  #:use-module (guix build-system go)
  #:use-module (guix build-system python)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages crates-io)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages docbook)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages image)
  #:use-module (gnu packages libcanberra)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages perl-check)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages popt)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages sphinx)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (srfi srfi-26))

(define-public tilda
  (package
    (name "tilda")
    (version "1.5.2")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/lanoxx/tilda.git")
                    (commit (string-append "tilda-" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0psq0f4s0s92bba6wwcf6b0j7i59b76svqxhvpavwv53yvhmmamn"))))
    (build-system glib-or-gtk-build-system)
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("gettext" ,gettext-minimal)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("libconfuse" ,libconfuse)
       ("vte" ,vte)))
    (synopsis "GTK+-based drop-down terminal")
    (description "Tilda is a terminal emulator similar to normal terminals like
gnome-terminal (GNOME) or Konsole (KDE), with the difference that it drops down
from the edge of a screen when a certain configurable hotkey is pressed.  This
is similar to the built-in consoles in some applications.  Tilda is highly
configurable through a graphical wizard.")
    (home-page "https://github.com/lanoxx/tilda")
    (license license:gpl2+)))

(define-public termite
  (package
    (name "termite")
    (version "15")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
              (url (string-append "https://github.com/thestinger/"
                                  name ".git"))
              (commit (string-append "v" version))
              (recursive? #t)))
        (file-name (string-append name "-" version "-checkout"))
        (sha256
         (base32
          "0hp1x6lj098m3jgna274wv5dv60lnzg22297di68g4hw9djjyd2k"))))
    (build-system gnu-build-system)
    (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'unpack 'patch-xdg-open
            (lambda _
              (substitute* "termite.cc"
                (("xdg-open") (which "xdg-open")))
              #t))
          (delete 'configure))
        #:tests? #f
        ;; This sets the destination when installing the necessary terminal
        ;; capability data, which are not provided by 'ncurses'.  See
        ;; <https://lists.gnu.org/archive/html/bug-ncurses/2009-10/msg00031.html>.
        #:make-flags (list "PREFIX="
                           (string-append "VERSION=v" (version))
                           (string-append "DESTDIR="
                                          (assoc-ref %outputs "out")))))
    (inputs
     `(("vte" ,vte-ng)
       ("gtk+" ,gtk+)
       ("xdg-utils" ,xdg-utils)
       ("ncurses" ,ncurses)))
    (native-inputs
     `(("pkg-config" ,pkg-config)))

    ;; FIXME: This should only be located in 'ncurses'.  Nonetheless it is
    ;; provided for usability reasons.  See <https://bugs.gnu.org/22138>.
    (native-search-paths
      (list (search-path-specification
              (variable "TERMINFO_DIRS")
              (files '("share/terminfo")))))
    (home-page "https://github.com/thestinger/termite/")
    (synopsis "Keyboard-centric, VTE-based terminal")
    (description "Termite is a minimal terminal emulator designed for use with
tiling window managers.  It is a modal application, similar to Vim, with an
insert mode and command mode where keybindings have different functions.")

    ;; Files under util/ are under the Expat license; the rest is LGPLv2+.
    (license license:lgpl2.0+)))

(define-public asciinema
  (package
    (name "asciinema")
    (version "2.0.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/asciinema/asciinema")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1a2pysxnp6icyd08mgf66xr6f6j0irnfxdpf3fmzcz31ix7l9kc4"))))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-before 'build 'patch-exec-paths
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((ncurses (assoc-ref inputs "ncurses")))
               (substitute* "asciinema/term.py"
                 (("'tput'")
                  (string-append "'" ncurses "/bin/tput'"))))
             #t))
         (replace 'check
           (lambda _ (invoke "nosetests" "-v"))))))
    (inputs `(("ncurses" ,ncurses)))
    (native-inputs
     ;; For tests.
     `(("python-nose" ,python-nose)))
    (home-page "https://asciinema.org")
    (synopsis "Terminal session recorder")
    (description
     "Use asciinema to record and share your terminal sessions, the right way.
Forget screen recording apps and blurry video.  Enjoy a lightweight, purely
text-based approach to terminal recording.")
    (license license:gpl3)))

(define-public libtsm
  (let ((commit "f70e37982f382b03c6939dac3d5f814450bda253")
        (revision "1"))
    (package
      (name "libtsm")
      (version (git-version "0.0.0" revision commit))
      (source (origin
                (method git-fetch)
                ;; The freedesktop repository is no longer maintained.
                (uri (git-reference
                      (url (string-append "https://github.com/Aetf/" name))
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "0mwn91i5h5d518i1s05y7hzv6bc13vzcvxszpfh77473iwg4wprx"))))
      (build-system cmake-build-system)
      (arguments
       `(#:configure-flags '("-DBUILD_TESTING=ON")))
      (native-inputs
       `(("pkg-config" ,pkg-config)))
      (inputs
       `(("libxkbcommon" ,libxkbcommon)
         ("check" ,check)))
      (synopsis "Xterm state machine library")
      (description "TSM is a state machine for DEC VT100-VT520 compatible
terminal emulators.  It tries to support all common standards while keeping
compatibility to existing emulators like xterm, gnome-terminal, konsole, etc.")
      (home-page "https://www.freedesktop.org/wiki/Software/libtsm")
      ;; Hash table implementation is lgpl2.1+ licensed.
      ;; The wcwidth implementation in external/wcwidth.{h,c} uses a license
      ;; derived from ISC.
      ;; UCS-4 to UTF-8 encoding is copied from "terminology" which is released
      ;; under the bsd 2 license.
      (license (list license:expat license:lgpl2.1+ license:isc license:bsd-2)))))

(define-public kmscon
  (let ((commit "01dd0a231e2125a40ceba5f59fd945ff29bf2cdc")
        (revision "1"))
    (package
      (name "kmscon")
      (version (git-version "0.0.0" revision commit))
      (source (origin
                (method git-fetch)
                ;; The freedesktop repository is no longer maintained.
                (uri (git-reference
                      (url (string-append "https://github.com/Aetf/" name))
                      (commit commit)))
                (sha256
                 (base32
                  "0q62kjsvy2iwy8adfiygx2bfwlh83rphgxbis95ycspqidg9py87"))
                (patches
                 (search-patches "kmscon-runtime-keymap-switch.patch"))
                (modules '((guix build utils)))
                (file-name (git-file-name name version))))
      (build-system gnu-build-system)
      (arguments
       `(;; The closure of MESA is huge so we'd rather avoid it.
         #:disallowed-references (,mesa)

         #:phases (modify-phases %standard-phases
                    ;; Use elogind instead of systemd.
                    (add-before 'configure 'remove-systemd
                      (lambda _
                        (substitute* "configure"
                          (("libsystemd-daemon libsystemd-login")
                           "libelogind"))
                        (substitute* "src/uterm_systemd.c"
                          (("#include <systemd/sd-login.h>")
                           "#include <elogind/sd-login.h>")
                          ;; We don't have this header.
                          (("#include <systemd/sd-daemon\\.h>")
                           "")
                          ;; Replace the call to 'sd_booted' by the truth value.
                          (("sd_booted\\(\\)")
                           "1")))))))
      (native-inputs
       `(("pkg-config" ,pkg-config)
         ("autoconf" ,autoconf)
         ("automake" ,automake)
         ("libtool" ,libtool)
         ("libxslt" ,libxslt)                       ;to build the man page
         ("libxml2" ,libxml2)                       ;for XML_CATALOG_FILES
         ("docbook-xsl" ,docbook-xsl)))
      (inputs
       `(("libdrm" ,libdrm)
         ("libtsm" ,libtsm)
         ("libxkbcommon" ,libxkbcommon)
         ("logind" ,elogind)
         ;; MESA can be used for accelerated video output via OpenGLESv2, but
         ;; it's a bit dependency that we'd rather avoid in the installation
         ;; image.
         ;; ("mesa" ,mesa)
         ("pango" ,pango)
         ("udev" ,eudev)))
      (synopsis "Linux KMS-based terminal emulator")
      (description "Kmscon is a terminal emulator based on Linux's @dfn{kernel
mode setting} (KMS).  It can replace the in-kernel virtual terminal (VT)
implementation with a user-space console.  Compared to the Linux console,
kmscon provides enhanced features including XKB-compatible internationalized
keyboard support, UTF-8 input/font support, hardware-accelerated rendering,
multi-seat support, a replacement for @command{mingetty}, and more.")
      (home-page "https://www.freedesktop.org/wiki/Software/kmscon")
      ;; Hash table implementation is lgpl2.1+ licensed.
      ;; The wcwidth implementation in external/wcwidth.{h,c} uses a license
      ;; derived from ISC.
      ;; UCS-4 to UTF-8 encoding is copied from "terminology" which is released
      ;; under the bsd 2 license.
      ;; Unifont-Font is from http://unifoundry.com/unifont.html and licensed
      ;; under the terms of the GNU GPL.
      (license (list license:expat license:lgpl2.1+ license:bsd-2
                     license:gpl2+))
      (supported-systems (filter (cut string-suffix? "-linux" <>)
                                 %supported-systems)))))

(define-public libtermkey
  (package
    (name "libtermkey")
    (version "0.21.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://www.leonerd.org.uk/code/libtermkey/"
                                  "libtermkey-" version ".tar.gz"))
              (sha256
               (base32 "0psd0kf10q5ixfima0mxz10syy7qq1ilz1npr0rz862xycvzgjyf"))))
    (build-system gnu-build-system)
    (arguments
     '(#:make-flags (list
                     "CC=gcc"
                     (string-append "PREFIX=" (assoc-ref %outputs "out")))
       #:phases (modify-phases %standard-phases
                  (delete 'configure))  ; no configure script
       #:test-target "test"))
    (inputs `(("ncurses" ,ncurses)))
    (native-inputs `(("libtool" ,libtool)
                     ("perl-test-harness" ,perl-test-harness)
                     ("pkg-config" ,pkg-config)))
    (synopsis "Keyboard entry processing library for terminal-based programs")
    (description
     "Libtermkey handles all the necessary logic to recognise special keys, UTF-8
combining, and so on, with a simple interface.")
    (home-page "http://www.leonerd.org.uk/code/libtermkey")
    (license license:expat)))

(define-public picocom
  (package
    (name "picocom")
    (version "3.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/npat-efault/picocom.git")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1vvjydqf0ax47nvdyyl67jafw5b3sfsav00xid6qpgia1gs2r72n"))))
    (build-system gnu-build-system)
    (arguments
     `(#:make-flags '("CC=gcc")
       #:tests? #f                      ; no tests
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)            ; no configure script
         (replace 'install
           ;; The Makefile lacks an ‘install’ target.
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (man (string-append out "/share/man/man1")))
               (install-file "picocom" bin)
               (install-file "picocom.1" man)))))))
    (home-page "https://github.com/npat-efault/picocom")
    (synopsis "Minimal dumb-terminal emulator")
    (description
     "Picocom is a minimal dumb-terminal emulation program.  It was designed to
serve as a simple and manual modem configuration, testing, and debugging tool.
It also serves well as a low-tech serial communications program to allow access
to all types of devices that provide serial consoles.")
    (license license:gpl2+)))

(define-public beep
  (package
    (name "beep")
    (version "1.4.9")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             ;; The original beep 1.3 at <http://www.johnath.com/beep> has been
             ;; unmaintained for some time, and vulnerable to at least two CVEs:
             ;; https://github.com/johnath/beep/issues/11#issuecomment-454056858
             ;; Use this maintained fork instead.
             (url "https://github.com/spkr-beep/beep.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0jmvqk6g5n0wzj9znw42njxq3mzw1769f4db99b83927hf4aidi4"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f                      ; no tests
       #:make-flags
       (list (string-append "prefix=" (assoc-ref %outputs "out"))
             (string-append "pkgdocdir=$(docdir)/" ,name "-" ,version))
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))         ; no configure script
    (synopsis "Linux command-line utility to control the PC speaker")
    (description "beep allows the user to control the PC speaker with precision,
allowing different sounds to indicate different events.  While it can be run
quite happily on the command line, its intended place of residence is within
scripts, notifying the user when something interesting occurs.  Of course, it
has no notion of what's interesing, but it's very good at that notifying part.")
    (home-page "https://github.com/spkr-beep/beep")
    (license license:gpl2+)))

(define-public unibilium
  (package
    (name "unibilium")
    (version "2.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/mauke/unibilium.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1wa9a32wzqnxqh1jh554afj13dzjr6mw2wzqzw8d08nza9pg2ra2"))))
    (build-system gnu-build-system)
    (arguments
     `(#:make-flags
       (list "CC=gcc"
             (string-append "PREFIX=" (assoc-ref %outputs "out")))
       #:test-target "test"
       ;; FIXME: tests require "prove"
       #:tests? #f
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))
    (native-inputs
     `(("libtool" ,libtool)
       ("perl" ,perl)))
    (home-page "https://github.com/mauke/unibilium")
    (synopsis "Terminfo parsing library")
    (description "Unibilium is a basic C terminfo library.  It doesn't depend
on curses or any other library.  It also doesn't use global variables, so it
should be thread-safe.")
    (license license:lgpl3+)))

(define-public libvterm
  (package
    (name "libvterm")
    (version "0.1.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://www.leonerd.org.uk/code/libvterm/"
                           "libvterm-" version ".tar.gz"))
       (sha256
        (base32
         "1n5maylann2anfifjy576vzyar9q5m1kzpyiz2hca2pacxy8xf4v"))))
    (build-system gnu-build-system)
    (arguments
     `(#:make-flags
       (list "CC=gcc"
             (string-append "PREFIX=" (assoc-ref %outputs "out")))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))
    (native-inputs
     `(("libtool" ,libtool)
       ("perl" ,perl)))
    (home-page "http://www.leonerd.org.uk/code/libvterm/")
    (synopsis "VT220/xterm/ECMA-48 terminal emulator library")
    (description "Libvterm is an abstract C99 library which implements a VT220
or xterm-like terminal emulator.  It doesn't use any particular graphics
toolkit or output system, instead it invokes callback function pointers that
its embedding program should provide it to draw on its behalf.  It avoids
calling @code{malloc} during normal running state, allowing it to be used in
embedded kernel situations.")
    (license license:expat)))

(define-public cool-retro-term
  (let ((commit "1.1.1")
        (revision "0"))                 ;not used currently
    (package
      (name "cool-retro-term")
      (version "1.1.1")
      (source (origin
                (method git-fetch)
                (file-name (string-append name "-" version "-checkout"))
                (uri (git-reference
                      (url (string-append "https://github.com/Swordfish90/" name))
                      (commit commit)
                      (recursive? #t)))
                (sha256
                 (base32 "0wb6anchxa5jpn9c73kr4byrf2xlj8x8qzc5x7ny6saj7kbbvp75"))
                (modules '((guix build utils)
                           (srfi srfi-1)
                           (srfi srfi-26)
                           (ice-9 rdelim)
                           (ice-9 regex)))
                (snippet
                 '(let* ((fonts '(;"1971-ibm-3278"     ; BSD 3-clause
                                  "1977-apple2"        ; Non-Free
                                  "1977-commodore-pet" ; Non-Free
                                  "1979-atari-400-800" ; Non-Free
                                  ;"1981-ibm-pc        ; CC-SA 4.0
                                  "1982-commodore64")) ; Non-Free
                                  ;"1985-ibm-pc-vga"   ; CC-SA 4.0
                                  ;"modern-fixedsys-excelsior" ; Redistributable
                                  ;"modern-hermit"     ; SIL
                                  ;"modern-inconsolata"; SIL
                                  ;"modern-pro-font-win-tweaked" ; X11
                                  ;"modern-proggy-tiny"; X11
                                  ;"modern-terminus"   ; SIL
                         (name-rx (make-regexp " *name: *\"([^\"]*)\""))
                         (source-rx (make-regexp " *source: \"fonts/([^/]*)[^\"]*\""))
                         (fontname-rx (make-regexp "\"fontName\":\"([^\"]*).*"))
                         (names
                          ;; Gather font names from all Fonts*.qml files.
                          ;; These will be used to remove items from the
                          ;; default profiles.
                          (fold
                           (lambda (font-file names)
                             (call-with-input-file font-file
                               (lambda (port)
                                 (let loop ((name #f) (names names))
                                   (let ((line (read-line port)))
                                     (cond
                                      ((eof-object? line) (pk 'names names))
                                      ((regexp-exec name-rx line)
                                       => (lambda (m)
                                            (loop (match:substring m 1) names)))
                                      ((regexp-exec source-rx line)
                                       => (lambda (m)
                                            (let ((font (match:substring m 1)))
                                              (if (member font fonts)
                                                  (loop #f (lset-adjoin string=?
                                                                        names name))
                                                  (loop #f names)))))
                                      (else (loop name names))))))))
                           '() (find-files "app/qml" "Font.*\\.qml"))))
                    ;; Remove the font files themselves
                    (for-each (lambda (font)
                                (delete-file-recursively
                                 (string-append "app/qml/fonts/" font)))
                              fonts)
                    ;; Remove mention of those fonts in the source
                    (substitute* "app/qml/resources.qrc"
                      (((string-append " *<file>fonts/("
                                       (string-join fonts "|")
                                       ").*"))
                       ""))
                    (for-each
                     (lambda (file)
                       (let ((start-rx (make-regexp " *ListElement\\{"))
                             (end-rx   (make-regexp " *\\}")))
                        (with-atomic-file-replacement file
                          (lambda (in out)
                            (let loop ((line-buffer '())
                                       (hold? #f)
                                       (discard? #f))
                              (let ((line (read-line in 'concat)))
                                (cond
                                 ((eof-object? line) #t) ;done
                                 ((regexp-exec start-rx line)
                                  (loop (cons line line-buffer) #t #f))
                                 ((or (regexp-exec source-rx line)
                                      (regexp-exec fontname-rx line))
                                  => (lambda (m)
                                       (let ((font-or-name (match:substring m 1)))
                                         (if (or (member font-or-name fonts)
                                                 (member font-or-name names))
                                             (loop '() #f #t)
                                             (loop (cons line line-buffer)
                                                   hold? #f)))))
                                 ((regexp-exec end-rx line)
                                  (unless discard?
                                          (for-each (cut display <> out)
                                                    (reverse line-buffer))
                                          (display line out))
                                  (loop '() #f #f))
                                 (hold? (loop (cons line line-buffer)
                                              hold? discard?))
                                 (discard? (loop line-buffer #f #t))
                                 (else (display line out)
                                       (loop '() #f #f)))))))))
                     '("app/qml/FontPixels.qml"
                       "app/qml/FontScanlines.qml"
                       "app/qml/Fonts.qml"
                       "app/qml/ApplicationSettings.qml"))
                    ;; Final substitution for default scanline and pixel fonts
                    (substitute* "app/qml/ApplicationSettings.qml"
                      (("COMMODORE_PET") "PROGGY_TINY"))
                    #t))))
      (build-system gnu-build-system)
      (inputs
       `(("qtbase" ,qtbase)
         ("qtdeclarative" ,qtdeclarative)
         ("qtgraphicaleffects" ,qtgraphicaleffects)
         ("qtquickcontrols" ,qtquickcontrols)))
      (arguments
       `(#:phases
         (modify-phases %standard-phases
           (replace 'configure
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((out (assoc-ref outputs "out")))
                 (substitute* '("qmltermwidget/qmltermwidget.pro")
                   (("INSTALL_DIR = \\$\\$\\[QT_INSTALL_QML\\]")
                    (string-append "INSTALL_DIR = " out "/lib/qt5/qml")))
                 (substitute* '("cool-retro-term.pro" "app/app.pro")
                   (("/usr") out))
                 (invoke "qmake"))))
           (add-after 'install 'wrap-executable
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let ((out (assoc-ref outputs "out"))
                     (qml "/lib/qt5/qml"))
                 (wrap-program (string-append out "/bin/cool-retro-term")
                   `("QML2_IMPORT_PATH" ":" prefix
                     (,(string-append out qml)
                      ,@(map (lambda (i)
                               (string-append (assoc-ref inputs i) qml))
                             '("qtdeclarative"
                               "qtgraphicaleffects"
                               "qtquickcontrols")))))
                 #t)))
           (add-after 'install 'add-alternate-name
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
                 (symlink (string-append bin "/cool-retro-term")
                          (string-append bin "/crt"))
                 #t)))
           (add-after 'install 'install-man
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((mandir (string-append (assoc-ref outputs "out")
                                            "/share/man/man1")))
                 (install-file "packaging/debian/cool-retro-term.1" mandir)
                 #t))))))
      (synopsis "Terminal emulator")
      (description
       "Cool-retro-term (crt) is a terminal emulator which mimics the look and
feel of the old cathode ray tube (CRT) screens.  It has been designed to be
eye-candy, customizable, and reasonably lightweight.")
      (home-page "https://github.com/Swordfish90/cool-retro-term")
      (license (list
                license:gpl2+           ; qmltermwidget
                license:gpl3+           ; cool-retro-term
                ;; Fonts
                license:silofl1.1
                license:x11
                license:bsd-3)))))

(define-public sakura
  (package
    (name "sakura")
    (version "3.7.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://launchpad.net/sakura/trunk/"
                                  version "/+download/sakura-" version
                                  ".tar.bz2"))
              (sha256
               (base32
                "12wjmckf03qbnm8cb7qma0980anzajn3l92rj2yr8hhafl74x6kj"))))
    (build-system cmake-build-system)
    (arguments
     '(#:tests? #f))                    ; no check phase
    (native-inputs
     `(("gettext" ,gettext-minimal)
       ("perl" ,perl)                   ; for pod2man
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("libxft" ,libxft)
       ("vte" ,vte)))
    (home-page "https://launchpad.net/sakura")
    (synopsis "A simple but powerful libvte-based terminal emulator")
    (description "@code{Sakura} is a terminal emulator based on GTK+ and VTE.
It's a terminal emulator with few dependencies, so you don't need a full GNOME
desktop installed to have a decent terminal emulator.")
    (license license:gpl2)))

(define-public go-github.com-nsf-termbox-go
  (let ((commit "288510b9734e30e7966ec2f22b87c5f8e67345e3")
        (revision "1"))
    (package
      (name "go-github.com-nsf-termbox-go")
      (version (git-version "0.0.0" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/nsf/termbox-go.git")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "0hdyisfaf8yb55h3p03p4sbq19546mp9fy28f2kn659mycmhxqk4"))))
      (build-system go-build-system)
      (arguments
       '(#:import-path "github.com/nsf/termbox-go"))
      (propagated-inputs
       `(("go-github.com-mattn-go-runewidth"
          ,go-github.com-mattn-go-runewidth)))
      (synopsis "@code{termbox} provides a minimal API for text-based user
interfaces")
      (description
       "Termbox is a library that provides a minimalistic API which allows the
programmer to write text-based user interfaces.")
      (home-page "https://github.com/nsf/termbox-go")
      (license license:expat))))

(define-public go-github-com-junegunn-fzf
  (package
    (name "go-github-com-junegunn-fzf")
    (version "0.18.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/junegunn/fzf")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0pwpr4fpw56yzzkcabzzgbgwraaxmp7xzzmap7w1xsrkbj7dl2xl"))))
    (build-system go-build-system)
    (arguments
     `(#:import-path "github.com/junegunn/fzf"))
    (inputs
     `(("go-github.com-mattn-go-runewidth" ,go-github.com-mattn-go-runewidth)
       ("go-github-com-mattn-go-shellwords" ,go-github-com-mattn-go-shellwords)
       ("go-github-com-mattn-go-isatty" ,go-github-com-mattn-go-isatty)
       ("go-github-com-gdamore-tcell" ,go-github-com-gdamore-tcell)
       ("go-golang-org-x-crypto" ,go-golang-org-x-crypto)))
    (home-page "https://github.com/junegunn/fzf")
    (synopsis "Command-line fuzzy-finder")
    (description "This package provides an interactive command-line filter
usable with any list--including files, command history, processes and more.")
    (license license:expat)))

(define-public go-github.com-howeyc-gopass
  (let ((commit "bf9dde6d0d2c004a008c27aaee91170c786f6db8")
        (revision "0"))
    (package
      (name "go-github.com-howeyc-gopass")
      (version (git-version "0.0.0" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/howeyc/gopass.git")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "1jxzyfnqi0h1fzlsvlkn10bncic803bfhslyijcxk55mgh297g45"))))
      (build-system go-build-system)
      (arguments
       '(#:import-path "github.com/howeyc/gopass"))
      (propagated-inputs
       `(("go-golang-org-x-crypto"
          ,go-golang-org-x-crypto)))
      (synopsis "Retrieve password from a terminal or piped input in Go")
      (description
       "@code{gopass} is a Go package for retrieving a password from user
terminal or piped input.")
      (home-page "https://github.com/howeyc/gopass")
      (license license:isc))))

(define-public python-pyte
  (package
    (name "python-pyte")
    (version "0.7.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pyte" version))
       (sha256
        (base32
         "1an54hvyjm8gncx8cgabz9mkpgjkdb0bkyjlkh7g7f94nr3wnfl7"))))
    (build-system python-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'remove-failing-test
           ;; TODO: Reenable when the `captured` files required by this test
           ;; are included in the archive.
           (lambda _
             (delete-file "tests/test_input_output.py")
             #t)))))
    (propagated-inputs
     `(("python-wcwidth" ,python-wcwidth)))
    (native-inputs
     `(("python-pytest-runner" ,python-pytest-runner)
       ("python-pytest" ,python-pytest)))
    (home-page "https://pyte.readthedocs.io/")
    (synopsis "Simple VTXXX-compatible terminal emulator")
    (description "@code{pyte} is an in-memory VTxxx-compatible terminal
emulator.  @var{VTxxx} stands for a series of video terminals, developed by
DEC between 1970 and 1995.  The first and probably most famous one was the
VT100 terminal, which is now a de-facto standard for all virtual terminal
emulators.

pyte is a fork of vt102, which was an incomplete pure Python implementation
of VT100 terminal.")
    (license license:lgpl3+)))

(define-public python2-pyte
  (package-with-python2 python-pyte))

(define-public python-blessings
  (package
    (name "python-blessings")
    (version "1.7")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "blessings" version))
       (sha256
        (base32
         "0z8mgkbmisxs10rz88qg46l1c9a8n08k8cy2iassal2zh16qbrcq"))))
    (build-system python-build-system)
    (arguments
     ;; FIXME: Test suite is unable to detect TTY conditions.
     `(#:tests? #f))
    (native-inputs
     `(("python-nose" ,python-nose)
       ("python-six" ,python-six)))
    (home-page "https://github.com/erikrose/blessings")
    (synopsis "Python module to manage terminal color, styling, and
positioning")
    (description "Blessings is a pythonic API to manipulate terminal color,
styling, and positioning.  It provides similar features to curses but avoids
some of curses’s limitations: it does not require clearing the whole screen
for little changes, provides a scroll-back buffer after the program exits, and
avoids styling altogether when the output is redirected to something other
than a terminal.")
    (license license:expat)))

(define-public python2-blessings
  (package-with-python2 python-blessings))

(define-public python-curtsies
  (package
    (name "python-curtsies")
    (version "0.2.11")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "curtsies" version))
       (sha256
        (base32
         "1vljmw3sy6lrqahhpyg4gk13mzcx3mwhvg8s41698ms3cpgkjipc"))))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda _
             (invoke "nosetests" "-v"))))))
    (propagated-inputs
     `(("python-blessings" ,python-blessings)
       ("python-wcwidth" ,python-wcwidth)))
    (native-inputs
     `(("python-mock" ,python-mock)
       ("python-pyte" ,python-pyte)
       ("python-nose" ,python-nose)))
    (home-page "https://github.com/thomasballinger/curtsies")
    (synopsis "Library for curses-like terminal interaction with colored
strings")
    (description "Curtsies is a Python library for interacting with the
terminal.  It features string-like objects which carry formatting information,
per-line fullscreen terminal rendering, and keyboard input event reporting.")
    (license license:expat)))

(define-public python2-curtsies
  (package-with-python2 python-curtsies))

(define-public tmate
  (package
    (name "tmate")
    (version "2.4.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/tmate-io/tmate.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0x5c31yq7ansmiy20a0qf59wagba9v3pq97mlkxrqxn4n1gcc6vi"))))
    (build-system gnu-build-system)
    (inputs
     `(("libevent" ,libevent)
       ("libssh" ,libssh)
       ("msgpack" ,msgpack)
       ("ncurses" ,ncurses)))
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ("pkg-config" ,pkg-config)))
    (home-page "https://tmate.io/")
    (synopsis "Terminal sharing application")
    (description "tmate is a terminal sharing application that allows you to
share your terminal with other users over the Internet.  tmate is a fork of
tmux.")
    (license license:isc)))

(define-public kitty
  (package
    (name "kitty")
    (version "0.16.0")
    (home-page "https://sw.kovidgoyal.net/kitty/")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/kovidgoyal/kitty.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1bszyddar0g1gdz67h8rd3gbrdhi6ahjg7j14cjiqxm1938z9ajf"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; patch needed as sphinx-build is used as a python script
           ;; whereas the guix package uses a bash script launching the
           ;; python script
           (substitute* "docs/conf.py"
             (("(from kitty.constants import str_version)" kitty-imp)
              (string-append "sys.path.append(\"..\")\n" kitty-imp)))
           (substitute* "docs/Makefile"
             (("^SPHINXBUILD[[:space:]]+= (python3.*)$")
              "SPHINXBUILD = sphinx-build\n"))
           #t))))
    (build-system gnu-build-system)
    (inputs
     `(("python" ,python)
       ("harfbuzz" ,harfbuzz)
       ("zlib" ,zlib)
       ("libcanberra" ,libcanberra)
       ("libpng" ,libpng)
       ("freetype" ,freetype)
       ("fontconfig" ,fontconfig)
       ("pygments" ,python-pygments)
       ("wayland" ,wayland)))
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("libxrandr" ,libxrandr)
       ("libdbus" ,dbus)
       ("libxcursor" ,libxcursor)
       ("libxi" ,libxi)
       ("libxinerama" ,libxinerama)
       ("libgl1-mesa" ,mesa)
       ("libxkbcommon" ,libxkbcommon)
       ("sphinx" ,python-sphinx)
       ("ncurses" ,ncurses) ;; for tic command
       ("wayland-protocols" ,wayland-protocols)))
    (arguments
     '(#:phases (modify-phases %standard-phases
                  (delete 'configure)
                  ;; Wayland backend requires EGL, which isn't found
                  ;; out-of-the-box for some reason. Hard-code it instead.
                  (add-after 'unpack 'hard-code-libegl
                    (lambda _
                      (let* ((mesa (assoc-ref %build-inputs "libgl1-mesa"))
                             (libegl (string-append mesa "/lib/libEGL.so.1")))
                        (substitute* "glfw/egl_context.c"
                                     (("libEGL.so.1") libegl)))
                      #t))
                  (replace 'build
                    (lambda _
                      (invoke "python3" "setup.py" "linux-package")))
                  (replace 'check
                    (lambda _
                      (invoke "python3" "setup.py" "test")))
                  (add-before 'install 'rm-pycache
                    ;; created python cache __pycache__ are non deterministic
                    (lambda _
                      (let ((pycaches (find-files "linux-package/"
                                                  "__pycache__"
                                                  #:directories? #t)))
                        (for-each delete-file-recursively pycaches)
                        #t)))
                  (replace 'install
                    (lambda _
                      (let* ((out (assoc-ref %outputs "out"))
                             (obin (string-append out "/bin"))
                             (olib (string-append out "/lib"))
                             (oshare (string-append out "/share")))
                        (copy-recursively "linux-package/bin" obin)
                        (copy-recursively "linux-package/share" oshare)
                        (copy-recursively "linux-package/lib" olib)
                        #t))))))
    (synopsis "Fast, featureful, GPU based terminal emulator")
    (description "Kitty is a fast and featureful GPU-based terminal emulator:
@itemize
@item Offloads rendering to the GPU for lower system load and buttery smooth
scrolling.  Uses threaded rendering to minimize input latency.
@item Supports all modern terminal features: graphics (images), unicode,
true-color, OpenType ligatures, mouse protocol, focus tracking, bracketed
paste and several new terminal protocol extensions.
@item Supports tiling multiple terminal windows side by side in different
layouts without needing to use an extra program like tmux.
@item Can be controlled from scripts or the shell prompt, even over SSH.
@item Has a framework for Kittens, small terminal programs that can be used to
extend kitty's functionality.  For example, they are used for Unicode input,
hints, and side-by-side diff.
@item Supports startup sessions which allow you to specify the window/tab
layout, working directories and programs to run on startup.
@item Allows you to open the scrollback buffer in a separate window using
arbitrary programs of your choice.  This is useful for browsing the history
comfortably in a pager or editor.
@end itemize")
    (license license:gpl3+)))

(define-public eternalterminal
  (package
    (name "eternalterminal")
    (version "6.0.7")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
               (url "https://github.com/MisterTea/EternalTerminal.git")
               (commit (string-append "et-v" version))))
        (file-name (git-file-name name version))
       (sha256
        (base32 "03pdspggqxkmz95qb96pig5x0xw18hy9a7ivszydr32ry6kxxx1h"))))
    (build-system cmake-build-system)
    (arguments
     '(#:configure-flags '("-DBUILD_TEST=ON")
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'insert-googletests
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((tests (assoc-ref inputs "googletest")))
               (copy-recursively tests "external/googletest"))
             #t)))))
    (inputs
     `(("gflags" ,gflags)
       ("libsodium" ,libsodium)
       ("protobuf" ,protobuf)))
    (native-inputs
     `(("googletest" ,(package-source googletest))))
    (home-page "https://mistertea.github.io/EternalTerminal/")
    (synopsis "Remote shell that reconnects without interrupting the session")
    (description "@dfn{Eternal Terminal} (ET) is a remote shell that
automatically reconnects without interrupting the session.  ET uses SSH to
initialize a secure connection.  Unlike SSH sessions, which must be killed and
reconnected after a network outage an ET session will survive network outages
and IP roaming.  ET provides the same core functionality as @command{mosh},
while also supporting native scrolling and @command{tmux} control mode
(@code{tmux -CC}).")
    (license license:asl2.0)))

(define-public wterm
  (package
    (name "wterm")
    (version "0.7")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/majestrate/wterm.git")
             (commit "0ae42717c08a85a6509214e881422c7fbe7ecc45")))
       (sha256
         (base32
          "0g4lzmc1w6na81i6hny32xds4xfig4xzswzfijyi6p93a1226dv0"))
       (file-name (git-file-name name version))))
    (build-system gnu-build-system)
    (native-inputs
     `(("pkg-config" ,pkg-config)))
    (inputs
     `(("fontconfig" ,fontconfig)
       ("freetype" ,freetype)
       ("libdrm" ,libdrm)
       ("libxkbcommon" ,libxkbcommon)
       ("ncurses" ,ncurses)
       ("pixman" ,pixman)
       ("wayland" ,wayland)))
    (arguments
     '(#:tests? #f

       ;; Without -j1 it fails to find file libwld.a.
       #:parallel-build? #f

       #:make-flags (list "CC=gcc"
                          (string-append "PREFIX=" %output)
                          (string-append "TERMINFO="
                                         (assoc-ref %outputs "out")
                                         "/share/terminfo"))
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (add-after 'unpack 'terminfo-fix
           (lambda _
             (substitute* "Makefile"
               (("\ttic .*") "\tmkdir -p $(SHARE_PREFIX)/share/terminfo
\ttic -o $(SHARE_PREFIX)/share/terminfo -s wterm.info\n"))
             #t)))))
    (native-search-paths
      (list (search-path-specification
              (variable "TERMINFO_DIRS")
              (files '("share/terminfo")))))
    (home-page "https://github.com/majestrate/wterm")
    (synopsis "Terminal emulator for Wayland")
    (description "wterm is a native Wayland terminal emulator based on
an st fork using wld. st is a simple terminal emulator for X originally
made by suckless.")
    (license license:x11)))

(define-public alacritty
  (package
    (name "alacritty")
    (version "0.4.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jwilm/alacritty.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "05jcg33ifngpzw2hdhgb614j87ihhhlqgar0kky183rywg0dxikg"))
       (modules '((guix build utils)))
       (snippet
         ;; Don't use a custom location for winit-0.20-alpha6.
         '(begin (substitute* "Cargo.toml"
                   (("winit .*") ""))
                 #t))))
    (build-system cargo-build-system)
    (arguments
     `(#:cargo-inputs
       (("rust-clap" ,rust-clap-2)
        ("rust-log" ,rust-log-0.4)
        ("rust-time" ,rust-time-0.1)
        ("rust-env-logger" ,rust-env-logger-0.7)
        ("rust-serde" ,rust-serde-1.0)
        ("rust-serde-yaml" ,rust-serde-yaml-0.8)
        ("rust-serde-json" ,rust-serde-json-1.0)
        ("rust-glutin" ,rust-glutin-0.22) ; adjust 'patch-glutin-libgl-path as needed
        ("rust-notify" ,rust-notify-4)
        ("rust-libc" ,rust-libc-0.2)
        ("rust-unicode-width" ,rust-unicode-width-0.1)
        ("rust-parking-lot" ,rust-parking-lot-0.9)
        ("rust-urlocator" ,rust-urlocator-0.1)
        ("rust-xdg" ,rust-xdg-2.2)
        ("rust-image" ,rust-image-0.22)
        ("rust-dirs" ,rust-dirs-2.0)
        ("rust-x11-dl" ,rust-x11-dl-2)
        ("rust-winapi" ,rust-winapi-0.3)
        ("rust-base64" ,rust-base64-0.11)
        ("rust-bigflags" ,rust-bitflags-1)
        ("rust-fnv" ,rust-fnv-1.0)
        ("rust-mio" ,rust-mio-0.6)
        ("rust-mio-extras" ,rust-mio-extras-2)
        ("rust-terminfo" ,rust-terminfo-0.6)
        ("rust-url" ,rust-url-2.1)
        ("rust-vte" ,rust-vte-0.3)
        ("rust-nix" ,rust-nix-0.15)
        ("rust-miow" ,rust-miow-0.3)
        ("rust-mio-anonymous-pipes" ,rust-mio-anonymous-pipes-0.1)
        ("rust-mio-named-pipes" ,rust-mio-named-pipes-0.1)
        ("rust-signal-hook" ,rust-signal-hook-0.1)
        ("rust-clipboard-win" ,rust-clipboard-win-2.1)
        ("rust-objc" ,rust-objc-0.2)
        ("rust-objc-id" ,rust-objc-id-0.1)
        ("rust-objc-foundation" ,rust-objc-foundation-0.1)
        ("rust-x11-clipboard" ,rust-x11-clipboard-0.4)
        ("rust-smithay-clipboard" ,rust-smithay-clipboard-0.3)
        ("rust-wayland-client" ,rust-wayland-client-0.23)
        ("rust-euclid" ,rust-euclid-0.20)
        ("rust-foreign-types" ,rust-foreign-types-0.5)
        ("rust-servo-fontconfig" ,rust-servo-fontconfig-0.4)
        ("rust-freetype-rs" ,rust-freetype-rs-0.23)
        ("rust-core-foundation" ,rust-core-foundation-0.6)
        ("rust-core-foundation-sys" ,rust-core-foundation-sys-0.6)
        ("rust-core-text" ,rust-core-text-13)
        ("rust-core-graphics" ,rust-core-graphics-0.17)
        ("rust-dwrote" ,rust-dwrote-0.9)
        ("rust-winpty-sys" ,rust-winpty-sys-0.4))
       #:cargo-development-inputs
       (("rust-rustc-tools-util" ,rust-rustc-tools-util-0.2)
        ("rust-gl-generator" ,rust-gl-generator-0.14)
        ("rust-andrew" ,rust-andrew-0.2)
        ("rust-smithay-client-toolkit" ,rust-smithay-client-toolkit-0.6)
        ("rust-embed-resource" ,rust-embed-resource-1.3)
        ("rust-http-req" ,rust-http-req-0.5)
        ("rust-zip" ,rust-zip-0.5)
        ("rust-tempfile" ,rust-tempfile-3.1)
        ("rust-named-pipe" ,rust-named-pipe-0.4)
        ("rust-winapi" ,rust-winapi-0.3))
       #:phases
       (modify-phases %standard-phases
         (add-after 'configure 'patch-glutin-libgl-path
           (lambda* (#:key inputs cargo-inputs vendor-dir #:allow-other-keys)
             (let* ((glutin-name ,(package-name rust-glutin-0.22))
                    (glutin-version ,(package-version rust-glutin-0.22))
                    (src-api
                      (string-append
                        glutin-name "-" glutin-version ".tar.gz/src/api/"))
                    (mesa (assoc-ref inputs "mesa")))
              (substitute* (string-append vendor-dir "/" src-api "glx/mod.rs")
                (("libGL.so") (string-append mesa "/lib/libGL.so")))
              (substitute* (string-append vendor-dir "/" src-api "egl/mod.rs")
                (("libEGL.so") (string-append mesa "/lib/libEGL.so")))
              #t)))
         (add-after 'configure 'remove-alacritty-vendor
           (lambda* (#:key vendor-dir #:allow-other-keys)
              ;; We don't want Alacritty to be a dependency of itself
              ;; If we don't delete it from guix-vendor then build will fail
              ;; because Alacritty has a virtual workspace Cargo.toml.
              (delete-file-recursively
                (string-append vendor-dir "/alacritty-" ,version ".tar.xz"))
              #t))
         (replace 'install
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out   (assoc-ref outputs "out"))
                    (share (string-append out "/share"))
                    (icons (string-append share "/icons/hicolor/scalable/apps"))
                    (tic   (string-append (assoc-ref inputs "ncurses") "/bin/tic"))
                    (man   (string-append share "/man/man1"))
                    (alacritty-bin "target/release/alacritty"))

               ;; Install binary
               (install-file alacritty-bin (string-append out "/bin"))

               ;; Install man pages
               (mkdir-p man)
               (copy-file "extra/alacritty.man"
                          (string-append man "/alacritty.1"))

               ;; Install desktop file
               (install-file "extra/linux/alacritty.desktop"
                             (string-append share "/applications"))

               ;; Install icon
               (mkdir-p icons)
               (copy-file "extra/logo/alacritty-term.svg"
                          (string-append icons "/Alacritty.svg"))

               ;; Install terminfo
               (mkdir-p (string-append share "/terminfo"))
               ;; We don't compile alacritty-common entry because
               ;; it's being used only for inheritance.
               (invoke tic "-x" "-e" "alacritty,alacritty-direct"
                       "-o" (string-append share "/terminfo/")
                       "extra/alacritty.info")

               ;; Install completions
               (install-file
                 "extra/completions/alacritty.bash"
                 (string-append out "/etc/bash_completion.d"))
               (install-file
                 "extra/completions/_alacritty"
                 (string-append share "/zsh/site-functions"))
               (install-file
                 "extra/completions/alacritty.fish"
                 (string-append share "/fish/vendor_completions.d"))
               #t))))))
    (inputs
     `(("expat" ,expat)
       ("fontconfig" ,fontconfig)
       ("freetype" ,freetype)
       ("libx11" ,libx11)
       ("libxcb" ,libxcb)
       ("libxcursor" ,libxcursor)
       ("libxi" ,libxi)
       ("libxkbcommon" ,libxkbcommon)
       ("libxrandr" ,libxrandr)
       ("libxxf86vm" ,libxxf86vm)
       ("wayland" ,wayland)
       ("mesa" ,mesa)))
    (native-inputs
     `(("cmake" ,cmake)
       ("ncurses" ,ncurses)
       ("pkg-config" ,pkg-config)
       ("python3" ,python)))
    (home-page "https://github.com/alacritty/alacritty")
    (synopsis "GPU-accelerated terminal emulator")
    (description
     "Alacritty is a GPU-accelerated terminal emulator with a strong focus on
simplicity and performance.  With such a strong focus on performance, included
features are carefully considered and you can always expect Alacritty to be
blazingly fast.  By making sane choices for defaults, Alacritty requires no
additional setup.  However, it does allow configuration of many aspects of the
terminal.  Note that you need support for OpenGL 3.2 or higher.")
    (license license:asl2.0)))
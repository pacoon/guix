;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016, 2017, 2019, 2020 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2018, 2019 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2020 Vinicius Monego <monego@posteo.net>
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

(define-module (gnu packages syndication)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix build-system glib-or-gtk)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (gnu packages)
  #:use-module (gnu packages check)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gstreamer)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-check)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages web)
  #:use-module (gnu packages webkit)
  #:use-module (gnu packages xml))

(define-public newsboat
  (package
    (name "newsboat")
    (version "2.13")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://newsboat.org/releases/" version
                           "/newsboat-" version ".tar.xz"))
       (sha256
        (base32
         "0pik1d98ydzqi6055vdbkjg5krwifbk2hy2f5jp5p1wcy2s16dn7"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("gettext" ,gettext-minimal)
       ("pkg-config" ,pkg-config)
       ;; For building documentation.
       ("asciidoc" ,asciidoc)))
    (inputs
     `(("curl" ,curl)
       ("json-c" ,json-c)
       ("libxml2" ,libxml2)
       ("ncurses" ,ncurses)
       ("stfl" ,stfl)
       ("sqlite" ,sqlite)))
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (delete 'configure)            ; no configure script
         (add-after 'build 'build-documentation
           (lambda _
             (invoke "make" "doc"))))
       #:make-flags
       (list (string-append "prefix=" (assoc-ref %outputs "out")))
       #:test-target "test"))
    (native-search-paths
     ;; Newsboat respects CURL_CA_BUNDLE.
     (package-native-search-paths curl))
    (home-page "https://newsboat.org/")
    (synopsis "Text-mode RSS and Atom feed reader with podcast support")
    (description "Newsboat is a feed reader for @dfn{RSS} and @dfn{Atom}, XML
formats widely used to transmit, publish, and syndicate news or blog articles.
It's designed for use on text terminals, and to have a coherent and easy-to-use
interface that might look familiar to @command{mutt} or @command{slrn} users.

Newsboat supports OPML import/exports, HTML rendering, podcasts (with
@command{podboat}), off-line reading, searching and storing articles to your
file system, and many more features.")
    (license (list license:gpl2+        ; filter/*
                   license:expat))))    ; everything else

(define-public liferea
  (package
    (name "liferea")
    (version "1.12.6")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/lwindolf/liferea/"
                           "releases/download/v" version "/liferea-"
                           version "b.tar.bz2"))
       (sha256
        (base32 "03pr1gmiv5y0i92bkhcxr8s311ll91chz19wb96jkixx32xav91d"))))
    (build-system glib-or-gtk-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-before 'configure 'prepare-build-environment
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Workaround for https://github.com/lwindolf/liferea/issues/767.
             (setenv "WEBKIT_DISABLE_COMPOSITING_MODE" "1")))
         (add-after 'install 'wrap-gi-python
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out               (assoc-ref outputs "out"))
                   (gi-typelib-path   (getenv "GI_TYPELIB_PATH"))
                   (python-path       (getenv "PYTHONPATH")))
               (wrap-program (string-append out "/bin/liferea")
                             `("GI_TYPELIB_PATH" ":" prefix (,gi-typelib-path))
                             `("PYTHONPATH" ":" prefix (,python-path))))
            #t)))))
    (native-inputs
     `(("gettext" ,gettext-minimal)
       ("glib:bin" ,glib "bin")
       ("gobject-introspection" ,gobject-introspection)
       ("intltool" ,intltool)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("glib-networking" ,glib-networking)
       ("gnome-keyring" ,gnome-keyring)
       ("gsettings-desktop-schemas" ,gsettings-desktop-schemas)
       ("gstreamer" ,gstreamer)
       ("json-glib" ,json-glib)
       ("libnotify" ,libnotify)
       ("libpeas" ,libpeas)
       ("libsecret" ,libsecret)
       ("libxml2" ,libxml2)
       ("libxslt" ,libxslt)
       ("python" ,python)
       ("python-pycairo" ,python-pycairo)
       ("python-pygobject" ,python-pygobject)
       ("webkitgtk" ,webkitgtk)))
    (home-page "https://lzone.de/liferea/")
    (synopsis "News reader for GTK/GNOME")
    (description "Liferea is a desktop feed reader/news aggregator that
brings together all of the content from your favorite subscriptions into
a simple interface that makes it easy to organize and browse feeds.")
    (license license:gpl2+)))

(define-public rtv
  (package
    (name "rtv")
    (version "1.27.0")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "rtv" version))
        (sha256
         (base32 "0hvw426y09l3yzwv2zkb9hifpfbg9wd1gg0y3z3pxcli6n3ii2wl"))))
    (build-system python-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (add-before 'check 'set-environment-variables
           (lambda* (#:key inputs #:allow-other-keys)
             (setenv "HOME" (getcwd))
             (setenv "TERM" "linux")
             (setenv "TERMINFO" (string-append (assoc-ref inputs "ncurses")
                                               "/share/terminfo"))
             #t)))
       #:tests? #f)) ; tests fail: _curses.error: nocbreak() returned ERR
    (propagated-inputs
     `(("python-beautifulsoup4" ,python-beautifulsoup4)
       ("python-decorator" ,python-decorator)
       ("python-kitchen" ,python-kitchen)
       ("python-requests" ,python-requests)
       ("python-six" ,python-six)))
    (native-inputs
     `(("ncurses" ,ncurses)
       ("python-coveralls" ,python-coveralls)
       ("python-coverage" ,python-coverage)
       ("python-mock" ,python-mock)
       ("python-pylint" ,python-pylint)
       ("python-pytest" ,python-pytest)
       ("python-vcrpy" ,python-vcrpy)))
    (home-page "https://github.com/michael-lazar/rtv")
    (synopsis "Terminal viewer for Reddit (Reddit Terminal Viewer)")
    (description
     "RTV provides a text-based interface to view and interact with Reddit.")
    (license (list license:expat
                   license:gpl3+)))) ; rtv/packages/praw

(define-public tuir
  (package
    (name "tuir")
    (version "1.29.0")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "tuir" version))
        (sha256
         (base32
          "06xb030ibphbrz4nsxm8mh3g60ld8xfp6kc3j6vi1k4ls5s4h79i"))))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (add-installed-pythonpath inputs outputs)
             (invoke "pytest"))))))
    (inputs
     `(("python-beautifulsoup4" ,python-beautifulsoup4)
       ("python-decorator" ,python-decorator)
       ("python-kitchen" ,python-kitchen)
       ("python-requests" ,python-requests)
       ("python-six" ,python-six)))
    (native-inputs
     `(("python-coverage" ,python-coverage)
       ("python-coveralls" ,python-coveralls)
       ("python-mock" ,python-mock)
       ("python-pylint" ,python-pylint)
       ("python-pytest" ,python-pytest)
       ("python-vcrpy" ,python-vcrpy)))
    (home-page "https://gitlab.com/ajak/tuir")
    (synopsis "Terminal viewer for Reddit (Terminal UI for Reddit)")
    (description
     "Tuir provides a simple terminal viewer for Reddit (Terminal UI for Reddit).")
    (license (list license:expat
                   license:gpl3+))))    ; tuir/packages/praw

(define-public rawdog
  (package
    (name "rawdog")
    (version "2.23")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://offog.org/files/rawdog-"
                           version ".tar.gz"))
       (sha256
        (base32
         "18nyg19mwxyqdnykplkqmzb4n27vvrhvp639zai8f81gg9vdbsjp"))))
    (build-system python-build-system)
    (arguments
     `(#:python ,python-2.7))
    (inputs
     `(("python2-feedparser" ,python2-feedparser)
       ("python2-pytidylib" ,python2-pytidylib)))
    (home-page "https://offog.org/code/rawdog/")
    (synopsis "RSS Aggregator Without Delusions Of Grandeur")
    (description
     "@command{rawdog} is a feed aggregator, capable of producing a personal
\"river of news\" or a public \"planet\" page.  It supports all common feed
formats, including all versions of RSS and Atom.")
    (license license:gpl2+)))

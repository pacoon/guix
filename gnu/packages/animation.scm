;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2015, 2017 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2018, 2019 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2019 Pkill -9 <pkill9@runbox.com>
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

(define-module (gnu packages animation)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages graphics)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages image)
  #:use-module (gnu packages imagemagick)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages video))

;; ETL, synfig, and Synfig Studio are updated in tandem.
(define synfig-version "1.2.2")

(define-public etl
  (package
    (name "etl")
    (version synfig-version)
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/synfig/releases/"
                                  version "/source/ETL-" version ".tar.gz"))
              (sha256
               (base32
                "12sd8pz8l5xcxcmapkvih3brihdhdb6xmxisr9a415lydid9rh8d"))))
    (build-system gnu-build-system)
    (home-page "https://www.synfig.org")
    (synopsis "Extended C++ template library")
    (description
     "ETL is a class and template library designed to add new datatypes and
functions which combine well with the existing types and functions from the
C++ @dfn{Standard Template Library} (STL).")
    (license license:gpl3+)))

(define-public synfig
  (package
    (name "synfig")
    (version synfig-version)
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/synfig/releases/"
                                  version "/source/synfig-" version
                                  ".tar.gz"))
              (sha256
               (base32
                "1vy27kl68sbg41sfasa58k3p2nc1xfalvzk3k9gich9h90rpnpsz"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       ;; The Boost library path is taken from the value of BOOST_LDFLAGS.
       (list (string-append "BOOST_LDFLAGS=-L"
                            (assoc-ref %build-inputs "boost")
                            "/lib"))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-boost-build-error
           ;; A chain of Boost headers leads to this error: "make_array" is
           ;; not a member of "boost::serialization".  This can be avoided by
           ;; loading the "array_wrapper" header first.
           (lambda _
             (substitute* "src/synfig/valuenodes/valuenode_dynamic.cpp"
               (("#include <boost/numeric/odeint/integrate/integrate.hpp>" match)
                (string-append
                 "#include <boost/serialization/array_wrapper.hpp>\n" match)))
             #t))
         (add-after 'unpack 'adapt-to-libxml++-changes
          (lambda _
            (substitute* "configure"
              (("libxml\\+\\+-2\\.6") "libxml++-3.0"))
            (substitute* (append (find-files "src/modules/" "\\.cpp$")
                                 (find-files "src/synfig/" "\\.(cpp|h)$"))
              (("add_child\\(") "add_child_element(")
              (("get_child_text\\(") "get_first_child_text(")
              (("set_child_text\\(") "set_first_child_text(")
              (("remove_child\\(") "remove_node("))
            (substitute* "src/modules/mod_svg/svg_parser.cpp"
              (("xmlpp::Node::NodeList") "xmlpp::Node::const_NodeList"))
            #t)))))
    (inputs
     `(("boost" ,boost)
       ("ffmpeg" ,ffmpeg)
       ("libdv" ,libdv)
       ("libjpeg" ,libjpeg-turbo)
       ("libpng" ,libpng)
       ("libmng" ,libmng)
       ("zlib" ,zlib)))
    ;; synfig.pc lists the following as required: Magick++ freetype2
    ;; fontconfig fftw OpenEXR ETL glibmm-2.4 giomm-2.4 libxml++-3.0 sigc++-2.0
    ;; cairo pango pangocairo mlt++
    (propagated-inputs
     `(("cairo" ,cairo)
       ("etl" ,etl)
       ("fftw" ,fftw)
       ("fontconfig" ,fontconfig)
       ("freetype" ,freetype)
       ("glibmm" ,glibmm)
       ("imagemagick" ,imagemagick)
       ("libxml++" ,libxml++)
       ("libsigc++" ,libsigc++)
       ("mlt" ,mlt)
       ("openexr" ,openexr)
       ("pango" ,pango)))
    (native-inputs
     `(("intltool" ,intltool)
       ("pkg-config" ,pkg-config)))
    (home-page "https://www.synfig.org")
    (synopsis "Vector-based 2D animation renderer")
    (description
     "Synfig is a vector-based 2D animation package.  It is designed to be
capable of producing feature-film quality animation.  It eliminates the need
for tweening, preventing the need to hand-draw each frame.")
    (license license:gpl3+)))

(define-public synfigstudio
  (package
    (name "synfigstudio")
    (version synfig-version)
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/synfig/releases/"
                                  version "/source/synfigstudio-" version
                                  ".tar.gz"))
              (sha256
               (base32
                "1ql92kh9z8w2j9yi3pr7hn7wh2r2j35xynwv9xlwyd7niackgykn"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  (substitute* "src/synfigapp/pluginmanager.cpp"
                    (("xmlpp::Node\\* n =")    "const xmlpp::Node* n =")
                    (("xmlpp::Node::NodeList") "xmlpp::Node::const_NodeList"))
                  #t))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         ;; This fixes the file chooser crash that happens with GTK 3.
         (add-after 'install 'wrap-program
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (gtk (assoc-ref inputs "gtk+"))
                    (gtk-share (string-append gtk "/share")))
               (wrap-program (string-append out "/bin/synfigstudio")
                 `("XDG_DATA_DIRS" ":" prefix (,gtk-share)))
               #t))))))
    (inputs
     `(("gtkmm" ,gtkmm)
       ("gtk+" ,gtk+)
       ("libsigc++" ,libsigc++)
       ("synfig" ,synfig)))
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("intltool" ,intltool)))
    (home-page "https://www.synfig.org")
    (synopsis "Vector-based 2D animation package (GUI)")
    (description
     "Synfig is a vector-based 2D animation package.  It is designed to
be capable of producing feature-film quality animation.  It eliminates the
need for tweening, preventing the need to hand-draw each frame.  This package
contains the graphical user interface for synfig.")
    (license license:gpl3+)))

(define-public papagayo
  (let ((commit "e143684b30e59fe4a554f965cb655d23cbe93ee7")
        (revision "1"))
    (package
      (name "papagayo")
      (version (string-append "2.0b1-" revision "." (string-take commit 9)))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/LostMoho/Papagayo.git")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "1p9gffjhbph34jhrvgpg93yha75bf88vkvlnk06x1r9601ph5321"))
                (modules '((guix build utils)))
                ;; Delete bundled libsndfile sources.
                (snippet
                 '(begin
                    (delete-file-recursively "libsndfile_1.0.19")
                    (delete-file-recursively "libsndfile_1.0.25")
                    #t))))
      (build-system gnu-build-system)
      (arguments
       `(#:phases
         (modify-phases %standard-phases
           (replace 'configure
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let ((libsndfile (assoc-ref inputs "libsndfile")))
                 ;; Do not use bundled libsndfile sources
                 (substitute* "Papagayo.pro"
                   (("else \\{")
                    (string-append "\nINCLUDEPATH += " libsndfile
                                   "/include"
                                   "\nLIBS +=" libsndfile
                                   "/lib/libsndfile.so\n"
                                   "win32 {"))))
               (invoke "qmake"
                       (string-append "DESTDIR="
                                      (assoc-ref outputs "out")
                                      "/bin"))))
           ;; Ensure that all required Qt plugins are found at runtime.
           (add-after 'install 'wrap-executable
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (qt '("qt" "qtmultimedia")))
                 (wrap-program (string-append out "/bin/Papagayo")
                   `("QT_PLUGIN_PATH" ":" prefix
                     ,(map (lambda (label)
                             (string-append (assoc-ref inputs label)
                                            "/lib/qt5/plugins/"))
                           qt)))
                 #t))))))
      (inputs
       `(("qt" ,qtbase)
         ("qtmultimedia" ,qtmultimedia)
         ("libsndfile" ,libsndfile)))
      (native-inputs
       `(("qttools" ,qttools)))
      (home-page "https://www.lostmarble.com/papagayo/")
      (synopsis "Lip-syncing for animations")
      (description
       "Papagayo is a lip-syncing program designed to help you line up
phonemes with the actual recorded sound of actors speaking.  Papagayo makes it
easy to lip sync animated characters by making the process very simple – just
type in the words being spoken, then drag the words on top of the sound’s
waveform until they line up with the proper sounds.")
      (license license:gpl3+))))

(define-public pencil2d
  (package
    (name "pencil2d")
    (version "0.6.4")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/pencil2d/pencil")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0zi8x0w8n817zds2lyw9l8j33c03kiybkrcyy3s5fg66mchmrwnr"))))
    (build-system gnu-build-system)
    (inputs
     `(("qtbase" ,qtbase)
       ("qtxmlpatterns" ,qtxmlpatterns)
       ("qtmultimedia" ,qtmultimedia)
       ("qtsvg" ,qtsvg)))
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (replace 'configure
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (invoke "qmake" (string-append "PREFIX=" out)))))
         (add-after 'install 'wrap-executable
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out"))
                   (plugin-path (getenv "QT_PLUGIN_PATH")))
               (wrap-program (string-append out "/bin/pencil2d")
                 `("QT_PLUGIN_PATH" ":" prefix (,plugin-path)))
               #t))))))
    (home-page "https://www.pencil2d.org")
    (synopsis "Make 2D hand-drawn animations")
    (description
     "Pencil2D is an easy-to-use and intuitive animation and drawing tool.  It
lets you create traditional hand-drawn animations (cartoons) using both bitmap
and vector graphics.")
    (license license:gpl2)))

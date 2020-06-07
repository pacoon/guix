;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017, 2018 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2017 Corentin Bocquillon <corentin@nybble.fr>
;;; Copyright © 2017, 2018, 2019, 2020 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2018 Fis Trivial <ybbs.daans@hotmail.com>
;;; Copyright © 2018 Tomáš Čech <sleep_walker@gnu.org>
;;; Copyright © 2018, 2020 Marius Bakke <mbakke@fastmail.com>
;;; Copyright © 2018 Alex Vong <alexvong1995@gmail.com>
;;; Copyright © 2019 Brett Gilio <brettg@gnu.org>
;;; Copyright © 2019 Jonathan Brielmaier <jonathan.brielmaier@web.de>
;;; Copyright © 2020 Leo Prikler <leo.prikler@student.tugraz.at>
;;; Copyright © 2020 Yuval Kogman <nothingmuch@woobling.org>
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

(define-module (gnu packages build-tools)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (gnu packages)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages lua)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages ninja)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python))

(define-public bam
  (package
    (name "bam")
    (version "0.5.1")
    (source (origin
              ;; do not use auto-generated tarballs
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/matricks/bam.git")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "13br735ig7lygvzyfd15fc2rdygrqm503j6xj5xkrl1r7w2wipq6"))))
    (build-system gnu-build-system)
    (arguments
     `(#:make-flags `("CC=gcc"
                      ,(string-append "INSTALL_PREFIX="
                                      (assoc-ref %outputs "out")))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))
    (native-inputs
     `(("python" ,python-2)))
    (inputs
     `(("lua" ,lua)))
    (home-page "https://matricks.github.io/bam/")
    (synopsis "Fast and flexible build system")
    (description "Bam is a fast and flexible build system.  Bam uses Lua to
describe the build process.  It takes its inspiration for the script files
from scons.  While scons focuses on being 100% correct when building, bam
makes a few sacrifices to acquire fast full and incremental build times.")
    (license license:bsd-3)))

(define-public bear
  (package
    (name "bear")
    (version "2.4.3")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/rizsotto/Bear")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "19fk4flfykbzhb89ppmzqf0zlrkbjm6ajl9fsayndj9km5ys0041"))))
    (build-system cmake-build-system)
    (inputs
     `(("python" ,python-wrapper)))
    (home-page "https://github.com/rizsotto/Bear")
    (synopsis "Tool for generating a compilation database")
    (description "A JSON compilation database is used in the Clang project to
provide information on how a given compilation unit is processed.  With this,
it is easy to re-run the compilation with alternate programs.  Bear is used to
generate such a compilation database.")
    (license license:gpl3+)))

(define-public gn
  (let ((commit "ec938ddaa276646eb8f1ab33e160c156011d8217")
        (revision "1736"))            ;as returned by `git describe`, used below
    (package
      (name "gn")
      (version (git-version "0.0" revision commit))
      (home-page "https://gn.googlesource.com/gn")
      (source (origin
                (method git-fetch)
                (uri (git-reference (url home-page) (commit commit)))
                (sha256
                 (base32
                  "0j1qjwp2biw12s6npzpx4z8nvih7pyn68q6cz2k4700bk9y0d574"))
                (file-name (git-file-name name version))))
      (build-system gnu-build-system)
      (arguments
       `(#:phases (modify-phases %standard-phases
                    (add-before 'configure 'set-build-environment
                      (lambda _
                        (setenv "CC" "gcc") (setenv "CXX" "g++")
                        (setenv "AR" "ar")
                        #t))
                    (replace 'configure
                      (lambda _
                        (invoke "python" "build/gen.py"
                                "--no-last-commit-position")))
                    (add-after 'configure 'create-last-commit-position
                      (lambda _
                        ;; Create "last_commit_position.h" to avoid a dependency
                        ;; on 'git' (and the checkout..).
                        (call-with-output-file "out/last_commit_position.h"
                          (lambda (port)
                            (format port
                                    (string-append
                                     "#define LAST_COMMIT_POSITION_NUM ~a\n"
                                     "#define LAST_COMMIT_POSITION \"~a (~a)\"\n")
                                    ,revision ,revision ,(string-take commit 8))
                            #t))))
                    (replace 'build
                      (lambda _
                        (invoke "ninja" "-C" "out" "gn"
                                "-j" (number->string (parallel-job-count)))))
                    (replace 'check
                      (lambda* (#:key (tests? #t) #:allow-other-keys)
                        (if tests?
                            (lambda ()
                              (invoke "ninja" "-C" "out" "gn_unittests"
                                      "-j" (number->string (parallel-job-count)))
                              (invoke "./out/gn_unittests"))
                            (format #t "test suite not run~%"))))
                    (replace 'install
                      (lambda* (#:key outputs #:allow-other-keys)
                        (let ((out (assoc-ref outputs "out")))
                          (install-file "out/gn" (string-append out "/bin"))
                          #t))))))
      (native-inputs
       `(("ninja" ,ninja)
         ("python" ,python-2)))
      (synopsis "Generate Ninja build files")
      (description
       "GN is a tool that collects information about a project from @file{.gn}
files and generates build instructions for the Ninja build system.")
      ;; GN is distributed as BSD-3, but bundles some files from ICU using the
      ;; X11 license.
      (license (list license:bsd-3 license:x11)))))

(define-public meson
  (package
    (name "meson")
    (version "0.53.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/mesonbuild/meson/"
                                  "releases/download/" version  "/meson-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "07y2hh9dfn1m9g4bsy49nbn3vdmd0b2iwr8bxg19fhqq6c7q73ry"))))
    (build-system python-build-system)
    (arguments
     `(;; FIXME: Tests require many additional inputs, a fix for the RUNPATH
       ;; patch in meson-for-build, and patching many hard-coded file system
       ;; locations in "run_unittests.py".
       #:tests? #f
       #:phases (modify-phases %standard-phases
                  ;; Meson calls the various executables in out/bin through the
                  ;; Python interpreter, so we cannot use the shell wrapper.
                  (delete 'wrap))))
    (inputs `(("ninja" ,ninja)))
    (propagated-inputs `(("python" ,python)))
    (home-page "https://mesonbuild.com/")
    (synopsis "Build system designed to be fast and user-friendly")
    (description
     "The Meson build system is focused on user-friendliness and speed.
It can compile code written in C, C++, Fortran, Java, Rust, and other
languages.  Meson provides features comparable to those of the
Autoconf/Automake/make combo.  Build specifications, also known as @dfn{Meson
files}, are written in a custom domain-specific language (@dfn{DSL}) that
resembles Python.")
    (license license:asl2.0)))

(define-public meson-for-build
  (package
    (inherit meson)
    (name "meson-for-build")
    (source (origin
              (inherit (package-source meson))
              (patches (search-patches "meson-for-build-rpath.patch"))))

    ;; People should probably install "meson", not "meson-for-build".
    (properties `((hidden? . #t)))))

(define-public premake4
  (package
    (name "premake")
    (version "4.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/premake/Premake/"
                                  version "/premake-" version "-src.zip"))
              (sha256
               (base32
                "1017rd0wsjfyq2jvpjjhpszaa7kmig6q1nimw76qx3cjz2868lrn"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("unzip" ,unzip))) ; for unpacking the source
    (arguments
     `(#:make-flags '("CC=gcc")
       #:tests? #f ; No test suite
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (add-after 'unpack 'enter-source
           (lambda _ (chdir "build/gmake.unix") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (install-file "../../bin/release/premake4"
                           (string-append (assoc-ref outputs "out") "/bin"))
             #t)))))
    (synopsis "Portable software build tool")
    (description "@code{premake4} is a command line utility that reads a
scripted definition of a software project and outputs @file{Makefile}s or
other lower-level build files.")
    (home-page "https://premake.github.io")
    (license license:bsd-3)))

(define-public premake5
  (package
    (inherit premake4)
    (version "5.0.0-alpha14")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/premake/premake-core/"
                                  "releases/download/v" version
                                  "/premake-" version "-src.zip"))
              (sha256
               (base32
                "0236s7bjvxf7x1l5faywmfzjywflpx42ngyhkn0mqqjnh54a97vw"))))
    (arguments
     (substitute-keyword-arguments (package-arguments premake4)
       ((#:phases phases)
        `(modify-phases ,phases
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               (install-file "../../bin/release/premake5"
                             (string-append (assoc-ref outputs "out") "/bin"))
               #t))))))
    (description "@code{premake5} is a command line utility that reads a
scripted definition of a software project and outputs @file{Makefile}s or
other lower-level build files.")))

(define-public osc
  (package
    (name "osc")
    (version "0.165.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/openSUSE/osc")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0yjwvbvv9fgkpiyvrag89zxchyn3nbgp9jz0wn5p0z9450zwfyz6"))))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'install 'fix-filename
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((bin (string-append (assoc-ref outputs "out") "/bin/")))
               ;; Main osc tool is renamed in spec file, not setup.py, let's
               ;; do that too.
               (rename-file
                (string-append bin "osc-wrapper.py")
                (string-append bin "osc"))
               #t))))))
    (inputs
     `(("python-m2crypto" ,python-m2crypto)
       ("python-pycurl" ,python-pycurl)
       ("rpm" ,rpm)))                   ; for python-rpm
    (home-page "https://github.com/openSUSE/osc")
    (synopsis "Open Build Service command line tool")
    (description "@command{osc} is a command line interface to the Open Build
Service.  It allows you to checkout, commit, perform reviews etc.  The vast
majority of the OBS functionality is available via commands and the rest can
be reached via direct API calls.")
    (license license:gpl2+)))

(define-public compiledb
  (package
    (name "compiledb")
    (version "0.10.1")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "compiledb" version))
        (sha256
          (base32 "0vlngsdxfakyl8b7rnvn8h3l216lhbrrydr04yhy6kd03zflgfq6"))))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'no-compat-shim-dependency
           ;; shutilwhich is only needed for python 3.3 and earlier
           (lambda _
             (substitute* "setup.py" (("^ *'shutilwhich'\n") ""))
             (substitute* "compiledb/compiler.py" (("shutilwhich") "shutil")))))))
    (propagated-inputs
      `(("python-bashlex" ,python-bashlex)
        ("python-click" ,python-click)))
    (native-inputs
      `(("python-pytest" ,python-pytest)))
    (home-page
      "https://github.com/nickdiego/compiledb")
    (synopsis
      "Generate Clang JSON Compilation Database files for make-based build systems")
    (description
     "@code{compiledb} provides a @code{make} python wrapper script which,
besides executing the make build command, updates the JSON compilation
database file corresponding to that build, resulting in a command-line
interface similar to Bear.")
    (license license:gpl3)))

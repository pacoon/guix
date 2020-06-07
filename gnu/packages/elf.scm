;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013, 2014, 2015 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2014, 2015 Mark H Weaver <mhw@netris.org>
;;; Copyright © 2015 Andreas Enge <andreas@enge.fr>
;;; Copyright © 2017, 2018, 2019, 2020 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2017 Leo Famulari <leo@famulari.name>
;;; Copyright © 2018 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2018 Marius Bakke <mbakke@fastmail.com>
;;; Copyright © 2020 Mark Wielaard <mark@klomp.org>
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

(define-module (gnu packages elf)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:select (gpl3+ lgpl3+ lgpl2.0+))
  #:use-module (gnu packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages sphinx)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages xml)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26))

(define-public elfutils
  (package
    (name "elfutils")
    (version "0.176")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://sourceware.org/elfutils/ftp/"
                                  version "/elfutils-" version ".tar.bz2"))
              (sha256
               (base32
                "08qhrl4g6qqr4ga46jhh78y56a47p3msa5b2x1qhzbxhf71lfmzb"))
              (patches (search-patches "elfutils-tests-ptrace.patch"))))
    (build-system gnu-build-system)

    ;; Separate programs because that's usually not what elfutils users want,
    ;; and because they duplicate what Binutils provides (but are named
    ;; differently, using the eu- prefix and can be installed in parallel).
    (outputs '("out"                           ; libelf.so, elfutils/*.h, etc.
               "bin"))                         ; eu-nm, eu-objdump, etc.

    (arguments
     ;; Programs don't have libelf.so in their RUNPATH and libraries don't
     ;; know where to find each other.
     `(#:configure-flags (list (string-append "LDFLAGS=-Wl,-rpath="
                                              (assoc-ref %outputs "out")
                                              "/lib"))

       ;; Disable tests on MIPS and PowerPC (without changing
       ;; the arguments list on other systems).
       ,@(if (any (cute string-prefix? <> (or (%current-target-system)
                                              (%current-system)))
                  '("mips" "powerpc"))
             '(#:tests? #f)
             '())

       #:phases
       (modify-phases %standard-phases
         ;; No reason has been found for this test to reliably fail on aarch64-linux.
         (add-after 'unpack 'disable-failing-aarch64-tests
           (lambda _
             (substitute* "tests/Makefile.in"
               (("run-backtrace-native.sh") ""))
             #t)))))

    (native-inputs `(("m4" ,m4)))
    (inputs `(("zlib" ,zlib)))
    (home-page "https://sourceware.org/elfutils/")
    (synopsis "Collection of utilities and libraries to handle ELF files and
DWARF data")
    (description
     "Elfutils is a collection of utilities and libraries to read, create and
modify Executable and Linkable Format (@dfn{ELF}) binary files, find and
handle Debugging With Arbitrary Record Formats (@dfn{DWARF}) debug data,
symbols, thread state and stacktraces for processes and core files on
GNU/Linux.  Elfutils includes @file{libelf} for manipulating ELF files,
@file{libdw} for inspecting DWARF data and process state and utilities like
@command{eu-stack} (to show backtraces), @command{eu-nm} (for listing symbols
from object files), @command{eu-size} (for listing the section sizes of an
object or archive file), @command{eu-strip} (for discarding symbols),
@command{eu-readelf} (to see the raw ELF file structures),
@command{eu-elflint} (to check for well-formed ELF files),
@command{eu-elfcompress} (to compress or decompress ELF sections), and more.")

    ;; Libraries are dual-licensed LGPLv3.0+ | GPLv2, and programs are GPLv3+.
    (license lgpl3+)))

(define-public libabigail
  (package
    (name "libabigail")
    (home-page "https://sourceware.org/libabigail/")
    (version "1.7")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://sourceware.org/pub/libabigail/"
                                  "libabigail-" version ".tar.gz"))
              (sha256
               (base32
                "0bf8w01l6wm7mm4clfg5rqi30m1ws11qqa4bp2vxghfwgi9ai8i7"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags '("--disable-static"
                           "--enable-bash-completion"
                           "--enable-manual")
       #:make-flags '("V=1")
       #:phases (modify-phases %standard-phases
                  (add-after 'unpack 'patch-source
                    (lambda _
                      (substitute* "build-aux/ltmain.sh"
                        ;; Don't add -specs=/usr/lib/rpm/redhat/redhat-hardened-ld
                        ;; to the GCC command line.
                        (("compiler_flags=\"-specs=.*")
                         "compiler_flags=\n"))
                      #t))
                  (add-after 'build 'build-documentation
                    (lambda _
                      (invoke "make" "-C" "doc/manuals" "html-doc" "man" "info")))
                  (add-before 'check 'set-test-environment
                    (lambda _
                      (setenv "XDG_CACHE_HOME" "/tmp")
                      #t))
                  (add-after 'install 'install-documentation
                    (lambda _
                      (invoke "make" "-C" "doc/manuals"
                              "install-man-and-info-doc")))
                  (add-after 'install-documentation 'install-bash-completion
                    (lambda* (#:key outputs #:allow-other-keys)
                      (for-each (lambda (file)
                                  (install-file
                                   file (string-append (assoc-ref outputs "out")
                                                       "/share/bash-completion"
                                                       "/completions")))
                                (find-files "bash-completion" ".*abi.*"))
                      #t)))))
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("makeinfo" ,texinfo)
       ("python-sphinx" ,python-sphinx)
       ("python" ,python)))             ;for tests
    (propagated-inputs
     `(("elfutils" ,elfutils)           ;libabigail.la says -lelf
       ("libxml2" ,libxml2)))           ;in Requires.private of libabigail.pc
    (synopsis "Analyze application binary interfaces (ABIs)")
    (description
     "@dfn{ABIGAIL} stands for the Application Binary Interface Generic
Analysis and Instrumentation Library.  It is a framework which aims at
helping developers and software distributors to spot ABI-related issues
like interface incompatibility in ELF shared libraries by performing a
static analysis of the ELF binaries at hand.")
    (license lgpl3+)))

(define-public libelf
  (package
    (name "libelf")
    (version "0.8.13")
    (source
     (origin
       (method url-fetch)
       (uri (list
             ;; As of May 2019, the original URL at mr511.de redirects to a
             ;; domain that doesn't resolve.  Use these two mirrors instead.
             (string-append "https://fossies.org/linux/misc/old/"
                            "libelf-" version ".tar.gz")
             (string-append "https://ftp.osuosl.org/pub/blfs/conglomeration/"
                            "libelf/libelf-" version ".tar.gz")))
       (sha256
        (base32
         "0vf7s9dwk2xkmhb79aigqm0x0yfbw1j0b9ksm51207qwr179n6jr"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (replace 'configure
           (lambda* (#:key outputs #:allow-other-keys)
             ;; This old `configure' script doesn't support
             ;; variables passed as arguments.
             (let ((out (assoc-ref outputs "out")))
               (setenv "CONFIG_SHELL" (which "bash"))
               (invoke "./configure"
                       (string-append "--prefix=" out)
                       ,@(if (string=? "aarch64-linux"
                                       (%current-system))
                             '("--host=aarch64-unknown-linux-gnu")
                             '()))))))))
    (home-page (string-append "https://web.archive.org/web/20181111033959/"
                              "http://www.mr511.de/software/english.html"))
    (synopsis "ELF object file access library")
    (description "Libelf is a C library to access ELF object files.")
    (license lgpl2.0+)))

(define-public patchelf
  (package
    (name "patchelf")
    (version "0.10")
    (source (origin
             (method url-fetch)
             (uri (string-append
                   "https://nixos.org/releases/patchelf/patchelf-"
                   version
                   "/patchelf-" version ".tar.bz2"))
             (sha256
              (base32
               "1wzwvnlyf853hw9zgqq5522bvf8gqadk8icgqa41a5n7593csw7n"))))
    (build-system gnu-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-tests
           ;; Our GCC code ensures that RUNPATH is never empty, it includes
           ;; at least glibc/lib and gcc:lib/lib.
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* "tests/no-rpath.sh"
               ;; Disable checking for an empty runpath:
               (("^if test.*") "")
               ;; Find libgcc_s.so, which is necessary for the test:
               (("/xxxxxxxxxxxxxxx") (string-append (assoc-ref inputs "gcc:lib")
                                                    "/lib")))
             #t)))))
    (native-inputs
     `(("gcc:lib" ,gcc "lib")))
    (home-page "https://nixos.org/patchelf.html")
    (synopsis "Modify the dynamic linker and RPATH of ELF executables")
    (description
     "PatchELF allows the ELF \"interpreter\" and RPATH of an ELF binary to be
changed.")
    (license gpl3+)))

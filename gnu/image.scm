;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2020 Mathieu Othacehe <m.othacehe@gmail.com>
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

(define-module (gnu image)
  #:use-module (guix records)
  #:export (partition
            partition?
            partition-device
            partition-size
            partition-offset
            partition-file-system
            partition-file-system-options
            partition-label
            partition-uuid
            partition-flags
            partition-initializer

            image
            image-name
            image-format
            image-size
            image-operating-system
            image-partitions
            image-compression?
            image-volatile-root?
            image-substitutable?))


;;;
;;; Partition record.
;;;

(define-record-type* <partition> partition make-partition
  partition?
  (device               partition-device (default #f))
  (size                 partition-size)
  (offset               partition-offset (default 0))
  (file-system          partition-file-system (default "ext4"))
  (file-system-options  partition-file-system-options
                        (default '()))
  (label                partition-label (default #f))
  (uuid                 partition-uuid (default #f))
  (flags                partition-flags (default '()))
  (initializer          partition-initializer (default #f)))


;;;
;;; Image record.
;;;

(define-record-type* <image>
  image make-image
  image?
  (format             image-format) ;symbol
  (size               image-size  ;size in bytes as integer
                      (default 'guess))
  (operating-system   image-operating-system  ;<operating-system>
                      (default #f))
  (partitions         image-partitions ;list of <partition>
                      (default '()))
  (compression?       image-compression? ;boolean
                      (default #t))
  (volatile-root?     image-volatile-root? ;boolean
                      (default #t))
  (substitutable?     image-substitutable? ;boolean
                      (default #t)))

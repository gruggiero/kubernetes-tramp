;;; kubernetes-tramp.el --- TRAMP integration for kubernetes containers  -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Giovanni Ruggiero <giovanni.ruggiero+github@gmail.com>

;; Author: Giovanni Ruggiero <giovanni.ruggiero+github@gmail.com>
;; URL: https://github.com/gruggiero/kubernetes-tramp.el
;; Keywords: kubernetes, convenience
;; Version: 0.1
;; Package-Requires: ((emacs "24") (cl-lib "0.5"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; `kubernetes-tramp.el' offers a TRAMP method for Docker containers deployed in a Kubernetes cluster.
;;
;; > **NOTE**: `kubernetes-tramp.el' relies on the `kubectl exec` command. Tested
;; > with version 1.7.3
;;
;;
;; This project is just a minor adaptation of [*docker-tramp.el*](https://github.com/emacs-pe/docker-tramp.el)
;; to allow connections through kubernetes client.
;;
;; All the merits should go to [*Mario Rodas*](marsam@users.noreply.github.com) while the errors are just mine.
;;
;; ## Usage
;;
;; Offers the TRAMP method `kubectl` to access running containers
;;
;;     C-x C-f /kubectl:container:/path/to/file
;;
;;     where
;;       container      is the name of the container
;;
;; ## Caveats
;;
;; At the moment this tool takes for granted that the `kubectl` client is already correctly configured.
;;
;; It's not possible to pass the configuration file (or others options) to the client as a command line parameter.

;;; Code:
(eval-when-compile (require 'cl-lib))

(require 'tramp)
(require 'tramp-cache)

(defgroup kubernetes-tramp nil
  "TRAMP integration for Docker containers deployed in a kubernetes cluster."
  :prefix "kubernetes-tramp-"
  :group 'applications
  :link '(url-link :tag "Github" "https://github.com/gruggiero/kubernetes-tramp")
  :link '(emacs-commentary-link :tag "Commentary" "kubernetes-tramp"))

(defcustom kubernetes-tramp-kubectl-executable "kubectl"
  "Path to kubectl executable."
  :type 'string
  :group 'kubernetes-tramp)

;;;###autoload
(defcustom kubernetes-tramp-kubectl-options nil
  "List of kubectl options."
  :type '(repeat string)
  :group 'kubernetes-tramp)

(defcustom kubernetes-tramp-use-names nil
  "Whether use names instead of id."
  :type 'boolean
  :group 'kubernetes-tramp)

;;;###autoload
(defconst kubernetes-tramp-completion-function-alist
  '((kubernetes-tramp--parse-running-containers  ""))
  "Default list of (FUNCTION FILE) pairs to be examined for kubectl method.")

;;;###autoload
(defconst kubernetes-tramp-method "kubectl"
  "Method to connect docker containers.")

(defun kubernetes-tramp--running-containers ()
  "Collect kubernetes running containers.

Return a list of containers names"
  (cl-loop for line in (cdr (apply #'process-lines kubernetes-tramp-kubectl-executable (list "get" "po" )))
           for info = (split-string line "[[:space:]]+" t)
           collect (car info)))

(defun kubernetes-tramp--parse-running-containers (&optional ignored)
  "Return a list of (user host) tuples.

TRAMP calls this function with a filename which is IGNORED.  The
user is an empty string because the kubectl TRAMP method uses bash
to connect to the default user containers."
  (cl-loop for name in (kubernetes-tramp--running-containers)
           collect (list ""  name)))

;;;###autoload
(defun kubernetes-tramp-cleanup ()
  "Cleanup TRAMP cache for kubernetes method."
  (interactive)
  (let ((containers (apply 'append (kubernetes-tramp--running-containers))))
    (maphash (lambda (key _)
               (and (vectorp key)
                    (string-equal kubernetes-tramp-method (tramp-file-name-method key))
                    (not (member (tramp-file-name-host key) containers))
                    (remhash key tramp-cache-data)))
             tramp-cache-data))
  (setq tramp-cache-data-changed t)
  (if (zerop (hash-table-count tramp-cache-data))
      (ignore-errors (delete-file tramp-persistency-file-name))
    (tramp-dump-connection-properties)))

;;;###autoload
(defun kubernetes-tramp-add-method ()
  "Add kubectl tramp method."
  (add-to-list 'tramp-methods
               `(,kubernetes-tramp-method
                 (tramp-login-program      ,kubernetes-tramp-kubectl-executable)
                 (tramp-login-args         (,kubernetes-tramp-kubectl-options ("exec" "-it") ("-u" "%u") ("%h") ("sh")))
                 (tramp-remote-shell       "bash")
                 (tramp-remote-shell-args  ("-i" "-c")))))

;;;###autoload
(eval-after-load 'tramp
  '(progn
     (kubernetes-tramp-add-method)
     (tramp-set-completion-function kubernetes-tramp-method kubernetes-tramp-completion-function-alist)))

(provide 'kubernetes-tramp)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; kubernetes-tramp.el ends here

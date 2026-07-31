;; -*- lexical-binding: t; -*-
;;; BASE ::::::::::::::::::::::::::::::::::::::::::::::::::::
(setq server-socket-dir (expand-file-name "server" user-emacs-directory))
(setenv "EMACS_SOCKET_NAME" (expand-file-name "server" server-socket-dir))
;; Idempotent : `s-r' recharge ce fichier, et un Emacs de diagnostic peut être
;; lancé à côté de la session sans entrer en conflit avec le serveur en place.
(require 'server)
(unless (server-running-p)
  (server-start))

;;;; Emacs 29 available?
(when (< emacs-major-version 29)
  (error "Emacs Writing Studio requires version 29 or later"))

;; Synchronise le kill-ring avec le CLIPBOARD X11
(setq select-enable-clipboard t)
;; Synchronise le kill-ring avec la sélection PRIMARY X11
(setq select-enable-primary t)

;;;; Package Management
(setq use-package-always-ensure nil
      package-native-compile t
      ;; On fait taire le bruit de la compilation native, et rien d'autre :
      ;; `warning-minimum-level' garde son défaut (:warning) pour que
      ;; *Warnings* reste exploitable au diagnostic.
      native-comp-async-report-warnings-errors 'silent)

;; Mesure du démarrage, à la demande : LATECI_STATS=1 emacs …
;; puis M-x use-package-report. Aucun surcoût sinon.
(setq use-package-compute-statistics (and (getenv "LATECI_STATS") t))

(require 'use-package)
(require 'org)

;;;; Optimisation du Garbage Collector (GCMH)
(use-package gcmh
  :demand t
  :config
  (gcmh-mode 1))

;;;; Load EWS functions safely
(let ((ews-path (concat (file-name-as-directory user-emacs-directory) "ews.el")))
  (if (file-exists-p ews-path)
      (progn
        (load-file ews-path)
        ;;;; Check for missing external software
        (ews-missing-executables
         '(("gs" "mutool")
           "pdftotext"
           "soffice"
           "zip"
           "ddjvu"
           "curl"
           ("mpg321" "ogg123" "mplayer" "mpv" "vlc") 
           ("grep" "ripgrep")
           ("convert" "gm")
           "dvipng"
           "latex"
           "hunspell"
           "git")))
    (display-warning 'init "Fichier ews.el introuvable. EXWM démarre en mode dégradé (les raccourcis spécifiques EWS généreront des erreurs)." :warning)))

;; Repli, à exécuter APRÈS la tentative de chargement ci-dessus.
;; `defvar' ne fixe une valeur que si la variable est vide : si ews.el a été
;; chargé, ces deux formes sont sans effet. Sinon elles évitent une
;; `void-variable' plus bas (citar, puis org-cite au niveau supérieur), qui
;; interromprait le chargement en plein milieu du fichier et laisserait
;; courriel, gptel et comptabilité non chargés, sans aucun message.
(defvar ews-bibtex-files nil
  "Repli lorsque ews.el est absent : aucune bibliographie.")
(defvar ews-bibtex-directory nil
  "Repli lorsque ews.el est absent.")

;;;; Org-mode
(use-package org
  ;; :ensure nil — sous Guix les paquets viennent du profil, package.el n'est
  ;; pas alimenté : `:ensure t' tenterait un package-install sans archive.
  :ensure nil
  :demand t
  
  :init
  ;; Fichiers sources pour l'agenda et la capture
  (setq org-default-notes-file "~/Bureau/Notes.org")
  (setq org-agenda-files
        '("~/Bureau/Notes.org"         
          "~/Bureau/FP6.org"))

;; =======================================================
;; COMPTEURS POUR DEVIS
;; =======================================================
(defvar lateci--devis-client "")
(defvar lateci--devis-num "")
(defvar lateci--devis-tags "")
(defvar lateci--devis-counter-file (expand-file-name "devis-counter.el" user-emacs-directory))

(defun lateci--get-next-devis-num ()
  "Génère le prochain numéro de devis. Le compteur repart à 01 chaque nouvelle année."
  (let* ((current-year (format-time-string "%Y"))
         ;; Lit le fichier s'il existe, sinon initialise une paire vide
         (data (if (file-exists-p lateci--devis-counter-file)
                   (with-temp-buffer
                     (insert-file-contents lateci--devis-counter-file)
                     (read (current-buffer)))
                 '("" . 0)))
         (last-year (car data))
         (last-count (cdr data))
         (new-count (if (string= current-year last-year) (1+ last-count) 1)))
    (with-temp-file lateci--devis-counter-file
      (insert (prin1-to-string (cons current-year new-count))))
    (format "%02d" new-count)))

;; =======================================================
;; COMPTEURS POUR FACTURES
;; =======================================================
(defvar lateci--facture-client "")
(defvar lateci--facture-num "")
(defvar lateci--facture-tags "")
(defvar lateci--facture-counter-file (expand-file-name "facture-counter.el" user-emacs-directory))

(defun lateci--get-next-facture-num ()
  "Génère le prochain numéro de facture (réinitialisation annuelle)."
  (let* ((current-year (format-time-string "%Y"))
         (data (if (file-exists-p lateci--facture-counter-file)
                   (with-temp-buffer
                     (insert-file-contents lateci--facture-counter-file)
                     (read (current-buffer)))
                 '("" . 0)))
         (last-year (car data))
         (last-count (cdr data))
         (new-count (if (string= current-year last-year) (1+ last-count) 1)))
    (with-temp-file lateci--facture-counter-file
      (insert (prin1-to-string (cons current-year new-count))))
    (format "%02d" new-count)))

;; =======================================================
;; COMPTEURS POUR REÇUS
;; =======================================================
(defvar lateci--recu-client "")
(defvar lateci--recu-num "")
(defvar lateci--recu-tags "")
(defvar lateci--recu-counter-file (expand-file-name "recu-counter.el" user-emacs-directory))

(defun lateci--get-next-recu-num ()
  "Génère le prochain numéro de reçu (réinitialisation annuelle)."
  (let* ((current-year (format-time-string "%Y"))
         (data (if (file-exists-p lateci--recu-counter-file)
                   (with-temp-buffer
                     (insert-file-contents lateci--recu-counter-file)
                     (read (current-buffer)))
                 '("" . 0)))
         (last-year (car data))
         (last-count (cdr data))
         (new-count (if (string= current-year last-year) (1+ last-count) 1)))
    (with-temp-file lateci--recu-counter-file
      (insert (prin1-to-string (cons current-year new-count))))
    (format "%02d" new-count)))
  
  :custom
  ;; --- Apparence et Rendu ---
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-startup-with-inline-images t)
  (org-image-actual-width '(450))
  (org-pretty-entities t)
  (org-use-sub-superscripts "{}")
  (org-id-link-to-org-use-id t)
  (org-fold-catch-invisible-edits 'show)
  
  ;; --- Exportation ---
  (org-export-with-drawers nil)
  (org-export-with-todo-keywords nil)
  (org-export-with-toc nil)
  (org-export-with-smart-quotes t)
  (org-export-date-timestamp-format "%e %B %Y")
  
  ;; --- Esthétique de l'Agenda ---
  (org-agenda-window-setup 'current-window)
  (org-agenda-block-separator ?─)
  (org-agenda-tags-column 0)
  (org-agenda-current-time-string "◄── MAINTENANT")
  (org-agenda-time-grid
   '((daily today require-timed)
     (800 1000 1200 1400 1600 1800 2000)
     " ┄┄┄┄┄ " "──────────────"))
  (org-agenda-prefix-format '(
			      (agenda . " %i %?-12t% s")
			      (todo   . " %i ")
			      (tags   . " %i ")
			      (search . " %i ")))
  
  ;; --- Commandes et États (Workflow) ---
  (org-agenda-custom-commands
   '(("e" "Agenda, next actions and waiting"
      ((agenda "" ((org-agenda-overriding-header "Next three days:")
                   (org-agenda-span 3)
                   (org-agenda-start-on-weekday nil)))
       (todo "NEXT" ((org-agenda-overriding-header "Next Actions:")))
       (todo "WAIT" ((org-agenda-overriding-header "Waiting:")))))))
  (org-todo-keywords
   '((sequence "TODO(t)" "WAIT(w)" "NEXT(n)" "RU(R)" "RDV(r)" "PRATOS(p)" "EVNT(e)" "|" "DONE(d)" "CANCELLED(c)")))
  
  ;;;; --- Modèles de Capture ---
  (org-capture-templates
   '(("f" "Fleeting note" item (file+headline org-default-notes-file "Notes") "- %?")
     ("j" "Journal Interstitiel" entry (file denote-journal-path-to-new-or-existing-entry) "* %<%H:%M>\n** DONE %?\n** NEXT " :empty-lines 1)
     ("n" "Permanent note" plain (file denote-last-path) #'denote-org-capture :no-save t :immediate-finish nil :kill-buffer t :jump-to-captured t)
     ("i" "NEXT" entry (file+headline org-default-notes-file "Tasks") "* NEXT %i%?")
     ("t" "TODO" entry (file+headline org-default-notes-file "Tasks") "* TODO %i%?")
     ("R" "RU" entry (file+headline org-default-notes-file "Tasks") "* RU %i%?")
     ("r" "RDV" entry (file+headline org-default-notes-file "Tasks") "* RDV %i%?")
     ("p" "PRATOS" entry (file+headline org-default-notes-file "Tasks") "* PRATOS %i%?")
     ("e" "EVNT" entry (file+headline org-default-notes-file "Tasks") "* EVNT %i%?")

     ;; ------------------------------------------------------
     ;; MODÈLE DEVIS
     ;; ------------------------------------------------------     
     ("d" "DEVIS" plain
      (file (lambda ()
              (setq lateci--devis-client (read-string "Nom du client : "))              
              (let ((user-tags (read-string "Tags additionnels (optionnels, ex: asso formation) : ")))
                (setq lateci--devis-tags (if (string-empty-p user-tags)
                                             "devis"
                                           (concat "devis_" (replace-regexp-in-string "[^[:alnum:]]+" "_" (downcase user-tags))))))              
              (setq lateci--devis-num (lateci--get-next-devis-num))
              (let* ((time-str (format-time-string "%Y%m%dT%H%M%S"))
                     (client-slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase lateci--devis-client)))
                     (filename (format "%s--%s-%s__%s.org" time-str client-slug lateci--devis-num lateci--devis-tags)))
                (expand-file-name filename "~/Bureau/"))))
      "#+TITLE: DEVIS %<%Y%m%d>-%(identity lateci--devis-num)
#+AUTHOR: LA TECI
#+OPTIONS: num:nil title:nil toc:nil
#+LATEX_CLASS: article
#+LATEX_CLASS_OPTIONS: [11pt, a4paper]
#+LATEX_HEADER: \\usepackage[margin=2cm]{geometry}
#+LATEX_HEADER: \\usepackage{graphicx}
#+LATEX_HEADER: \\usepackage{xcolor}
#+LATEX_HEADER: \\definecolor{lateciblue}{RGB}{40, 80, 120} % Couleur institutionnelle
#+LATEX_HEADER: \\pagestyle{empty} % Suppression de la numérotation des pages

#+BEGIN_EXPORT latex
% --------------------------------------------------------
% EN-TÊTE
% --------------------------------------------------------
\\begin{minipage}[t]{0.5\\textwidth}
  \\vspace{-1cm} % Alignement vertical
  \\includegraphics[width=4cm]{/home/thomas_rm/Bureau/logo.jpg} \\\\[0.5em] % <-- DÉCOMMENTER POUR LE LOGO
  {\\LARGE \\textbf{\\textcolor{lateciblue}{LA TECI}}} \\\\[0.5em]
  9bis Chemin des Tillières \\\\
  41000 BLOIS \\\\[0.5em]
  lateci@club1.fr \\\\
  https://lateci.club1.fr
\\end{minipage}%
\\begin{minipage}[t]{0.5\\textwidth}
  \\begin{flushright}
    \\vspace{-1cm}
    {\\Huge \\textbf{\\textcolor{lateciblue}{DEVIS}}} \\\\[0.5em]
    \\textbf{Numéro :} %<%Y%m%d>-%(identity lateci--devis-num) \\\\
    \\textbf{Date :} %<%d %B %Y> \\\\[1.5em]
    % Boîte d'adresse du destinataire
    \\colorbox{gray!10}{
      \\begin{minipage}{0.8\\textwidth}
        \\vspace{0.2cm}
        \\textbf{Destinataire} \\\\
        \\textbf{%(identity lateci--devis-client)} \\\\
        %^{Adresse du Client}
        \\vspace{0.2cm}
      \\end{minipage}
    }
  \\end{flushright}
\\end{minipage}

\\vspace{1.5cm}
#+END_EXPORT

* Objet : %^{Objet du devis}

#+ATTR_LATEX: :align p{8.5cm} c r r :placement [h]
| Description de la prestation | Qté | Prix U. (HT) | Total (HT) |
|------------------------------+-----+--------------+------------|
| %?                           |   1 |            0 |          0 |
|------------------------------+-----+--------------+------------|
| *TOTAL*                      |     |              |          0 |
#+TBLFM: $4=$2*$3::@3$4=vsum(@2$4..@-1$4);%.2f

#+BEGIN_EXPORT latex
\\vspace{1cm}
\\rule{\\textwidth}{0.4pt}
\\vspace{0.5cm}

% --------------------------------------------------------
% PIED DE DOCUMENT
% --------------------------------------------------------
\\noindent
\\begin{minipage}[t]{0.45\\textwidth}
  \\small
  \\textbf{Conditions de paiement} \\\\[0.2em]
  Délai de paiement : 30 jours à date d'émission. \\\\
  Règlement par Chèque ou virement bancaire. \\\\
  Escompte pour règlement anticipé : 0\\textpercent{\%} \\\\
  \\\\
  TVA non applicable art. 293b du CGI. \\\\
  \\\\
  En cas de retard de paiement, une pénalité égale à 3 fois le taux d'intérêt légal sera exigible \\\\
  \\texttt{\\textit{Décret 2009-138 du 9 février 2009}} \\\\
  \\\\
  Pour les professionnels, une indemnité minimum forfaitaire de 40 euros pour frais de recouvrement sera exigible \\\\
  \\texttt{\\textit{Décret 2012-1115 du 9 octobre 2012}}

\\end{minipage}%
\\hfill
\\begin{minipage}[t]{0.45\\textwidth}
  \\small
  \\textbf{Coordonnées bancaires} \\\\[0.2em]
  Association Terrain d'Expérimentation de Créations \\& d'Initiatives \\\\
  SIRET : 94386876000019 | APE : 94.99Z \\\\
  IBAN : \\texttt{FR76 1027 8371 6000 0132 5090 255} \\\\
  BIC : \\texttt{CMCIFR2A}
\\end{minipage}

\\vspace{2cm}

% --------------------------------------------------------
% ZONE DE SIGNATURE
% --------------------------------------------------------
\\hfill
\\begin{minipage}[t]{0.45\\textwidth}
  \\centering
  \\textbf{Bon pour accord} \\\\
  \\textit{Date, signature et cachet du client} \\\\[2.5cm]
  \\rule{6cm}{0.4pt}
\\end{minipage}
#+END_EXPORT
"
      :jump-to-captured t)

     ;; ------------------------------------------------------
     ;; MODÈLE FACTURE
     ;; ------------------------------------------------------
     ("F" "FACTURE" plain
      (file (lambda ()
              (setq lateci--facture-client (read-string "Nom du client : "))
              
              (let ((user-tags (read-string "Tags additionnels (optionnels) : ")))
                (setq lateci--facture-tags (if (string-empty-p user-tags)
                                           "facture"
                                         (concat "facture_" (replace-regexp-in-string "[^[:alnum:]]+" "_" (downcase user-tags))))))
              
              (setq lateci--facture-num (lateci--get-next-facture-num))
              (let* ((time-str (format-time-string "%Y%m%dT%H%M%S"))
                     (client-slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase lateci--facture-client)))
                     (filename (format "%s--%s-%s__%s.org" time-str client-slug lateci--facture-num lateci--facture-tags)))
                (expand-file-name filename "~/Bureau/"))))
      "#+TITLE: FACTURE %<%Y%m%d>-%(identity lateci--facture-num)
#+AUTHOR: LA TECI
#+OPTIONS: num:nil title:nil toc:nil
#+LATEX_CLASS: article
#+LATEX_CLASS_OPTIONS: [11pt, a4paper]
#+LATEX_HEADER: \\usepackage[margin=2cm]{geometry}
#+LATEX_HEADER: \\usepackage{graphicx}
#+LATEX_HEADER: \\usepackage{xcolor}
#+LATEX_HEADER: \\definecolor{lateciblue}{RGB}{40, 80, 120} % Couleur institutionnelle
#+LATEX_HEADER: \\pagestyle{empty} % Suppression de la numérotation des pages

#+BEGIN_EXPORT latex
% --------------------------------------------------------
% EN-TÊTE
% --------------------------------------------------------
\\begin{minipage}[t]{0.5\\textwidth}
  \\vspace{-1cm} % Alignement vertical
  \\includegraphics[width=4cm]{/home/thomas_rm/Bureau/logo.jpg} \\\\[0.5em] % <-- DÉCOMMENTER POUR LE LOGO
  {\\LARGE \\textbf{\\textcolor{lateciblue}{LA TECI}}} \\\\[0.5em]
  9bis Chemin des Tillières \\\\
  41000 BLOIS \\\\[0.5em]
  lateci@club1.fr \\\\
  https://lateci.club1.fr
\\end{minipage}%
\\begin{minipage}[t]{0.5\\textwidth}
  \\begin{flushright}
    \\vspace{-1cm}
    {\\Huge \\textbf{\\textcolor{lateciblue}{FACTURE}}} \\\\[0.5em]
    \\textbf{Numéro :} %<%Y%m%d>-%(identity lateci--facture-num) \\\\
    \\textbf{Date :} %<%d %B %Y> \\\\[1.5em]
    % Boîte d'adresse du destinataire
    \\colorbox{gray!10}{
      \\begin{minipage}{0.8\\textwidth}
        \\vspace{0.2cm}
        \\textbf{Destinataire} \\\\
        \\textbf{%(identity lateci--facture-client)} \\\\
        %^{Adresse du Client}
        \\vspace{0.2cm}
      \\end{minipage}
    }
  \\end{flushright}
\\end{minipage}

\\vspace{1.5cm}
#+END_EXPORT

* Objet : %^{Objet de la facture}

#+ATTR_LATEX: :align p{8.5cm} c r r :placement [h]
| Description de la prestation | Qté | Prix U. (HT) | Total (HT) |
|------------------------------+-----+--------------+------------|
| %?                           |   1 |            0 |          0 |
|------------------------------+-----+--------------+------------|
| *TOTAL*                      |     |              |          0 |
#+TBLFM: $4=$2*$3;N :: @>$4=vsum(@I..@II);%.2f

#+BEGIN_EXPORT latex
\\vspace{1cm}
\\rule{\\textwidth}{0.4pt}
\\vspace{0.5cm}

% --------------------------------------------------------
% PIED DE DOCUMENT
% --------------------------------------------------------
\\noindent
\\begin{minipage}[t]{0.45\\textwidth}
  \\small
  \\textbf{Conditions de paiement} \\\\[0.2em]
  Délai de paiement : 30 jours à date d'émission. \\\\
  Règlement par Chèque ou virement bancaire. \\\\
  Escompte pour règlement anticipé : 0\\textpercent{\%} \\\\
  \\\\
  TVA non applicable art. 293b du CGI. \\\\
  \\\\
  En cas de retard de paiement, une pénalité égale à 3 fois le taux d'intérêt légal sera exigible \\\\
  \\texttt{\\textit{Décret 2009-138 du 9 février 2009}} \\\\
  \\\\
  Pour les professionnels, une indemnité minimum forfaitaire de 40 euros pour frais de recouvrement sera exigible \\\\
  \\texttt{\\textit{Décret 2012-1115 du 9 octobre 2012}}
\\end{minipage}%
\\hfill
\\begin{minipage}[t]{0.45\\textwidth}
  \\small
  \\textbf{Coordonnées bancaires} \\\\[0.2em]
  Association Terrain d'Expérimentation de Créations \\& d'Initiatives \\\\
  SIRET : 94386876000019 | APE : 94.99Z \\\\
  IBAN : \\texttt{FR76 1027 8371 6000 0132 5090 255} \\\\
  BIC : \\texttt{CMCIFR2A}
\\end{minipage}

\\vspace{2cm}

% --------------------------------------------------------
% ZONE DE SIGNATURE
% --------------------------------------------------------
\\hfill
\\begin{minipage}[t]{0.45\\textwidth}
  \\centering
  \\textit{Cachet et signature de l'association} \\\\[2.5cm]
  \\rule{6cm}{0.4pt}
\\end{minipage}
#+END_EXPORT
"
      :jump-to-captured t)
     
     ;; ------------------------------------------------------
     ;; MODÈLE REÇU
     ;; ------------------------------------------------------
     ("u" "REÇU" plain
      (file (lambda ()
              (setq lateci--recu-client (read-string "Nom du payeur : "))
              (let ((user-tags (read-string "Tags additionnels (optionnels) : ")))
                (setq lateci--recu-tags (if (string-empty-p user-tags) "recu"
                                           (concat "recu_" (replace-regexp-in-string "[^[:alnum:]]+" "_" (downcase user-tags))))))
              (setq lateci--recu-num (lateci--get-next-recu-num))
              (let* ((time-str (format-time-string "%Y%m%dT%H%M%S"))
                     (client-slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase lateci--recu-client)))
                     (filename (format "%s--%s-%s__%s.org" time-str client-slug lateci--recu-num lateci--recu-tags)))
                (expand-file-name filename "~/Bureau/"))))
      "#+TITLE: REÇU %<%Y%m%d>-%(identity lateci--recu-num)
#+AUTHOR: LA TECI
#+OPTIONS: num:nil title:nil toc:nil
#+LATEX_CLASS: article
#+LATEX_CLASS_OPTIONS: [11pt, a4paper]
#+LATEX_HEADER: \\usepackage[margin=2cm]{geometry}
#+LATEX_HEADER: \\usepackage{ebgaramond}
#+LATEX_HEADER: \\usepackage{graphicx}
#+LATEX_HEADER: \\pagestyle{empty}

#+BEGIN_EXPORT latex
% --------------------------------------------------------
% EN-TÊTE
% --------------------------------------------------------
\\begin{minipage}[t]{0.5\\textwidth}
  \\vspace{-1cm}
  {\\LARGE \\textbf{LA TECI}} \\\\[0.5em]
  9bis Chemin des Tillières \\\\
  41000 BLOIS \\\\[0.5em]
  lateci@club1.fr \\\\
  https://lateci.club1.fr
\\end{minipage}%
\\begin{minipage}[t]{0.5\\textwidth}
  \\begin{flushright}
    \\vspace{-1cm}
    {\\Huge \\textbf{REÇU}} \\\\[0.5em]
    \\textbf{Numéro :} %<%Y%m%d>-%(identity lateci--recu-num) \\\\
    \\textbf{Date :} %<%d %B %Y> \\\\[1.5em]
    \\fbox{
      \\begin{minipage}{0.8\\textwidth}
        \\vspace{0.2cm}
        \\textbf{Payeur :} \\\\
        \\textbf{%(identity lateci--recu-client)} \\\\
        %^{Adresse du Client}
        \\vspace{0.2cm}
      \\end{minipage}
    }
  \\end{flushright}
\\end{minipage}

\\vspace{1.5cm}
#+END_EXPORT

* Objet : %^{Nature du paiement (ex: Adhésion, Don)}

#+ATTR_LATEX: :align p{8.5cm} c r r :placement [h]
| Description                                  | Qté | Prix U. (HT) | Total (HT) |
|----------------------------------------------+-----+--------------+------------|
| %?                                           |   1 |            0 |          0 |
|----------------------------------------------+-----+--------------+------------|
| *TOTAL RÉGLÉ*                                |     |              |          0 |
#+TBLFM: $4=$2*$3;N :: @>$4=vsum(@I..@II);%.2f

#+BEGIN_EXPORT latex
\\vspace{1cm}
\\rule{\\textwidth}{0.4pt}
\\vspace{0.5cm}
% --------------------------------------------------------
% PIED DE DOCUMENT
% --------------------------------------------------------
\\noindent
\\begin{minipage}[t]{0.45\\textwidth}
  \\small
  \\textbf{Détail du règlement} \\\\[0.2em]
  Reçu le : %^{Date de règlement (ex:%<%d %B %Y>)} \\\\
  Moyen de paiement : %^{Moyen de paiement (ex: Chèque, Virement, Espèces)} \\\\
  \\textit{Ce document atteste la bonne réception des fonds pour solde de tout compte.}
\\end{minipage}%
\\hfill
\\begin{minipage}[t]{0.45\\textwidth}
  \\small
  \\textbf{Identifiant association} \\\\[0.2em]
  Association Terrain d'Expérimentation de Créations \\& d'Initiatives \\\\
  SIRET : 94386876000019 | APE : 94.99Z \\\\
\\end{minipage}

\\vspace{2cm}

% --------------------------------------------------------
% ZONE DE SIGNATURE
% --------------------------------------------------------
\\hfill
\\begin{minipage}[t]{0.45\\textwidth}
  \\centering
  \\textit{Pour acquit, signature du trésorier/représentant} \\\\[2.5cm]
  \\rule{6cm}{0.4pt}
\\end{minipage}
#+END_EXPORT
"
      :jump-to-captured t)))

  
  :bind
  ;; --- Raccourcis Globaux ---
  (("C-c c" . org-capture)
   ("C-c l" . org-store-link)
   ("C-c a" . org-agenda)
   ("C-c A" . (lambda () (interactive) (org-agenda nil "e")))
   ;; --- Raccourcis Spécifiques au Mode ---
   :map org-mode-map
   ("C-c w n" . ews-org-insert-notes-drawer)
   ("C-c w p" . ews-org-insert-screenshot)
   ("C-c w c" . ews-org-count-words)))

;;; LOOK AND FEEL :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

(setq ring-bell-function 'ignore)

;;;; Modus and EF Themes
(use-package modus-themes
  :ensure nil
  :init
  ;; copy-sequence : `disable-theme' retire l'élément de `custom-enabled-themes'
  ;; au fil de l'itération, ce qui ferait sauter un thème sur deux au rechargement.
  (mapc #'disable-theme (copy-sequence custom-enabled-themes))
  (load-theme 'modus-operandi t)
  
  :custom
  (modus-themes-italic-constructs t)
  (modus-themes-bold-constructs t)
  (modus-themes-mixed-fonts t)
  (modus-themes-to-toggle '(modus-operandi
			    modus-vivendi))
  :bind
  (("C-c w t t" . modus-themes-toggle)
   ("C-c w t m" . modus-themes-select)
   ("C-c w t s" . consult-theme)))

(setq inhibit-splash-screen t)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)

(set-fringe-mode 0) ;; Supprime les bandes grises sur les bords de l'écran

;; Marge globale autour de l'écran (remplace 15 par 0 si tu ne veux AUCUN espace avec les bords de l'écran)
;;(add-to-list 'default-frame-alist '(internal-border-width . 15))
;;(modify-all-frames-parameters '((internal-border-width . 15)))

;; Activer des espaces vides entre les fenêtres
(setq window-divider-default-right-width 10   ;; Espace vertical entre fenêtres côte à côte
      window-divider-default-bottom-width 10) ;; Espace horizontal entre fenêtres superposées
(window-divider-mode 1)

;;;; RETOUCHES DE FACES ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;;
;; `set-face-attribute' modifie une face directement, en dehors de tout thème.
;; Or `enable-theme' recalcule chaque face à partir de sa spécification, ce qui
;; efface ces retouches — y compris les attributs que le thème ne touche pas,
;; comme la taille de police. Sans le crochet installé plus bas, tout ce bloc
;; était donc perdu au premier `C-c w t t' : police rétrécie, séparateurs
;; redevenus visibles, modeline inactive au fond clair sur thème sombre,
;; hiérarchie des titres Org aplatie.
;;
;; Les couleurs sont relues à chaque passage (`fond' ci-dessous), et le
;; calendrier hérite de faces sémantiques plutôt que de couleurs littérales :
;; l'ensemble suit donc le thème actif, clair comme sombre.

(defun lateci--set-face (face &rest attributs)
  "Applique ATTRIBUTS à FACE, si FACE existe.
La garde évite d'échouer sur les faces d'un paquet non encore chargé."
  (when (facep face)
    (apply #'set-face-attribute face nil attributs)))

(defun lateci/appliquer-faces (&rest _)
  "Applique les retouches de faces propres à cette configuration.
Rejouée à chaque activation de thème via `enable-theme-functions'."
  (let ((fond (face-attribute 'default :background)))

    ;; --- Taille de police globale ---
    (lateci--set-face 'default :height 120)

    ;; --- Séparateurs fondus dans le fond ---
    ;; Pour une ligne fine visible, remplacer `fond' par "grey50".
    (lateci--set-face 'vertical-border :foreground fond)
    (lateci--set-face 'internal-border :background fond)
    (dolist (face '(window-divider
                    window-divider-first-pixel
                    window-divider-last-pixel))
      (lateci--set-face face :foreground fond))

    ;; --- Modeline ---
    ;; mode-line-active est le paramètre distinct d'Emacs 29+ ; mode-line reste
    ;; réglée pour les faces qui en héritent.
    (lateci--set-face 'mode-line :height 0.90)
    (lateci--set-face 'mode-line-active :height 0.90)
    ;; Modeline inactive masquée : texte et fond à la couleur du fond d'Emacs.
    (lateci--set-face 'mode-line-inactive
                      :foreground fond
                      :background fond
                      :box nil
                      :overline nil
                      :underline nil)

    ;; --- Org : hiérarchie des titres ---
    (lateci--set-face 'org-document-title :height 1.5  :weight 'bold)
    (lateci--set-face 'org-level-1        :height 1.3  :weight 'bold)
    (lateci--set-face 'org-level-2        :height 1.2  :weight 'bold)
    (lateci--set-face 'org-level-3        :height 1.1  :weight 'semi-bold)
    (lateci--set-face 'org-level-4        :height 1.05)
    (lateci--set-face 'org-level-5        :height 1.0)
    (lateci--set-face 'org-level-6        :height 1.0)

    ;; --- Org : étiquettes et horodatages ---
    (lateci--set-face 'org-tag
                      :box '(:line-width 1 :color "grey50")
                      :height 0.8
                      :weight 'normal)
    (lateci--set-face 'org-date
                      :box '(:line-width 1 :color "grey70")
                      :underline nil)

    ;; --- Calendrier ---
    ;; `:inherit' de faces sémantiques (highlight, error, success) plutôt que
    ;; des couleurs littérales : elles suivent le thème. L'ancienne version
    ;; codait « white sur dark blue » et « firebrick », illisibles en sombre.
    (lateci--set-face 'calendar-today :inherit 'highlight :weight 'bold)
    (lateci--set-face 'calendar-weekend-header :inherit 'error)
    (lateci--set-face 'calendar-month-header :weight 'bold :height 1.2)
    (lateci--set-face 'diary :inherit 'success :weight 'bold)))

;; Rejouée à chaque activation de thème (Emacs 29+).
(add-hook 'enable-theme-functions #'lateci/appliquer-faces)

;; Les faces du calendrier n'existent qu'une fois leur paquet chargé : on
;; rejoue alors la fonction pour qu'elles ne soient pas laissées de côté.
(with-eval-after-load 'calendar (lateci/appliquer-faces))
(with-eval-after-load 'diary-lib (lateci/appliquer-faces))

;; Application initiale : le thème est chargé plus haut.
(lateci/appliquer-faces)

;;;; Short answers only please
(setq-default use-short-answers t)

;;;; Scratch buffer settings
(setq inhibit-startup-screen t)
(setq initial-buffer-choice (lambda () (get-buffer "*Messages*")))

;; Fonctions nommées plutôt que lambdas anonymes : `add-hook' peut alors
;; reconnaître une entrée déjà présente et ne pas l'empiler à chaque `s-r'.
(defun lateci--tuer-scratch ()
  "Supprime le tampon *scratch* au démarrage."
  (when (get-buffer "*scratch*")
    (kill-buffer "*scratch*")))

(add-hook 'emacs-startup-hook #'lateci--tuer-scratch)

(defun lateci--garder-un-tampon ()
  "Bascule sur *Messages* lorsque le dernier tampon visible est tué."
  (unless (seq-some (lambda (buf)
                      (let ((name (buffer-name buf)))
                        (and (not (string-prefix-p " " name))
                             (not (eq buf (current-buffer))))))
                    (buffer-list))
    (switch-to-buffer "*Messages*")))

(add-hook 'kill-buffer-hook #'lateci--garder-un-tampon)

;;;; Mixed-pitch mode
(use-package mixed-pitch
  :hook
  (org-mode . mixed-pitch-mode))

;;;; Window management
;;;;; Split windows sensibly
(setq split-width-threshold 120
      split-height-threshold nil)

(use-package consult
  :bind
  (("C-c w h" . consult-org-heading)
   ("C-c w g" . consult-grep)
   ("C-x b"   . consult-buffer)) ;; Remplace le switch-to-buffer par défaut
  :config
  (add-to-list 'consult-preview-allowed-hooks 'visual-line-mode)
  
  ;; --- Catégorie dédiée pour les applications X11 (EXWM) ---
  (defvar lateci-consult--source-exwm
    `(:name "Applications X11"
      :narrow ?x
      :category buffer
      :state ,#'consult--buffer-state
      :items ,(lambda ()
                (let (exwm-bufs)
                  (dolist (buf (buffer-list))
                    (with-current-buffer buf
                      (when (eq major-mode 'exwm-mode)
                        (push (buffer-name buf) exwm-bufs))))
                  exwm-bufs))))
  (add-to-list 'consult-buffer-sources 'lateci-consult--source-exwm 'append))

;; Outline-minor-mode
(setq outline-minor-mode-cycle t)

;;;; MINIBUFFER COMPLETION :::::::::::::::
;;;;; Enable vertico
(use-package vertico
  :init
  (vertico-mode)
  :custom
  (vertico-sort-function 'vertico-sort-history-alpha))

;;;;; Persist history over Emacs restarts.
(use-package savehist
  :init
  (savehist-mode))

;;;;; Search for partial matches in any order
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles partial-completion)))))

;;;;; Enable richer annotations using the Marginalia package
(use-package marginalia
  :init
  (marginalia-mode))

;;;;; Improve keyboard shortcut discoverability
(use-package which-key
  :ensure nil
  :config
  (which-key-mode)
  :custom
  (which-key-max-description-length 40)
  (which-key-lighter nil)
  (which-key-sort-order 'which-key-description-order)
  :init
  (which-key-add-key-based-replacements
    "C-c w"   "Emacs Writing Studio"
    "C-c w b" "Bibliographic"
    "C-c w d" "Denote"
    "C-c w m" "Multimedia"
    "C-c w s" "Spelling and Grammar"
    "C-c w t" "Themes"
    "C-c w x" "Explore"))

;;;;; Contextual menu with right mouse button
(when (display-graphic-p)
  (context-menu-mode))

;; Improved help buffers
(use-package helpful
  :bind
  (("C-h f" . helpful-function)
   ("C-h x" . helpful-command)
   ("C-h k" . helpful-key)
   ("C-h v" . helpful-variable)))

;; Text mode settings
(use-package text-mode
  :ensure
  nil
  :hook
  (text-mode . visual-line-mode)
  :init
  (delete-selection-mode t)
  :custom
  (sentence-end-double-space nil)
  (scroll-error-top-bottom t)
  (save-interprogram-paste-before-kill t))

;; Check spelling with flyspell and hunspell
;; Exemple : tu veux juste le dico français "fr-toutesvariantes"
(setq ews-hunspell-dictionaries "fr-toutesvariantes")

(use-package flyspell
  :ensure nil
  :init
  ;; Forcer le chemin du dictionnaire Guix pour le processus Hunspell
  (setenv "DICPATH" (expand-file-name "~/.guix-home/profile/share/hunspell"))
  :custom
  (ispell-program-name "hunspell")
  (ispell-dictionary "fr-toutesvariantes")
  (flyspell-mark-duplications-flag nil)
  (org-fold-core-style 'overlays)
  :config
  ;; Déclarer explicitement le fichier d'affixes à Emacs
  (add-to-list 'ispell-local-dictionary-alist
               '("fr-toutesvariantes" "[[:alpha:]]" "[^[:alpha:]]" "[']" nil ("-d" "fr-toutesvariantes") nil utf-8))
  (add-to-list 'ispell-hunspell-dict-paths-alist
               '("fr-toutesvariantes" "~/.guix-home/profile/share/hunspell/fr-toutesvariantes.aff"))
               
  (ispell-set-spellchecker-params)
  (ispell-hunspell-add-multi-dic ews-hunspell-dictionaries)
  :hook
  (text-mode . flyspell-mode)
  :bind
  (("C-c w s s" . ispell)
   ("C-;"       . flyspell-auto-correct-previous-word)))

;; LaTeX previews
(use-package org-fragtog
  :after org
  :hook
  (org-mode . org-fragtog-mode)
  :custom
  (org-startup-with-latex-preview nil)
  :config
  ;; `:custom' attend (VARIABLE VALEUR [COMMENTAIRE]) : au-delà du 3e élément
  ;; tout est ignoré. Les trois plist-put y étaient donc lus comme
  ;; « valeur + commentaire + rebut », et seul :scale était appliqué —
  ;; les aperçus LaTeX gardaient des couleurs fixes en thème sombre.
  (setq org-format-latex-options (plist-put org-format-latex-options :scale 2))
  (setq org-format-latex-options (plist-put org-format-latex-options :foreground 'auto))
  (setq org-format-latex-options (plist-put org-format-latex-options :background 'auto)))

;; Les tailles des titres Org, org-tag et org-date sont réglées par
;; `lateci/appliquer-faces' (section RETOUCHES DE FACES), afin d'être
;; réappliquées à chaque changement de thème.

(with-eval-after-load 'org
  ;; Les mots-clés TODO en mode "bouton".
  ;; `org-todo-keyword-faces' est une variable, pas une face : son contenu
  ;; survit au changement de thème, d'où son maintien ici.
  (setq org-todo-keyword-faces
        '(("TODO"   . (:foreground "firebrick"   :weight bold :box (:line-width 1 :style released-button)))
          ("NEXT"   . (:foreground "royalblue"   :weight bold :box (:line-width 1 :style released-button)))
          ("WAIT"   . (:foreground "dark orange" :weight bold :box (:line-width 1 :style released-button)))
          ("RU"     . (:foreground "magenta"     :weight bold :box (:line-width 1 :style released-button)))
          ("RDV"    . (:foreground "purple"      :weight bold :box (:line-width 1 :style released-button)))
          ("PRATOS" . (:foreground "dark cyan"   :weight bold :box (:line-width 1 :style released-button)))
          ("EVNT"   . (:foreground "goldenrod"   :weight bold :box (:line-width 1 :style released-button)))
          ("DONE"   . (:foreground "forest green" :weight bold :strike-through t))
          ("CANCELLED" . (:foreground "grey"     :weight bold :strike-through t)))))


;;;; MODELINE
(dolist (buf-name '(" *Echo Area 0*" " *Echo Area 1*"))
  (with-current-buffer (get-buffer-create buf-name)
    ;; 1. On efface tout redimensionnement précédent
    (setq-local face-remapping-alist nil)
    ;; 2. On applique la réduction de manière fixe
    (face-remap-add-relative 'default :height 0.90)))

;; Les faces mode-line, mode-line-active et mode-line-inactive sont réglées par
;; `lateci/appliquer-faces' (section RETOUCHES DE FACES) : leur couleur dépend
;; du fond, qui change avec le thème.

(use-package time
  :ensure nil
  :config
  ;; Format demandé : [mar. 10 | 12:21]
  (setq display-time-format "[%a%d | %H:%M]")
  (setq display-time-default-load-average nil)
  (display-time-mode 1))

(use-package battery
  :ensure nil
  :config
  (setq battery-mode-line-format "[%b%p%%] ")
  (display-battery-mode 1))

;; Position compacte avec pied-de-mouche
(setq-default mode-line-position '("%p¶%l"))

;;;;; Modeline unifiée (Réseau, SSH, Hydroxide, GPG, Syncthing) 
(defvar lateci--reseau-online nil)
(defvar lateci--gpg-unlocked nil)
(defvar lateci--ssh-mounted nil)
(defvar lateci--syncthing-online nil)
(defvar lateci--hydroxide-online nil)
(defvar lateci--system-status-string " ")

(or global-mode-string (setq global-mode-string '("")))
(unless (memq 'lateci--system-status-string global-mode-string)
  (setq global-mode-string (append global-mode-string '(lateci--system-status-string))))

(defun lateci--actualiser-affichage ()
  "Génère le texte compact et force la mise à jour visuelle."
  (let ((symboles (delq nil (list (when lateci--gpg-unlocked "gpg")
                                  (when lateci--reseau-online "net")
                                  (when lateci--ssh-mounted "srv")
                                  (when lateci--syncthing-online "lan")
                                  (when lateci--hydroxide-online "eml"))))) ; <-- Modifié ici
    (setq lateci--system-status-string
          (if symboles
              (format "[%s] " (mapconcat 'identity symboles " "))
            " "))
    (force-mode-line-update t)))

(defun lateci--network-online-p ()
  "Vérifie localement si une route par défaut active existe (sans envoyer de paquets)."
  (let ((route-file "/proc/net/route"))
    (and (file-exists-p route-file)
         (with-temp-buffer
           (insert-file-contents route-file)
           (goto-char (point-min))
           ;; Cherche '00000000' dans la colonne Destination (indique la passerelle par défaut)
           (not (null (re-search-forward "^[a-z0-9]+\\s-+00000000\\s-+" nil t)))))))

(defun lateci--monte-p (point-de-montage)
  "Vrai si POINT-DE-MONTAGE figure dans /proc/mounts.
Lecture en Lisp pur, sans lancer de processus — même approche que
`lateci--network-online-p'."
  (let ((chemin (directory-file-name (expand-file-name point-de-montage))))
    (and (file-exists-p "/proc/mounts")
         (with-temp-buffer
           (insert-file-contents "/proc/mounts")
           (goto-char (point-min))
           ;; Chaque ligne : périphérique, point de montage, type, options…
           ;; Le noyau échappe les espaces du chemin en \040.
           (and (search-forward
                 (concat " " (string-replace " " "\\040" chemin) " ")
                 nil t)
                t)))))

(defun lateci--verifier-systeme ()
  "Moteur de vérification principal, asynchrone."
  ;; 1. GPG Async
  (setq lateci--gpg-unlocked nil)
  (make-process
   :name "gpg-check" :buffer nil :noquery t
   :command '("gpg-connect-agent" "keyinfo --list" "/bye")
   :filter (lambda (_proc output)
             (when (string-match-p "KEYINFO .*\\b1\\b" output)
               (setq lateci--gpg-unlocked t)))
   :sentinel (lambda (_proc _event) (lateci--actualiser-affichage)))

  ;; 2. Montage distant — lu dans /proc/mounts, sans lancer de processus.
  (setq lateci--ssh-mounted (lateci--monte-p "~/Club1"))

  ;; 3. Réseau — lu dans /proc/net/route, sans lancer de processus.
  (setq lateci--reseau-online (lateci--network-online-p))

  ;; 4. Syncthing Async
  (make-process
   :name "syncthing-check" :buffer nil :noquery t
   :command '("pgrep" "-x" "syncthing")
   :sentinel (lambda (proc _event)
               (when (memq (process-status proc) '(exit signal))
                 (setq lateci--syncthing-online (= (process-exit-status proc) 0))
                 (lateci--actualiser-affichage))))

  ;; 5. Hydroxide Async
  (make-process
   :name "hydroxide-check" :buffer nil :noquery t
   :command '("pgrep" "-x" "hydroxide")
   :sentinel (lambda (proc _event)
               (when (memq (process-status proc) '(exit signal))
                 (setq lateci--hydroxide-online (= (process-exit-status proc) 0))
                 (lateci--actualiser-affichage))))

  ;; Reflète tout de suite le réseau et le montage, sans attendre les sondes.
  (lateci--actualiser-affichage))

(defvar lateci-sondage-intervalle 30
  "Intervalle, en secondes, entre deux sondages de l'état système.

Les commandes qui changent cet état (montage, Syncthing, GPG) forcent
elles-mêmes un rafraîchissement immédiat : cet intervalle ne conditionne
que la détection des changements venus de l'extérieur. Remettre 10 pour
l'ancien comportement.")

(defvar lateci--verifier-systeme-timer nil
  "Minuteur de sondage système, conservé pour pouvoir être annulé.")

;; Idempotent : `s-r' recharge ce fichier, et sans cette garde chaque
;; rechargement empilait un minuteur supplémentaire — donc autant de séries
;; de processus de sondage en parallèle. `M-x list-timers' doit n'afficher
;; qu'une seule entrée `lateci--verifier-systeme'.
(when (timerp lateci--verifier-systeme-timer)
  (cancel-timer lateci--verifier-systeme-timer))

(lateci--verifier-systeme)
(setq lateci--verifier-systeme-timer
      (run-with-timer 0 lateci-sondage-intervalle #'lateci--verifier-systeme))

;;;; EXWM
(require 'exwm)
(require 'exwm-input)

;;(defun xres ()
;;  "Charger ~/.Xresources dans la session X courante."
;;  (interactive)
;;  (let ((f (expand-file-name "~/.Xresources")))
;;    (when (file-exists-p f)
;;      (start-process "xrdb" nil "xrdb" "-merge" f))))

;;(add-hook 'exwm-init-hook #'xres)

;;;; Keyboard shortcut in X11 windows ---
(with-eval-after-load 'exwm
  ;; C-g reste pour Emacs (quit, etc.) et n'est jamais envoyé aux applis X
  (add-to-list 'exwm-input-prefix-keys ?\C-g))

;;;; Simulation de touches pour les applications X11 (IceCat, etc.) ---
(setq exwm-input-simulation-keys
      '(
        ;; Copier / Coller / Couper (Style Emacs -> Style X11)
        ([?\M-w] . [C-c])   ; Alt-w envoie Ctrl-c
        ([?\C-y] . [C-v])   ; Ctrl-y envoie Ctrl-v
        ([?\C-w] . [C-x])   ; Ctrl-w envoie Ctrl-x
        
        ;; Recherche
        ([?\C-s] . [C-f])   ; Ctrl-s envoie Ctrl-f (recherche dans la page)
      ))

;;;; — Volume et Modeline —
(defvar lateci--volume-string "[--%] ")

;; Ajout sécurisé à la modeline globale
(or global-mode-string (setq global-mode-string '("")))
(unless (memq 'lateci--volume-string global-mode-string)
  (setq global-mode-string (append global-mode-string '(lateci--volume-string))))

(defun lateci--actualiser-volume ()
  "Récupère le volume actuel via amixer et met à jour la modeline."
  (make-process
   :name "amixer-get"
   :buffer nil
   :command '("amixer" "sget" "Master")
   :filter (lambda (_proc output)
             ;; Cherche le pourcentage [XX%] et l'état [on]/[off] dans la réponse d'amixer
             (when (string-match "\\[\\([0-9]+%\\)\\].*\\[\\(o[nf]+\\)\\]" output)
               (let ((vol (match-string 1 output))
                     (etat (match-string 2 output)))
                 (setq lateci--volume-string
                       (if (string= etat "off")
                           "[Muet]"
                         (format "[%s]" vol)))
                 (force-mode-line-update t))))))

;; Initialiser l'affichage au démarrage d'Emacs
(lateci--actualiser-volume)

(defun vol-up () 
  (interactive) 
  (start-process-shell-command "v-up" nil "amixer sset Master 5%+")
  (run-at-time "0.1 sec" nil #'lateci--actualiser-volume))

(defun vol-dn () 
  (interactive) 
  (start-process-shell-command "v-dn" nil "amixer sset Master 5%-")
  (run-at-time "0.1 sec" nil #'lateci--actualiser-volume))

(defun vol-tg () 
  (interactive) 
  (start-process-shell-command "v-tg" nil "amixer sset Master toggle")
  (run-at-time "0.1 sec" nil #'lateci--actualiser-volume))

;;;; — Luminosité —
(defun light-up () 
  (interactive) 
  (start-process-shell-command "l-up" nil "light -s sysfs/backlight/intel_backlight -A 5"))

(defun light-dn () 
  (interactive) 
  (start-process-shell-command "l-dn" nil "light -s sysfs/backlight/intel_backlight -U 5"))

;;;; poweroff, reboot & suspend
(defun poweroff ()
      (interactive)
      (when (yes-or-no-p "Éteindre l'ordinateur ? ")
        (save-some-buffers) ;; Sauvegarde silencieuse de tout ce qui a été modifié
        (start-process "poweroff" nil "poweroff")))

(defun reboot ()
      (interactive)
      (when (yes-or-no-p "Redémarrer l'ordinateur ? ")
        (save-some-buffers) ;; Sauvegarde silencieuse de tout ce qui a été modifié
        (start-process "reboot" nil "reboot")))

(defun suspend ()
  (interactive)
  (start-process "suspend" nil "suspend"))

(defun lateci/verrouiller-ecran ()
  "Verrouille l'écran avec slock.
Le binaire setuid est fourni par `screen-locker-service-type' (config.scm)."
  (interactive)
  (start-process "slock" nil "/run/setuid-programs/slock"))

;;;; Guix
(defun lateci/guix-pull ()
  "Lance `guix pull' dans un tampon de compilation.
Les canaux utilisés sont ceux de ~/.config/guix/channels.scm. La
reconfiguration du système et du profil Home reste une opération
délibérée, à lancer séparément."
  (interactive)
  (compilation-start "guix pull" nil (lambda (_) "*guix pull*")))

;;;; EXWM — RACCOURCIS ORGANISÉS ::::::::::::::::::::::::::::::::::::::::::::::
;; Quatre familles seulement, toutes sous Super :
;;   1. Touches simples  → fenêtres, tampons, espaces de travail
;;   2. s-a …            → Applications
;;   3. s-y …            → sYstème (énergie, chiffrement, montages, services)
;;   4. s-g …            → Assistant IA (gptel)
;; Mnémotechnique : s-0/1/2/3, s-b, s-k reprennent la logique du C-x d'Emacs.

;;;;; --- Préalables ----------------------------------------------------------
(with-eval-after-load 'exwm
  ;; C-g et C-c restent à Emacs, jamais transmis au client X.
  (dolist (k '(?\C-g ?\C-c))
    (add-to-list 'exwm-input-prefix-keys k)))

(defun lateci--exwm-bind (map specs)
  "Remplit MAP à partir de SPECS, liste de (TOUCHE . COMMANDE)."
  (dolist (paire specs)
    (define-key map (kbd (car paire)) (cdr paire)))
  map)

(defun lateci--exwm-set-keys (specs)
  "Déclare SPECS, liste de (TOUCHE . COMMANDE), comme raccourcis globaux EXWM."
  (dolist (paire specs)
    (exwm-input-set-key (kbd (car paire)) (cdr paire))))

;;;;; --- 1. Fenêtres, tampons, espaces de travail ----------------------------
(lateci--exwm-set-keys
 '(;; Tampons et fenêtres
   ("s-b" . consult-buffer)
   ("s-k" . kill-current-buffer)
   ("s-0" . delete-window)
   ("s-o" . delete-other-windows)
   ("s-h" . split-window-below)
   ("s-v" . split-window-right)
   ("s-f" . find-file)
   ("s-<prior>" . previous-buffer)
   ("s-<next>"  . next-buffer)
   ;; Déplacements directionnels
   ("s-<left>"  . windmove-left)
   ("s-<right>" . windmove-right)
   ("s-<up>"    . windmove-up)
   ("s-<down>"  . windmove-down)
   ;; Espaces de travail
   ("s-w" . exwm-workspace-switch)
   ("s-&" . exwm-workspace-switch-create)
   ;; Modes de fenêtre X11
   ("s-<tab>" . exwm-layout-toggle-fullscreen)
   ("s-c"     . exwm-input-toggle-keyboard)
   ;; Divers
   ("s-x" . execute-extended-command)
   ("s-r" . lateci/exwm-recharger)))

;;;;; --- 2. Applications :  s-a ----------------------------------------------
(define-prefix-command 'lateci-exwm-app-map)
(lateci--exwm-bind lateci-exwm-app-map
                   '(("t" . xterm)          ; terminal X11
                     ("e" . eshell)         ; terminal Emacs
                     ("i" . icecat)         ; navigateur
                     ("d" . dired)          ; fichiers
                     ("m" . notmuch)        ; courriels
                     ("f" . elfeed)         ; flux RSS
                     ("a" . org-agenda)     ; agenda
                     ("c" . org-capture)    ; capture
                     ("p" . proced)         ; processus
                     ("v" . emms)))         ; musique
(exwm-input-set-key (kbd "s-a") 'lateci-exwm-app-map)

;;;;; --- 3. Système :  s-y ---------------------------------------------------
(define-prefix-command 'lateci-exwm-sys-map)
(lateci--exwm-bind lateci-exwm-sys-map
                   '(;; Énergie
                     ("q" . poweroff)
                     ("r" . reboot)
                     ("z" . suspend)
                     ("l" . lateci/verrouiller-ecran)
                     ;; Chiffrement
                     ("g" . gpg-unlock-teci)
                     ("G" . gpg-lock-teci)
                     ;; Montages distants
                     ("m" . mount-club1)
                     ("M" . umount-club1)
                     ;; Synchronisations
                     ("s" . st-on)
                     ("S" . st-off)
                     ;; Guix
                     ("u" . lateci/guix-pull)
                     ("i" . guix)))
(exwm-input-set-key (kbd "s-y") 'lateci-exwm-sys-map)

;;;;; --- 4. Multimédia et rétroéclairage :  touches dédiées ------------------
(lateci--exwm-set-keys
 '(("<XF86AudioRaiseVolume>"  . vol-up)
   ("<XF86AudioLowerVolume>"  . vol-dn)
   ("<XF86AudioMute>"         . vol-tg)
   ("<XF86AudioPlay>"         . emms-pause)
   ("<XF86AudioNext>"         . emms-next)
   ("<XF86AudioPrev>"         . emms-previous)
   ("<XF86MonBrightnessUp>"   . light-up)
   ("<XF86MonBrightnessDown>" . light-dn)))

;;;;; --- 5. Assistant IA :  s-g ----------------------------------------------
(defun lateci--gptel-prep ()
  "Charge gptel avant toute commande du préfixe s-g."
  (unless (featurep 'gptel) (require 'gptel)))

(define-prefix-command 'lateci-exwm-ia-map)
(dolist (paire
         '(;; Dialogue au minibuffer, disponible même depuis une fenêtre X11
           ("q"   . lateci/gptel-question)
           ("t"   . lateci/gptel-dialogue)
           ("T"   . lateci/gptel-dialogue-reset)
           ("y"   . lateci/gptel-mb-recuperer)
           ("b"   . lateci/gptel-mb-buffer)
           ;; Session et envoi dans un tampon Emacs
           ("g"   . gptel)
           ("RET" . gptel-send)
           ("SPC" . gptel-menu)
           ;; Action sur le texte
           ("c"   . lateci/corriger-region)
           ("e"   . lateci/courriel-region)
           ("r"   . gptel-rewrite)
           ;; Contexte
           ("a"   . gptel-add)
           ("x"   . gptel-context-remove-all)
           ;; Réglages isolés du minibuffer
           ("D"   . lateci/gptel-mb-directive)
           ("m"   . lateci/gptel-mb-modele)
           ("G"   . lateci/gptel-mb-modele-defaut)
           ("?"   . lateci/gptel-mb-etat)))
  (define-key lateci-exwm-ia-map (kbd (car paire))
              (let ((cmd (cdr paire)))
                (lambda ()
                  (interactive)
                  (lateci--gptel-prep)
                  (call-interactively cmd)))))
(exwm-input-set-key (kbd "s-g") 'lateci-exwm-ia-map)

;;;;; --- 6. Rechargement de la configuration ---------------------------------
(defun lateci/exwm-recharger ()
  "Recharge le fichier d'initialisation sans quitter la session EXWM."
  (interactive)
  (load-file user-init-file)
  (message "Configuration rechargée."))

;;;;; --- 7. Étiquettes which-key --------------------------------------------
(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    ;; Préfixes
    "s-a"     "Applications"
    "s-y"     "Système"
    "s-g"     "Assistant IA"
    ;; Applications
    "s-a t"   "terminal X11"
    "s-a e"   "eshell"
    "s-a i"   "navigateur"
    "s-a d"   "fichiers"
    "s-a m"   "courriels"
    "s-a f"   "flux RSS"
    "s-a a"   "agenda"
    "s-a c"   "capture"
    "s-a p"   "processus"
    "s-a v"   "musique"
    ;; Système
    "s-y q"   "éteindre"
    "s-y r"   "redémarrer"
    "s-y z"   "veille"
    "s-y l"   "verrouiller"
    "s-y g"   "déverrouiller GPG"
    "s-y G"   "verrouiller GPG"
    "s-y m"   "monter club1"
    "s-y M"   "démonter club1"
    "s-y s"   "synchro activer"
    "s-y S"   "synchro désactiver"
    "s-y u"   "guix pull"
    "s-y i"   "interface Guix"
    ;; Assistant IA
    "s-g q"   "question ponctuelle"
    "s-g t"   "dialogue suivi"
    "s-g T"   "réinitialiser le fil"
    "s-g y"   "copier la réponse"
    "s-g b"   "réponse en Org"
    "s-g g"   "nouvelle session"
    "s-g RET" "envoyer"
    "s-g SPC" "menu gptel"
    "s-g c"   "corriger la région"
    "s-g e"   "rédiger un courriel"
    "s-g r"   "réécrire"
    "s-g a"   "ajouter au contexte"
    "s-g x"   "vider le contexte"
    ;; Les touches réelles sont D et G (cf. `lateci-exwm-ia-map' plus haut) ;
    ;; les étiquettes portaient s et g, cette dernière écrasant en silence
    ;; celle de « nouvelle session ».
    "s-g D"   "directive"
    "s-g m"   "modèle"
    "s-g G"   "modèle par défaut"
    "s-g ?"   "état"))

;; LATECI_NO_EXWM=1 permet de charger cette configuration dans un Emacs de
;; diagnostic, à côté de la session courante, sans tenter de prendre le
;; contrôle du gestionnaire de fenêtres. Sans effet en usage normal.
(if (getenv "LATECI_NO_EXWM")
    (message "LATECI_NO_EXWM : exwm-wm-mode non activé (mode diagnostic).")
  (exwm-wm-mode))

;;; INSPIRATION :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;; surf the web - eww
(use-package eww
  :ensure nil
  ;;:custom
  ;; Forcer Eww à utiliser les couleurs et polices du thème Modus
  ;;(shr-use-colors nil)
  ;;(shr-use-fonts nil)
  ;; Limiter la largeur de lecture pour le confort visuel
  ;;(shr-max-width 80)
  ;; Bloquer les images par défaut pour un chargement immédiat (décommenter si besoin)
  ;;(shr-inhibit-images t)
  :hook
  ;; Appliquer la typographie proportionnelle comme dans les buffers Org
  (eww-mode . mixed-pitch-mode))

;; elfeed
(use-package elfeed
  :bind
  ;; Raccourcis globaux
  (("C-c w E" . elfeed)
   ("C-c w u" . elfeed-update)
   ;; Raccourcis spécifiques à la liste de recherche
   :map elfeed-search-mode-map
   ("c" . lateci/denote-elfeed-capture)
   ("d" . lateci/elfeed-yt-dlp-audio)
   ;; Raccourcis spécifiques à la lecture d'un article
   :map elfeed-show-mode-map
   ("c" . lateci/denote-elfeed-capture)
   ("d" . lateci/elfeed-yt-dlp-audio))
   
  :custom
  (elfeed-search-face-alist '((unread . (font-lock-keyword-face bold))))
  
  :hook
  (elfeed-show-mode . mixed-pitch-mode)
  
  :config
  ;; --- 1. Capture vers Denote (Format feed-auteur-titre) ---
  (defun lateci/denote-elfeed-capture ()
    "Crée une note Denote à partir de l'article Elfeed (Source + Auteur)."
    (interactive)
    (let* ((entry (if (eq major-mode 'elfeed-show-mode)
                      elfeed-show-entry
                    (elfeed-search-selected :ignore-region)))
           (lien (elfeed-entry-link entry))
           (titre (elfeed-entry-title entry))
           (date (format-time-string "%Y-%m-%d" (seconds-to-time (elfeed-entry-date entry))))
           
           (feed (elfeed-entry-feed entry))
           (source (or (elfeed-feed-title feed) "inconnu"))
           
           (auteurs (elfeed-meta entry :authors))
           (auteur (if auteurs (plist-get (car auteurs) :name) "inconnu"))
           
           (tags-sym (elfeed-entry-tags entry))
           (tags-str (mapcar #'symbol-name tags-sym))
           (tags-clean (seq-remove (lambda (t-str) (string= t-str "unread")) tags-str))
           (tags-list (seq-uniq (cons "rss" tags-clean)))
           
           (titre-complet (if (string= source auteur)
                              (format "%s - %s" source titre)
                            (format "%s - %s - %s" source auteur titre))))
           
      (denote titre-complet tags-list 'org)
      
      (insert (format "* Source\n- Flux : %s\n- Auteur : %s\n- Titre : %s\n- Lien : %s\n- Date de publication : %s\n\n* Notes de lecture\n\n" 
                      source auteur titre lien date))))


  ;; --- 2. Téléchargement Audio via yt-dlp (Format feed-auteur-titre) ---
  (defun lateci/elfeed-yt-dlp-audio ()
    "Télécharge le flux audio via yt-dlp de manière invisible avec spinner."
    (interactive)
    (let* ((entry (if (eq major-mode 'elfeed-show-mode)
                      elfeed-show-entry
                    (elfeed-search-selected :ignore-region)))
           (lien (elfeed-entry-link entry))
           (titre (elfeed-entry-title entry))
           
           (feed (elfeed-entry-feed entry))
           (source (or (elfeed-feed-title feed) "inconnu"))
           
           (auteurs (elfeed-meta entry :authors))
           (auteur (if auteurs (plist-get (car auteurs) :name) "inconnu"))
           
           (tags-sym (elfeed-entry-tags entry))
           (tags-str (mapcar #'symbol-name tags-sym))
           (tags-clean (seq-remove (lambda (t-str) (string= t-str "unread")) tags-str))
           (tags-list (seq-uniq (cons "audio" tags-clean)))
           (tags-joined (mapconcat #'identity tags-list "_"))
           
           (time-str (format-time-string "%Y%m%dT%H%M%S"))
           
           (source-slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase source)))
           (source-clean (replace-regexp-in-string "^-\\|-$" "" source-slug))
           
           (auteur-slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase auteur)))
           (auteur-clean (replace-regexp-in-string "^-\\|-$" "" auteur-slug))
           
           (titre-slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase titre)))
           (titre-clean (replace-regexp-in-string "^-\\|-$" "" titre-slug))
           
           (titre-complet (if (string= source-clean auteur-clean)
                              (concat source-clean "-" titre-clean)
                            (concat source-clean "-" auteur-clean "-" titre-clean)))
           
           (nom-fichier (format "%s--%s__%s.%%(ext)s" time-str titre-complet tags-joined))
           (chemin-final (expand-file-name nom-fichier "~/Bureau/")))
           
      (when lien
        (lateci--start-spinner "Téléchargement audio en cours")
        
        (let* ((process-connection-type nil)
               (proc (start-process-shell-command
                      "yt-dlp-elfeed" " *yt-dlp-log*"
                      (format "yt-dlp -x --audio-format mp3 -o '%s' '%s'" chemin-final lien))))
          
          (set-process-filter 
           proc 
           (lambda (process output)
             (let ((texte (string-trim output)))
               (when (> (length texte) 0)
                 (unless (string-match-p "\\[download\\].*%" texte)
                   (let ((inhibit-message t))
                     (message "[yt-dlp] %s" texte)))))))

          (set-process-sentinel
           proc
           (lambda (p event)
             (when (memq (process-status p) '(exit signal))
               (if (/= (process-exit-status p) 0)
                   (lateci--stop-spinner (format "yt-dlp ❌ Échec : %s" (string-trim event)))
                 (lateci--stop-spinner "yt-dlp ✅ Audio extrait sur le Bureau !"))))))))))

;; Doc-View
(use-package doc-view
  :custom
  (doc-view-resolution 300))
(setq large-file-warning-threshold (* 50 (expt 2 20)))

;; Read ePub files
(use-package nov
  :init
  (add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode)))

;; Managing Bibliographies
(use-package bibtex
  :custom
  (bibtex-user-optional-fields
   '(("keywords" "Keywords to describe the entry" "")
     ("file"     "Relative or absolute path to attachments" "" )))
  (bibtex-align-at-equal-sign t)
  :config
  (when (fboundp 'ews-bibtex-register)
    (ews-bibtex-register))
  :bind
  (("C-c w b r" . ews-bibtex-register)))

;; Biblio package for adding BibTeX records
(use-package biblio
  :bind
  (("C-c w b b" . ews-bibtex-biblio-lookup)))

;; Citar to access bibliographies
(use-package citar
  :defer t
  :custom
  (citar-bibliography ews-bibtex-files)
  :bind
  (("C-c w b o" . citar-open)))

;; Easy insertion of weblinks
(use-package org-web-tools
  :bind
  (("C-c w w" . org-web-tools-insert-link-for-url)))

;; Emacs Multimedia System
(use-package emms
  :config
  (require 'emms-setup)
  (require 'emms-mpris)
  (emms-all)
  (emms-default-players)
  (emms-mpris-enable)
  :custom
  (emms-browser-covers #'emms-browser-cache-thumbnail-async)
  :bind
  (("C-c w m b" . emms-browser)
   ("C-c w m e" . emms)
   ("C-c w m p" . emms-play-playlist )
   ("<XF86AudioPrev>" . emms-previous)
   ("<XF86AudioNext>" . emms-next)
   ("<XF86AudioPlay>" . emms-pause)))

;; Denote
(setq denote-directory "~/Bureau/")
(setq denote-dired-directories "~/Bureau/")
(setq denote-journal-directories "~/Bureau/")

(use-package denote
  :defer t
  :custom
  (denote-sort-keywords t)
  (denote-link-description-function "%t")
  (denote-rename-buffer-mode 1)
  :hook
  (dired-mode . denote-dired-mode)
  :custom-face
  (denote-faces-link ((t (:slant italic))))
  :bind
  (("C-c w d b" . denote-find-backlink)
   ("C-c w d d" . denote-date)
   ("C-c w d l" . denote-find-link)
   ("C-c w d i" . denote-link-or-create)
   ("C-c w d k" . denote-rename-file-keywords)
   ("C-c w d n" . denote)
   ("C-c w d r" . denote-rename-file)
   ("C-c w d R" . denote-rename-file-using-front-matter)))

;; Denote auxiliary packages
(use-package denote-journal)

(use-package denote-org
  :bind
  (("C-c w d h" . denote-org-link-to-heading)))

(use-package denote-sequence)

;; Consult est configuré plus haut (section MINIBUFFER COMPLETION), avec en
;; plus C-x b et la source « Applications X11 » pour les tampons EXWM.

;; Consult-Notes for easy access to notes
(use-package consult-notes
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :bind
  (("C-c w d f" . consult-notes)
   ("C-c w d g" . consult-notes-search-in-all-notes))
  :init
  (consult-notes-denote-mode))

;; Citar-Denote to manage literature notes
(use-package citar-denote
  :custom
  (citar-open-always-create-notes t)
  :config
  (citar-denote-mode)
  :bind
  (("C-c w b c" . citar-create-note)
   ("C-c w b n" . citar-denote-open-note)
   ("C-c w b x" . citar-denote-nocite)
   :map org-mode-map
   ("C-c w b k" . citar-denote-add-citekey)
   ("C-c w b K" . citar-denote-remove-citekey)
   ("C-c w b d" . citar-denote-dwim)
   ("C-c w b e" . citar-denote-open-reference-entry)))

;; Explore and manage your Denote collection

(use-package denote-explore
  :bind
  (;; Statistics
   ("C-c w x c" . denote-explore-count-notes)
   ("C-c w x C" . denote-explore-count-keywords)
   ("C-c w x b" . denote-explore-barchart-keywords)
   ("C-c w x e" . denote-explore-barchart-filetypes)
   ;; Random walks
   ("C-c w x r" . denote-explore-random-note)
   ("C-c w x l" . denote-explore-random-link)
   ("C-c w x k" . denote-explore-random-keyword)
   ("C-c w x x" . denote-explore-random-regex)
   ;; Denote Janitor
   ("C-c w x d" . denote-explore-identify-duplicate-notes)
   ("C-c w x z" . denote-explore-zero-keywords)
   ("C-c w x s" . denote-explore-single-keywords)
   ("C-c w x o" . denote-explore-sort-keywords)
   ("C-c w x w" . denote-explore-rename-keyword)
   ;; Visualise denote
   ("C-c w x n" . denote-explore-network)
   ("C-c w x v" . denote-explore-network-regenerate)
   ("C-c w x D" . denote-explore-barchart-degree)))

;; Distraction-free writing
(use-package darkroom
  :demand t
  :bind
  (("C-c w o" . darkroom-mode)))

;; Vundo
(use-package vundo
  :bind
  (("C-M-/" . vundo)))

;; Export citations with Org Mode
(require 'oc-natbib)
(require 'oc-csl)

(setq org-cite-global-bibliography ews-bibtex-files
      org-cite-insert-processor 'citar
      org-cite-follow-processor 'citar
      org-cite-activate-processor 'citar)

;; Lookup words in online dictionaries
(use-package dictionary
  :custom
  (dictionary-server "dict.org")
  :bind
  (("C-c w s d" . dictionary-lookup-definition)))

;; Writegood-Mode for weasel words, passive writing and repeated word detection
(use-package writegood-mode
  :bind
  (("C-c w s r" . writegood-reading-ease))
  :hook
  (text-mode . writegood-mode))

;; Abbreviations
(add-hook 'text-mode-hook 'abbrev-mode)

;; ediff
(use-package ediff
  :ensure nil
  :custom
  (ediff-keep-variants nil)
  (ediff-split-window-function 'split-window-horizontally)
  (ediff-window-setup-function 'ediff-setup-windows-plain))

;;;; Enable Other text modes
(use-package markdown-mode)

;;; PUBLICATION :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;; epub export
(use-package ox-epub
  :demand t
  :init
  (require 'ox-org))

;; LaTeX PDF Export settings
(use-package ox-latex
  :ensure nil
  :demand t
  :custom
  ;; Multiple LaTeX passes for bibliographies
  (org-latex-pdf-process
   '("pdflatex -interaction nonstopmode -output-directory %o %f"
     "bibtex %b"
     "pdflatex -shell-escape -interaction nonstopmode -output-directory %o %f"
     "pdflatex -shell-escape -interaction nonstopmode -output-directory %o %f"))
  ;; Clean temporary files after export
  (org-latex-logfiles-extensions
   (quote ("lof" "lot" "tex~" "aux" "idx" "log" "out"
           "toc" "nav" "snm" "vrb" "dvi" "fdb_latexmk"
           "blg" "brf" "fls" "entoc" "ps" "spl" "bbl"
           "tex" "bcf"))))

;; EWS paperback configuration
(with-eval-after-load 'ox-latex
  (add-to-list
   'org-latex-classes
   '("ews"
     "\\documentclass[11pt, twoside, hidelinks]{memoir}
        \\setstocksize{9.25in}{7.5in}
        \\settrimmedsize{\\stockheight}{\\stockwidth}{*}
        \\setlrmarginsandblock{1.5in}{1in}{*} 
        \\setulmarginsandblock{1in}{1.5in}{*}
        \\checkandfixthelayout
        \\layout
        \\setcounter{tocdepth}{0}
        \\renewcommand{\\baselinestretch}{1.25}
        \\setheadfoot{0.5in}{0.75in}
        \\setlength{\\footskip}{0.8in}
        \\chapterstyle{bianchi}
        \\setsecheadstyle{\\normalfont \\raggedright \\textbf}
        \\setsubsecheadstyle{\\normalfont \\raggedright \\emph}
        \\setsubsubsecheadstyle{\\normalfont\\centering}
        \\pagestyle{myheadings}
        \\usepackage[font={small, it}]{caption}
        \\usepackage{ccicons}
        \\usepackage{ebgaramond}
        \\usepackage[authoryear]{natbib}
        \\bibliographystyle{apalike}
        \\usepackage{svg}
\\hyphenation{mini-buffer}"
     ("\\chapter{%s}" . "\\chapter*{%s}")
     ("\\section{%s}" . "\\section*{%s}")
     ("\\subsection{%s}" . "\\subsection*{%s}")
     ("\\subsubsection{%s}" . "\\subsubsection*{%s}"))))

;; Paramétrage de l'export HTML pour un blog artisanal
(use-package ox-html
  :ensure nil
  :custom
  ;; 1. Utiliser le standard HTML5 moderne et épuré
  (org-html-doctype "html5")
  
  ;; 2. Désactiver le code CSS injecté par défaut par Emacs
  (org-html-head-include-default-style nil)
  
  ;; 3. Désactiver les scripts JavaScript par défaut
  (org-html-head-include-scripts nil)
  
  ;; 4. Désactiver les blocs automatiques en haut et en bas de page
  (org-html-preamble nil)
  (org-html-postamble nil)
  
  ;; 5. (Optionnel) Ne pas exporter les balises <div> superflues autour des sections
  (org-html-container-element "section"))

;;; ADMINISTRATION ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;;;; Calendar
(use-package calendar
  :ensure nil
  :custom

  ;; --- COMPORTEMENT ---
  (calendar-week-start-day 1)
  (calendar-date-style 'european)
  (calendar-day-name-array ["Dimanche" "Lundi" "Mardi" "Mercredi" "Jeudi" "Vendredi" "Samedi"])
  (calendar-month-name-array ["Janvier" "Février" "Mars" "Avril" "Mai" "Juin" 
                              "Juillet" "Août" "Septembre" "Octobre" "Novembre" "Décembre"])
  (calendar-intermonth-text
   '(propertize
     (format "%2d"
             (car
              (calendar-iso-from-absolute
               (calendar-absolute-from-gregorian (list month day year)))))
     'font-lock-face 'font-lock-function-name-face))
  
  ;; --- INTÉGRATION ORG-AGENDA ---

  ;; Activer le marquage visuel des jours contenant des tâches
  (calendar-mark-diary-entries-flag t)
  
  :config
  ;; Faire le pont avec les fichiers Org automatiquement
  ;; Création silencieuse du fichier diary s'il n'existe pas
  (setq diary-file (expand-file-name "diary" user-emacs-directory))
  (unless (file-exists-p diary-file)
    (with-temp-file diary-file
      (insert "%%(org-diary)\n"))))

;; La typographie du calendrier (calendar-today, calendar-weekend-header,
;; calendar-month-header, diary) est réglée par `lateci/appliquer-faces'
;; (section RETOUCHES DE FACES), avec des faces sémantiques au lieu de
;; couleurs littérales.

;; --- CORRECTION DE LA GRILLE ---
(defun lateci--calendrier-police-fixe ()
  "Force une police à chasse fixe : la grille du calendrier en dépend."
  (face-remap-add-relative 'default :family "Monospace"))

(add-hook 'calendar-mode-hook #'lateci--calendrier-police-fixe)

(setq org-read-date-popup-calendar nil)

(with-eval-after-load 'org-agenda
  (defun my/org-agenda-after-quit (&rest _ignore)
    "Fermer les buffers sources d'agenda (org-agenda-files) à la fermeture de l'agenda."
    (when (boundp 'org-agenda-files)
      (let* ((agenda-files (org-agenda-files t)) ;; t = truenames
             (agenda-files-truename
              (mapcar #'file-truename agenda-files)))
        (dolist (buf (buffer-list))
          (with-current-buffer buf
            (when (and buffer-file-name
                       (member (file-truename buffer-file-name)
                               agenda-files-truename))
              (kill-buffer buf)))))))

  ;; Lancer tout ça après la fermeture de l’agenda (touche `q`)
  (advice-add 'org-agenda-quit :after #'my/org-agenda-after-quit))

;;; FILE MANAGEMENT ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :hook (dired-mode . dired-omit-mode)
  :custom
  (dired-listing-switches "-goah --group-directories-first --time-style=long-iso")
  (dired-dwim-target t)
  (delete-by-moving-to-trash t)
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-omit-files "^\\.[a-zA-Z0-9]+")
  :bind (:map dired-mode-map
              ("." . dired-omit-mode))
  :init
  (put 'dired-find-alternate-file 'disabled nil))

(use-package filechooser
  :ensure nil
  :demand t
  :custom  
  (filechooser-use-popup-frame nil)
  :config
  (filechooser-start))

(defun vider-la-corbeille ()
  "Vider la corbeille FreeDesktop (~/.local/share/Trash/{files,info})."
  (interactive)
  (when (yes-or-no-p "Vider définitivement la corbeille ? ")
    (let* ((trash (expand-file-name "~/.local/share/Trash/"))
           (dirs  (list (expand-file-name "files/" trash)
                        (expand-file-name "info/"  trash))))
      (condition-case err
          (progn
            ;; s'assure que la structure existe
            (dolist (d dirs) (make-directory d t))
            ;; supprime tout le contenu, sans supprimer les dossiers eux-mêmes
            (dolist (d dirs)
              (dolist (f (directory-files d t directory-files-no-dot-files-regexp))
                (if (file-directory-p f)
                    (delete-directory f t)
                  (delete-file f t))))
            (message "Corbeille vidée"))
        (error
         (message "Échec vidage corbeille : %s" (error-message-string err)))))))

;;;; Backup files
(setq-default backup-directory-alist
              `(("." . ,(expand-file-name "backups/" user-emacs-directory)))
              version-control t
              delete-old-versions t
              create-lockfiles nil)

;;;; Recent files
(use-package recentf
  :config
  (recentf-mode t)
  :custom
  (recentf-max-saved-items 50)
  :bind
  (("C-c w r" . recentf-open)))

;;;; Bookmarks
(use-package bookmark
  :custom
  (bookmark-save-flag 1)
  :bind
  ("C-x r d" . bookmark-delete))

;;;; Image viewer
(use-package emacs
  :custom
  (image-dired-external-viewer "gimp")
  :bind
  (:map image-mode-map
         ("k" . image-kill-buffer)
         ("<right>" . image-next-file)
         ("<left>"  . image-previous-file)
    :map dired-mode-map
         ("C-<return>" . image-dired-dired-display-external)))

(use-package image-dired
  :bind
  (("C-c w I" . image-dired)
  (:map image-dired-thumbnail-mode-map
        ("C-<right>" . image-dired-display-next)
        ("C-<left>"  . image-dired-display-previous))))

;;;; Bind key for customising variables
(keymap-global-set "C-c w v" 'customize-variable)

;;;; Custom settings in a separate file and load the custom settings
(setq-default custom-file (expand-file-name
			     "custom.el"
			     user-emacs-directory))

(load custom-file :no-error-if-file-is-missing)

;;;; ADVANCED UNDOCUMENTED EXPORT SETTINGS FOR EWS ::::::::::::::::::::::::::
;; Use GraphViz for flow diagrams
;; requires GraphViz software
(org-babel-do-load-languages
 'org-babel-load-languages
 '((dot . t)))

;;;; org-export-latex-pdf-export-dir 
(defvar org-latex-export-destination-table (make-hash-table :test 'equal)
  "Table de correspondance fichier Org → dernier dossier d’export PDF choisi.")

(defun org-latex-export-to-pdf-choose-dir (dir)
  "Exporter le buffer Org en PDF puis déplacer le fichier dans DIR.
Se souvient du dernier dossier utilisé pour ce fichier Org."
  (interactive
   (let* ((org-file  (buffer-file-name))
          (last-dir  (gethash org-file org-latex-export-destination-table))
          (start-dir (or last-dir default-directory)))
     ;; Ici, `start-dir` est utilisé comme dossier de départ ET valeur initiale.
     (list (read-directory-name
            "Exporter le PDF vers le dossier : "
            start-dir   ; dossier de départ
            start-dir   ; défaut
            t           ; doit être un dossier existant
            nil))))     ; pas de texte initial supplémentaire

  ;; Mémoriser le dossier choisi pour ce fichier Org
  (puthash (buffer-file-name) dir org-latex-export-destination-table)

  (let* ((pdf-file (org-latex-export-to-pdf))
         (basename (file-name-nondirectory pdf-file))
         (dest-dir (file-name-as-directory (expand-file-name dir)))
         (dest     (expand-file-name basename dest-dir)))
    (make-directory dest-dir t)
    (rename-file pdf-file dest t)
    (message "PDF exporté vers : %s" dest)))

;;;; NOTMUCH ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
(use-package notmuch
  :ensure nil
  :defer t
  :commands (notmuch notmuch-mua-new-mail)
  :init
  (setq notmuch-search-oldest-first nil
        notmuch-archive-tags '("-inbox" "-unread")
        notmuch-saved-searches
	
	;; --- Nouveaux Courriels --- 
        '((:name "Nouveau(x) courriel(s) pour la TECI"
                 :query "tag:unread AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"
                 :key "n")
	  (:name "Nouveau(x) courriel(s) du Fight-Club"
                 :query "tag:unread AND to:fight-club@framagroupes.org AND NOT tag:trash"
                 :key "c")
	  (:name "Nouveau(x) courriel(s) du Hangar"
                 :query "tag:unread AND (to:membres.actif-ves@lestempsdarts.lautre.net OR to:commission.numerique@lestempsdarts.lautre.net OR to:actus@lestempsdarts.lautre.net) AND NOT tag:trash"
                 :key "h")
	   (:name "Nouveau(x) courriel(s) perso"
                 :query "tag:unread AND to:thomas.millasseau@protonmail.com AND NOT tag:trash"
                 :key "N")
	   
	  ;; --- Boites de réception ---
	  (:name "Boites de réception de la TECI"
                 :query "tag:inbox AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"
                 :key "p")
	  (:name "Boite de réception du Fight-Club"
                 :query "tag:inbox AND to:fight-club@framagroupes.org AND NOT tag:trash"
                 :key "f")
	  ;; "H" et non "h" : cette touche était en collision avec « Nouveau(x)
	  ;; courriel(s) du Hangar » ci-dessus, rendant cette entrée inatteignable.
	  (:name "Boite de réception du Hangar"
                 :query "tag:inbox AND (to:membres.actif-ves@lestempsdarts.lautre.net OR to:commission.numerique@lestempsdarts.lautre.net OR to:actus@lestempsdarts.lautre.net) AND NOT tag:trash"
                 :key "H")
          (:name "Boite de réception personnelle"
                 :query "tag:inbox AND to:thomas.millasseau@protonmail.com AND NOT tag:trash"
                 :key "P")
	  
	  ;; --- Courriels Envoyés ---
          (:name "Courriels Envoyés"
                 :query "tag:sent AND NOT tag:trash"
                 :key "s")

            (:name "Brouillons"
                 :query "tag:draft AND NOT tag:trash"
                 :key "d")))
  
  :config
  ;; Charger explicitement notmuch-hello pour être sûr que les variables existent
  (require 'notmuch-hello)
  ;; Ne garder que le header et les recherches enregistrées
  (setq notmuch-hello-sections
        '(notmuch-hello-insert-saved-searches)
        ;; Désactiver le logo
        notmuch-hello-logo nil))

;; --- ANIMATION DE CHARGEMENT (SPINNER) OPTIMISÉE ---
(defvar lateci--spinner-timer nil)
(defvar lateci--spinner-frames '("[-]" "[\\]" "[|]" "[/]" "[-]" "[\\]" "[|]" "[/]"))
(defvar lateci--spinner-index 0)

(defun lateci--start-spinner (texte)
  "Démarre une animation uniquement dans le minibuffer sans polluer *Messages*."
  (when lateci--spinner-timer (cancel-timer lateci--spinner-timer))
  (setq lateci--spinner-index 0)
  (setq lateci--spinner-timer
        (run-with-timer 0 0.2
                        (lambda ()
                          (let ((inhibit-quit t)
                                (message-log-max nil)) ;; <-- Empêche l'écriture de la frame dans *Messages*
                            (message "%s %s" texte (nth lateci--spinner-index lateci--spinner-frames))
                            (setq lateci--spinner-index (mod (1+ lateci--spinner-index) (length lateci--spinner-frames))))))))

(defun lateci--stop-spinner (texte-fin)
  "Arrête l'animation et affiche le message final (qui sera lui bien historisé)."
  (when lateci--spinner-timer
    (cancel-timer lateci--spinner-timer)
    (setq lateci--spinner-timer nil))
  (message "%s" texte-fin))

;; --- FONCTIONS DE SYNCHRONISATION SILENCIEUSE (AVEC LOGS) ---

(defun lateci--lancer-mbsync-seul ()
  "Lance mbsync silencieusement, conserve les logs, et met à jour la BDD sans ouvrir Notmuch."
  (lateci--start-spinner "Récupération des courriels")
  
  (let* ((process-connection-type nil)
         (proc (start-process-shell-command "mbsync-boite" " *mbsync-log*" "mbsync -a")))
    
    ;; Maintien strict de ton filtre pour écrire dans *Messages*
    (set-process-filter 
     proc 
     (lambda (process output)
       (let ((texte (string-trim output)))
         (when (> (length texte) 0)
           (let ((inhibit-message t))
             (message "[mbsync] %s" texte))))))

    (set-process-sentinel
     proc
     (lambda (p event)
       (when (memq (process-status p) '(exit signal))
         (if (/= (process-exit-status p) 0)
             (lateci--stop-spinner (format "Échec mbsync : %s" (string-trim event)))
           (progn
             (lateci--stop-spinner "Synchronisation terminée !")
             ;; Met à jour Notmuch en arrière-plan
             (when (fboundp 'notmuch-poll)
               (let ((inhibit-message t)) 
                 (message "Lancement de notmuch-poll…"))
               (notmuch-poll))
             (when (fboundp 'notmuch-hello-update)
               (when-let ((buf (get-buffer "*notmuch-hello*")))
                 (with-current-buffer buf (notmuch-hello-update)))))))))))

(defun mbx-sync ()
  "Lance mbsync manuellement avec animation, puis met à jour Notmuch."
  (interactive)
  (lateci--start-spinner "Récupération des courriels")
  (let* ((process-connection-type nil)
         (proc (start-process-shell-command "mbsync-boite" " *mbsync-log*" "mbsync -a")))
    
    (set-process-filter 
     proc 
     (lambda (process output)
       (let ((texte (string-trim output)))
         (when (> (length texte) 0)
           (let ((inhibit-message t))
             (message "[mbsync] %s" texte))))))

    (set-process-sentinel
     proc
     (lambda (p event)
       (when (memq (process-status p) '(exit signal))
         (if (/= (process-exit-status p) 0)
             (lateci--stop-spinner (format "Échec mbsync : %s" (string-trim event)))
           (progn
             (lateci--stop-spinner "Mise à jour des courriels terminée !")
             (when (fboundp 'notmuch-poll)
               (notmuch-poll))
             (when (fboundp 'notmuch-hello-update)
               (when-let ((buf (get-buffer "*notmuch-hello*")))
                 (with-current-buffer buf (notmuch-hello-update)))))))))))

(defun notmuch-open-unread-teci ()
  "Ouvre les courriels non lus du Terrain d'Expérimentation de Créations et d'Initiative."
  (interactive)
  (notmuch-search "tag:unread AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"))

(defun notmuch-open-inbox-teci ()
  "Ouvre la boite de réception globale."
  (interactive)
  (notmuch-search "tag:inbox AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"))

;; --- DÉCLARATION DES RACCOURCIS COURRIELS ---
(defvar lateci-mail-map (make-sparse-keymap)
  "Keymap pour la gestion des courriels.")
(global-set-key (kbd "C-c m") lateci-mail-map)

(define-key lateci-mail-map (kbd "s") #'mbx-sync)                ;; Sync
(define-key lateci-mail-map (kbd "m") #'notmuch)                 ;; Menu Principal
(define-key lateci-mail-map (kbd "n") #'notmuch-open-unread-teci) ;; Nouveaux TECI
(define-key lateci-mail-map (kbd "i") #'notmuch-open-inbox-teci)  ;; Inbox TECI
(define-key lateci-mail-map (kbd "f") #'notmuch-search)          ;; Chercher (Find)
(define-key lateci-mail-map (kbd "c") #'notmuch-mua-new-mail)    ;; Écrire (Compose)

;; ENVOI COURRIEL VIA CLUB1 (SMTP)
(setq user-full-name "LA TECI"
      user-mail-address "lateci@club1.fr")

(setq sendmail-program (executable-find "msmtp")
      send-mail-function #'message-send-mail-with-sendmail
      message-send-mail-function #'message-send-mail-with-sendmail)

(setq notmuch-fcc-dirs
      "club1/Sent +sent -inbox -unread")

(setq message-signature-insert-empty-line t)
(setq message-signature
      "~$ thomas r.-m. | https://lateci.club1.fr | +33 7 80 32 63 09
Documents & flyers en sobriété numérique : https://static.club1.fr/lateci/")

(global-set-key (kbd "C-x m") #'notmuch-mua-mail)
;; Fermer automatiquement le buffer de rédaction après l'envoi du courriel
(setq message-kill-buffer-on-exit t)

;; Rendre les URL cliquables dans le texte brut de notmuch
(add-hook 'notmuch-show-hook 'goto-address-mode)

;;;; Gestion des contacts (EBDB)
(use-package ebdb
  :defer t
  :custom
  (ebdb-sources '("~/.emacs.d/ebdb"))
  :config
  (require 'ebdb-com)
  (require 'ebdb-message))

;;;; Pièces jointes depuis Dired vers Notmuch
(require 'gnus-dired)

;; Déclare formellement Notmuch comme agent pour Dired
(setq gnus-dired-mail-mode 'notmuch-user-agent)

(with-eval-after-load 'dired
  ;; Assigne directement la fonction native (qui s'exécute de manière interactive par défaut)
  (define-key dired-mode-map (kbd "C-c RET") #'gnus-dired-attach))

;;;; Applications X11 :::::::::::::::::::::::::::::::::::::::::::::::::::::::::

(defun exwm-rename-buffer-by-class ()
  "Renomme le buffer EXWM selon la classe de la fenêtre."
  (when (eq major-mode 'exwm-mode)
    (when exwm-class-name
      (pcase exwm-class-name
        ("Icecat"
         (exwm-workspace-rename-buffer "IceCat"))
        ("Soffice"
         (exwm-workspace-rename-buffer "soffice"))
;;        ((or "XTerm" "xterm")
;;         (exwm-workspace-rename-buffer "XTerm"))
        (_
         (exwm-workspace-rename-buffer exwm-class-name))))))

(add-hook 'exwm-manage-finish-hook #'exwm-rename-buffer-by-class)

;;;;; --- Web ---
(defun icecat ()
  (interactive)
  (let ((buf (get-buffer "Icecat")))
    (if (and buf (buffer-live-p buf))
        (exwm-workspace-switch-to-buffer buf)
      (start-process "icecat" nil "icecat"))))

(global-set-key (kbd "C-c i") #'icecat)

;; Utiliser Luakit comme navigateur par défaut
(setq browse-url-browser-function 'browse-url-generic)
(setq browse-url-generic-program "icecat")


;;(defun icecat ()
;;  (interactive)
;  (let ((buf (get-buffer "²")))
;    (if (and buf (buffer-live-p buf))
;        (exwm-workspace-switch-to-buffer buf)
;      (start-process "icecat" nil "icecat"))))

;(global-set-key (kbd "C-c i") #'icecat)

;;;;; --- XTERM ---
(defun xterm ()
  (interactive)
  (let ((buf (get-buffer "XTerm")))
    (if (and buf (buffer-live-p buf))
        (exwm-workspace-switch-to-buffer buf)
      (start-process "xterm" nil "xterm"))))

(global-set-key (kbd "C-c x") #'xterm)
(global-set-key (kbd "C-c X") #'eshell)

;;;;; --- SOFFICE ---
;;(defun soffice ()
;;  (interactive)
;;  (let ((buf (get-buffer "soffice")))
;;    (if (and buf (buffer-live-p buf))
;;        (exwm-workspace-switch-to-buffer buf)
;;      (start-process "soffice" nil "soffice"))))

;;(global-set-key (kbd "C-c o") #'soffice)

;;;;; --- SCRIBUS ---
;;(defun scribus ()
;;  (interactive)
;;  (let ((buf (get-buffer "scribus")))
;;    (if (and buf (buffer-live-p buf))
;;        (exwm-workspace-switch-to-buffer buf)
;;      (start-process "scribus" nil "scribus"))))

;;(global-set-key (kbd "C-c p") #'scribus)

;;;; SSHFS :::::::::::::::::::::::::::::::::::::::::::::::

(defun mount-club1 ()
  "Demande à Shepherd de démarrer le service SSHFS."
  (interactive)
  (start-process "shepherd-sshfs-on" nil "herd" "start" "sshfs-club1")
  (message "Montage de Club1 via Shepherd...")
  ;; Le montage passe par le réseau : on laisse le temps à sshfs d'aboutir
  ;; avant de rafraîchir l'indicateur « srv ».
  (run-at-time "3 sec" nil #'lateci--verifier-systeme))

(defun umount-club1 ()
  "Demande à Shepherd d'arrêter le service SSHFS."
  (interactive)
  (start-process "shepherd-sshfs-off" nil "herd" "stop" "sshfs-club1")
  (message "Démontage de Club1 via Shepherd...")
  (run-at-time "2 sec" nil #'lateci--verifier-systeme))

(global-set-key (kbd "C-c <f7>") #'mount-club1)
(global-set-key (kbd "C-c S-<f7>") #'umount-club1)

;;;; SYNCTHING ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
(use-package syncthing
  :defer t
  :custom
  (syncthing-host "127.0.0.1:8384")
  ;; La lecture du jeton reste ici, donc au démarrage d'Emacs : .bash_profile
  ;; déverrouille la clé GPG avant startx, elle est en cache, `pass show'
  ;; répond immédiatement. Différer cet appel le déplacerait vers un moment où
  ;; le cache peut avoir expiré, et le message d'erreur de gpg finirait dans
  ;; le jeton lui-même.
  (syncthing-default-server-token
    (string-trim (shell-command-to-string "pass show api/syncthing"))))

(defun st-on ()
  "Démarre Syncthing via le gestionnaire de services Shepherd."
  (interactive)
  (start-process "shepherd-st-on" nil "herd" "start" "syncthing")
  (message "Démarrage de Syncthing")
  ;; Force la mise à jour de la modeline après une seconde
  (run-at-time "1 sec" nil #'lateci--verifier-systeme))

(defun st-off ()
  "Arrête Syncthing via le gestionnaire de services Shepherd."
  (interactive)
  (start-process "shepherd-st-off" nil "herd" "stop" "syncthing")
  (message " Arrêt de Syncthing")
  (run-at-time "1 sec" nil #'lateci--verifier-systeme))
 
(global-set-key (kbd "C-c s s") #'st-on)
(global-set-key (kbd "C-c s S") #'st-off)
(global-set-key (kbd "C-c s c") #'syncthing)

;;;; GnuPG + PINENTRY :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
(use-package pinentry
  :init
  (require 'epa)
  (require 'epa-file)
  ;;(epa-file-enable)
  :config
  (setq epg-pinentry-mode 'loopback)
  (setq epa-pinentry-mode 'loopback)
  (pinentry-start))

(defun gpg-unlock-teci ()
  (interactive)
  (let ((file (expand-file-name "~/.gnupg/.verrou.gpg"))
        (ctx (epg-make-context 'OpenPGP))
        (succes t))
    (if (not (file-exists-p file))
        (user-error "Fichier inexistant : %s" file)
      (condition-case nil
          (epg-decrypt-file ctx file nil)
        (error (setq succes nil)))
      (if succes
          (progn
            (message "Clé GPG déverrouillée.")
            (lateci--verifier-systeme))
        (message "Échec GPG : Mot de passe incorrect ou annulé.")))))

(defun gpg-lock-teci ()
  (interactive)
  (let ((bin (executable-find "gpgconf")))
    (when (and bin (numberp (call-process bin nil nil nil "--kill" "gpg-agent")))
      (message "Clé GPG verrouillée.")
      (setq lateci--gpg-unlocked nil)
      (lateci--actualiser-affichage))))

(global-set-key (kbd "C-c g u") #'gpg-unlock-teci)
(global-set-key (kbd "C-c g l") #'gpg-lock-teci)


;;;;  MODE KIOSK LA TECI (CORRIGÉ) ---
(defvar lateci/kiosk-url "https://lateci.club1.fr/accueil.html"
  "L'adresse du site autorisé pour le mode kiosk.")

(defun ksk-on ()
  (interactive)
  (message "Activation du mode Kiosk...")
  (start-process "icecat-kiosk" nil "icecat" "--kiosk" lateci/kiosk-url))

(defun ksk-off ()
  (interactive)
  (let ((proc (get-process "icecat-kiosk")))
    (if proc
        (progn
          (delete-process proc)
          (message "Mode Kiosk désactivé."))
      (message "Le processus Kiosk n'a pas été trouvé."))))

(exwm-input-set-key (kbd "s-C-k") #'ksk-on)   
(exwm-input-set-key (kbd "s-C-K") #'ksk-off) 

;;; ASSISTANT IA (gptel) ::::::::::::::::::::::::::::::::::::::::::::::::::::::

(defun lateci--anthropic-key ()
  (string-trim (shell-command-to-string "pass show api/claude")))

(defun lateci--gemini-key ()
  (string-trim (shell-command-to-string "pass show api/gemini")))

(defun lateci--openai-key ()
  (string-trim (shell-command-to-string "pass show api/openai")))

(defvar lateci-gptel-modele-rapide 'claude-haiku-4-5)

(defun lateci/corriger-region (debut fin &optional systeme)
  "Corrige la région en place. SYSTEME optionnel remplace la directive."
  (interactive "r")
  (let ((texte (buffer-substring-no-properties debut fin))
        (buf (current-buffer)))
    (lateci--start-spinner "Correction")
    (gptel-request texte
      :system (or systeme
                  "Corrige grammaire, orthographe, syntaxe et lourdeurs en français. Conserve le balisage Org et LaTeX à l'identique. Ne change pas le sens ni le ton. Renvoie UNIQUEMENT le texte corrigé, sans commentaire.")
      :context (list debut fin buf)
      :callback
      (lambda (reponse info)
        (if (not (stringp reponse))
            (lateci--stop-spinner (format "Échec : %s" (plist-get info :status)))
          (pcase-let ((`(,d ,f ,b) (plist-get info :context)))
            (with-current-buffer b
              (save-excursion
                (delete-region d f)
                (goto-char d)
                (insert reponse))))
          (lateci--stop-spinner "Terminé."))))))

(defun lateci/courriel-region (debut fin)
  "Développe des notes en courriel associatif."
  (interactive "r")
  (lateci/corriger-region
   debut fin
   "Développe ces notes en courriel associatif français : ton cordial et sobre, court, formule de politesse. Renvoie uniquement le corps du courriel."))

(defun lateci/expliquer-erreur ()
  "Envoie le buffer courant (backtrace, log, sortie Guix) pour diagnostic."
  (interactive)
  (let ((extrait (buffer-substring-no-properties
                  (point-min) (min (point-max) 6000))))
    (gptel-request extrait
      :system "Tu diagnostiques des erreurs sous Guix System, Emacs Lisp, Guile Scheme et LaTeX. Donne : (1) la cause en une phrase, (2) le correctif exact. Pas de préambule."
      :callback (lambda (r _i)
                  (when (stringp r)
                    (with-current-buffer (get-buffer-create "*diagnostic*")
                      (erase-buffer) (org-mode) (insert r)
                      (pop-to-buffer (current-buffer))))))))

(defun lateci/gptel-context-clear ()
  (interactive)
  (gptel-context-remove-all)
  (message "Contexte gptel vidé."))

(defun lateci/gptel-toggle-web ()
  "Bascule le backend Anthropic avec recherche web serveur."
  (interactive)
  (if (eq gptel-backend gptel--backend-anthropic-web)
      (progn (setq gptel-backend gptel--backend-anthropic)
             (message "Recherche web désactivée."))
    (setq gptel-backend gptel--backend-anthropic-web)
    (message "Recherche web activée — max 3 requêtes/tour.")))

(use-package gptel
  :ensure nil
  :defer t
  :bind
  (("C-c w a n" . gptel)
   ("C-c w a s" . gptel-send)
   ("C-c w a m" . gptel-menu)
   ("C-c w a a" . gptel-add)
   ("C-c w a f" . gptel-add-file)
   ("C-c w a r" . gptel-rewrite)
   ("C-c w a c" . lateci/corriger-region)
   ("C-c w a d" . lateci/expliquer-erreur)
   ("C-c w a x" . lateci/gptel-context-clear)
   ("C-c w a W" . lateci/gptel-toggle-web))
  :init
  (with-eval-after-load 'which-key
    (which-key-add-key-based-replacements "C-c w a" "Assistant IA"))

  :config
  (setq gptel-default-mode 'org-mode
        gptel-max-tokens 4096
        gptel-use-tools nil
        gptel-confirm-tool-calls t)

  ;; --- Backends ---
  (defvar gptel--backend-anthropic
    (gptel-make-anthropic "anthropic"
      :key #'lateci--anthropic-key
      :stream t
      :models '(claude-fable-5
                claude-opus-5
                claude-sonnet-5
                claude-haiku-4-5)))

  (defvar gptel--backend-anthropic-web
    (gptel-make-anthropic "anthropic-web"
      :key #'lateci--anthropic-key
      :stream t
      :models '(claude-haiku-4-5 claude-sonnet-5 claude-opus-5)
      :request-params
      '(:tools [(:type "web_search_20250305"
                 :name "web_search"
                 :max_uses 3
                 :user_location (:type "approximate"
                                 :country "FR"
                                 :city "Blois"
                                 :timezone "Europe/Paris"))])))

  (defvar gptel--backend-gemini
    (gptel-make-gemini "gemini"
      :key #'lateci--gemini-key
      :stream t
      :models '(gemini-3.5-flash-light
                gemini-3.6-flash
                gemini-3.1-pro-preview)))

  (defvar gptel--backend-openai
    (gptel-make-openai "openai"
      :key #'lateci--openai-key
      :stream t
      :models '(gpt-5.6-sol
                gpt-5.6-terra
                gpt-5.6-luna)))

  ;; Sélection par défaut, une fois tous les backends déclarés.
  (setq gptel-backend gptel--backend-anthropic
        gptel-model 'claude-opus-5
        gptel-cache '(message system tool))


  ;; --- Outils ---
  (defvar lateci--outil-notes
    (gptel-make-tool
     :name "rechercher_notes_lateci"
     :description "Recherche un mot-clé dans la base Denote (fichiers Org)."
     :args (list '(:name "requete" :type "string" :description "Le texte à chercher"))
     :category "lateci"
     :function (lambda (requete)
                 (let ((default-directory "~/Bureau/"))
                   (shell-command-to-string
                    (format "rg -i --no-heading --max-columns 200 --max-count 5 %s *.org | head -c 8000"
                            (shell-quote-argument requete)))))))

  (defvar lateci--outil-note-lire
    (gptel-make-tool
     :name "lire_fichier_note"
     :description "Lit le contenu d'un fichier Org spécifique."
     :args (list '(:name "nom_fichier" :type "string" :description "Nom complet du fichier"))
     :category "lateci"
     :function (lambda (nom_fichier)
                 (let ((chemin (expand-file-name nom_fichier "~/Bureau/")))
                   (if (file-exists-p chemin)
                       (with-temp-buffer
                         (insert-file-contents chemin)
                         (let ((texte (buffer-string)))
                           (substring texte 0 (min 12000 (length texte)))))
                     "Fichier introuvable.")))))

  (defun lateci/gptel-outils (jeu)
    "Active un JEU d'outils : notes ou aucun."
    (interactive (list (intern (completing-read "Outils : " '("notes" "aucun") nil t))))
    (setq gptel-tools
          (pcase jeu
            ('notes (list lateci--outil-notes lateci--outil-note-lire))
            ('aucun nil))
          gptel-use-tools (not (null gptel-tools)))
    (message "Outils gptel : %s" jeu))
  (define-key gptel-mode-map (kbd "C-c w a o") #'lateci/gptel-outils)

  ;; --- Directives ---
  (setf (alist-get 'default gptel-directives)
        "Tu es un grand modèle linguistique vivant dans GUIX OS / EXWM / Emacs. Sois concis, expert en Scheme, Lisp, Org-mode et LaTeX.")

  (setf (alist-get 'correction gptel-directives)
        "Agis comme un correcteur professionnel. Améliore la grammaire, la syntaxe et la clarté du texte en français, sans changer son sens. Ne réponds que par le texte corrigé.")

  (setf (alist-get 'lateci gptel-directives)
        "Tu es l'assistant de l'association LA TECI. Aide à rédiger des courriels et bilans.
Utilise `rechercher_notes_lateci` avant de répondre à une question sur l'association ; approfondis avec `lire_fichier_note` si besoin.
Si la réponse ne se trouve ni dans les notes ni dans le contexte, réponds : 'L'information n'est pas présente dans les documents fournis.'")

  (setf (alist-get 'rag gptel-directives)
        "Assistant strict d'analyse de documents (RAG). Réponds EXCLUSIVEMENT à partir du contexte fourni.
Si la réponse n'y figure pas, réponds : 'L'information n'est pas présente dans les documents fournis.'
Aucune connaissance externe. Concis, cite le document source.")

  (setf (alist-get 'concis gptel-directives)
        "Réponds en français, en 3 phrases maximum. Pas de préambule ni de résumé final.")

  (setf (alist-get 'courriel gptel-directives)
        "Rédige un courriel associatif en français, ton cordial et sobre. Structure : objet, corps court, formule de politesse. Renvoie uniquement le courriel.")

  (setf (alist-get 'code gptel-directives)
        "Expert Emacs Lisp, Guile Scheme, Org, LaTeX et Guix. Renvoie uniquement le code demandé dans un bloc, commentaire uniquement sur demande. Aucune explication hors bloc."))

(with-eval-after-load 'message
  (define-key message-mode-map (kbd "C-c w a e") #'lateci/courriel-region))
  

;;;; DIALOGUE GPTEL DEPUIS LE MINIBUFFER ::::::::::::::::::::::::::::::::::::::

;; --- État isolé : historique, fil, directive, backend/modèle, dernière réponse ---
(defvar lateci--gptel-mb-history nil
  "Historique des invites saisies au minibuffer.")

(defvar lateci--gptel-mb-fil nil
  "Fil de conversation : liste de chaînes alternant utilisateur/assistant.")

(defvar lateci--gptel-mb-derniere nil
  "Dernière réponse reçue, conservée pour récupération ultérieure.")

(defvar lateci-gptel-mb-buffer "*gptel-réponse*"
  "Nom du buffer d'affichage des réponses longues.")

(defvar lateci-gptel-mb-directive 'concis
  "Directive propre aux commandes minibuffer (clé de `gptel-directives').")

(defvar lateci-gptel-mb-backend nil
  "Backend propre au minibuffer ; nil = backend global de gptel.")

(defvar lateci-gptel-mb-model nil
  "Modèle propre au minibuffer ; nil = modèle global de gptel.")

(defvar lateci-gptel-mb-seuil-echo 300
  "Longueur maximale d'une réponse affichée en écho dans le minibuffer.")

;; --- Choix de la directive ---
(defun lateci/gptel-mb-directive (nom)
  "Sélectionne la directive NOM pour les commandes gptel du minibuffer."
  (interactive
   (progn
     (require 'gptel)
     (list (intern (completing-read
                    "Directive minibuffer : "
                    (mapcar (lambda (c) (symbol-name (car c))) gptel-directives)
                    nil t nil nil
                    (symbol-name lateci-gptel-mb-directive))))))
  (setq lateci-gptel-mb-directive nom)
  (message "Directive minibuffer : %s" nom))

;; --- Choix du couple backend/modèle ---
(defun lateci/gptel-mb-modele ()
  "Sélectionne le backend et le modèle propres au minibuffer."
  (interactive)
  (require 'gptel)
  (let* ((cands
          (mapcan
           (lambda (cell)
             (let ((backend (cdr cell)))
               (mapcar (lambda (m)
                         (list (format "%s : %s" (car cell) (gptel--model-name m))
                               backend m))
                       (gptel-backend-models backend))))
           gptel--known-backends))
         (choix (assoc (completing-read "Modèle minibuffer : " cands nil t) cands)))
    (setq lateci-gptel-mb-backend (nth 1 choix)
          lateci-gptel-mb-model   (nth 2 choix))
    (message "Modèle minibuffer : %s" (car choix))))

;; --- Retour au backend/modèle globaux ---
(defun lateci/gptel-mb-modele-defaut ()
  "Rétablit l'usage du backend et du modèle globaux de gptel."
  (interactive)
  (setq lateci-gptel-mb-backend nil
        lateci-gptel-mb-model   nil)
  (message "Minibuffer aligné sur le backend/modèle globaux."))

;; --- Affichage : écho si court (conservé dans *Messages*), buffer Org sinon ---
(defun lateci--gptel-mb-afficher (reponse)
  (setq lateci--gptel-mb-derniere reponse)
  (if (and (< (length reponse) lateci-gptel-mb-seuil-echo)
           (not (string-match-p "\n" reponse)))
      (let ((message-log-max t))
        (message "%s" reponse))
    (with-current-buffer (get-buffer-create lateci-gptel-mb-buffer)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert reponse)
        (goto-char (point-min)))
      (display-buffer (current-buffer))))
  reponse)

;; --- Récupération de la dernière réponse ---
(defun lateci/gptel-mb-recuperer (&optional inserer)
  "Copie la dernière réponse dans le kill-ring ; avec préfixe, l'insère au point."
  (interactive "P")
  (if (not lateci--gptel-mb-derniere)
      (message "Aucune réponse en mémoire.")
    (kill-new lateci--gptel-mb-derniere)
    (if inserer
        (insert lateci--gptel-mb-derniere)
      (message "Réponse copiée (%d caractères)." (length lateci--gptel-mb-derniere)))))

;; --- Ouverture du buffer de réponse ---
(defun lateci/gptel-mb-buffer ()
  "Affiche la dernière réponse dans le buffer Org dédié."
  (interactive)
  (if (not lateci--gptel-mb-derniere)
      (message "Aucune réponse en mémoire.")
    (with-current-buffer (get-buffer-create lateci-gptel-mb-buffer)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert lateci--gptel-mb-derniere)
        (goto-char (point-min))))
    (pop-to-buffer lateci-gptel-mb-buffer)))

;; --- Question ponctuelle sans mémoire ; préfixe = insertion au point ---
(defun lateci/gptel-question (invite &optional inserer)
  "Interroge gptel avec INVITE depuis le minibuffer, sans conserver de fil.
La région active est jointe à l'invite. Avec INSERER, la réponse est
insérée au point plutôt qu'affichée."
  (interactive
   (list (read-string "gptel : " nil 'lateci--gptel-mb-history)
         current-prefix-arg))
  (require 'gptel)
  (let* ((region (and (use-region-p)
                      (buffer-substring-no-properties
                       (region-beginning) (region-end))))
         (texte (if region
                    (format "%s\n\n--- Texte joint ---\n%s" invite region)
                  invite))
         (buf (current-buffer))
         (pos (point))
         ;; Liaisons dynamiques : le payload est bâti ici, l'état global reste intact.
         (gptel-backend (or lateci-gptel-mb-backend gptel-backend))
         (gptel-model   (or lateci-gptel-mb-model   gptel-model)))
    (lateci--start-spinner "gptel")
    (gptel-request texte
      :system (alist-get lateci-gptel-mb-directive gptel-directives)
      :callback
      (lambda (reponse info)
        (if (not (stringp reponse))
            (lateci--stop-spinner (format "Échec : %s" (plist-get info :status)))
          (lateci--stop-spinner "gptel ✔")
          (setq lateci--gptel-mb-derniere reponse)
          (if inserer
              (with-current-buffer buf
                (save-excursion (goto-char pos) (insert reponse)))
            (lateci--gptel-mb-afficher reponse)))))))

;; --- Dialogue suivi : le fil complet est renvoyé à chaque tour ---
(defun lateci/gptel-dialogue (invite)
  "Poursuit un dialogue gptel depuis le minibuffer avec INVITE."
  (interactive
   (list (read-string (if lateci--gptel-mb-fil
                          "gptel (suite) : "
                        "gptel (nouveau) : ")
                      nil 'lateci--gptel-mb-history)))
  (require 'gptel)
  (setq lateci--gptel-mb-fil (append lateci--gptel-mb-fil (list invite)))
  (let ((gptel-backend (or lateci-gptel-mb-backend gptel-backend))
        (gptel-model   (or lateci-gptel-mb-model   gptel-model)))
    (lateci--start-spinner "gptel")
    (gptel-request (copy-sequence lateci--gptel-mb-fil)
      :system (alist-get lateci-gptel-mb-directive gptel-directives)
      :callback
      (lambda (reponse info)
        (if (not (stringp reponse))
            (lateci--stop-spinner (format "Échec : %s" (plist-get info :status)))
          (setq lateci--gptel-mb-fil (append lateci--gptel-mb-fil (list reponse)))
          (lateci--stop-spinner "gptel ✔")
          (lateci--gptel-mb-afficher reponse)
          (when (y-or-n-p "Poursuivre le dialogue ? ")
            (call-interactively #'lateci/gptel-dialogue)))))))

;; --- Réinitialisation du fil ---
(defun lateci/gptel-dialogue-reset ()
  "Vide le fil de conversation du minibuffer."
  (interactive)
  (setq lateci--gptel-mb-fil nil)
  (message "Fil gptel réinitialisé."))

;; --- État courant ---
(defun lateci/gptel-mb-etat ()
  "Affiche directive, modèle et longueur du fil du minibuffer."
  (interactive)
  (require 'gptel)
  (message "Directive : %s | Modèle : %s | Fil : %d tour(s) | Réponse : %s"
           lateci-gptel-mb-directive
           (gptel--model-name (or lateci-gptel-mb-model gptel-model))
           (/ (length lateci--gptel-mb-fil) 2)
           (if lateci--gptel-mb-derniere "en mémoire" "aucune")))

;; --- Raccourcis ---
(keymap-global-set "C-c w a q" #'lateci/gptel-question)
(keymap-global-set "C-c w a t" #'lateci/gptel-dialogue)
(keymap-global-set "C-c w a T" #'lateci/gptel-dialogue-reset)
(keymap-global-set "C-c w a y" #'lateci/gptel-mb-recuperer)
(keymap-global-set "C-c w a b" #'lateci/gptel-mb-buffer)
(keymap-global-set "C-c w a D" #'lateci/gptel-mb-directive)
(keymap-global-set "C-c w a M" #'lateci/gptel-mb-modele)
(keymap-global-set "C-c w a G" #'lateci/gptel-mb-modele-defaut)
(keymap-global-set "C-c w a ?" #'lateci/gptel-mb-etat)

;;; COMPTABILITÉ ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

(defvar lateci-comptabilite-directory
  (expand-file-name "~/Bureau/compta/")
  "Répertoire contenant les journaux comptables.")

(defvar lateci-comptabilite-file
  (expand-file-name
   (format "%s.ledger" (format-time-string "%Y"))
   lateci-comptabilite-directory)
  "Journal Ledger de l’exercice courant.")

(use-package ledger-mode
  :mode ("\\.ledger\\'" . ledger-mode)
  :custom
  (ledger-default-date-format "%Y-%m-%d")
  (ledger-post-amount-alignment-column 72)
  (ledger-post-account-alignment-column 4)
  (ledger-report-use-native-highlighting t)
  (ledger-reports
  '(("balance" "%(binary) -f %(ledger-file) balance")
   ("registre" "%(binary) -f %(ledger-file) register")
   ("écritures" "%(binary) -f %(ledger-file) print")
   ("résultat" "%(binary) -f %(ledger-file) balance '^(Charges|Produits):'")
   ("banque" "%(binary) -f %(ledger-file) register '^Actif:512-Banque'")
   ("caisse" "%(binary) -f %(ledger-file) register '^Actif:530-Caisse'")
   ("charges" "%(binary) -f %(ledger-file) register '^Charges:'")
   ("produits" "%(binary) -f %(ledger-file) register '^Produits:'")
   ("mensuel" "%(binary) -f %(ledger-file) register --monthly")
   ("Softerie"
 "%(binary) -f %(ledger-file) balance '^(Charges|Produits):' --limit 'tag(\"praticable\") =~ /^Softerie/'")

("Softerie — Fluxus"
 "%(binary) -f %(ledger-file) balance '^(Charges|Produits):' --limit 'tag(\"praticable\") == \"Softerie/Fluxus\"'")
("client — Ville de Blois"
 "%(binary) -f %(ledger-file) register --limit 'tag(\"Client\") == \"Ville-de-Blois\"'")

("fournisseur — Biocoop"
 "%(binary) -f %(ledger-file) register --limit 'tag(\"Fournisseur\") == \"Biocoop\"'")
   ("comptes" "%(binary) -f %(ledger-file) accounts")
   ("bénéficiaires" "%(binary) -f %(ledger-file) payees")))

  :config
(setq ledger-master-file lateci-comptabilite-file)

(defun lateci--ledger-master-courant ()
  "Prend le fichier visité comme journal maître."
  (when buffer-file-name
    (setq-local ledger-master-file buffer-file-name)))

(add-hook 'ledger-mode-hook #'lateci--ledger-master-courant)
  :bind
  (:map ledger-mode-map
        ("C-c C-a" . ledger-add-transaction)
        ("C-c C-r" . ledger-report)
        ("C-c C-c" . ledger-mode-clean-buffer)))

(defun lateci/comptabilite ()
  "Ouvre le journal comptable de l'exercice courant."
  (interactive)
  (make-directory lateci-comptabilite-directory t)
  (find-file lateci-comptabilite-file))

(defun lateci/comptabilite-verifier ()
  "Vérifie l'équilibre et la syntaxe du journal courant."
  (interactive)
  (unless (derived-mode-p 'ledger-mode)
    (user-error "Cette commande doit être lancée depuis un fichier Ledger"))
  (save-buffer)
  (compilation-start
   (format "ledger -f %s balance"
           (shell-quote-argument buffer-file-name))
   'compilation-mode
   (lambda (_) "*Vérification comptable*")))

(defun lateci/comptabilite-export-csv ()
  "Exporte le registre comptable courant au format CSV."
  (interactive)
  (let* ((journal lateci-comptabilite-file)
         (destination
          (expand-file-name
           (format-time-string "%Y-registre.csv")
           lateci-comptabilite-directory)))
    (make-directory lateci-comptabilite-directory t)
    (unless (file-exists-p journal)
      (user-error "Journal inexistant : %s" journal))
    (with-temp-file destination
      (let ((status
             (call-process "ledger" nil t nil
                           "-f" journal
                           "csv")))
        (unless (zerop status)
          (user-error "Échec de l'export Ledger"))))
    (message "Registre exporté : %s" destination)
    (find-file destination)))

;; Préfixe comptabilité : C-c $
(defvar-keymap lateci-comptabilite-map
  :doc "Commandes de comptabilité."
  "o" #'lateci/comptabilite
  "v" #'lateci/comptabilite-verifier
  "r" #'ledger-report
  "e" #'lateci/comptabilite-export-csv)

(keymap-global-set "C-c $" lateci-comptabilite-map)

(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "C-c $"   "Comptabilité"
    "C-c $ o" "ouvrir le journal"
    "C-c $ v" "vérifier le journal"
    "C-c $ r" "rapports"
    "C-c $ e" "exporter en CSV"))


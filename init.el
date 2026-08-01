;; -*- lexical-binding: t; -*-
;;; BASE ::::::::::::::::::::::::::::::::::::::::::::::::::::
(setq server-socket-dir (expand-file-name "server" user-emacs-directory))
(setenv "EMACS_SOCKET_NAME" (expand-file-name "server" server-socket-dir))
(require 'server)
(unless (server-running-p)
  (server-start))

;;;; Emacs 29 available?
(when (< emacs-major-version 29)
  (error "Emacs Writing Studio requires version 29 or later"))

;;Synchronise le kill-ring avec le CLIPBOARD X11
(setq select-enable-clipboard t)
;;Synchronise le kill-ring avec la sélection PRIMARY X11
(setq select-enable-primary t)

;;;; Package Management
(setq use-package-always-ensure nil
      package-native-compile t
      native-comp-async-report-warnings-errors 'silent)
(setq use-package-compute-statistics (and (getenv "LATECI_STATS") t))
(require 'use-package)

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


(defvar ews-bibtex-files nil
  "Repli lorsque ews.el est absent : aucune bibliographie.")
(defvar ews-bibtex-directory nil
  "Repli lorsque ews.el est absent.")

;;;; IDENTITÉ ET DONNÉES PRIVÉES :::::::::::::::::::::::::::::::::::::::::::::
;;
;; Ce qui décrit l'association vit ici, en un seul endroit, plutôt que recopié
;; dans chaque modèle de document.
;;
;; Les valeurs qui n'ont pas leur place dans un dépôt public — coordonnées
;; bancaires, adresse postale, téléphone, courriel personnel — portent
;; ci-dessous une valeur de démonstration.  Les valeurs réelles vivent dans
;; ~/.config/lateci/prive.el, hors du dépôt, chargé plus bas s'il existe.
;; Voir prive.el.exemple pour le modèle.

(require 'cl-lib)

;;;;; --- Identité publique ---

(defvar lateci-org-nom "LA TECI"
  "Nom d'usage de l'association, tel qu'il s'imprime en tête des documents.")

(defvar lateci-org-raison-sociale
  "Association Terrain d'Expérimentation de Créations \\& d'Initiatives"
  "Dénomination complète.  Échappée pour LaTeX : le « & » y porte sa barre.")

(defvar lateci-org-courriel "lateci@club1.fr"
  "Adresse de courriel de l'association.")

(defvar lateci-org-site "https://lateci.club1.fr"
  "Site public de l'association.")

(defvar lateci-org-logo "~/Bureau/logo.jpg"
  "Logo imprimé en tête des devis et factures, ou nil pour s'en passer.")

(defvar lateci-org-couleur "40, 80, 120"
  "Couleur institutionnelle, en composantes RVB pour \\definecolor.")

;;;;; --- Données privées : valeurs de démonstration ---

(defvar lateci-org-adresse '("1 rue de l'Exemple" "00000 VILLE")
  "Adresse postale du siège, une chaîne par ligne imprimée.")

(defvar lateci-org-siret "00000000000000"
  "Numéro SIRET de l'association.")

(defvar lateci-org-ape "00.00Z"
  "Code APE de l'association.")

(defvar lateci-banque-iban "FR76 0000 0000 0000 0000 0000 000"
  "IBAN imprimé en pied de devis et de facture.")

(defvar lateci-banque-bic "XXXXXXXX"
  "BIC imprimé en pied de devis et de facture.")

(defvar lateci-tel "+33 0 00 00 00 00"
  "Téléphone repris dans la signature de courriel.")

(defvar lateci-courriel-perso "personne@exemple.org"
  "Adresse personnelle, distincte de celle de l'association.")

;;;;; --- Chargement du fichier privé ---

(defvar lateci-prive-fichier
  (expand-file-name "lateci/prive.el"
                    (or (getenv "XDG_CONFIG_HOME") "~/.config"))
  "Fichier des valeurs privées, hors du dépôt.

Il est délibérément placé hors de `user-emacs-directory' : celui-ci peut
être effacé ou recloné, ce qui emporterait le fichier avec lui.")

(if (file-exists-p lateci-prive-fichier)
    (load lateci-prive-fichier nil :sans-message)
  (display-warning
   'lateci
   (format "%s est absent : les documents s'impriment avec des coordonnées de démonstration.
Copier prive.el.exemple vers ce chemin pour rétablir les vraies valeurs."
           lateci-prive-fichier)
   :warning))

;;;; DOCUMENTS COMMERCIAUX ::::::::::::::::::::::::::::::::::::::::::::::::::::
;;
;; Devis, facture et reçu partagent leur en-tête, leur pied et leur mise en
;; page.  Ils sont donc assemblés à partir de fragments communs plutôt que
;; recopiés : chaque coordonnée de l'association n'apparaît qu'une fois.

(defvar usr--devis-client "")
(defvar usr--devis-num "")
(defvar usr--devis-tags "")

(defvar usr--facture-client "")
(defvar usr--facture-num "")
(defvar usr--facture-tags "")

(defvar usr--recu-client "")
(defvar usr--recu-num "")
(defvar usr--recu-tags "")

(defconst lateci--latex-couleur-nom "lateciblue"
  "Nom LaTeX de la couleur institutionnelle.")

(defun lateci--numero-suivant (genre)
  "Numéro suivant pour GENRE (\"devis\", \"facture\", \"recu\").
Le compteur repart à 01 à chaque nouvelle année.  Il est conservé dans
GENRE-counter.el, au sein de `user-emacs-directory'."
  (let* ((fichier (expand-file-name (format "%s-counter.el" genre)
                                    user-emacs-directory))
         (annee (format-time-string "%Y"))
         (etat (if (file-exists-p fichier)
                   (with-temp-buffer
                     (insert-file-contents fichier)
                     (read (current-buffer)))
                 '("" . 0)))
         (rang (if (string= annee (car etat)) (1+ (cdr etat)) 1)))
    (with-temp-file fichier
      (insert (prin1-to-string (cons annee rang))))
    (format "%02d" rang)))

(defun lateci--document-cible (genre invite-client invite-tags)
  "Fonction cible d'un modèle de capture, pour GENRE.
Demande le client puis les mots-clés, tire le numéro suivant et renvoie le
chemin du fichier Org à créer."
  (let ((v-client (intern (format "usr--%s-client" genre)))
        (v-num    (intern (format "usr--%s-num" genre)))
        (v-tags   (intern (format "usr--%s-tags" genre))))
    (lambda ()
      (set v-client (read-string invite-client))
      (let ((saisie (read-string invite-tags)))
        (set v-tags (if (string-empty-p saisie)
                        genre
                      (concat genre "_"
                              (replace-regexp-in-string
                               "[^[:alnum:]]+" "_" (downcase saisie))))))
      (set v-num (lateci--numero-suivant genre))
      (expand-file-name
       (format "%s--%s-%s__%s.org"
               (format-time-string "%Y%m%dT%H%M%S")
               (replace-regexp-in-string
                "[^[:alnum:]]+" "-" (downcase (symbol-value v-client)))
               (symbol-value v-num)
               (symbol-value v-tags))
       "~/Bureau/"))))

(defun lateci--latex-emetteur (couleur)
  "Bloc LaTeX de l'émetteur : logo, nom, adresse, contacts.
Avec COULEUR, le nom est teinté et le logo présent ; sans, le bloc est sobre."
  (concat
   "\\begin{minipage}[t]{0.5\\textwidth}\n"
   (if couleur
       (concat
        "  \\vspace{-1cm} % Alignement vertical\n"
        (if lateci-org-logo
            (concat "  \\includegraphics[width=4cm]{"
                    (expand-file-name lateci-org-logo)
                    "} \\\\[0.5em] % <-- DÉCOMMENTER POUR LE LOGO\n")
          "")
        "  {\\LARGE \\textbf{\\textcolor{" lateci--latex-couleur-nom "}{"
        lateci-org-nom "}}} \\\\[0.5em]\n")
     (concat
      "  \\vspace{-1cm}\n"
      "  {\\LARGE \\textbf{" lateci-org-nom "}} \\\\[0.5em]\n"))
   (mapconcat (lambda (ligne) (concat "  " ligne " \\\\\n"))
              (butlast lateci-org-adresse) "")
   "  " (car (last lateci-org-adresse)) " \\\\[0.5em]\n"
   "  " lateci-org-courriel " \\\\\n"
   "  " lateci-org-site "\n"
   "\\end{minipage}%\n"))

(defun lateci--latex-identite-legale ()
  "Deux lignes LaTeX : dénomination complète, puis SIRET et code APE."
  (concat
   "  " lateci-org-raison-sociale " \\\\\n"
   "  SIRET : " lateci-org-siret " | APE : " lateci-org-ape " \\\\\n"))

(defun lateci--latex-coordonnees-bancaires ()
  "Pied de page droit des devis et factures : identité légale et banque."
  (concat
   "  \\textbf{Coordonnées bancaires} \\\\[0.2em]\n"
   (lateci--latex-identite-legale)
   "  IBAN : \\texttt{" lateci-banque-iban "} \\\\\n"
   "  BIC : \\texttt{" lateci-banque-bic "}\n"))

(defun lateci--latex-identifiant-association ()
  "Pied de page droit des reçus : identité légale seule, sans banque."
  (concat
   "  \\textbf{Identifiant association} \\\\[0.2em]\n"
   (lateci--latex-identite-legale)))

(defconst lateci--latex-conditions-paiement
  (concat
   "  \\textbf{Conditions de paiement} \\\\[0.2em]\n"
   "  Délai de paiement : 30 jours à date d'émission. \\\\\n"
   "  Règlement par Chèque ou virement bancaire. \\\\\n"
   "  Escompte pour règlement anticipé : 0\\textpercent{%} \\\\\n"
   "  \\\\\n"
   "  TVA non applicable art. 293b du CGI. \\\\\n"
   "  \\\\\n"
   "  En cas de retard de paiement, une pénalité égale à 3 fois le taux d'intérêt légal sera exigible \\\\\n"
   "  \\texttt{\\textit{Décret 2009-138 du 9 février 2009}} \\\\\n"
   "  \\\\\n"
   "  Pour les professionnels, une indemnité minimum forfaitaire de 40 euros pour frais de recouvrement sera exigible \\\\\n"
   "  \\texttt{\\textit{Décret 2012-1115 du 9 octobre 2012}}\n")
  "Mentions légales de paiement, communes au devis et à la facture.")

(defconst lateci--latex-tableau-prestations
  (concat
   "#+ATTR_LATEX: :align p{8.5cm} c r r :placement [h]\n"
   "| Description de la prestation | Qté | Prix U. (HT) | Total (HT) |\n"
   "|------------------------------+-----+--------------+------------|\n"
   "| %?                           |   1 |            0 |          0 |\n"
   "|------------------------------+-----+--------------+------------|\n"
   "| *TOTAL*                      |     |              |          0 |\n")
  "Tableau de prestations du devis et de la facture, sans sa ligne #+TBLFM.")

(cl-defun lateci--document
    (&key touche type genre invite-client invite-tags objet
          couleur police boite etiquette tableau tblfm
          pied-gauche pied-droit signature)
  "Assemble le modèle de capture Org d'un document commercial.

TOUCHE et TYPE nomment l'entrée ; GENRE sert de préfixe aux variables
`usr--GENRE-num' et consorts, et de racine au fichier compteur.  COULEUR
active le logo et la teinte institutionnelle ; POLICE ajoute un paquet
LaTeX.  BOITE encadre l'adresse du destinataire, ETIQUETTE le désigne."
  (let ((num    (concat "%(identity usr--" genre "-num)"))
        (client (concat "%(identity usr--" genre "-client)")))
    (list
     touche type 'plain
     (list 'file (lateci--document-cible genre invite-client invite-tags))
     (concat
      ;; --- Préambule Org et LaTeX ---
      "#+TITLE: " type " %<%Y%m%d>-" num "\n"
      "#+AUTHOR: " lateci-org-nom "\n"
      "#+OPTIONS: num:nil title:nil toc:nil\n"
      "#+LATEX_CLASS: article\n"
      "#+LATEX_CLASS_OPTIONS: [11pt, a4paper]\n"
      "#+LATEX_HEADER: \\usepackage[margin=2cm]{geometry}\n"
      (if police (concat "#+LATEX_HEADER: \\usepackage{" police "}\n") "")
      "#+LATEX_HEADER: \\usepackage{graphicx}\n"
      (if couleur
          (concat
           "#+LATEX_HEADER: \\usepackage{xcolor}\n"
           "#+LATEX_HEADER: \\definecolor{" lateci--latex-couleur-nom
           "}{RGB}{" lateci-org-couleur "} % Couleur institutionnelle\n"
           "#+LATEX_HEADER: \\pagestyle{empty} % Suppression de la numérotation des pages\n")
        "#+LATEX_HEADER: \\pagestyle{empty}\n")
      "\n"
      ;; --- En-tête ---
      "#+BEGIN_EXPORT latex\n"
      "% --------------------------------------------------------\n"
      "% EN-TÊTE\n"
      "% --------------------------------------------------------\n"
      (lateci--latex-emetteur couleur)
      "\\begin{minipage}[t]{0.5\\textwidth}\n"
      "  \\begin{flushright}\n"
      "    \\vspace{-1cm}\n"
      "    {\\Huge \\textbf{"
      (if couleur (concat "\\textcolor{" lateci--latex-couleur-nom "}{" type "}") type)
      "}} \\\\[0.5em]\n"
      "    \\textbf{Numéro :} %<%Y%m%d>-" num " \\\\\n"
      "    \\textbf{Date :} %<%d %B %Y> \\\\[1.5em]\n"
      boite
      "      \\begin{minipage}{0.8\\textwidth}\n"
      "        \\vspace{0.2cm}\n"
      "        \\textbf{" etiquette "} \\\\\n"
      "        \\textbf{" client "} \\\\\n"
      "        %^{Adresse du Client}\n"
      "        \\vspace{0.2cm}\n"
      "      \\end{minipage}\n"
      "    }\n"
      "  \\end{flushright}\n"
      "\\end{minipage}\n"
      "\n"
      "\\vspace{1.5cm}\n"
      "#+END_EXPORT\n"
      "\n"
      ;; --- Corps ---
      "* Objet : " objet "\n"
      "\n"
      tableau
      "#+TBLFM: " tblfm "\n"
      "\n"
      ;; --- Pied ---
      "#+BEGIN_EXPORT latex\n"
      "\\vspace{1cm}\n"
      "\\rule{\\textwidth}{0.4pt}\n"
      "\\vspace{0.5cm}\n"
      (if couleur "\n" "")
      "% --------------------------------------------------------\n"
      "% PIED DE DOCUMENT\n"
      "% --------------------------------------------------------\n"
      "\\noindent\n"
      "\\begin{minipage}[t]{0.45\\textwidth}\n"
      "  \\small\n"
      pied-gauche
      "\\end{minipage}%\n"
      "\\hfill\n"
      "\\begin{minipage}[t]{0.45\\textwidth}\n"
      "  \\small\n"
      pied-droit
      "\\end{minipage}\n"
      "\n"
      "\\vspace{2cm}\n"
      "\n"
      ;; --- Signature ---
      "% --------------------------------------------------------\n"
      "% ZONE DE SIGNATURE\n"
      "% --------------------------------------------------------\n"
      "\\hfill\n"
      "\\begin{minipage}[t]{0.45\\textwidth}\n"
      "  \\centering\n"
      signature
      "  \\rule{6cm}{0.4pt}\n"
      "\\end{minipage}\n"
      "#+END_EXPORT\n")
     :jump-to-captured t)))

(defun lateci--modele-devis ()
  "Modèle de capture du devis."
  (lateci--document
   :touche "d" :type "DEVIS" :genre "devis"
   :invite-client "Nom du client : "
   :invite-tags "Tags additionnels (optionnels, ex: asso formation) : "
   :objet "%^{Objet du devis}"
   :couleur t
   :boite (concat "    % Boîte d'adresse du destinataire\n"
                  "    \\colorbox{gray!10}{\n")
   :etiquette "Destinataire"
   :tableau lateci--latex-tableau-prestations
   :tblfm "$4=$2*$3::@3$4=vsum(@2$4..@-1$4);%.2f"
   :pied-gauche (concat lateci--latex-conditions-paiement "\n")
   :pied-droit (lateci--latex-coordonnees-bancaires)
   :signature (concat "  \\textbf{Bon pour accord} \\\\\n"
                      "  \\textit{Date, signature et cachet du client} \\\\[2.5cm]\n")))

(defun lateci--modele-facture ()
  "Modèle de capture de la facture."
  (lateci--document
   :touche "F" :type "FACTURE" :genre "facture"
   :invite-client "Nom du client : "
   :invite-tags "Tags additionnels (optionnels) : "
   :objet "%^{Objet de la facture}"
   :couleur t
   :boite (concat "    % Boîte d'adresse du destinataire\n"
                  "    \\colorbox{gray!10}{\n")
   :etiquette "Destinataire"
   :tableau lateci--latex-tableau-prestations
   :tblfm "$4=$2*$3;N :: @>$4=vsum(@I..@II);%.2f"
   :pied-gauche lateci--latex-conditions-paiement
   :pied-droit (lateci--latex-coordonnees-bancaires)
   :signature "  \\textit{Cachet et signature de l'association} \\\\[2.5cm]\n"))

(defun lateci--modele-recu ()
  "Modèle de capture du reçu."
  (lateci--document
   :touche "u" :type "REÇU" :genre "recu"
   :invite-client "Nom du payeur : "
   :invite-tags "Tags additionnels (optionnels) : "
   :objet "%^{Nature du paiement (ex: Adhésion, Don)}"
   :couleur nil
   :police "ebgaramond"
   :boite "    \\fbox{\n"
   :etiquette "Payeur :"
   :tableau (concat
             "#+ATTR_LATEX: :align p{8.5cm} c r r :placement [h]\n"
             "| Description                                  | Qté | Prix U. (HT) | Total (HT) |\n"
             "|----------------------------------------------+-----+--------------+------------|\n"
             "| %?                                           |   1 |            0 |          0 |\n"
             "|----------------------------------------------+-----+--------------+------------|\n"
             "| *TOTAL RÉGLÉ*                                |     |              |          0 |\n")
   :tblfm "$4=$2*$3;N :: @>$4=vsum(@I..@II);%.2f"
   :pied-gauche (concat
                 "  \\textbf{Détail du règlement} \\\\[0.2em]\n"
                 "  Reçu le : %^{Date de règlement (ex:%<%d %B %Y>)} \\\\\n"
                 "  Moyen de paiement : %^{Moyen de paiement (ex: Chèque, Virement, Espèces)} \\\\\n"
                 "  \\textit{Ce document atteste la bonne réception des fonds pour solde de tout compte.}\n")
   :pied-droit (lateci--latex-identifiant-association)
   :signature "  \\textit{Pour acquit, signature du trésorier/représentant} \\\\[2.5cm]\n"))


;;;; Org-mode
(use-package org
  :ensure nil
  :demand t
  
  :init
  ;; Fichiers sources pour l'agenda et la capture
  (setq org-default-notes-file "~/Bureau/Notes.org")
  (setq org-agenda-files
        '("~/Bureau/Notes.org"         
          "~/Bureau/FP6.org"))

  
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

  ;; Les notes vocales pointent leur audio par un lien « file: ».  Sans cette
  ;; association, un clic ouvrirait le fichier en binaire dans un tampon.
  (org-file-apps
   '((remote . emacs)
     (auto-mode . emacs)
     (directory . emacs)
     ("\\.\\(wav\\|mp3\\|m4a\\|ogg\\|oga\\|opus\\|flac\\|aac\\|amr\\)\\'" . "mpv --really-quiet %s")
     ("\\.x?html?\\'" . default)
     ("\\.pdf\\'" . default)))
  
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
   `(("f" "Fleeting note" item (file+headline org-default-notes-file "Notes") "- %?")
     ("j" "Journal Interstitiel" entry (file denote-journal-path-to-new-or-existing-entry) "* %<%H:%M>\n** DONE %?\n** NEXT " :empty-lines 1)
     ("n" "Permanent note" plain (file denote-last-path) #'denote-org-capture :no-save t :immediate-finish nil :kill-buffer t :jump-to-captured t)

     ;; Notes vocales : la cible enregistre (ou récupère l'enregistrement qui
     ;; vient de s'achever), dépose l'audio dans le Bureau au format Denote et
     ;; pose le squelette.  Voir la section NOTE VOCALE.
     ("v" "Note vocale" plain (function usr--vocale-cible-note) "%?"
      :empty-lines 0 :kill-buffer nil :jump-to-captured t)
     ("V" "Note vocale brève" item (function usr--vocale-cible-notes)
      "- %<%Y-%m-%d %H:%M> %(usr--vocale-lien-org) %?" :empty-lines 0)

     ("i" "NEXT" entry (file+headline org-default-notes-file "Tasks") "* NEXT %i%?")
     ("t" "TODO" entry (file+headline org-default-notes-file "Tasks") "* TODO %i%?")
     ("R" "RU" entry (file+headline org-default-notes-file "Tasks") "* RU %i%?")
     ("r" "RDV" entry (file+headline org-default-notes-file "Tasks") "* RDV %i%?")
     ("p" "PRATOS" entry (file+headline org-default-notes-file "Tasks") "* PRATOS %i%?")
     ("e" "EVNT" entry (file+headline org-default-notes-file "Tasks") "* EVNT %i%?")

     ;; ------------------------------------------------------
     ;; DOCUMENTS COMMERCIAUX
     ;; Assemblés depuis la section du même nom, plus haut : l'identité de
     ;; l'association n'est écrite qu'à un seul endroit.
     ;; ------------------------------------------------------
     ,(lateci--modele-devis)
     ,(lateci--modele-facture)
     ,(lateci--modele-recu))))

  

;;; LOOK AND FEEL :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

(setq ring-bell-function 'ignore)

;;;; Modus and EF Themes
(use-package modus-themes
  :ensure nil
  :init
  (mapc #'disable-theme (copy-sequence custom-enabled-themes))
  (load-theme 'modus-operandi t)
  
  :custom
  (modus-themes-italic-constructs t)
  (modus-themes-bold-constructs t)
  (modus-themes-mixed-fonts t)
  (modus-themes-to-toggle '(modus-operandi
			    modus-vivendi)))

(setq inhibit-splash-screen t)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)

(set-fringe-mode 0) ;; Supprime les bandes grises sur les bords de l'écran

(setq window-divider-default-right-width 10   ;; Espace vertical entre fenêtres côte à côte
      window-divider-default-bottom-width 10) ;; Espace horizontal entre fenêtres superposées
(window-divider-mode 1)

(defun usr--set-face (face &rest attributs)
  "Applique ATTRIBUTS à FACE, si FACE existe.
La garde évite d'échouer sur les faces d'un paquet non encore chargé."
  (when (facep face)
    (apply #'set-face-attribute face nil attributs)))

(defun usr-appliquer-faces (&rest _)
  "Applique les retouches de faces propres à cette configuration.
Rejouée à chaque activation de thème via `enable-theme-functions'."
  (let ((fond (face-attribute 'default :background)))

    ;; --- Taille de police globale ---
    (usr--set-face 'default :height 120)

    ;; --- Séparateurs fondus dans le fond ---
    ;; Pour une ligne fine visible, remplacer `fond' par "grey50".
    (usr--set-face 'vertical-border :foreground fond)
    (usr--set-face 'internal-border :background fond)
    (dolist (face '(window-divider
                    window-divider-first-pixel
                    window-divider-last-pixel))
      (usr--set-face face :foreground fond))

    ;; --- Modeline ---
    ;; mode-line-active est le paramètre distinct d'Emacs 29+ ; mode-line reste
    ;; réglée pour les faces qui en héritent.
    (usr--set-face 'mode-line :height 0.90)
    (usr--set-face 'mode-line-active :height 0.90)
    ;; Modeline inactive masquée : texte et fond à la couleur du fond d'Emacs.
    (usr--set-face 'mode-line-inactive
                      :foreground fond
                      :background fond
                      :box nil
                      :overline nil
                      :underline nil)

    ;; --- Org : hiérarchie des titres ---
    (usr--set-face 'org-document-title :height 1.5  :weight 'bold)
    (usr--set-face 'org-level-1        :height 1.3  :weight 'bold)
    (usr--set-face 'org-level-2        :height 1.2  :weight 'bold)
    (usr--set-face 'org-level-3        :height 1.1  :weight 'semi-bold)
    (usr--set-face 'org-level-4        :height 1.05)
    (usr--set-face 'org-level-5        :height 1.0)
    (usr--set-face 'org-level-6        :height 1.0)

    ;; --- Org : étiquettes et horodatages ---
    (usr--set-face 'org-tag
                      :box '(:line-width 1 :color "grey50")
                      :height 0.8
                      :weight 'normal)
    (usr--set-face 'org-date
                      :box '(:line-width 1 :color "grey70")
                      :underline nil)

    ;; --- Calendrier ---
    ;; `:inherit' de faces sémantiques (highlight, error, success) plutôt que
    ;; des couleurs littérales : elles suivent le thème. L'ancienne version
    ;; codait « white sur dark blue » et « firebrick », illisibles en sombre.
    (usr--set-face 'calendar-today :inherit 'highlight :weight 'bold)
    (usr--set-face 'calendar-weekend-header :inherit 'error)
    (usr--set-face 'calendar-month-header :weight 'bold :height 1.2)
    (usr--set-face 'diary :inherit 'success :weight 'bold)))

;; Rejouée à chaque activation de thème (Emacs 29+).
(add-hook 'enable-theme-functions #'usr-appliquer-faces)

;; Les faces du calendrier n'existent qu'une fois leur paquet chargé : on
;; rejoue alors la fonction pour qu'elles ne soient pas laissées de côté.
(with-eval-after-load 'calendar (usr-appliquer-faces))
(with-eval-after-load 'diary-lib (usr-appliquer-faces))

;; Application initiale : le thème est chargé plus haut.
(usr-appliquer-faces)

;;;; Short answers only please
(setq-default use-short-answers t)

;;;; Scratch buffer settings
(setq inhibit-startup-screen t)
(setq initial-buffer-choice (lambda () (get-buffer "*Messages*")))

(defun usr--tuer-scratch ()
  "Supprime le tampon *scratch* au démarrage."
  (when (get-buffer "*scratch*")
    (kill-buffer "*scratch*")))

(add-hook 'emacs-startup-hook #'usr--tuer-scratch)

(defun usr--garder-un-tampon ()
  "Bascule sur *Messages* lorsque le dernier tampon visible est tué."
  (unless (seq-some (lambda (buf)
                      (let ((name (buffer-name buf)))
                        (and (not (string-prefix-p " " name))
                             (not (eq buf (current-buffer))))))
                    (buffer-list))
    (switch-to-buffer "*Messages*")))

(add-hook 'kill-buffer-hook #'usr--garder-un-tampon)

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
  (("C-x b" . consult-buffer))
  :config
  (add-to-list 'consult-preview-allowed-hooks 'visual-line-mode)
  
  ;; --- Catégorie dédiée pour les applications X11 (EXWM) ---
  (defvar usr--consult-source-exwm
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
  (add-to-list 'consult-buffer-sources 'usr--consult-source-exwm 'append))

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
  ;; Tri par touche et non par description : les préfixes ne sont plus
  ;; éparpillés au milieu des commandes.
  (which-key-sort-order 'which-key-key-order-alpha)
  (which-key-idle-delay 0.4)
  (which-key-add-column-padding 2))

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
  ((org-mode . flyspell-mode)
   (message-mode . flyspell-mode)
   (notmuch-message-mode . flyspell-mode))
  :bind
  (("C-;" . flyspell-auto-correct-previous-word)))

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

(with-eval-after-load 'org
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
(defvar usr--reseau-online nil)
(defvar usr--gpg-unlocked nil)
(defvar usr--ssh-mounted nil)
(defvar usr--syncthing-online nil)
(defvar usr--hydroxide-online nil)
(defvar usr--system-status-string " ")

(or global-mode-string (setq global-mode-string '("")))
(unless (memq 'usr--system-status-string global-mode-string)
  (setq global-mode-string (append global-mode-string '(usr--system-status-string))))

(defun usr--actualiser-affichage ()
  "Met à jour l’état système uniquement s’il a changé."
  (let* ((symboles
          (delq nil
                (list (when usr--gpg-unlocked "gpg")
                      (when usr--reseau-online "net")
                      (when usr--ssh-mounted "srv")
                      (when usr--syncthing-online "lan")
                      (when usr--hydroxide-online "eml"))))
         (nouveau
          (if symboles
              (format "[%s] " (mapconcat #'identity symboles " "))
            " ")))
    (unless (equal nouveau usr--system-status-string)
      (setq usr--system-status-string nouveau)
      (force-mode-line-update t))))
 
(defun usr--network-online-p ()
  "Vérifie localement si une route par défaut active existe (sans envoyer de paquets)."
  (let ((route-file "/proc/net/route"))
    (and (file-exists-p route-file)
         (with-temp-buffer
           (insert-file-contents route-file)
           (goto-char (point-min))
           ;; Cherche '00000000' dans la colonne Destination (indique la passerelle par défaut)
           (not (null (re-search-forward "^[a-z0-9]+\\s-+00000000\\s-+" nil t)))))))

(defun usr--monte-p (point-de-montage)
  "Vrai si POINT-DE-MONTAGE figure dans /proc/mounts.
Lecture en Lisp pur, sans lancer de processus — même approche que
`usr--network-online-p'."
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

(defun usr--processus-actif-p (nom)
  "Retourne non-nil si un processus dont la commande est NOM existe."
  (seq-some
   (lambda (pid)
     (when-let ((attributs (process-attributes pid)))
       (string= (alist-get 'comm attributs) nom)))
   (list-system-processes)))

(defun usr--verifier-systeme ()

  (setq usr--gpg-unlocked nil)
  (make-process
   :name "gpg-check" :buffer nil :noquery t
   :command '("gpg-connect-agent" "keyinfo --list" "/bye")
   :filter (lambda (_proc output)
             (when (string-match-p "KEYINFO .*\\b1\\b" output)
               (setq usr--gpg-unlocked t)))
   :sentinel (lambda (_proc _event) (usr--actualiser-affichage)))

  (setq usr--syncthing-online
	(usr--processus-actif-p "syncthing")
	usr--hydroxide-online
	(usr--processus-actif-p "hydroxide")
	usr--reseau-online
	(usr--network-online-p)
	usr--ssh-mounted
	(usr--monte-p "~/Club1"))

  (usr--actualiser-affichage))
(defvar usr-sondage-intervalle 60)
(defvar usr--verifier-systeme-timer nil)
  
(when (timerp usr--verifier-systeme-timer)
  (cancel-timer usr--verifier-systeme-timer))

(usr--verifier-systeme)
(setq usr--verifier-systeme-timer
      (run-with-timer 0 usr-sondage-intervalle #'usr--verifier-systeme))
  
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
(defvar usr--volume-string "[--%] ")

;; Ajout sécurisé à la modeline globale
(or global-mode-string (setq global-mode-string '("")))
(unless (memq 'usr--volume-string global-mode-string)
  (setq global-mode-string (append global-mode-string '(usr--volume-string))))

(defun usr--actualiser-volume ()
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
                 (setq usr--volume-string
                       (if (string= etat "off")
                           "[Muet]"
                         (format "[%s]" vol)))
                 (force-mode-line-update t))))))

;; Initialiser l'affichage au démarrage d'Emacs
(usr--actualiser-volume)

(defun usr-volume-monter () 
  (interactive) 
  (start-process-shell-command "v-up" nil "amixer sset Master 5%+")
  (run-at-time "0.1 sec" nil #'usr--actualiser-volume))

(defun usr-volume-baisser () 
  (interactive) 
  (start-process-shell-command "v-dn" nil "amixer sset Master 5%-")
  (run-at-time "0.1 sec" nil #'usr--actualiser-volume))

(defun usr-volume-couper () 
  (interactive) 
  (start-process-shell-command "v-tg" nil "amixer sset Master toggle")
  (run-at-time "0.1 sec" nil #'usr--actualiser-volume))

;;;; — Luminosité —
(defun usr-luminosite-monter () 
  (interactive) 
  (start-process-shell-command "l-up" nil "light -s sysfs/backlight/intel_backlight -A 5"))

(defun usr-luminosite-baisser () 
  (interactive) 
  (start-process-shell-command "l-dn" nil "light -s sysfs/backlight/intel_backlight -U 5"))

;;;; poweroff, reboot & suspend
(defun usr-eteindre ()
      (interactive)
      (when (yes-or-no-p "Éteindre l'ordinateur ? ")
        (save-some-buffers) ;; Sauvegarde silencieuse de tout ce qui a été modifié
        (start-process "poweroff" nil "poweroff")))

(defun usr-redemarrer ()
      (interactive)
      (when (yes-or-no-p "Redémarrer l'ordinateur ? ")
        (save-some-buffers) ;; Sauvegarde silencieuse de tout ce qui a été modifié
        (start-process "reboot" nil "reboot")))

(defun usr-veille ()
  (interactive)
  (start-process "suspend" nil "suspend"))

(defun usr-ecran-verrouiller ()
  "Verrouille l'écran avec slock.
Le binaire setuid est fourni par `screen-locker-service-type' (config.scm)."
  (interactive)
  (start-process "slock" nil "/run/setuid-programs/slock"))

;;;; Guix
(defun usr-guix-mettre-a-jour ()
  "Lance `guix pull' dans un tampon de compilation.
Les canaux utilisés sont ceux de ~/.config/guix/channels.scm. La
reconfiguration du système et du profil Home reste une opération
délibérée, à lancer séparément."
  (interactive)
  (compilation-start "guix pull" nil (lambda (_) "*guix pull*")))

;;;; EXWM — PRÉALABLES CLAVIER :::::::::::::::::::::::::::::::::::::::::::::::
;; Toutes les touches sont déclarées dans la section « RACCOURCIS » en fin de
;; fichier, seul endroit du fichier où une liaison globale est définie.

(with-eval-after-load 'exwm
  ;; C-g et C-c restent à Emacs, jamais transmis au client X.
  (dolist (k '(?\C-g ?\C-c))
    (add-to-list 'exwm-input-prefix-keys k)))

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
  (:map elfeed-search-mode-map
   ("c" . teci-flux-capturer)
   ("d" . teci-flux-telecharger-audio)
   :map elfeed-show-mode-map
   ("c" . teci-flux-capturer)
   ("d" . teci-flux-telecharger-audio))
   
  :custom
  (elfeed-search-face-alist '((unread . (font-lock-keyword-face bold))))
  
  :hook
  (elfeed-show-mode . mixed-pitch-mode)
  
  :config
  ;; --- 1. Capture vers Denote (Format feed-auteur-titre) ---
  (defun usr-flux-capturer ()
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
  (defun usr-flux-telecharger-audio ()
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
        (usr--start-spinner "Téléchargement audio en cours")
        
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
                   (usr--stop-spinner (format "yt-dlp ❌ Échec : %s" (string-trim event)))
                 (usr--stop-spinner "yt-dlp ✅ Audio extrait sur le Bureau !"))))))))))

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
    (ews-bibtex-register)))

;; Biblio package for adding BibTeX records
(use-package biblio)

;; Citar to access bibliographies
(use-package citar
  :defer t
  :custom
  (citar-bibliography ews-bibtex-files))

;; Easy insertion of weblinks
(use-package org-web-tools)

;; Emacs Multimedia System
(use-package emms
  :config
  (require 'emms-setup)
  (require 'emms-mpris)
  (emms-all)
  (emms-default-players)
  (emms-mpris-enable)
  :custom
  (emms-browser-covers #'emms-browser-cache-thumbnail-async))

;; Denote
(setq denote-directory "~/Bureau/")
(setq denote-dired-directories "~/Bureau/")
(setq denote-journal-directories "~/Bureau/")
;; La boîte de dépôt des notes vocales venues du téléphone vit dans le
;; répertoire Denote : on l'écarte de tous les parcours de la base (recherche,
;; statistiques, renommages en lot).  Le motif est comparé au nom du répertoire
;; seul, d'où l'ancrage.
(setq denote-excluded-directories-regexp "\\`\\.vocal_input\\'")

(use-package denote
  :defer t
  :custom
  (denote-sort-keywords t)
  (denote-link-description-function "%t")
  (denote-rename-buffer-mode 1)
  :hook
  (dired-mode . denote-dired-mode)
  :custom-face
  (denote-faces-link ((t (:slant italic)))))

;; Denote auxiliary packages
(use-package denote-journal)

(use-package denote-org)

(use-package denote-sequence)

;; Consult-Notes for easy access to notes
(use-package consult-notes
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :init
  (consult-notes-denote-mode))

;; Citar-Denote to manage literature notes
(use-package citar-denote
  :custom
  (citar-open-always-create-notes t)
  :config
  (citar-denote-mode))

;; Explore and manage your Denote collection

(use-package denote-explore)

;; Distraction-free writing
(use-package darkroom
  :demand t)

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
  (dictionary-server "dict.org"))

;; Writegood-Mode for weasel words, passive writing and repeated word detection
(use-package writegood-mode
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

;; --- CORRECTION DE LA GRILLE ---
(defun usr--calendrier-police-fixe ()
  "Force une police à chasse fixe : la grille du calendrier en dépend."
  (face-remap-add-relative 'default :family "Monospace"))

(add-hook 'calendar-mode-hook #'usr--calendrier-police-fixe)

(setq org-read-date-popup-calendar nil)

(with-eval-after-load 'org-agenda
  (defun usr--agenda-fermer-sources (&rest _ignore)
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
  (advice-add 'org-agenda-quit :after #'usr--agenda-fermer-sources))

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

(defun usr-corbeille-vider ()
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
  (recentf-max-saved-items 50))

;;;; Bookmarks
(use-package bookmark
  :custom
  (bookmark-save-flag 1)
  :bind
  ("C-x r d" . bookmark-delete))

;;;; Image viewer
(use-package emacs
  :custom
  (image-dired-external-viewer "display")
  :bind
  (:map image-mode-map
         ("k" . image-kill-buffer)
         ("<right>" . image-next-file)
         ("<left>"  . image-previous-file)
    :map dired-mode-map
         ("C-<return>" . image-dired-dired-display-external)))

(use-package image-dired
  :bind
  (:map image-dired-thumbnail-mode-map
        ("C-<right>" . image-dired-display-next)
        ("C-<left>"  . image-dired-display-previous)))

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
(defvar usr--export-pdf-destinations (make-hash-table :test 'equal)
  "Table de correspondance fichier Org → dernier dossier d’export PDF choisi.")

(defun usr-export-pdf-vers (dir)
  "Exporter le buffer Org en PDF puis déplacer le fichier dans DIR.
Se souvient du dernier dossier utilisé pour ce fichier Org."
  (interactive
   (let* ((org-file  (buffer-file-name))
          (last-dir  (gethash org-file usr--export-pdf-destinations))
          (start-dir (or last-dir default-directory)))
     ;; Ici, `start-dir` est utilisé comme dossier de départ ET valeur initiale.
     (list (read-directory-name
            "Exporter le PDF vers le dossier : "
            start-dir   ; dossier de départ
            start-dir   ; défaut
            t           ; doit être un dossier existant
            nil))))     ; pas de texte initial supplémentaire

  ;; Mémoriser le dossier choisi pour ce fichier Org
  (puthash (buffer-file-name) dir usr--export-pdf-destinations)

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
        `((:name "Nouveau(x) courriel(s) pour la TECI"
                 :query "tag:unread AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"
                 :key "n")
	  (:name "Nouveau(x) courriel(s) du Fight-Club"
                 :query "tag:unread AND to:fight-club@framagroupes.org AND NOT tag:trash"
                 :key "c")
	  (:name "Nouveau(x) courriel(s) du Hangar"
                 :query "tag:unread AND (to:membres.actif-ves@lestempsdarts.lautre.net OR to:commission.numerique@lestempsdarts.lautre.net OR to:actus@lestempsdarts.lautre.net) AND NOT tag:trash"
                 :key "h")
	   (:name "Nouveau(x) courriel(s) perso"
                 :query ,(concat "tag:unread AND to:" lateci-courriel-perso
                                 " AND NOT tag:trash")
                 :key "N")
	   
	  ;; --- Boites de récpetion ---	   
	  (:name "Boites de réception de la TECI"
                 :query "tag:inbox AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"
                 :key "p")
	  (:name "Boite de réception du Fight-Club"
                 :query "tag:inbox AND to:fight-club@framagroupes.org AND NOT tag:trash"
                 :key "f")
	  (:name "Boite de réception du Hangar"
                 :query "tag:inbox AND (to:membres.actif-ves@lestempsdarts.lautre.net OR to:commission.numerique@lestempsdarts.lautre.net OR to:actus@lestempsdarts.lautre.net) AND NOT tag:trash"
                 :key "H")	  
          (:name "Boite de réception personnelle"
                 :query ,(concat "tag:inbox AND to:" lateci-courriel-perso
                                 " AND NOT tag:trash")
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
(defvar usr--spinner-timer nil)
(defvar usr--spinner-frames '("[-]" "[\\]" "[|]" "[/]" "[-]" "[\\]" "[|]" "[/]"))
(defvar usr--spinner-index 0)

(defun usr--start-spinner (texte)
  "Démarre une animation uniquement dans le minibuffer sans polluer *Messages*."
  (when usr--spinner-timer (cancel-timer usr--spinner-timer))
  (setq usr--spinner-index 0)
  (setq usr--spinner-timer
        (run-with-timer 0 0.2
                        (lambda ()
                          (let ((inhibit-quit t)
                                (message-log-max nil)) ;; <-- Empêche l'écriture de la frame dans *Messages*
                            (message "%s %s" texte (nth usr--spinner-index usr--spinner-frames))
                            (setq usr--spinner-index (mod (1+ usr--spinner-index) (length usr--spinner-frames))))))))

(defun usr--stop-spinner (texte-fin)
  "Arrête l'animation et affiche le message final (qui sera lui bien historisé)."
  (when usr--spinner-timer
    (cancel-timer usr--spinner-timer)
    (setq usr--spinner-timer nil))
  (message "%s" texte-fin))

(defun usr-courriel-synchroniser ()
  "Lance mbsync manuellement avec animation, puis met à jour Notmuch."
  (interactive)
  (usr--start-spinner "Récupération des courriels")
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
             (usr--stop-spinner (format "Échec mbsync : %s" (string-trim event)))
           (progn
             (usr--stop-spinner "mise à jours des courriels terminée !")
             (when (fboundp 'notmuch-poll)
               (notmuch-poll))
             (when (fboundp 'notmuch-hello-update)
               (when-let ((buf (get-buffer "*notmuch-hello*")))
                 (with-current-buffer buf (notmuch-hello-update)))))))))))

(defun usr-courriel-nouveaux ()
  "Ouvre les courriels non lus du Terrain d'Expérimentation de Créations et d'Initiative."
  (interactive)
  (notmuch-search "tag:unread AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"))

(defun usr-courriel-boite ()
  "Ouvre la boite de réception globale."
  (interactive)
  (notmuch-search "tag:inbox AND (to:teci.blois@pm.me OR to:lateci@club1.fr OR to:groupi@framagroupes.org) AND NOT tag:trash"))

;; ENVOI COURRIEL VIA CLUB1 (SMTP)
(setq user-full-name lateci-org-nom
      user-mail-address lateci-org-courriel)

(setq sendmail-program (executable-find "msmtp")
      send-mail-function #'message-send-mail-with-sendmail
      message-send-mail-function #'message-send-mail-with-sendmail)

(setq notmuch-fcc-dirs
      "club1/Sent +sent -inbox -unread")

(setq message-signature-insert-empty-line t)
(setq message-signature
      (concat "~$ thomas r.-m. | " lateci-org-site " | " lateci-tel "\n"
              "Documents & flyers en sobriété numérique : https://static.club1.fr/lateci/"))

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

(defun usr--exwm-renommer-tampon ()
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

(add-hook 'exwm-manage-finish-hook #'usr--exwm-renommer-tampon)

;;;;; --- Web ---
(defun usr-navigateur ()
  (interactive)
  (let ((buf (get-buffer "Icecat")))
    (if (and buf (buffer-live-p buf))
        (exwm-workspace-switch-to-buffer buf)
      (start-process "icecat" nil "icecat"))))

(setq browse-url-browser-function 'browse-url-generic)
(setq browse-url-generic-program "icecat")

;;;;; --- XTERM ---
(defun usr-terminal ()
  (interactive)
  (let ((buf (get-buffer "XTerm")))
    (if (and buf (buffer-live-p buf))
        (exwm-workspace-switch-to-buffer buf)
      (start-process "xterm" nil "xterm"))))

;;;;; --- SOFFICE ---
(defun usr-bureautique ()
 (interactive)
 (let ((buf (get-buffer "soffice")))
   (if (and buf (buffer-live-p buf))
       (exwm-workspace-switch-to-buffer buf)
     (start-process "soffice" nil "soffice"))))

;;;; SSHFS :::::::::::::::::::::::::::::::::::::::::::::::

(defun usr-club1-monter ()
  "Demande à Shepherd de démarrer le service SSHFS."
  (interactive)
  (start-process "shepherd-sshfs-on" nil "herd" "start" "sshfs-club1")
  (message "Montage de Club1 via Shepherd..."))

(defun usr-club1-demonter ()
  "Demande à Shepherd d'arrêter le service SSHFS."
  (interactive)
  (start-process "shepherd-sshfs-off" nil "herd" "stop" "sshfs-club1")
  (message "Démontage de Club1 via Shepherd..."))

;;;; SYNCTHING ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
(use-package syncthing
  :defer t
  :custom
  (syncthing-host "127.0.0.1:8384")
  (syncthing-default-server-token
    (string-trim (shell-command-to-string "pass show api/syncthing"))))

(defun usr-syncthing-demarrer ()
  "Démarre Syncthing via le gestionnaire de services Shepherd."
  (interactive)
  (start-process "shepherd-st-on" nil "herd" "start" "syncthing")
  (message "Démarrage de Syncthing")
  ;; Force la mise à jour de la modeline après une seconde
  (run-at-time "1 sec" nil #'usr--verifier-systeme))

(defun usr-syncthing-arreter ()
  "Arrête Syncthing via le gestionnaire de services Shepherd."
  (interactive)
  (start-process "shepherd-st-off" nil "herd" "stop" "syncthing")
  (message " Arrêt de Syncthing")
  (run-at-time "1 sec" nil #'usr--verifier-systeme))
 
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

(defun usr-gpg-deverrouiller ()
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
            (usr--verifier-systeme))
        (message "Échec GPG : Mot de passe incorrect ou annulé.")))))

(defun usr-gpg-verrouiller ()
  (interactive)
  (let ((bin (executable-find "gpgconf")))
    (when (and bin (numberp (call-process bin nil nil nil "--kill" "gpg-agent")))
      (message "clé gpg est vérouillé")
      (setq usr--gpg-unlocked nil)
      (usr--actualiser-affichage))))



;;;;  MODE KIOSK LA TECI (CORRIGÉ) ---
(defvar usr-kiosque-url "https://lateci.club1.fr/accueil.html"
  "L'adresse du site autorisé pour le mode kiosk.")

(defun usr-kiosque-activer ()
  (interactive)
  (message "Activation du mode Kiosk...")
  (start-process "icecat-kiosk" nil "icecat" "--kiosk" usr-kiosque-url))

(defun usr-kiosque-desactiver ()
  (interactive)
  (let ((proc (get-process "icecat-kiosk")))
    (if proc
        (progn
          (delete-process proc)
          (message "Mode Kiosk désactivé."))
      (message "Le processus Kiosk n'a pas été trouvé."))))


;;; ASSISTANT IA (gptel) ::::::::::::::::::::::::::::::::::::::::::::::::::::::

(defun usr--cle-anthropic ()
  (string-trim (shell-command-to-string "pass show api/claude")))
(defun usr--cle-gemini ()
  (string-trim (shell-command-to-string "pass show api/gemini")))
(defun usr--cle-openai ()
  (string-trim (shell-command-to-string "pass show api/openai")))

(defvar usr-ia-modele-rapide 'gpt-5.6-luna)

(defun usr-ia-corriger (debut fin &optional systeme)
  "Corrige la région en place. SYSTEME optionnel remplace la directive."
  (interactive "r")
  (let ((texte (buffer-substring-no-properties debut fin))
        (buf (current-buffer)))
    (usr--start-spinner "Correction")
    (gptel-request texte
      :system (or systeme
                  "Corrige grammaire, orthographe, syntaxe et lourdeurs en français. Conserve le balisage Org et LaTeX à l'identique. Ne change pas le sens ni le ton. Renvoie UNIQUEMENT le texte corrigé, sans commentaire.")
      :context (list debut fin buf)
      :callback
      (lambda (reponse info)
        (if (not (stringp reponse))
            (usr--stop-spinner (format "Échec : %s" (plist-get info :status)))
          (pcase-let ((`(,d ,f ,b) (plist-get info :context)))
            (with-current-buffer b
              (save-excursion
                (delete-region d f)
                (goto-char d)
                (insert reponse))))
          (usr--stop-spinner "Terminé."))))))

(defun usr-ia-courriel (debut fin)
  "Développe des notes en courriel associatif."
  (interactive "r")
  (usr-ia-corriger
   debut fin
   "Développe ces notes en courriel associatif français : ton cordial et sobre, court, formule de politesse. Renvoie uniquement le corps du courriel."))

(defun usr-ia-diagnostiquer ()
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

(defun usr-ia-contexte-vider ()
  (interactive)
  (gptel-context-remove-all)
  (message "Contexte gptel vidé."))

(defun usr-ia-recherche-web ()
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
  :init
  :config
  (setq gptel-default-mode 'org-mode
        gptel-max-tokens 4096
        gptel-use-tools nil
        gptel-confirm-tool-calls t)

  ;; --- Backends ---
  (defvar gptel--backend-anthropic
    (gptel-make-anthropic "anthropic"
      :key #'usr--cle-anthropic
      :stream t
      :models '(claude-fable-5
                claude-opus-5
                claude-sonnet-5
                claude-haiku-4-5)))

  (defvar gptel--backend-anthropic-web
    (gptel-make-anthropic "anthropic-web"
      :key #'usr--cle-anthropic
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
      :key #'usr--cle-gemini
      :stream t
      :models '(gemini-3.5-flash-light
                gemini-3.6-flash
                gemini-3.1-pro-preview)))

    (defvar gptel--backend-openai
    (gptel-make-openai "openai"
      :key #'usr--cle-openai
      :stream t
      :models '(gpt-5.6-sol
                gpt-5.6-terra
		gpt-5.6-luna)))

    (setq gptel-backend gptel--backend-openai
        gptel-model 'gpt-5.6-terra
	gptel-cache '(message system tool))
  
  ;; --- Outils ---
  (defvar usr--ia-outil-notes
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

  (defvar usr--ia-outil-lire
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

  (defun usr-ia-outils (jeu)
    "Active un JEU d'outils : notes ou aucun."
    (interactive (list (intern (completing-read "Outils : " '("notes" "aucun") nil t))))
    (setq gptel-tools
          (pcase jeu
            ('notes (list usr--ia-outil-notes usr--ia-outil-lire))
            ('aucun nil))
          gptel-use-tools (not (null gptel-tools)))
    (message "Outils gptel : %s" jeu))
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

  

;;;; DIALOGUE GPTEL DEPUIS LE MINIBUFFER ::::::::::::::::::::::::::::::::::::::

;; --- État isolé : historique, fil, directive, backend/modèle, dernière réponse ---
(defvar usr--ia-historique nil
  "Historique des invites saisies au minibuffer.")

(defvar usr--ia-fil nil
  "Fil de conversation : liste de chaînes alternant utilisateur/assistant.")

(defvar usr--ia-derniere-reponse nil
  "Dernière réponse reçue, conservée pour récupération ultérieure.")

(defvar usr-ia-tampon-reponse "*gptel-réponse*"
  "Nom du buffer d'affichage des réponses longues.")

(defvar usr-ia-directive-courante 'concis
  "Directive propre aux commandes minibuffer (clé de `gptel-directives').")

(defvar usr-ia-backend-courant nil
  "Backend propre au minibuffer ; nil = backend global de gptel.")

(defvar usr-ia-modele-courant nil
  "Modèle propre au minibuffer ; nil = modèle global de gptel.")

(defvar usr-ia-seuil-echo 300
  "Longueur maximale d'une réponse affichée en écho dans le minibuffer.")

;; --- Choix de la directive ---
(defun usr-ia-directive (nom)
  "Sélectionne la directive NOM pour les commandes gptel du minibuffer."
  (interactive
   (progn
     (require 'gptel)
     (list (intern (completing-read
                    "Directive minibuffer : "
                    (mapcar (lambda (c) (symbol-name (car c))) gptel-directives)
                    nil t nil nil
                    (symbol-name usr-ia-directive-courante))))))
  (setq usr-ia-directive-courante nom)
  (message "Directive minibuffer : %s" nom))

;; --- Choix du couple backend/modèle ---
(defun usr-ia-modele ()
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
    (setq usr-ia-backend-courant (nth 1 choix)
          usr-ia-modele-courant   (nth 2 choix))
    (message "Modèle minibuffer : %s" (car choix))))

;; --- Retour au backend/modèle globaux ---
(defun usr-ia-modele-defaut ()
  "Rétablit l'usage du backend et du modèle globaux de gptel."
  (interactive)
  (setq usr-ia-backend-courant nil
        usr-ia-modele-courant   nil)
  (message "Minibuffer aligné sur le backend/modèle globaux."))

;; --- Affichage : écho si court (conservé dans *Messages*), buffer Org sinon ---
(defun usr--ia-afficher (reponse)
  (setq usr--ia-derniere-reponse reponse)
  (if (and (< (length reponse) usr-ia-seuil-echo)
           (not (string-match-p "\n" reponse)))
      (let ((message-log-max t))
        (message "%s" reponse))
    (with-current-buffer (get-buffer-create usr-ia-tampon-reponse)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert reponse)
        (goto-char (point-min)))
      (display-buffer (current-buffer))))
  reponse)

;; --- Récupération de la dernière réponse ---
(defun usr-ia-copier-reponse (&optional inserer)
  "Copie la dernière réponse dans le kill-ring ; avec préfixe, l'insère au point."
  (interactive "P")
  (if (not usr--ia-derniere-reponse)
      (message "Aucune réponse en mémoire.")
    (kill-new usr--ia-derniere-reponse)
    (if inserer
        (insert usr--ia-derniere-reponse)
      (message "Réponse copiée (%d caractères)." (length usr--ia-derniere-reponse)))))

;; --- Ouverture du buffer de réponse ---
(defun usr-ia-voir-reponse ()
  "Affiche la dernière réponse dans le buffer Org dédié."
  (interactive)
  (if (not usr--ia-derniere-reponse)
      (message "Aucune réponse en mémoire.")
    (with-current-buffer (get-buffer-create usr-ia-tampon-reponse)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert usr--ia-derniere-reponse)
        (goto-char (point-min))))
    (pop-to-buffer usr-ia-tampon-reponse)))

;; --- Question ponctuelle sans mémoire ; préfixe = insertion au point ---
(defun usr-ia-question (invite &optional inserer)
  "Interroge gptel avec INVITE depuis le minibuffer, sans conserver de fil.
La région active est jointe à l'invite. Avec INSERER, la réponse est
insérée au point plutôt qu'affichée."
  (interactive
   (list (read-string "gptel : " nil 'usr--ia-historique)
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
         (gptel-backend (or usr-ia-backend-courant gptel-backend))
         (gptel-model   (or usr-ia-modele-courant   gptel-model)))
    (usr--start-spinner "gptel")
    (gptel-request texte
      :system (alist-get usr-ia-directive-courante gptel-directives)
      :callback
      (lambda (reponse info)
        (if (not (stringp reponse))
            (usr--stop-spinner (format "Échec : %s" (plist-get info :status)))
          (usr--stop-spinner "gptel ✔")
          (setq usr--ia-derniere-reponse reponse)
          (if inserer
              (with-current-buffer buf
                (save-excursion (goto-char pos) (insert reponse)))
            (usr--ia-afficher reponse)))))))

;; --- Dialogue suivi : le fil complet est renvoyé à chaque tour ---
(defun usr-ia-dialogue (invite)
  "Poursuit un dialogue gptel depuis le minibuffer avec INVITE."
  (interactive
   (list (read-string (if usr--ia-fil
                          "gptel (suite) : "
                        "gptel (nouveau) : ")
                      nil 'usr--ia-historique)))
  (require 'gptel)
  (setq usr--ia-fil (append usr--ia-fil (list invite)))
  (let ((gptel-backend (or usr-ia-backend-courant gptel-backend))
        (gptel-model   (or usr-ia-modele-courant   gptel-model)))
    (usr--start-spinner "gptel")
    (gptel-request (copy-sequence usr--ia-fil)
      :system (alist-get usr-ia-directive-courante gptel-directives)
      :callback
      (lambda (reponse info)
        (if (not (stringp reponse))
            (usr--stop-spinner (format "Échec : %s" (plist-get info :status)))
          (setq usr--ia-fil (append usr--ia-fil (list reponse)))
          (usr--stop-spinner "gptel ✔")
          (usr--ia-afficher reponse)
          (when (y-or-n-p "Poursuivre le dialogue ? ")
            (call-interactively #'usr-ia-dialogue)))))))

;; --- Réinitialisation du fil ---
(defun usr-ia-dialogue-reinitialiser ()
  "Vide le fil de conversation du minibuffer."
  (interactive)
  (setq usr--ia-fil nil)
  (message "Fil gptel réinitialisé."))

;; --- État courant ---
(defun usr-ia-etat ()
  "Affiche directive, modèle et longueur du fil du minibuffer."
  (interactive)
  (require 'gptel)
  (message "Directive : %s | Modèle : %s | Fil : %d tour(s) | Réponse : %s"
           usr-ia-directive-courante
           (gptel--model-name (or usr-ia-modele-courant gptel-model))
           (/ (length usr--ia-fil) 2)
           (if usr--ia-derniere-reponse "en mémoire" "aucune")))


;;; COMPTABILITÉ ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

(defvar usr-compta-repertoire
  (expand-file-name "~/Bureau/compta/")
  "Répertoire contenant les journaux comptables.")

(defvar usr-compta-fichier
  (expand-file-name
   (format "%s.ledger" (format-time-string "%Y"))
   usr-compta-repertoire)
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
(setq ledger-master-file usr-compta-fichier)

(defun usr--ledger-master-courant ()
  "Prend le fichier visité comme journal maître."
  (when buffer-file-name
    (setq-local ledger-master-file buffer-file-name)))

(add-hook 'ledger-mode-hook #'usr--ledger-master-courant)

  :bind
  (:map ledger-mode-map
        ("C-c C-a" . ledger-add-transaction)
        ("C-c C-r" . ledger-report)
        ("C-c C-c" . ledger-mode-clean-buffer)))

(defun usr-compta-ouvrir ()
  "Ouvre le journal comptable de l'exercice courant."
  (interactive)
  (make-directory usr-compta-repertoire t)
  (find-file usr-compta-fichier))

(defun usr-compta-verifier ()
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

(defun usr-compta-exporter ()
  "Exporte le registre comptable courant au format CSV."
  (interactive)
  (let* ((journal usr-compta-fichier)
         (destination
          (expand-file-name
           (format-time-string "%Y-registre.csv")
           usr-compta-repertoire)))
    (make-directory usr-compta-repertoire t)
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

;;; NOTE VOCALE ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;;
;; Une note vocale est une note comme les autres : elle passe par org-capture,
;; elle atterrit dans la base Denote du Bureau, elle se retrouve avec les mêmes
;; outils.  L'audio est déposé à côté de la note, sous un nom Denote lui aussi.
;;
;;   XF86AudioMicMute   1re pression : enregistre (témoin ● REC en modeline).
;;                      2e pression  : arrête et propose la destination.
;;
;; La transcription est toujours facultative et toujours asynchrone : la note
;; est utilisable immédiatement, le texte s'y dépose plus tard, tout seul et
;; sans voler le focus.  Deux moteurs au choix, whisper.cpp en local ou l'API
;; OpenAI, et une boîte de dépôt pour les enregistrements venus du téléphone.

;;;; --- Réglages -------------------------------------------------------------

(defvar usr-vocale-repertoire (expand-file-name "vocal/" user-emacs-directory)
  "Répertoire de travail : enregistrements en cours et conversions.
Délibérément hors de /tmp, qui est un tmpfs — donc de la mémoire vive.")

(defvar usr-vocale-boite (expand-file-name ".vocal_input/" "~/Bureau/")
  "Boîte de dépôt des enregistrements venus de l'extérieur (Syncthing).
Ce qui s'y trouve est temporaire : une fois traité, l'audio est renommé au
format Denote et déplacé dans le Bureau ; rien ne subsiste ici.")

(defvar usr-vocale-extensions
  '("wav" "m4a" "mp3" "opus" "ogg" "oga" "3gp" "3gpp" "amr" "aac" "flac" "mp4" "webm")
  "Extensions reconnues comme des enregistrements audio.")

(defvar usr-vocale-mot-cle "vocal"
  "Mot-clé Denote apposé à toute note vocale.")

(defvar usr-vocale-marqueur-attente "(transcription en cours…)"
  "Texte déposé sous « * Transcription » tant que le résultat n'est pas là.")

(defvar usr-vocale-diode "/sys/class/leds/platform::micmute/brightness"
  "Fichier de la diode du micro, ou nil pour ne pas la piloter.
Sur ThinkPad, cette diode est normalement asservie au noyau par son trigger
`audio-micmute' ; la règle udev de config.scm la détache et en ouvre
l'écriture au groupe « input ».")

(defvar usr-transcription-moteur 'local
  "Moteur de transcription : `local' (whisper.cpp) ou `api' (OpenAI).")

(defvar usr-whisper-binaire nil
  "Nom du binaire whisper.cpp.  Détecté automatiquement lorsqu'il vaut nil.")

(defvar usr-whisper-modele (expand-file-name "~/.local/share/whisper/ggml-medium.bin")
  "Poids whisper.cpp.  Absents de Guix : voir `usr-vocale-installer-modele'.")

(defvar usr-whisper-langue "fr"
  "Langue passée aux deux moteurs de transcription.")

(defvar usr-transcription-modele-api "gpt-4o-transcribe"
  "Modèle de l'endpoint /v1/audio/transcriptions.")

(defvar usr-transcription-taille-max-api (* 25 1024 1024)
  "Limite d'envoi de l'API OpenAI, en octets.")

;;;; --- État et témoin de modeline -------------------------------------------

(defvar usr--vocale-processus nil)
(defvar usr--vocale-fichier nil)
(defvar usr--vocale-debut nil)
(defvar usr--vocale-horodatage nil)
(defvar usr--vocale-suite nil)
(defvar usr--vocale-minuteur nil)
(defvar usr--vocale-taches 0 "Nombre de transcriptions en cours.")

(defvar usr--vocale-en-attente nil
  "(CHEMIN . DURÉE) du dernier enregistrement, en attente de rattachement.")

(defvar usr--vocale-lien-courant nil
  "Lien Org du dernier audio déposé, lu par le modèle de capture « V ».")

(defvar usr--vocale-temoin "")

(or global-mode-string (setq global-mode-string '("")))
(unless (memq 'usr--vocale-temoin global-mode-string)
  (setq global-mode-string (append global-mode-string '(usr--vocale-temoin))))

(defun usr--vocale-temoin-poser (texte &optional face)
  "Affiche TEXTE dans la modeline, ou l'efface lorsque TEXTE vaut nil."
  (setq usr--vocale-temoin
        (if texte
            (propertize (format " %s " texte) 'face (or face 'mode-line-emphasis))
          ""))
  (force-mode-line-update t))

(defun usr--vocale-duree-texte (secondes)
  (let ((s (floor (or secondes 0))))
    (format "%02d:%02d" (/ s 60) (% s 60))))

(defun usr--vocale-en-cours-p ()
  (process-live-p usr--vocale-processus))

(defun usr--vocale-temoin-taches ()
  "Repose le témoin sur l'état des transcriptions en cours."
  (usr--vocale-temoin-poser
   (when (> usr--vocale-taches 0)
     (format "⋯ transcription (%d)" usr--vocale-taches))))

(defun usr--vocale-temoin-rafraichir ()
  (usr--vocale-temoin-poser
   (format "● REC %s"
           (usr--vocale-duree-texte
            (float-time (time-subtract (current-time) usr--vocale-debut))))
   '(:foreground "red" :weight bold)))

(defun usr--vocale-tache-debut ()
  (setq usr--vocale-taches (1+ usr--vocale-taches))
  (unless (usr--vocale-en-cours-p) (usr--vocale-temoin-taches)))

(defun usr--vocale-tache-fin ()
  (setq usr--vocale-taches (max 0 (1- usr--vocale-taches)))
  (unless (usr--vocale-en-cours-p) (usr--vocale-temoin-taches)))

;;;; --- Enregistrement -------------------------------------------------------

(defun usr--vocale-diode (allumee)
  "Allume ou éteint la diode du micro selon ALLUMEE.
Sans permission d'écriture — règle udev absente, ou machine sans cette diode —
ne fait rien et ne signale rien : la note vocale ne doit jamais dépendre d'un
détail de matériel."
  (when (and usr-vocale-diode (file-writable-p usr-vocale-diode))
    (ignore-errors
      (let ((coding-system-for-write 'no-conversion))
        (write-region (if allumee "1\n" "0\n") nil usr-vocale-diode nil 'silence)))))

;; Une sortie brutale en cours d'enregistrement laisserait la diode allumée.
(add-hook 'kill-emacs-hook (lambda () (usr--vocale-diode nil)))

(defun usr--vocale-demarrer (&optional suite)
  "Lance arecord.  SUITE, si elle est fournie, est appelée sans argument à
l'arrêt, à la place du menu de destination."
  (unless (executable-find "arecord")
    (user-error "arecord est absent : installez alsa-utils"))
  (make-directory usr-vocale-repertoire t)
  (setq usr--vocale-horodatage (format-time-string "%Y%m%dT%H%M%S")
        usr--vocale-debut (current-time)
        usr--vocale-suite suite
        usr--vocale-fichier (expand-file-name (concat usr--vocale-horodatage ".wav")
                                              usr-vocale-repertoire))
  (setq usr--vocale-processus
        (make-process
         :name "note-vocale"
         :buffer " *note-vocale*"
         :noquery t
         ;; 16 kHz mono S16_LE : exactement le format d'entrée exigé par
         ;; whisper.cpp, aucune conversion ne sera nécessaire ensuite.
         :command (list "arecord" "-q" "-D" "default"
                        "-f" "S16_LE" "-r" "16000" "-c" "1" "-t" "wav"
                        usr--vocale-fichier)
         :sentinel #'usr--vocale-sentinelle))
  (when usr--vocale-minuteur (cancel-timer usr--vocale-minuteur))
  (setq usr--vocale-minuteur (run-with-timer 0 1 #'usr--vocale-temoin-rafraichir))
  (usr--vocale-diode t)
  (message "Enregistrement en cours — même touche pour arrêter."))

(defun usr--vocale-arreter ()
  ;; SIGINT et jamais SIGKILL : arecord doit pouvoir réécrire l'en-tête WAV
  ;; avec la taille réelle, faute de quoi le fichier est illisible.
  (when (usr--vocale-en-cours-p)
    (interrupt-process usr--vocale-processus)))

(defun usr--vocale-sentinelle (proc _evenement)
  (when (memq (process-status proc) '(exit signal))
    (when usr--vocale-minuteur
      (cancel-timer usr--vocale-minuteur)
      (setq usr--vocale-minuteur nil))
    (setq usr--vocale-processus nil)
    (usr--vocale-diode nil)
    (usr--vocale-temoin-taches)
    (let ((fichier usr--vocale-fichier)
          (suite usr--vocale-suite))
      (setq usr--vocale-suite nil)
      ;; Arrêté par SIGINT, arecord sort en « signal » : son code de sortie ne
      ;; dit rien du succès.  Seul le fichier fait foi — 44 octets, c'est
      ;; l'en-tête WAV tout seul, donc rien d'enregistré.
      (if (and fichier
               (file-exists-p fichier)
               (> (file-attribute-size (file-attributes fichier)) 44))
          (progn
            (setq usr--vocale-en-attente
                  (cons fichier
                        (float-time (time-subtract (current-time) usr--vocale-debut))))
            ;; On ne dialogue jamais depuis une sentinelle : elle s'exécute à un
            ;; point arbitraire du programme, potentiellement au milieu d'une
            ;; autre commande.
            (run-at-time 0 nil (or suite #'usr--vocale-proposer-destination)))
        (when (and fichier (file-exists-p fichier)) (delete-file fichier))
        (setq usr--vocale-en-attente nil)
        (message "Échec de l'enregistrement vocal.")))))

(defun usr-note-vocale ()
  "Démarre ou arrête une note vocale.
À l'arrêt, propose de la rattacher à une note."
  (interactive)
  (if (usr--vocale-en-cours-p)
      (usr--vocale-arreter)
    (usr--vocale-demarrer)))

(defun usr--vocale-proposer-destination ()
  "Demande ce qu'il faut faire de l'enregistrement qui vient de s'achever.
La réécoute ne referme pas l'invite : on peut vérifier avant de choisir."
  (catch 'fini
    (while t
      (let ((choix (read-char-choice
                    (format "Note vocale (%s) : [v] note Denote  [V] note brève  [e] réécouter  [g] audio seul  [s] supprimer "
                            (usr--vocale-duree-texte (cdr usr--vocale-en-attente)))
                    '(?v ?V ?e ?g ?s))))
        (pcase choix
          (?e (usr-vocale-ecouter))
          (?v (org-capture nil "v") (throw 'fini t))
          (?V (org-capture nil "V") (throw 'fini t))
          (?g (usr-vocale-garder-audio) (throw 'fini t))
          (?s (usr-vocale-supprimer) (throw 'fini t)))))))

;;;; --- Nommage et dépôt de l'audio ------------------------------------------

(defun usr--vocale-slug (texte)
  "Réduit TEXTE à un fragment de nom de fichier, à la manière de Denote."
  (replace-regexp-in-string
   "^-\\|-$" ""
   (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase (or texte "")))))

(defun usr--vocale-bureau ()
  (if (fboundp 'denote-directory)
      (denote-directory)
    (expand-file-name "~/Bureau/")))

(defun usr--vocale-nom-denote (horodatage titre mots extension)
  (format "%s--%s__%s.%s"
          horodatage
          (usr--vocale-slug titre)
          (mapconcat #'usr--vocale-slug
                     (seq-uniq (cons usr-vocale-mot-cle mots))
                     "_")
          extension))

(defun usr--vocale-deposer-audio (source titre mots &optional temps)
  "Déplace SOURCE dans le Bureau sous un nom conforme à Denote.
TEMPS fixe l'identifiant ; à défaut, la date de modification de SOURCE — ce
qui, pour un fichier venu du téléphone, est bien l'instant de l'enregistrement.
Renvoie le chemin de destination."
  (let* ((temps (or temps (file-attribute-modification-time (file-attributes source))))
         (extension (or (file-name-extension source) "wav"))
         (decalage 0)
         cible)
    ;; Collision d'identifiant (deux dépôts dans la même seconde) : on décale.
    (while (progn
             (setq cible (expand-file-name
                          (usr--vocale-nom-denote
                           (format-time-string "%Y%m%dT%H%M%S"
                                               (time-add temps decalage))
                           titre mots extension)
                          (usr--vocale-bureau)))
             (and (file-exists-p cible) (< decalage 60)))
      (setq decalage (1+ decalage)))
    (rename-file source cible)
    cible))

(defun usr--vocale-duree-fichier (fichier)
  "Durée de FICHIER en secondes via ffprobe, ou nil."
  (when (executable-find "ffprobe")
    (with-temp-buffer
      (when (zerop (call-process "ffprobe" nil t nil
                                 "-v" "error"
                                 "-show_entries" "format=duration"
                                 "-of" "default=noprint_wrappers=1:nokey=1"
                                 fichier))
        (ignore-errors (string-to-number (string-trim (buffer-string))))))))

;;;; --- Squelette de la note -------------------------------------------------

(defun usr--vocale-moteur-texte ()
  (pcase usr-transcription-moteur
    ('local (format "whisper.cpp (%s)" (file-name-base usr-whisper-modele)))
    ('api (format "API OpenAI (%s)" usr-transcription-modele-api))
    (_ "—")))

(defun usr--vocale-lien (audio &optional etiquette)
  ;; Lien « file: » et non « denote: » : le premier passe par org-file-apps et
  ;; donc par un lecteur audio, le second ferait un find-file qui ouvrirait le
  ;; WAV en binaire dans Emacs.
  (format "[[file:%s][%s]]"
          (file-name-nondirectory audio)
          (or etiquette (file-name-nondirectory audio))))

(defun usr--vocale-squelette (audio duree)
  (format "* Audio
:PROPERTIES:
:AUDIO: %s
:END:
- Fichier : %s
- Durée : %s
- Enregistré le : %s
- Moteur : %s

* Transcription

%s

* Notes

"
          (file-name-base audio)
          (usr--vocale-lien audio (format "🎙 %s" (usr--vocale-duree-texte duree)))
          (usr--vocale-duree-texte duree)
          (format-time-string "%Y-%m-%d %a %H:%M")
          (usr--vocale-moteur-texte)
          usr-vocale-marqueur-attente))

;;;; --- Moteurs de transcription ---------------------------------------------

(defun usr--whisper-binaire ()
  "Localise le binaire whisper.cpp.
Le projet amont a renommé « main » en « whisper-cli » ; selon le commit du
canal Guix, l'un ou l'autre peut être exposé, on essaie donc les deux."
  (or (and usr-whisper-binaire (executable-find usr-whisper-binaire))
      (seq-some #'executable-find '("whisper-cli" "whisper-cpp" "whisper" "main"))))

(defun usr--transcription-obstacle ()
  "Raison pour laquelle la transcription est impossible, ou nil."
  (pcase usr-transcription-moteur
    ('local (cond ((null (usr--whisper-binaire)) "whisper.cpp est absent")
                  ((not (file-exists-p usr-whisper-modele))
                   "le modèle est absent (M-x usr-vocale-installer-modele)")))
    ('api (unless (executable-find "curl") "curl est absent"))
    (_ "moteur de transcription inconnu")))

(defun usr--vocale-notre-enregistrement-p (fichier)
  "FICHIER sort-il de notre propre enregistreur ?
Auquel cas il est déjà en WAV 16 kHz mono et ne demande aucune conversion."
  (string-prefix-p (file-name-as-directory (expand-file-name usr-vocale-repertoire))
                   (expand-file-name fichier)))

(defvar usr-vocale-extensions-api
  '("mp3" "mp4" "mpeg" "mpga" "m4a" "wav" "webm")
  "Formats acceptés en l'état par l'API OpenAI.
Tout le reste — .opus, .ogg, .amr, .3gp, courants sur les téléphones — doit
être converti au préalable.")

(defun usr--vocale-conversion-requise-p (fichier)
  (pcase usr-transcription-moteur
    ;; whisper.cpp n'accepte que du WAV 16 kHz mono : tout le reste y passe.
    ('local (not (usr--vocale-notre-enregistrement-p fichier)))
    ;; L'API accepte la plupart des formats du téléphone en l'état.  Restent
    ;; deux motifs de conversion : un format qu'elle ignore, et la taille — un
    ;; WAV 16 kHz atteint la limite de 25 Mo en une quinzaine de minutes.
    ('api (or (not (member (downcase (or (file-name-extension fichier) ""))
                           usr-vocale-extensions-api))
              (> (file-attribute-size (file-attributes fichier)) (* 20 1024 1024))))
    (_ nil)))

(defun usr--vocale-preparer (fichier rappel)
  "Prépare FICHIER pour le moteur courant, puis appelle (RAPPEL CHEMIN ERREUR).
CHEMIN vaut FICHIER lorsqu'aucune conversion n'est nécessaire ; sinon c'est un
fichier temporaire, que l'appelant se charge de supprimer."
  (if (not (usr--vocale-conversion-requise-p fichier))
      (funcall rappel fichier nil)
    (if (not (executable-find "ffmpeg"))
        (funcall rappel nil "ffmpeg est absent, conversion impossible")
      (make-directory usr-vocale-repertoire t)
      (let* ((api (eq usr-transcription-moteur 'api))
             (sortie (expand-file-name
                      (format "%s-prep.%s" (file-name-base fichier) (if api "mp3" "wav"))
                      usr-vocale-repertoire))
             ;; -nostdin est indispensable sous make-process : sans lui, ffmpeg
             ;; consomme l'entrée standard et reste en attente.
             (commande (append
                        (list "ffmpeg" "-nostdin" "-y" "-loglevel" "error"
                              "-i" fichier "-vn" "-ac" "1" "-ar" "16000")
                        (if api
                            ;; MP3 mono 32 kb/s : une heure de parole ≈ 14 Mo,
                            ;; donc sous la limite, et c'est un format que
                            ;; l'API accepte à coup sûr.
                            (list "-c:a" "libmp3lame" "-b:a" "32k")
                          ;; whisper.cpp : WAV 16 kHz mono 16 bits, rien d'autre.
                          (list "-c:a" "pcm_s16le"))
                        (list sortie))))
        (make-process
         :name "ffmpeg-vocale" :buffer " *ffmpeg-vocale*" :noquery t
         :command commande
         :sentinel
         (lambda (proc _evenement)
           (when (memq (process-status proc) '(exit signal))
             (if (and (zerop (process-exit-status proc)) (file-exists-p sortie))
                 (funcall rappel sortie nil)
               (funcall rappel nil "échec de la conversion ffmpeg")))))))))

(defun usr--transcrire-local (fichier rappel)
  (let* ((base (expand-file-name (format "%s-%d" (file-name-base fichier) (random 100000))
                                 usr-vocale-repertoire))
         (sortie (concat base ".txt")))
    (make-process
     :name "whisper" :buffer " *whisper*" :noquery t
     ;; -of attend un chemin SANS extension : whisper.cpp ajoute « .txt ».
     ;; -nt supprime les horodatages, qui n'ont rien à faire dans une note.
     :command (list (usr--whisper-binaire)
                    "-m" (expand-file-name usr-whisper-modele)
                    "-l" usr-whisper-langue
                    "-nt"
                    "-t" (number-to-string (max 1 (1- (num-processors))))
                    "-otxt" "-of" base
                    "-f" fichier)
     :sentinel
     (lambda (proc _evenement)
       (when (memq (process-status proc) '(exit signal))
         (let ((texte (when (file-exists-p sortie)
                        (with-temp-buffer
                          (insert-file-contents sortie)
                          (string-trim (buffer-string))))))
           (when (file-exists-p sortie) (delete-file sortie))
           (if (and texte (not (string-empty-p texte)))
               (funcall rappel texte nil)
             (funcall rappel nil "whisper.cpp n'a rien produit"))))))))

(defun usr--transcrire-api (fichier rappel)
  (let ((taille (file-attribute-size (file-attributes fichier))))
    (if (> taille usr-transcription-taille-max-api)
        (funcall rappel nil (format "fichier trop volumineux (%.1f Mo, limite 25 Mo)"
                                    (/ taille 1048576.0)))
      (let ((proc
             (make-process
              :name "transcription-api"
              :buffer (generate-new-buffer " *transcription-api*")
              :noquery t
              :connection-type 'pipe
              ;; « -H @- » lit les en-têtes sur l'entrée standard : la clé ne
              ;; transite donc jamais par argv, où n'importe quel « ps » de la
              ;; machine pourrait la lire.  --fail-with-body conserve le corps
              ;; JSON en cas d'erreur, sans quoi on n'aurait qu'un code muet.
              :command (list "curl" "-sS" "--fail-with-body"
                             "-H" "@-"
                             "-F" (concat "file=@" fichier)
                             "-F" (concat "model=" usr-transcription-modele-api)
                             "-F" (concat "language=" usr-whisper-langue)
                             "-F" "response_format=text"
                             "https://api.openai.com/v1/audio/transcriptions")
              :sentinel
              (lambda (proc _evenement)
                (when (memq (process-status proc) '(exit signal))
                  (let ((sortie (with-current-buffer (process-buffer proc)
                                  (string-trim (buffer-string)))))
                    (kill-buffer (process-buffer proc))
                    (if (zerop (process-exit-status proc))
                        (funcall rappel sortie nil)
                      (funcall rappel nil (if (string-empty-p sortie)
                                              "échec de l'appel à l'API"
                                            sortie)))))))))
        (process-send-string proc (format "Authorization: Bearer %s\n" (usr--cle-openai)))
        (process-send-eof proc)))))

(defun usr--transcrire (fichier rappel)
  "Transcrit FICHIER puis appelle (RAPPEL TEXTE ERREUR), hors sentinelle."
  (let ((enveloppe (lambda (texte erreur) (run-at-time 0 nil rappel texte erreur))))
    (usr--vocale-preparer
     fichier
     (lambda (prepare erreur)
       (if erreur
           (funcall enveloppe nil erreur)
         (let ((fin (lambda (texte err)
                      (unless (equal prepare fichier)
                        (when (file-exists-p prepare) (delete-file prepare)))
                      (funcall enveloppe texte err))))
           (pcase usr-transcription-moteur
             ('local (usr--transcrire-local prepare fin))
             ('api (usr--transcrire-api prepare fin))
             (_ (funcall fin nil "moteur de transcription inconnu")))))))))

;;;; --- Dépôt différé de la transcription ------------------------------------

(defun usr--vocale-fichier-cible (cible)
  (let ((fichier (plist-get cible :fichier))
        (id (plist-get cible :id)))
    (cond ((and fichier (file-exists-p fichier)) fichier)
          ;; La note a pu être renommée entre-temps ; son identifiant Denote,
          ;; lui, ne bouge pas.
          ((and id (fboundp 'denote-get-path-by-id)) (denote-get-path-by-id id)))))

(defun usr--vocale-inserer (texte type ancre)
  "Insère TEXTE dans le tampon courant.  Renvoie non-nil en cas de succès."
  (goto-char (point-min))
  (pcase type
    ('note
     ;; Le squelette est de notre fabrication : une recherche d'en-tête suffit,
     ;; et coûte infiniment moins qu'une analyse org-element du tampon entier.
     (when (re-search-forward "^\\* Transcription[ \t]*$" nil t)
       (forward-line 1)
       (let ((fin (save-excursion
                    (if (re-search-forward "^\\* " nil t)
                        (match-beginning 0)
                      (point-max)))))
         (delete-region (point) fin))
       (insert "\n" (string-trim texte) "\n\n")
       t))
    ('item
     ;; L'ancre est le nom de base du fichier audio : il figure littéralement
     ;; dans le lien de l'item et survit donc à son déplacement dans le fichier.
     (when (and ancre (search-forward ancre nil t))
       (end-of-line)
       (let ((marge (make-string 4 ?\s)))
         (insert "\n" marge
                 (string-replace "\n" (concat "\n" marge) (string-trim texte))))
       t))))

(defun usr--vocale-secours (cible texte)
  "Écrit TEXTE à part : la transcription n'est jamais perdue silencieusement."
  (make-directory usr-vocale-repertoire t)
  (let ((secours (expand-file-name
                  (format "%s-transcription.txt"
                          (or (plist-get cible :ancre) "orpheline"))
                  usr-vocale-repertoire)))
    (with-temp-file secours (insert texte))
    (message "Note introuvable — transcription écrite dans %s"
             (abbreviate-file-name secours))))

(defun usr--vocale-deposer-transcription (cible texte &optional essai)
  "Dépose TEXTE dans la note désignée par CIBLE, sans voler le focus."
  (let ((fichier (usr--vocale-fichier-cible cible))
        (essai (or essai 0)))
    (if (null fichier)
        (usr--vocale-secours cible texte)
      (let* ((deja (find-buffer-visiting fichier))
             ;; find-file-noselect et jamais find-file : ni fenêtre ni tampon
             ;; courant ne changent, l'utilisateur continue de travailler
             ;; pendant que la note se complète sous lui.
             (tampon (or deja (find-file-noselect fichier t)))
             (pose nil))
        (with-current-buffer tampon
          (save-excursion
            (save-restriction
              (widen)
              (setq pose (usr--vocale-inserer texte
                                              (plist-get cible :type)
                                              (plist-get cible :ancre)))
              (when pose (let ((save-silently t)) (save-buffer))))))
        ;; On ne tue que les tampons que nous avons nous-mêmes ouverts.
        (unless deja (kill-buffer tampon))
        (cond
         (pose t)
         ;; La capture n'est peut-être pas encore finalisée : on réessaie.
         ((< essai 6)
          (run-at-time 5 nil #'usr--vocale-deposer-transcription
                       cible texte (1+ essai)))
         (t (usr--vocale-secours cible texte)))))))

(defun usr--vocale-transcrire-vers (audio cible)
  "Propose de transcrire AUDIO et de déposer le résultat dans CIBLE."
  (let ((obstacle (usr--transcription-obstacle)))
    (cond
     (obstacle
      (usr--vocale-deposer-transcription
       cible (format "(transcription indisponible : %s)" obstacle)))
     ((not (y-or-n-p "Transcrire cet enregistrement en arrière-plan ? "))
      (usr--vocale-deposer-transcription cible "(pas de transcription)"))
     (t
      (usr--vocale-tache-debut)
      (usr--transcrire
       audio
       (lambda (texte erreur)
         (usr--vocale-tache-fin)
         (usr--vocale-deposer-transcription
          cible (or texte (format "(échec de la transcription : %s)" erreur)))
         (message (if texte
                      "Transcription déposée."
                    (format "Transcription en échec : %s" erreur)))))))))

;;;; --- Cibles de capture ----------------------------------------------------

(defun usr--vocale-attendre-fichier ()
  (let ((tours 0))
    (while (and (null usr--vocale-en-attente) (< tours 200))
      (accept-process-output nil 0.05)
      (setq tours (1+ tours))))
  (unless usr--vocale-en-attente
    (user-error "L'enregistrement n'a pas pu être finalisé")))

(defun usr--vocale-assurer-enregistrement ()
  "Garantit qu'un enregistrement terminé attend d'être rattaché."
  (cond
   (usr--vocale-en-attente)
   ((usr--vocale-en-cours-p)
    (usr--vocale-arreter)
    (usr--vocale-attendre-fichier))
   (t
    ;; org-capture appelé sans enregistrement préalable : on enregistre ici.
    ;; C'est le seul chemin synchrone du dispositif ; la touche micro y met fin
    ;; aussi bien que n'importe quelle autre.
    (usr--vocale-demarrer #'ignore)
    (unwind-protect
        (read-event (propertize " ● Enregistrement — une touche pour arrêter… "
                                'face '(:foreground "red" :weight bold)))
      (usr--vocale-arreter))
    (usr--vocale-attendre-fichier))))

(defun usr--vocale-lire-mots-cles ()
  "Demande les mots-clés de la note, `usr-vocale-mot-cle' déjà en place."
  (seq-uniq
   (cons usr-vocale-mot-cle
         (completing-read-multiple "Mots-clés : "
                                   (ignore-errors (denote-keywords))
                                   nil nil
                                   (concat usr-vocale-mot-cle ",")))))

(defun usr--vocale-cible-note ()
  "Cible du modèle de capture « v » : crée la note Denote et son squelette."
  (usr--vocale-assurer-enregistrement)
  (let* ((paire usr--vocale-en-attente)
         (source (car paire))
         (duree (cdr paire))
         (titre (read-string "Titre de la note vocale : "))
         (mots (usr--vocale-lire-mots-cles))
         (audio (usr--vocale-deposer-audio source titre mots)))
    (setq usr--vocale-en-attente nil)
    ;; Même idiome que usr-flux-capturer : denote visite le nouveau tampon,
    ;; on y écrit à la suite.
    (denote titre mots 'org)
    (goto-char (point-max))
    (insert (usr--vocale-squelette audio duree))
    ;; La note doit exister sur le disque tout de suite : la transcription
    ;; arrive plus tard et doit pouvoir la retrouver, tampon tué ou non.
    (save-buffer)
    (usr--vocale-transcrire-vers
     audio (list :type 'note
                 :fichier (buffer-file-name)
                 :ancre (file-name-base audio)
                 :id (and (fboundp 'denote-retrieve-filename-identifier)
                          (denote-retrieve-filename-identifier (buffer-file-name)))))
    (goto-char (point-max))))

(defun usr--vocale-lien-org ()
  "Lien Org du dernier audio déposé, pour le modèle de capture « V »."
  (or usr--vocale-lien-courant ""))

(defun usr--vocale-cible-notes ()
  "Cible du modèle de capture « V » : fin de la rubrique « Notes »."
  (usr--vocale-assurer-enregistrement)
  (let* ((paire usr--vocale-en-attente)
         (source (car paire))
         (duree (cdr paire))
         (audio (usr--vocale-deposer-audio source "note-vocale"
                                           (list usr-vocale-mot-cle)))
         (fichier (expand-file-name org-default-notes-file)))
    (setq usr--vocale-en-attente nil
          usr--vocale-lien-courant
          (usr--vocale-lien audio (format "🎙 %s" (usr--vocale-duree-texte duree))))
    (set-buffer (find-file-noselect fichier))
    (widen)
    (goto-char (point-min))
    (unless (re-search-forward "^\\*+[ \t]+Notes[ \t]*$" nil t)
      (goto-char (point-max))
      (insert "\n* Notes\n"))
    (org-back-to-heading t)
    (org-end-of-subtree t t)
    (usr--vocale-transcrire-vers
     audio (list :type 'item :fichier fichier :ancre (file-name-base audio)))))

;;;; --- Commandes ------------------------------------------------------------

(defun usr--vocale-afficher-texte (texte &optional titre)
  "Affiche TEXTE dans le tampon *transcription* et renvoie ce tampon."
  (let ((tampon (get-buffer-create "*transcription*")))
    (with-current-buffer tampon
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (when titre (insert titre "\n\n"))
        (insert texte "\n")
        (goto-char (point-min)))
      (setq buffer-read-only t))
    (display-buffer tampon)
    tampon))

(defun usr-vocale-ecouter ()
  "Réécoute l'enregistrement en attente de rattachement."
  (interactive)
  (if (null usr--vocale-en-attente)
      (message "Aucun enregistrement en attente.")
    (let ((fichier (car usr--vocale-en-attente)))
      (cond ((fboundp 'emms-play-file) (emms-play-file fichier))
            ((executable-find "mpv")
             (start-process "mpv-vocale" nil "mpv" "--really-quiet" fichier))
            (t (message "Aucun lecteur audio disponible."))))))

(defun usr-vocale-garder-audio ()
  "Dépose l'enregistrement en attente dans le Bureau, sans créer de note."
  (interactive)
  (if (null usr--vocale-en-attente)
      (message "Aucun enregistrement en attente.")
    (let ((audio (usr--vocale-deposer-audio (car usr--vocale-en-attente)
                                            "note-vocale"
                                            (list usr-vocale-mot-cle))))
      (setq usr--vocale-en-attente nil)
      (message "Audio conservé : %s" (file-name-nondirectory audio)))))

(defun usr-vocale-supprimer ()
  "Supprime l'enregistrement en attente."
  (interactive)
  (if (null usr--vocale-en-attente)
      (message "Aucun enregistrement en attente.")
    (delete-file (car usr--vocale-en-attente))
    (setq usr--vocale-en-attente nil)
    (message "Enregistrement supprimé.")))

(defun usr-transcription-basculer ()
  "Alterne entre le moteur local (whisper.cpp) et l'API OpenAI."
  (interactive)
  (setq usr-transcription-moteur
        (if (eq usr-transcription-moteur 'local) 'api 'local))
  (message "Moteur de transcription : %s" (usr--vocale-moteur-texte)))

(defun usr--vocale-desc-moteur ()
  (format "moteur        : %s" (usr--vocale-moteur-texte)))

(defun usr-transcrire-fichier (fichier)
  "Transcrit FICHIER et affiche le texte, sans créer de note."
  (interactive
   (list (read-file-name "Fichier audio : " (usr--vocale-bureau) nil t)))
  (let ((obstacle (usr--transcription-obstacle)))
    (when obstacle
      (user-error "Transcription impossible : %s" obstacle))
    (usr--vocale-tache-debut)
    (usr--start-spinner (format "Transcription de %s" (file-name-nondirectory fichier)))
    (usr--transcrire
     fichier
     (lambda (texte erreur)
       (usr--vocale-tache-fin)
       (if texte
           (progn (usr--stop-spinner "Transcription terminée.")
                  (usr--vocale-afficher-texte texte))
         (usr--stop-spinner (format "Échec de la transcription : %s" erreur)))))))

(defun usr-vocale-installer-modele ()
  "Télécharge les poids whisper.cpp (~1,5 Go) : Guix ne les fournit pas."
  (interactive)
  (unless (executable-find "curl")
    (user-error "curl est absent"))
  (when (or (not (file-exists-p usr-whisper-modele))
            (yes-or-no-p "Le modèle est déjà présent.  Le retélécharger ? "))
    (make-directory (file-name-directory usr-whisper-modele) t)
    (usr--start-spinner "Téléchargement du modèle whisper (~1,5 Go)")
    (set-process-sentinel
     (make-process
      :name "whisper-modele" :buffer " *whisper-modele*" :noquery t
      ;; ggml-medium.bin, et surtout pas ggml-medium.en.bin : la variante
      ;; « .en » ne connaît que l'anglais et produirait du charabia.
      :command (list "curl" "-fL" "--create-dirs"
                     "-o" (expand-file-name usr-whisper-modele)
                     "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"))
     (lambda (proc _evenement)
       (when (memq (process-status proc) '(exit signal))
         (usr--stop-spinner
          (if (zerop (process-exit-status proc))
              "Modèle whisper installé."
            "Échec du téléchargement du modèle.")))))))

;;;; --- Boîte vocale externe -------------------------------------------------

(defvar usr--boite-echecs nil)
(defvar usr--boite-reussites 0)

(defun usr--boite-lister ()
  "Enregistrements prêts à être traités dans `usr-vocale-boite'."
  (let ((maintenant (current-time)))
    (sort
     (seq-filter
      (lambda (fichier)
        (and (file-regular-p fichier)
             (member (downcase (or (file-name-extension fichier) ""))
                     usr-vocale-extensions)
             (not (string-prefix-p "~syncthing~" (file-name-nondirectory fichier)))
             ;; On laisse passer trente secondes : un transfert Syncthing peut
             ;; être encore en cours sur ce fichier.
             (> (float-time
                 (time-subtract maintenant
                                (file-attribute-modification-time
                                 (file-attributes fichier))))
                30)))
      (directory-files usr-vocale-boite t "\\`[^.]"))
     #'string<)))

(defun usr-boite-vocale-traiter ()
  "Traite un à un les enregistrements déposés dans la boîte vocale.
Chaque fichier est transcrit, puis titré et tagué par vos soins, puis déplacé
dans le Bureau au format Denote : la boîte se vide au fur et à mesure."
  (interactive)
  (make-directory usr-vocale-boite t)
  (let ((fichiers (usr--boite-lister)))
    (if (null fichiers)
        (message "Boîte vocale vide (%s)." (abbreviate-file-name usr-vocale-boite))
      (setq usr--boite-echecs nil
            usr--boite-reussites 0)
      (usr--boite-suivant fichiers))))

(defun usr--boite-suivant (restants)
  (if (null restants)
      (message "Boîte vocale : %d note(s) créée(s), %d échec(s)%s"
               usr--boite-reussites (length usr--boite-echecs)
               (if usr--boite-echecs
                   (format " — %s" (mapconcat #'file-name-nondirectory
                                              (reverse usr--boite-echecs) ", "))
                 ""))
    (let ((fichier (car restants))
          (suite (cdr restants)))
      (usr--vocale-tache-debut)
      (usr--start-spinner (format "Transcription de %s"
                                  (file-name-nondirectory fichier)))
      (usr--transcrire
       fichier
       (lambda (texte erreur)
         (usr--vocale-tache-fin)
         (usr--stop-spinner
          (if texte
              "Transcription terminée."
            (format "Transcription en échec : %s" erreur)))
         ;; Sans transcription, on demande : le fichier est peut-être corrompu,
         ;; auquel cas il doit rester dans la boîte pour être examiné.
         (if (or texte
                 (yes-or-no-p
                  (format "Pas de transcription pour %s.  Créer la note quand même ? "
                          (file-name-nondirectory fichier))))
             (condition-case err
                 (usr--boite-finaliser fichier texte)
               (error
                (push fichier usr--boite-echecs)
                (message "Échec sur %s : %s"
                         (file-name-nondirectory fichier)
                         (error-message-string err))))
           (push fichier usr--boite-echecs))
         (usr--boite-suivant suite))))))

(defun usr--boite-finaliser (fichier texte)
  "Crée la note Denote de FICHIER puis sort l'audio de la boîte."
  (let ((apercu (usr--vocale-afficher-texte
                 (or texte "(transcription indisponible)")
                 (format "#+TITLE: %s" (file-name-nondirectory fichier)))))
    (unwind-protect
        (let* ((titre (read-string "Titre : " (usr--vocale-titre-suggere texte)))
               (mots (usr--vocale-lire-mots-cles))
               ;; L'horodatage vient de la date du fichier — l'instant de
               ;; l'enregistrement sur le téléphone — et non de maintenant :
               ;; la chronologie de la base Denote reste juste.
               (temps (file-attribute-modification-time (file-attributes fichier)))
               (duree (usr--vocale-duree-fichier fichier))
               ;; Le déplacement vient en dernier : si quoi que ce soit échoue
               ;; avant, le fichier est resté intact dans la boîte et sera
               ;; repris au prochain passage.  L'audio n'est jamais perdu.
               (audio (usr--vocale-deposer-audio fichier titre mots temps)))
          (denote titre mots 'org)
          (goto-char (point-max))
          (insert (usr--vocale-squelette audio duree))
          (save-excursion
            (save-restriction
              (widen)
              (usr--vocale-inserer (or texte "(transcription indisponible)") 'note nil)))
          (save-buffer)
          (setq usr--boite-reussites (1+ usr--boite-reussites)))
      (when (buffer-live-p apercu) (kill-buffer apercu)))))

(defun usr--vocale-titre-suggere (texte)
  "Propose un titre à partir des premiers mots de TEXTE."
  (when texte
    (let ((extrait (string-trim (replace-regexp-in-string "[ \t\n]+" " " texte))))
      (if (> (length extrait) 60) (substring extrait 0 60) extrait))))

;;; RACCOURCIS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;;
;; Une seule porte d'entrée : s-SPC (C-c SPC en secours, hors session X).
;; C'est le SEUL endroit du fichier où une touche globale est déclarée ; les
;; tables propres aux modes (org, ledger, dired, notmuch, elfeed, image) et
;; les idiomes Emacs standards (C-x b, C-x m, C-h f, C-;, C-M-/) restent
;; définis auprès de leur paquet.
;;
;;   s-SPC          le menu
;;   s-<flèches>    déplacement entre fenêtres
;;   s-<tab>        plein écran
;;   touches XF86   volume, lecture, luminosité
;;
;; Tout le reste passe par le menu.

(require 'transient)

;;;; --- Commandes d'appoint --------------------------------------------------

(defun usr-configuration-recharger ()
  "Recharge le fichier d'initialisation sans quitter la session EXWM."
  (interactive)
  (load-file user-init-file)
  (message "Configuration rechargée."))

(defun usr-configuration-editer ()
  "Ouvre le fichier d'initialisation."
  (interactive)
  (find-file user-init-file))

(defun usr-agenda-trois-jours ()
  "Ouvre la vue d'agenda « trois jours, actions et attentes »."
  (interactive)
  (org-agenda nil "e"))

(defun usr-journal-du-jour ()
  "Ouvre ou crée l'entrée de journal interstitiel du jour."
  (interactive)
  (org-capture nil "j"))

(defun usr-tache-todo ()
  "Capture une nouvelle tâche TODO."
  (interactive)
  (org-capture nil "t"))

(defun usr-tache-suivante ()
  "Capture une action NEXT."
  (interactive)
  (org-capture nil "i"))

(defun usr-rendez-vous ()
  "Capture un rendez-vous."
  (interactive)
  (org-capture nil "r"))

(defun usr-note-vocale-denote ()
  "Enregistre une note vocale et en fait une note Denote."
  (interactive)
  (org-capture nil "v"))

(defun usr-note-vocale-breve ()
  "Enregistre une note vocale brève dans le fichier de notes."
  (interactive)
  (org-capture nil "V"))

(defun usr-facturation-devis ()
  "Crée un devis à partir du modèle LaTeX de l'association."
  (interactive)
  (org-capture nil "d"))

(defun usr-facturation-facture ()
  "Crée une facture à partir du modèle LaTeX de l'association."
  (interactive)
  (org-capture nil "F"))

(defun usr-facturation-recu ()
  "Crée un reçu à partir du modèle LaTeX de l'association."
  (interactive)
  (org-capture nil "u"))

;;;; --- Socle transient ------------------------------------------------------

;; Le menu s'affiche dans une fenêtre latérale basse : sous EXWM, une fenêtre
;; X11 occupant tout le cadre se rétrécit au lieu d'avaler le menu.
(setq transient-display-buffer-action
      '(display-buffer-in-side-window
        (side . bottom)
        (dedicated . t)
        (inhibit-same-window . t)))
(setq transient-mode-line-format nil)

;; --- Parade au mode caractère d'EXWM ---
;; En mode ligne, Emacs garde le focus X et voit toutes les touches : le menu
;; fonctionne normalement. En mode caractère, le client X détient le focus et
;; seules les touches saisies par `exwm-input-set-key' remontent — la touche
;; qui suit s-SPC partirait donc dans le client. On rend donc le clavier à
;; Emacs le temps du menu, et on le restitue à la fermeture.

(defvar usr--tampon-mode-char nil
  "Tampon EXWM dont le mode caractère doit être rétabli après le menu.")

(defun usr--clavier-emprunter ()
  "Rend le clavier à Emacs si le tampon courant est une fenêtre X11 en mode caractère."
  (when (and (derived-mode-p 'exwm-mode)
             (eq (bound-and-true-p exwm--input-mode) 'char-mode)
             (fboundp 'exwm-input-grab-keyboard))
    (setq usr--tampon-mode-char (current-buffer))
    (exwm-input-grab-keyboard)))

(defun usr--clavier-restituer ()
  "Rétablit le mode caractère emprunté par `usr--clavier-emprunter'."
  (when (buffer-live-p usr--tampon-mode-char)
    (with-current-buffer usr--tampon-mode-char
      (when (fboundp 'exwm-input-release-keyboard)
        (exwm-input-release-keyboard))))
  (setq usr--tampon-mode-char nil))

;; `transient-exit-hook' ne se déclenche qu'à la fermeture complète de la
;; pile : les sous-menus ne restituent donc pas le clavier prématurément.
(add-hook 'transient-exit-hook #'usr--clavier-restituer)

(defun usr-menu-ouvrir ()
  "Ouvre le menu principal, y compris depuis une fenêtre X11 en mode caractère."
  (interactive)
  (usr--clavier-emprunter)
  (call-interactively #'usr-menu))

;;;; --- Descriptions vivantes de l'assistant ---------------------------------

(defun usr--ia-desc-directive ()
  (format "directive     : %s" (or usr-ia-directive-courante "—")))

(defun usr--ia-desc-modele ()
  (format "modèle        : %s"
          (let ((m (or usr-ia-modele-courant (bound-and-true-p gptel-model))))
            (cond ((and m (fboundp 'gptel--model-name)) (gptel--model-name m))
                  (m (format "%s" m))
                  (t "—")))))

(defun usr--ia-desc-outils ()
  (format "outils        : %s"
          (if (bound-and-true-p gptel-tools) "notes" "aucun")))

(defun usr--ia-desc-web ()
  (format "recherche web : %s"
          (if (and (boundp 'gptel-backend)
                   (boundp 'gptel--backend-anthropic-web)
                   (eq gptel-backend gptel--backend-anthropic-web))
              "activée"
            "désactivée")))

(defun usr--ia-desc-fil ()
  (format "fil           : %d tour(s)" (/ (length usr--ia-fil) 2)))

;;;; --- Menus ----------------------------------------------------------------

(transient-define-prefix usr-menu-applications ()
  "Lancer ou rejoindre une application."
  [["Terminaux"
    ("t" "terminal (XTerm)" usr-terminal)
    ("e" "eshell"           eshell)
    ("S" "shell"            shell)
    ("p" "processus"        proced)]
   ["Bureau"
    ("f" "fichiers (Dired)" dired)
    ("n" "navigateur"       usr-navigateur)
    ("o" "LibreOffice"      usr-bureautique)
    ("k" "mode kiosque"     usr-kiosque-activer)
    ("K" "quitter le kiosque" usr-kiosque-desactiver)]
   ["Média"
    ("m" "musique"          emms)
    ("b" "bibliothèque musicale" emms-browser)
    ("l" "liste de lecture" emms-play-playlist)
    ("i" "images"           image-dired)
    ("r" "flux RSS"         elfeed)]
   ["Services"
    ("s" "interface Syncthing" syncthing)]])

(transient-define-prefix usr-menu-fenetres ()
  "Disposition des fenêtres et tampons."
  [["Disposition"
    ("h" "scinder en bas"    split-window-below)
    ("v" "scinder à droite"  split-window-right)
    ("0" "fermer la fenêtre" delete-window)
    ("1" "fermer les autres" delete-other-windows)
    ("=" "équilibrer"        balance-windows)]
   ["Naviguer"
    ("<left>"  "à gauche"    windmove-left)
    ("<right>" "à droite"    windmove-right)
    ("<up>"    "au-dessus"   windmove-up)
    ("<down>"  "en dessous"  windmove-down)]
   ["Tampons"
    ("<" "précédent"         previous-buffer)
    (">" "suivant"           next-buffer)
    ("r" "fichiers récents…" recentf-open)]
   ["Fenêtre X11"
    ("p" "plein écran"       exwm-layout-toggle-fullscreen)
    ("M" "mode ligne / caractère" exwm-input-toggle-keyboard)
    ("w" "bureau…"           exwm-workspace-switch)
    ("W" "nouveau bureau"    exwm-workspace-switch-create)]])

(transient-define-prefix usr-menu-organisation ()
  "Agenda, capture et calendrier."
  [["Agenda"
    ("a" "agenda"              org-agenda)
    ("A" "vue « trois jours »" usr-agenda-trois-jours)
    ("j" "journal du jour"     usr-journal-du-jour)]
   ["Capturer"
    ("c" "capture…"            org-capture)
    ("t" "nouvelle tâche"      usr-tache-todo)
    ("n" "action suivante"     usr-tache-suivante)
    ("r" "rendez-vous"         usr-rendez-vous)
    ("v" "note vocale"         usr-note-vocale-denote)
    ("V" "note vocale brève"   usr-note-vocale-breve)]
   ["Dates"
    ("k" "calendrier"          calendar)
    ("l" "insérer un lien"     org-store-link)]])

(transient-define-prefix usr-menu-notes-explorer ()
  "Statistiques et entretien de la base Denote."
  [["Statistiques"
    ("c" "compter les notes"       denote-explore-count-notes)
    ("C" "compter les mots-clés"   denote-explore-count-keywords)
    ("b" "histogramme des mots-clés" denote-explore-barchart-keywords)
    ("t" "histogramme des types"   denote-explore-barchart-filetypes)]
   ["Marche aléatoire"
    ("r" "note au hasard"          denote-explore-random-note)
    ("l" "lien au hasard"          denote-explore-random-link)
    ("k" "mot-clé au hasard"       denote-explore-random-keyword)
    ("x" "expression au hasard"    denote-explore-random-regex)]
   ["Entretien"
    ("d" "notes en double"         denote-explore-identify-duplicate-notes)
    ("z" "notes sans mot-clé"      denote-explore-zero-keywords)
    ("s" "mots-clés uniques"       denote-explore-single-keywords)
    ("o" "trier les mots-clés"     denote-explore-sort-keywords)
    ("w" "renommer un mot-clé"     denote-explore-rename-keyword)]
   ["Graphe"
    ("g" "générer le réseau"       denote-explore-network)
    ("G" "régénérer le réseau"     denote-explore-network-regenerate)
    ("D" "histogramme des degrés"  denote-explore-barchart-degree)]])

(transient-define-prefix usr-menu-notes-biblio ()
  "Bibliographie et notes de lecture."
  [["Références"
    ("b" "chercher en ligne…"   ews-bibtex-biblio-lookup)
    ("o" "ouvrir une référence" citar-open)
    ("R" "réenregistrer la base" ews-bibtex-register)]
   ["Notes de lecture"
    ("c" "créer une note"       citar-create-note)
    ("n" "ouvrir la note"       citar-denote-open-note)
    ("x" "références sans note" citar-denote-nocite)]
   ["Dans le texte (Org)"
    ("k" "ajouter une clé"      citar-denote-add-citekey)
    ("K" "retirer une clé"      citar-denote-remove-citekey)
    ("d" "agir sur la citation" citar-denote-dwim)
    ("e" "ouvrir l'entrée BibTeX" citar-denote-open-reference-entry)]])

(transient-define-prefix usr-menu-notes ()
  "Notes Denote et documentation."
  [["Créer"
    ("n" "nouvelle note"        denote)
    ("d" "note datée"           denote-date)
    ("i" "lier ou créer"        denote-link-or-create)
    ("h" "lien vers un titre"   denote-org-link-to-heading)]
   ["Parcourir"
    ("f" "chercher une note…"   consult-notes)
    ("g" "chercher dans les notes…" consult-notes-search-in-all-notes)
    ("l" "liens sortants"       denote-find-link)
    ("b" "rétroliens"           denote-find-backlink)]
   ["Entretien"
    ("r" "renommer"             denote-rename-file)
    ("R" "renommer (en-tête)"   denote-rename-file-using-front-matter)
    ("k" "modifier les mots-clés" denote-rename-file-keywords)]
   ["Approfondir"
    ("x" "explorer la base…"    usr-menu-notes-explorer)
    ("B" "bibliographie…"       usr-menu-notes-biblio)]
   ["Vocal"
    ("v" "enregistrer / arrêter"   usr-note-vocale)
    ("t" "transcrire un fichier…"  usr-transcrire-fichier)
    ("I" "traiter la boîte vocale" usr-boite-vocale-traiter)
    ("m" usr-transcription-basculer :description usr--vocale-desc-moteur)]])

(transient-define-prefix usr-menu-ecriture ()
  "Écriture, relecture et export."
  [["Langue"
    ("o" "corriger le mot"      flyspell-auto-correct-previous-word)
    ("O" "vérifier tout le texte" ispell)
    ("m" "définition d'un mot…" dictionary-lookup-definition)
    ("l" "lisibilité du texte"  writegood-reading-ease)]
   ["Org"
    ("n" "tiroir de notes"      ews-org-insert-notes-drawer)
    ("c" "compter les mots"     ews-org-count-words)
    ("i" "insérer une capture d'écran" ews-org-insert-screenshot)
    ("w" "insérer un lien web…" org-web-tools-insert-link-for-url)
    ("h" "aller à un titre…"    consult-org-heading)
    ("g" "chercher dans les fichiers…" consult-grep)]
   ["Confort"
    ("s" "sans distraction"     darkroom-mode)
    ("t" "thème clair / sombre" modus-themes-toggle)
    ("T" "choisir un thème…"    modus-themes-select)
    ("u" "annuler visuellement" vundo)]
   ["Exporter"
    ("p" "en PDF"               org-latex-export-to-pdf)
    ("P" "en PDF vers un dossier…" usr-export-pdf-vers)
    ("e" "en EPUB"              org-epub-export-to-epub)]])

(transient-define-prefix usr-menu-courriel ()
  "Courriel (notmuch)."
  [["Lire"
    ("n" "nouveaux (TECI)"      usr-courriel-nouveaux)
    ("i" "boîte de réception"   usr-courriel-boite)
    ("m" "accueil notmuch"      notmuch)
    ("f" "chercher…"            notmuch-search)]
   ["Écrire"
    ("c" "nouveau message"      notmuch-mua-new-mail)
    ("p" "contacts"             ebdb)]
   ["Entretien"
    ("s" "synchroniser"         usr-courriel-synchroniser)]])

(transient-define-prefix usr-menu-ia ()
  "Assistant IA (gptel)."
  [["Dialogue"
    ("q" "question…"            usr-ia-question)
    ("t" "fil de discussion…"   usr-ia-dialogue)
    ("T" "réinitialiser le fil" usr-ia-dialogue-reinitialiser)
    ("b" "voir la réponse"      usr-ia-voir-reponse)
    ("y" "copier la réponse"    usr-ia-copier-reponse)]
   ["Sur le texte"
    ("c" "corriger la région"   usr-ia-corriger)
    ("e" "rédiger un courriel"  usr-ia-courriel)
    ("r" "réécrire"             gptel-rewrite)
    ("D" "diagnostiquer une erreur" usr-ia-diagnostiquer)]
   ["Contexte"
    ("a" "ajouter le tampon"    gptel-add)
    ("F" "ajouter un fichier"   gptel-add-file)
    ("x" "vider le contexte"    usr-ia-contexte-vider)]
   ["Session Emacs"
    ("g" "nouvelle session"     gptel)
    ("RET" "envoyer"            gptel-send)
    ("SPC" "menu gptel"         gptel-menu)]
   ["Réglages"
    ("d" usr-ia-directive   :description usr--ia-desc-directive)
    ("m" usr-ia-modele      :description usr--ia-desc-modele)
    ("M" "modèle par défaut" usr-ia-modele-defaut)
    ("o" usr-ia-outils      :description usr--ia-desc-outils)
    ("w" usr-ia-recherche-web :description usr--ia-desc-web)
    ("?" usr-ia-etat        :description usr--ia-desc-fil)]]
  (interactive)
  (require 'gptel nil t)
  (transient-setup 'usr-menu-ia))

(transient-define-prefix usr-menu-comptabilite ()
  "Comptabilité et facturation de l'association."
  [["Journal"
    ("o" "ouvrir le journal"    usr-compta-ouvrir)
    ("a" "ajouter une écriture" ledger-add-transaction)
    ("v" "vérifier le journal"  usr-compta-verifier)
    ("r" "rapports…"            ledger-report)
    ("e" "exporter en CSV"      usr-compta-exporter)]
   ["Documents"
    ("d" "nouveau devis"        usr-facturation-devis)
    ("f" "nouvelle facture"     usr-facturation-facture)
    ("u" "nouveau reçu"         usr-facturation-recu)]])

(transient-define-prefix usr-menu-systeme ()
  "Énergie, sécurité, services et matériel."
  [["Énergie"
    ("q" "éteindre"             usr-eteindre)
    ("r" "redémarrer"           usr-redemarrer)
    ("z" "mettre en veille"     usr-veille)
    ("v" "verrouiller l'écran"  usr-ecran-verrouiller)]
   ["Sécurité & réseau"
    ("g" "déverrouiller GPG"    usr-gpg-deverrouiller)
    ("G" "verrouiller GPG"      usr-gpg-verrouiller)
    ("m" "monter Club1"         usr-club1-monter)
    ("M" "démonter Club1"       usr-club1-demonter)
    ("s" "démarrer Syncthing"   usr-syncthing-demarrer)
    ("S" "arrêter Syncthing"    usr-syncthing-arreter)
    ("a" "actualiser les témoins" usr-etat-actualiser)]
   ["Son & affichage"
    ("+" "volume +"             usr-volume-monter    :transient t)
    ("-" "volume −"             usr-volume-baisser   :transient t)
    ("0" "couper le son"        usr-volume-couper    :transient t)
    (">" "luminosité +"         usr-luminosite-monter  :transient t)
    ("<" "luminosité −"         usr-luminosite-baisser :transient t)]
   ["Configuration"
    ("u" "mettre à jour (guix pull)" usr-guix-mettre-a-jour)
    ("c" "recharger la configuration" usr-configuration-recharger)
    ("e" "éditer init.el"       usr-configuration-editer)
    ("t" "vider la corbeille"   usr-corbeille-vider)
    ("p" "personnaliser une variable…" customize-variable)]])

(transient-define-prefix usr-menu-aide ()
  "Découvrir les commandes et les touches."
  [["Découvrir"
    ("k" "décrire une touche…"  helpful-key)
    ("m" "touches du mode"      describe-mode)
    ("a" "chercher une commande…" apropos-command)]
   ["Décrire"
    ("f" "une fonction…"        helpful-function)
    ("x" "une commande…"        helpful-command)
    ("v" "une variable…"        helpful-variable)]
   ["Cette configuration"
    ("c" "la carte des raccourcis"  usr-carte-raccourcis)
    ("t" "les touches matérielles"  usr-touches-materielles)
    ("V" "vérifier les touches"     usr-touches-verifier)]])

(transient-define-prefix usr-menu ()
  "Menu principal de la session."
  [:description "s-SPC — menu de la session"
   ["Rapide"
    ("SPC" "tampon…"            consult-buffer)
    ("t"   "trouver un fichier…" find-file)
    ("x"   "commande (M-x)"     execute-extended-command)
    ("k"   "fermer le tampon"   kill-current-buffer)]
   ["Travail"
    ("o" "Organisation"         usr-menu-organisation)
    ("n" "Notes & documents"    usr-menu-notes)
    ("e" "Écriture"             usr-menu-ecriture)
    ("c" "Courriel"             usr-menu-courriel)
    ("i" "Assistant IA"         usr-menu-ia)
    ("$" "Comptabilité"         usr-menu-comptabilite)]
   ["Machine"
    ("a" "Applications"         usr-menu-applications)
    ("f" "Fenêtres"             usr-menu-fenetres)
    ("s" "Système"              usr-menu-systeme)
    ("?" "Aide"                 usr-menu-aide)]])

;;;; --- Commandes liées au matériel ------------------------------------------

(defun usr-etat-actualiser ()
  "Relance la sonde système et rafraîchit les témoins de la modeline.
Utile pour vérifier tout de suite après avoir branché le réseau ou
monté un partage, sans attendre le prochain sondage périodique."
  (interactive)
  (usr--verifier-systeme)
  (message "État système actualisé."))


;;;; --- Touches directes -----------------------------------------------------

(when (display-graphic-p)
  (condition-case err
      (call-process "setxkbmap" nil nil nil "-option" "caps:super")
    (error (message "setxkbmap absent : VerrMaj non convertie en Super (%s)"
                    (error-message-string err)))))

(defun usr--lier-touche (touche commande)
  "Lie TOUCHE à COMMANDE pour EXWM sans interrompre le chargement en cas d'échec.
Une touche absente du clavier est simplement ignorée."
  (condition-case err
      (exwm-input-set-key (kbd touche) commande)
    (error (message "Raccourci ignoré (%s) : %s"
                    touche (error-message-string err)))))

(defvar usr--touches-declarees
  '(;; --- La porte d'entrée unique ---
    ("s-SPC"     . usr-menu-ouvrir)
    ("s-g"       . keyboard-quit)

    ;; --- Gestes réflexes ---
    ("s-<left>"   . windmove-left)
    ("s-<right>"  . windmove-right)
    ("s-<up>"     . windmove-up)
    ("s-<down>"   . windmove-down)
    ("s-<prior>"  . previous-buffer)
    ("s-<next>"   . next-buffer)
    ("s-<return>"    . delete-other-windows)
    ("s-<tab>" . split-window-right)

    ;; --- Touches dédiées du clavier ---
    ;; Son
    ("<XF86AudioRaiseVolume>"  . usr-volume-monter)
    ("<XF86AudioLowerVolume>"  . usr-volume-baisser)
    ("<XF86AudioMute>"         . usr-volume-couper)
    ("<XF86AudioPlay>"         . emms-pause)
    ("<XF86AudioNext>"         . emms-next)
    ("<XF86AudioPrev>"         . emms-previous)
    ;; Écran
    ("<XF86MonBrightnessUp>"   . usr-luminosite-monter)
    ("<XF86MonBrightnessDown>" . usr-luminosite-baisser)
    ;; La touche « écran » met la fenêtre X11 courante en plein écran.
    ("<XF86Display>"           . exwm-layout-toggle-fullscreen)
    ;; La touche « sans-fil » rafraîchit les témoins réseau de la modeline
    ;; plutôt que de couper la radio : c'est l'usage réellement utile ici.
    ("<XF86WLAN>"              . usr-etat-actualiser)
    ;; La touche « micro » démarre l'enregistrement ; une seconde pression
    ;; l'arrête et propose de le rattacher à une note.
    ("<XF86AudioMicMute>"      . usr-note-vocale))
  "Touches globales déclarées, sous forme (TOUCHE . COMMANDE).
Sert aussi de source à `usr-touches-materielles'.")

(dolist (paire usr--touches-declarees)
  (usr--lier-touche (car paire) (cdr paire)))

;; Ces déclarations arrivent bien après (exwm-wm-mode), qui démarre EXWM en
;; début de fichier. Selon la version, `exwm-input-set-key' ne redemande pas
;; toujours la capture des touches au serveur X pour une session déjà lancée :
;; sans nouvelle prise, la touche part au client X11 au lieu de remonter à
;; Emacs. On redemande donc explicitement la prise.
(dolist (fonction '(exwm-input--update-global-prefix-keys
                    exwm-input--update-global-keys))
  (when (and (fboundp fonction) (bound-and-true-p exwm--connection))
    (ignore-errors (funcall fonction))))

;; Filet complémentaire : la table du mode majeur est consultée avant la table
;; globale. Déclarer aussi les touches Super dans `exwm-mode-map' garantit
;; qu'elles agissent depuis un tampon X11, y compris en mode ligne.
(with-eval-after-load 'exwm
  (dolist (paire usr--touches-declarees)
    (when (string-prefix-p "s-" (car paire))
      (ignore-errors
        (keymap-set exwm-mode-map (car paire) (cdr paire))))))

(define-key key-translation-map (kbd "s-g") (kbd "C-g"))

(defun usr-touches-verifier ()
  "Vérifie que chaque touche déclarée est bien vue par Emacs et par EXWM.
Une touche « globale non » signale que le lien Emacs manque ; une touche
« EXWM non » signale que le serveur X ne la remonte pas à Emacs et
l'envoie au client X11 à la place."
  (interactive)
  (let ((prises (or (bound-and-true-p exwm-input--global-prefix-keys)
                    (bound-and-true-p exwm-input--global-keys))))
    (with-current-buffer (get-buffer-create "*vérification des touches*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert "#+TITLE: Vérification des touches\n#+OPTIONS: toc:nil\n\n"
                "| touche | commande | globale | EXWM | mode EXWM |\n"
                "|--------+----------+---------+------+-----------|\n")
        (dolist (paire usr--touches-declarees)
          (let* ((touche (car paire))
                 (attendue (cdr paire))
                 (sequence (kbd touche))
                 (globale (eq (lookup-key (current-global-map) sequence) attendue))
                 (dans-exwm (and prises (member sequence prises) t))
                 (dans-map (and (boundp 'exwm-mode-map)
                                (eq (lookup-key exwm-mode-map sequence) attendue))))
            (insert (format "| %s | %s | %s | %s | %s |\n"
                            touche attendue
                            (if globale "oui" "NON")
                            (if dans-exwm "oui" "NON")
                            (if dans-map "oui" "non")))))
        (insert "\n"
                "Une touche dont la colonne EXWM vaut NON n'est pas capturée au\n"
                "serveur X : elle atteindra Emacs depuis un tampon Emacs, mais\n"
                "partira dans IceCat ou XTerm depuis un tampon X11.\n")
        (goto-char (point-min))))
    (pop-to-buffer "*vérification des touches*")))

;; Porte de secours quand la touche Super n'est pas disponible : Emacs en
;; terminal, emacsclient hors session X, machine distante.
(keymap-global-set "C-c SPC" #'usr-menu-ouvrir)

(defun usr-touches-materielles ()
  "Liste les touches XF86 déclarées et celles que le clavier émet réellement.
Une touche déclarée mais absente du clavier ne coûte rien ; l'inverse
signale une touche disponible qui n'est pas encore exploitée."
  (interactive)
  (let ((declarees
         ;; « <XF86AudioMute> » -> « XF86AudioMute », pour comparer à xmodmap.
         (sort (delq nil
                     (mapcar (lambda (k)
                               (when (string-match "\\`<\\(XF86[A-Za-z0-9]+\\)>\\'" k)
                                 (match-string 1 k)))
                             (mapcar #'car usr--touches-declarees)))
               #'string<))
        (emises
         (when (executable-find "xmodmap")
           (sort (delete-dups
                  (seq-filter (lambda (s) (string-prefix-p "XF86" s))
                              (split-string
                               (shell-command-to-string "xmodmap -pke") "[ \n]+" t)))
                 #'string<))))
    (with-current-buffer (get-buffer-create "*touches matérielles*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert "#+TITLE: Touches matérielles\n#+OPTIONS: toc:nil\n\n")
        (insert (format "* Déclarées dans la configuration (%d)\n\n" (length declarees)))
        (dolist (d declarees) (insert (format "  - %s\n" d)))
        (insert "\n* Émises par ce clavier\n\n")
        (cond
         ((not emises)
          (insert "  xmodmap n'est pas installé : impossible d'interroger le clavier.\n"
                  "  Ajoutez « xmodmap » à home.scm, ou appuyez sur une touche après\n"
                  "  C-h k depuis un tampon Emacs pour connaître son nom.\n"))
         (t
          (dolist (e emises)
            (insert (format "  - %s%s\n" e
                            (if (member e declarees) "" "   ← non exploitée"))))))
        (goto-char (point-min))))
    (pop-to-buffer "*touches matérielles*")))

;;;; --- Carte des raccourcis -------------------------------------------------

(defvar usr-carte-menus
  '((usr-menu                 . "Menu principal — s-SPC")
    (usr-menu-organisation    . "Organisation — s-SPC o")
    (usr-menu-notes           . "Notes & documents — s-SPC n")
    (usr-menu-notes-explorer  . "Explorer la base — s-SPC n x")
    (usr-menu-notes-biblio    . "Bibliographie — s-SPC n B")
    (usr-menu-ecriture        . "Écriture — s-SPC e")
    (usr-menu-courriel        . "Courriel — s-SPC c")
    (usr-menu-ia              . "Assistant IA — s-SPC i")
    (usr-menu-comptabilite    . "Comptabilité — s-SPC $")
    (usr-menu-applications    . "Applications — s-SPC a")
    (usr-menu-fenetres        . "Fenêtres — s-SPC f")
    (usr-menu-systeme         . "Système — s-SPC s")
    (usr-menu-aide            . "Aide — s-SPC ?"))
  "Menus à recenser dans `usr-carte-raccourcis', et leur titre.")

(defun usr--carte-texte (valeur)
  "Ramène VALEUR — chaîne ou fonction — à une chaîne affichable."
  (cond ((stringp valeur) valeur)
        ((functionp valeur) (condition-case nil
                                (format "%s" (funcall valeur))
                              (error "…")))
        (t nil)))

(defun usr--carte-noeud (noeud lignes)
  "Ajoute la description de NOEUD à LIGNES (accumulateur inversé).
Parcourt la structure `transient--layout', faite de vecteurs
[NIVEAU CLASSE PROPRIÉTÉS ENFANTS] pour les groupes et
[NIVEAU CLASSE PROPRIÉTÉS] pour les commandes."
  (cond
   ((and (listp noeud) (not (null noeud)))
    (dolist (e noeud) (setq lignes (usr--carte-noeud e lignes)))
    lignes)
   ((not (vectorp noeud)) lignes)
   ((>= (length noeud) 4)                              ; groupe
    (let ((titre (usr--carte-texte (plist-get (aref noeud 2) :description))))
      (when titre (push (format "  /%s/" titre) lignes))
      (usr--carte-noeud (aref noeud 3) lignes)))
   (t                                                  ; commande
    (let* ((p (aref noeud 2))
           (touche (plist-get p :key))
           (desc (usr--carte-texte (plist-get p :description)))
           (cmd (plist-get p :command)))
      (if touche
          (push (format "  | %-6s | %-38s | %s |"
                        touche (or desc "") (or cmd ""))
                lignes)
        lignes)))))

(defun usr-carte-raccourcis ()
  "Produit un tampon Org listant l'intégralité de l'arbre des raccourcis.
La carte est construite à partir des menus eux-mêmes : elle ne peut pas
diverger de ce que les touches font réellement."
  (interactive)
  (let ((tampon (get-buffer-create "*carte des raccourcis*")))
    (with-current-buffer tampon
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert "#+TITLE: Carte des raccourcis\n"
                "#+OPTIONS: toc:nil\n\n"
                "Une seule porte d'entrée : =s-SPC= (=C-c SPC= en secours).\n\n"
                "* Touches directes\n\n"
                "  | s-SPC                | le menu                          |\n"
		"  | s-g                  | annuler (vaut C-g)               |\n"
                "  | s-<flèches>          | déplacement entre fenêtres       |\n"
                "  | s-<tab>              | plein écran                      |\n"
                "  | XF86Audio*           | volume, lecture                  |\n"
                "  | XF86AudioMicMute     | note vocale (marche / arrêt)     |\n"
                "  | XF86MonBrightness*   | luminosité                       |\n"
                "  | C-;                  | corriger le mot précédent        |\n"
                "  | C-x b / C-x m        | tampon / nouveau courriel        |\n"
                "  | C-M-/                | annuler visuellement             |\n\n")
        (dolist (entree usr-carte-menus)
          (let ((prefixe (car entree)))
            (insert (format "* %s\n\n" (cdr entree)))
            (let ((lignes (nreverse
                           (usr--carte-noeud
                            (get prefixe 'transient--layout) nil))))
              (if lignes
                  (insert (mapconcat #'identity lignes "\n") "\n\n")
                (insert "  (menu vide ou non chargé)\n\n")))))
        (goto-char (point-min))))
    (pop-to-buffer tampon)))

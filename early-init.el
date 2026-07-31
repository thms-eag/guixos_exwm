;; -*- lexical-binding: t; -*-
;;; early-init.el --- Chargé avant l'initialisation de l'interface graphique

;; Ce fichier est lu par Emacs avant la création de la première frame et avant
;; init.el. On n'y met que ce qui doit impérativement précéder l'affichage.

;;;; Ramasse-miettes
;; Seuil relevé le temps du chargement : init.el alloue beaucoup (Org, EXWM,
;; les gabarits LaTeX). GCMH (init.el, section « Optimisation du Garbage
;; Collector ») reprend la main juste après et gère le régime de croisière.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;;;; Interface : ne pas dessiner ce qu'init.el retire ensuite
;; init.el appelle tool-bar-mode/menu-bar-mode/scroll-bar-mode à -1, mais après
;; que les barres ont été créées : cela provoque un redimensionnement visible de
;; la frame au démarrage de la session X. Ici, elles ne sont jamais dessinées.
;; Les appels d'init.el restent en place, simplement sans effet.
(push '(tool-bar-lines . 0)          default-frame-alist)
(push '(menu-bar-lines . 0)          default-frame-alist)
(push '(vertical-scroll-bars . nil)  default-frame-alist)

;; Empêche Emacs de redimensionner la frame à chaque changement de police ou de
;; retrait d'élément d'interface — sans intérêt sous EXWM, où Emacs occupe
;; l'écran entier.
(setq frame-inhibit-implied-resize t)

;; Frame initiale en plein écran dès sa création.
;;
;; .xinitrc lance Emacs sans gestionnaire de fenêtres (c'est lui qui le
;; devient), mais `exwm-wm-mode' n'est appelé qu'à la toute fin d'init.el.
;; Sans cette ligne, la frame reste à sa taille par défaut (80x25) dans un coin
;; de l'écran pendant tout le chargement. Faute de WM pour honorer la requête
;; EWMH, Emacs se rabat sur un redimensionnement direct aux dimensions de
;; l'écran — ce qu'on veut ici.
;;
;; `initial-frame-alist' et non `default-frame-alist' : seule la frame de
;; départ est concernée, les frames créées ensuite par
;; `exwm-workspace-switch-create' gardent leur comportement propre.
(push '(fullscreen . fullboth) initial-frame-alist)

;; L'écran d'accueil est déjà désactivé dans init.el ; le poser ici évite qu'il
;; soit brièvement composé.
(setq inhibit-startup-screen t)

;;;; package.el
;; Sous Guix, les paquets Emacs viennent du profil et sont ajoutés au load-path
;; par site-start.el ; package.el n'est pas utilisé (init.el pose d'ailleurs
;; `use-package-always-ensure' à nil). Éviter `package-initialize' au démarrage
;; économise le balayage de ~/.emacs.d/elpa.
;;
;; ATTENTION : ne jamais neutraliser `site-run-file' ici. C'est site-start.el
;; qui rend visibles les paquets installés par Guix ; le désactiver les ferait
;; tous disparaître du load-path.
(setq package-enable-at-startup nil)

;;; early-init.el ends here

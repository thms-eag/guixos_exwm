;;; machines/lateci.scm --- Profil de la machine « lateci »   -*- scheme -*-
;;;
;;; Liste associative lue — et non évaluée — par config.scm et par home.scm.
;;; Elle rassemble ce qui change d'une machine à l'autre sans relever du
;;; secret (prive.scm) ni du goût (init.el).
;;;
;;; Ajouter une machine, c'est déposer un fichier de la même forme dans ce
;;; répertoire, puis nommer ce fichier dans le prive.scm de cette machine :
;;;
;;;     (machine . "portable-atelier")
;;;
;;; Le dépôt reste alors identique partout ; seul prive.scm diffère.
;;;
;;; home.scm engendre depuis ces valeurs ~/.local/share/lateci/machine.el, que
;;; init.el charge au démarrage.  La diode du micro, décrite à la fois par une
;;; règle udev et par la capture vocale, n'est ainsi écrite qu'ici.

((nom-hote         . "lateci")
 (utilisateur      . "thomas_rm")
 (nom-complet      . "Thomas Rousseau-Millasseau")
 (groupes          . ("wheel" "netdev" "audio" "video" "input" "tty"))

 (locale           . "fr_FR.utf8")
 (fuseau           . "Europe/Paris")
 (clavier          . "fr")

 (bootloader-cible . "/boot/efi")

 ;; Nom noyau de la diode du micro.  config.scm s'en sert pour cibler la
 ;; règle udev qui la détache de son trigger et en ouvre l'écriture au
 ;; groupe « input » ; init.el l'allume pendant l'enregistrement d'une note
 ;; vocale, via /sys/class/leds/<nom>/brightness.
 (diode-micmute    . "platform::micmute")

 ;; Verrou d'écran, appelé depuis Emacs et depuis ~/.local/bin/suspend.
 (verrou-ecran     . "/run/setuid-programs/slock")

 ;; Écran : corps de la police par défaut, en dixièmes de point, et largeur
 ;; à partir de laquelle Emacs divise les fenêtres côte à côte.
 (police-taille    . 120)
 (seuil-division   . 120))

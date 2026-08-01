(use-modules (gnu)
	     (guix gexp)
	     (gnu system setuid))

(use-service-modules base cups networking ssh xorg pm)

;;; Valeurs propres à cette machine — identifiants de partitions, accès
;;; distants.  Elles vivent dans prive.scm, à côté de ce fichier, qui n'est
;;; pas versionné.  Voir prive.scm.exemple.
;;;
;;; Contrairement à la configuration Emacs, qui se rabat sur des valeurs de
;;; démonstration, on échoue ici explicitement : construire un système qui
;;; désigne la mauvaise partition serait pire qu'un arrêt net.

(define %prive
  (let* ((ici (or (and=> (current-filename) dirname) "."))
         (fichier (string-append ici "/prive.scm")))
    (if (file-exists? fichier)
        (call-with-input-file fichier read)
        '())))

(define (prive cle)
  "Valeur privée CLE, ou erreur explicite si elle manque."
  (or (assq-ref %prive cle)
      (error (string-append
              "valeur privée absente : " (symbol->string cle)
              " — copier prive.scm.exemple en prive.scm et y porter les"
              " valeurs réelles (lsblk -o NAME,MOUNTPOINT,UUID)"))))

(operating-system
 (locale "fr_FR.utf8")
 (timezone "Europe/Paris")
 (keyboard-layout (keyboard-layout "fr"))
 (host-name "lateci")
 (sudoers-file
  (plain-file "sudoers"
              "root ALL=(ALL) ALL\n%wheel ALL=(ALL) ALL\n%wheel ALL=(ALL) NOPASSWD: /run/current-system/profile/bin/herd power-off root, /run/current-system/profile/sbin/reboot, /run/current-system/profile/bin/tee /sys/power/state\n"))
 
 (users (cons* (user-account
                (name "thomas_rm")
                (comment "Thomas Rousseau-Millasseau")
                (group "users")
                (home-directory "/home/thomas_rm")
                (supplementary-groups '("wheel" "netdev" "audio" "video" "input" "tty")))
               %base-user-accounts))

 (packages (append (list
                    (specification->package "xinit")
                    (specification->package "xorg-server")
		    (specification->package "xf86-input-libinput")
		    (specification->package "xf86-input-evdev")
		    (specification->package "xkeyboard-config")
                    (specification->package "xterm"))
                   %base-packages))
 
 (services
  (append (list
           (service dhcpcd-service-type)
           (service openssh-service-type
		    (openssh-configuration
		     (password-authentication? #f)
		     (permit-root-login #f)))
           (service cups-service-type)
           (service tlp-service-type)
	   (service screen-locker-service-type
		    (screen-locker-configuration
		     (name "slock")
		     (program (file-append (specification->package "slock") "/bin/slock"))))
	   
           (udev-rules-service 'light (specification->package "light"))

	   (simple-service 'diode-micmute udev-service-type
			   (list (udev-rule
				  "90-micmute.rules"
				  (string-append
				   "ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"platform::micmute\", "
				   "ATTR{trigger}=\"none\", "
				   "RUN+=\"/run/current-system/profile/bin/chgrp input /sys/class/leds/%k/brightness\", "
				   "RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/leds/%k/brightness\""))))

	   (simple-service 'xorg-peripheriques
                           etc-service-type
                           (list `("X11/xorg.conf.d/90-touchpad.conf"
                                   ,(plain-file "90-touchpad.conf"
                                                "Section \"InputClass\"\nIdentifier \"touchpad-all\"\nDriver \"libinput\"\nMatchIsTouchpad \"on\"\nOption \"Tapping\" \"on\"\nOption \"NaturalScrolling\" \"on\"\nEndSection\n"))


				 `("X11/xorg.conf.d/90-clavier.conf"
				   ,(plain-file "90-clavier.conf"
						"Section \"InputClass\"\nIdentifier \"clavier-all\"\nDriver \"libinput\"\nMatchIsKeyboard \"on\"\nOption \"XkbLayout\" \"fr\"\nEndSection\n")))))
	  %base-services))


 (bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets (list "/boot/efi"))
              (keyboard-layout keyboard-layout)))
 (swap-devices (list (swap-space
                      (target (uuid (prive 'uuid-swap))))))
 (file-systems (cons* (file-system
		       (mount-point "/boot/efi")
		       (device (uuid (prive 'uuid-efi) 'fat32))
		       (type "vfat"))
                      (file-system
		       (mount-point "/")
		       (device (uuid (prive 'uuid-racine) 'ext4))
		       (type "ext4")) %base-file-systems)))

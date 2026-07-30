(use-modules (gnu)
	     (guix gexp)
	     (gnu system setuid))

(use-service-modules cups networking ssh xorg pm)

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
                      (target (uuid "a9e9d62e-f2c7-487a-a1cf-ed463e7da1e2")))))
 (file-systems (cons* (file-system
		       (mount-point "/boot/efi")
		       (device (uuid "D8A6-ABF1" 'fat32))
		       (type "vfat"))
                      (file-system
		       (mount-point "/")
		       (device (uuid "54c7e021-1f3d-4613-8362-5e479c7f2c8f" 'ext4))
		       (type "ext4")) %base-file-systems)))

(use-modules (gnu home)
             (gnu home services)
             (gnu home services xdg)
	     (gnu home services syncthing)
	     (gnu home services shepherd)
	     (gnu home services gnupg)
             (gnu home services mcron)
             (gnu packages)
             (guix gexp))

;;; Même lecteur de valeurs privées que config.scm.  Les quinze lignes sont
;;; volontairement recopiées : c'est l'amorçage, et le factoriser supposerait
;;; de savoir charger un fichier tiers avant de savoir en trouver un.

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
              " — copier prive.scm.exemple en prive.scm"))))

(define %utilisateur "thomas_rm")
(define %home (string-append "/home/" %utilisateur))

(home-environment
 (packages
  (map specification->package
       '(
         ;; --- Outils Système, IA et Web ---
         "sshfs" "syncthing" "curl" "git" "xdg-utils"
	 "desktop-file-utils" "ripgrep" "isync" "notmuch" "msmtp"
	 "gnupg" "password-store" "pinentry-tty" "pinentry-emacs"
	 "xrdb" "xauth" "setxkbmap" "dbus" "light" "hydroxide" "xdg-desktop-portal"
         "icecat" "yt-dlp"
	 
         ;; --- Bureautique et Média ---
         "ghostscript" "mupdf" "poppler" "imagemagick"
         "djvulibre" "zip" "unzip" "pandoc" "fgallery"
         "vorbis-tools" "mpg321" "mpv" "alsa-utils"
	 "hunspell" "hunspell-dict-fr-toutesvariantes"
         "font-dejavu" "font-gnu-unifont" "libreoffice"
	 "ledger" "graphviz" "ffmpeg" "whisper-cpp"
         
         ;; --- Emacs ---
	 "emacs" "emacs-exwm" "emacs-xelb"
	 "emacs-biblio" "emacs-citar-denote" "emacs-consult-notes"
	 "emacs-consult-notmuch" "emacs-darkroom" "emacs-denote-explore"
	 "emacs-denote-journal" "emacs-denote-org" "emacs-dictionary"
	 "emacs-denote-sequence" "emacs-emms" "emacs-helpful" "emacs-marginalia"
	 "emacs-markdown-mode" "emacs-mixed-pitch"
	 "emacs-nov" "emacs-orderless" "emacs-org-caldav"
	 "emacs-org-fragtog" "emacs-org-web-tools" "emacs-ox-epub"
	 "emacs-pinentry" "emacs-syncthing"
	 "emacs-vertico" "emacs-vundo" "emacs-writegood-mode"
	 "emacs-pass" "emacs-filechooser" "emacs-gptel"
	 "emacs-ebdb" "emacs-elfeed" "emacs-gcmh"
	 "emacs-ledger-mode"
	 
	 ;; --- LaTeX ---
	 "texlive-scheme-basic"
	 "texlive-hyperref"
         "texlive-capt-of"
         "texlive-ulem"
         "texlive-amsmath"
         "texlive-amsfonts"       
         "texlive-graphics"       
         "texlive-tools"        
	 "texlive-dvipng"
	 "texlive-memoir"
	 "texlive-wrapfig"         
	 "texlive-caption"
	 "texlive-ccicons"
	 "texlive-ebgaramond"
	 "texlive-natbib"
	 "texlive-svg"
	 "texlive-trimspaces"
	 "texlive-catchfile" 
	 "texlive-transparent"
	 "texlive-xcolor"
	 )))

 (services
  (list
   (service home-syncthing-service-type)
   
   (service home-gpg-agent-service-type
            (home-gpg-agent-configuration
             (default-cache-ttl 43200)
             (max-cache-ttl 43200)
             (extra-content
              (string-append "pinentry-program " %home
                             "/.guix-home/profile/bin/pinentry-emacs\n"
                             "allow-loopback-pinentry\nallow-emacs-pinentry"))))

   (simple-service 'sshfs-club1
                   home-shepherd-service-type
                   (list (shepherd-service
                          (provision '(sshfs-club1))
                          (requirement '()) 
                          (auto-start? #f) ;; Démarre sur demande, pas au boot
                          (start #~(make-forkexec-constructor
                                    (list "sshfs"
                                          #$(string-append (prive 'sshfs-hote) ":"
                                                           (prive 'sshfs-distant))
                                          #$(string-append %home "/Club1")
                                          "-f" ;; Requis par Shepherd
                                          "-o"
                                          #$(string-append
                                             "IdentityFile=" %home "/" (prive 'sshfs-cle)
                                             ",reconnect,ServerAliveInterval=15,ServerAliveCountMax=3"))
                                    #:log-file (string-append (getenv "HOME") "/.local/var/log/sshfs-club1.log")))
                          (stop  #~(make-kill-destructor)))))
   
   (simple-service 'hydroxide-daemon
                   home-shepherd-service-type
                   (list (shepherd-service
                          (provision '(hydroxide))
                          (requirement '())
                          (start #~(make-forkexec-constructor
                                    '("hydroxide" "serve")
                                    #:log-file (string-append (getenv "HOME") "/.local/var/log/hydroxide.log")))
                          (stop  #~(make-kill-destructor)))))

   (simple-service 'mbsync-cron
                   home-mcron-service-type
                   (list
                    #~(job '(next-minute (range 0 60 10))
                           "mbsync -a && notmuch new"
                           "mbsync-job")))
   
   (simple-service 'mes-variables-environnement
                   home-environment-variables-service-type
                   '(("PATH" . "$HOME/.local/bin:$PATH")))

   (simple-service 'x11-fichiers
                   home-files-service-type
                   (list
		    `(".bash_profile"
		      ,(plain-file "bash_profile" "# Honor per-interactive-shell startup file\nif [ -f ~/.bashrc ]; then . ~/.bashrc; fi\n\nif [ -z \"$DISPLAY\" ] && [ \"$(tty)\" = \"/dev/tty1\" ]; then\necho \"\"\nread -s -p \"Mot de passe GPG pour LA TECI (Entrée pour ignorer) : \" GPG_PASS\necho \"\"\nif [ -n \"$GPG_PASS\" ]; then\necho \"$GPG_PASS\" | gpg --batch --pinentry-mode loopback --passphrase-fd 0 --decrypt ~/.gnupg/.verrou.gpg > /dev/null 2>&1\nif [ $? -eq 0 ]; then\necho \"Clé déverrouillée !\"\nelse\necho \"Échec du déverrouillage (mot de passe incorrect).\"\nfi\nunset GPG_PASS\nelse\necho \"Déverrouillage GPG ignoré.\"\nfi\nsleep 1\necho \"\"\nread -p \"Démarrer l'interface graphique (startx) ? [O/n] \" STARTX_ANS\nif [ \"$STARTX_ANS\" != \"n\" ] && [ \"$STARTX_ANS\" != \"N\" ]; then\nexec startx\nfi\nfi\n"))
		    
		    `(".local/bin/poweroff"
		      ,(program-file "poweroff-cmd"
		                     #~(execl "/run/setuid-programs/sudo" "sudo" "/run/current-system/profile/bin/herd" "power-off" "root")))

		    `(".local/bin/reboot"
		      ,(program-file "reboot-cmd"
		                     #~(execl "/run/setuid-programs/sudo" "sudo" "/run/current-system/profile/sbin/reboot")))
		    
		    `(".local/bin/suspend"
		      ,(program-file "suspend-cmd"
		                     #~(execl "/run/current-system/profile/bin/sh" "sh" "-c"
		                              "DISPLAY=:0 nohup /run/setuid-programs/slock >/dev/null 2>&1 & sleep 2 ; echo mem | /run/setuid-programs/sudo /run/current-system/profile/bin/tee /sys/power/state > /dev/null")))
		    
		    `(".local/share/dbus-1/services/org.gnu.Emacs.FileChooser.service"
		      ,(plain-file "emacs-filechooser-dbus"
		    		   "[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.emacs\nExec=/bin/true\n"))

		    `(".config/xdg-desktop-portal/portals.conf"
		      ,(plain-file "portals.conf"
				   "[preferred]\ndefault=emacs\norg.freedesktop.impl.portal.FileChooser=emacs\n"))

		    `(".local/share/xdg-desktop-portal/portals/emacs.portal"
		      ,(plain-file "emacs.portal"
		    		   "[portal]\nName=Emacs\nInterfaces=org.freedesktop.impl.portal.FileChooser\nUseIn=emacs\n"))
		    
		    `(".xserverrc"
		      ,(plain-file "xserverrc" "#!/bin/sh\nexec Xorg \"$@\" -modulepath /run/current-system/profile/lib/xorg/modules -xkbdir /run/current-system/profile/share/X11/xkb -configdir /etc/X11/xorg.conf.d\n"))

		    `(".xinitrc"
		      ,(plain-file "xinitrc" "#!/bin/sh\n\nGUIX_PROFILE=\"$HOME/.guix-home/profile\"\n[ -f \"$GUIX_PROFILE/etc/profile\" ] && . \"$GUIX_PROFILE/etc/profile\"\n\n[ -f ~/.profile ] && . ~/.profile\n[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources\nexport XDG_RUNTIME_DIR=\"/tmp/user-$(id -u)\"\nmkdir -p \"$XDG_RUNTIME_DIR\"\nchmod 700 \"$XDG_RUNTIME_DIR\"\nshepherd &\n\nexport GTK_USE_PORTAL=1\nexport QT_QPA_PLATFORMTHEME=xdgdesktopportal\nexec dbus-run-session emacs\n"))
		    
		    `(".Xresources"
		      ,(plain-file "Xresources"
				   "! Police et réglages de base\nXTerm*faceName: monospace\nXTerm*faceSize: 12\nXTerm*utf8: always\nXTerm*metaSendsEscape: true\n\n! Couleurs Modus Operandi\nXTerm*reverseVideo: false\nXTerm*background: #ffffff\nXTerm*foreground: #000000\nXTerm*cursorColor: #000000\n\nXTerm*color0:  #000000\nXTerm*color8:  #595959\nXTerm*color1:  #a60000\nXTerm*color9:  #972500\nXTerm*color2:  #005e00\nXTerm*color10: #315b00\nXTerm*color3:  #813e00\nXTerm*color11: #704800\nXTerm*color4:  #0031a9\nXTerm*color12: #2544bb\nXTerm*color5:  #721045\nXTerm*color13: #5317ac\nXTerm*color6:  #00538b\nXTerm*color14: #005a5f\nXTerm*color7:  #bfbfbf\nXTerm*color15: #ffffff\n\n! Gestion du presse-papiers CLIPBOARD\nXTerm*VT100.Translations: #override \\\n    Shift Ctrl <Key> C: copy-selection(CLIPBOARD) \\n\\\n    Shift Ctrl <Key> V: insert-selection(CLIPBOARD)\n"))))
   
   ;; 2. Configuration XDG (MIME et Fichier .desktop unifiés)
   (service home-xdg-mime-applications-service-type
            (home-xdg-mime-applications-configuration
             (default '(("inode/directory" . ("emacs-dired.desktop"))))
             (desktop-entries
              (list (xdg-desktop-entry
                     (file "emacs-dired")
                     (name "Emacs Dired as a file manager")
                     (type 'application)
                     (config
                      '((exec . "emacsclient -n -a emacs %f")
			(mimetype . "inode/directory")))))))))))

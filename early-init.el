;; -*- lexical-binding: t; -*-
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(push '(tool-bar-lines . 0)          default-frame-alist)
(push '(menu-bar-lines . 0)          default-frame-alist)
(push '(vertical-scroll-bars . nil)  default-frame-alist)
(setq frame-inhibit-implied-resize t)
(push '(fullscreen . fullboth) initial-frame-alist)
(setq inhibit-startup-screen t)
(setq package-enable-at-startup nil)

;;; early-init.el ends here

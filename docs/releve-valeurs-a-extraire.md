# Relevé des valeurs à extraire

Inventaire préalable à la modularisation.

**État d'avancement** — les étapes 1 à 3 du § 10 sont faites :

| Étape | État | Où |
|---|---|---|
| 1. Sortir D1 du dépôt | ✅ | `prive.scm` / `~/.config/lateci/prive.el`, modèles `*.exemple` |
| 2. Factoriser les modèles LaTeX | ✅ | section « Documents commerciaux » d'`init.el` |
| 3. Profil machine Guix ↔ Emacs | ✅ | `machines/lateci.scm`, engendre `~/.local/share/lateci/machine.el` |
| 4. Extraire D4 (`~/Bureau/`) | ⬜ | — |
| 5. Extraire D3 (organisation) | ◐ | fait dans les modèles ; reste les requêtes notmuch |
| 6. D5 en `defcustom` | ⬜ | — |

Les références `fichier:ligne` ci-dessous datent du relevé initial et ont
bougé dans `init.el` depuis.

Périmètre scanné : `config.scm` (85 l.), `home.scm` (165 l.), `channels.scm`
(11 l.), `early-init.el` (13 l.), `init.el` (3947 l.).

---

## 0. Deux constats préalables

### 0.1 — Le dépôt est public et contient des données bancaires

Vérifié via l'API GitHub : `thms-eag/guixos_exwm` est en `visibility: public`.

Les modèles de devis/facture/reçu embarquent en clair les coordonnées
complètes de l'association :

| Donnée | Emplacements | Occ. |
|---|---|---|
| IBAN de l'association | `init.el:319`, `init.el:442` | 2 |
| BIC | `init.el:320`, `init.el:443` | 2 |
| SIRET + code APE | `init.el:318`, `init.el:441`, `init.el:548` | 3 |
| Adresse postale du siège | `init.el:251-252`, `init.el:375-376`, `init.el:492-493` | 3 |
| Téléphone personnel | `init.el:1763` | 1 |
| Adresse courriel personnelle | `init.el:1652`, `init.el:1666` | 2 |
| UUID des trois partitions | `config.scm:76`, `config.scm:79`, `config.scm:83` | 3 |

Un IBAN d'association figure de toute façon sur chaque facture émise : ce
n'est pas un secret au sens strict. Mais l'agrégat *IBAN + SIRET + adresse +
téléphone*, indexable et historisé dans un dépôt public, est d'une autre
nature — et l'historique Git conserve ces valeurs même après correction.

**Conséquence sur le plan :** ces valeurs ne doivent pas seulement être
*extraites*, elles doivent sortir du dépôt (fichier local non versionné,
chargé s'il existe). C'est le seul point du relevé qui me semble mériter
d'être traité avant tout le reste. Le nettoyage de l'historique est une
décision distincte, qui t'appartient (réécriture + repousse forcée, ou
acceptation).

Bonne nouvelle en revanche : **aucune clé d'API n'est en dur.** Les quatre
appels passent par `pass` (`init.el:1932-1937`, `init.el:1857`), et
`usr--transcrire-api` prend soin de passer la clé sur l'entrée standard
plutôt que par `argv` (`init.el:2830-2833`). C'est déjà la bonne pratique.

### 0.2 — Un raccourci elfeed est mort

Sans rapport direct avec l'extraction, mais découvert au passage :

- `init.el:1121-1125` lie `c` et `d` à `teci-flux-capturer` /
  `teci-flux-telecharger-audio`
- les fonctions réellement définies sont `usr-flux-capturer`
  (`init.el:1135`) et `usr-flux-telecharger-audio` (`init.el:1167`)

Les deux touches sont donc inopérantes (`void-function`). C'est exactement
le type d'incohérence qu'une convention de préfixe unique élimine — argument
concret en faveur du renommage évoqué plus bas.

---

## 1. Familles et destinations proposées

| Code | Famille | Destination proposée | Versionné ? |
|---|---|---|---|
| **D1** | Sensible | `~/.config/lateci/prive.el` + `prive.scm` | ❌ non |
| **D2** | Profil machine | `machines/<nom>.scm` + `lateci-machine.el` | ✅ |
| **D3** | Identité de l'organisation | `lateci-identite.el` | ✅ (sauf D1) |
| **D4** | Chemins et emplacements | `lateci-chemins.el` | ✅ |
| **D5** | Préférences | restent sur place, en `defcustom` | ✅ |
| **D6** | À ne pas extraire | — | ✅ |

---

## 2. D1 — Sensible, à sortir du dépôt

| Valeur | Emplacements | Nom proposé |
|---|---|---|
| IBAN | `init.el:319,442` | `lateci-banque-iban` |
| BIC | `init.el:320,443` | `lateci-banque-bic` |
| SIRET | `init.el:318,441,548` | `lateci-org-siret` |
| Code APE | `init.el:318,441,548` | `lateci-org-ape` |
| Adresse postale (2 lignes) | `init.el:251-252,375-376,492-493` | `lateci-org-adresse` |
| Téléphone | `init.el:1763` | `lateci-tel` |
| Courriel personnel | `init.el:1652,1666` | `lateci-courriel-perso` |
| UUID racine (ext4) | `config.scm:83` | `machines/lateci.scm` |
| UUID EFI (fat32) | `config.scm:79` | idem |
| UUID swap | `config.scm:76` | idem |
| Hôte + compte SSH distant | `home.scm:85` | `prive.scm` |
| Chemin de la clé SSH | `home.scm:87` | idem |

Mécanisme suggéré, calqué sur le chargement conditionnel d'`ews.el` déjà en
place (`init.el:32-51`) : charger si présent, dégrader proprement sinon, avec
des valeurs de démonstration versionnées pour que la configuration reste
utilisable par un tiers.

Les entrées `pass` (`api/claude`, `api/gemini`, `api/openai`,
`api/syncthing`) restent où elles sont — ce sont des *références*, pas des
secrets. Seuls leurs chemins dans le magasin méritent de devenir des
variables.

---

## 3. D2 — Profil machine

| Valeur | Actuel | Emplacements |
|---|---|---|
| Nom d'hôte | `lateci` | `config.scm:11` |
| Locale | `fr_FR.utf8` | `config.scm:8` |
| Fuseau | `Europe/Paris` | `config.scm:9` |
| Disposition clavier | `fr` | `config.scm:10`, `config.scm:66` |
| Compte utilisateur | `thomas_rm` + commentaire + groupes | `config.scm:17-21` |
| Répertoire personnel absolu (gpg-agent) | `/home/thomas_rm/...` | `home.scm:76` |
| Répertoire personnel absolu (sshfs) | `/home/thomas_rm/...` | `home.scm:85-88` |
| Logo (chemin absolu) | `/home/thomas_rm/Bureau/logo.jpg` | `init.el:249,373` |
| Cible du bootloader | `/boot/efi` | `config.scm:73` |
| Points de montage | `/boot/efi`, `/` | `config.scm:78,82` |
| Diode micro | `/sys/class/leds/platform::micmute/...` | `init.el:2435`, `config.scm:53-56` |
| Chemin `slock` setuid | `/run/setuid-programs/slock` | `init.el:1076` |
| Taille de police par défaut | `120` | `init.el:609` |
| Seuil de division des fenêtres | `120` | `init.el:703` |

Les deux dernières lignes sont dépendantes de l'écran : elles n'ont pas leur
place au même endroit qu'un thème, mais bien dans le profil machine.

Note : `config.scm:53-56` (règle udev de la diode) et `init.el:2435` (chemin
lu par Emacs) décrivent **le même périphérique depuis les deux moitiés du
dépôt**. C'est le seul couplage Guix ↔ Emacs du relevé, et il justifie à lui
seul qu'un profil machine soit partagé entre les deux.

---

## 4. D3 — Identité de l'organisation

| Valeur | Emplacements | Occ. |
|---|---|---|
| Nom court « LA TECI » | `init.el:233,250,357,374,476,491,1751,2096` | 8 |
| Raison sociale complète | `init.el:317,440,547` | 3 |
| Couleur institutionnelle (RGB) | `init.el:240,364` | 2 |
| Site web | `init.el:254,378,495,1763,1912` | 5 |
| Courriel principal | `init.el:253,377,494,1752` + requêtes | 4+ |
| Signature de courriel | `init.el:1762-1764` | 1 |
| Dossier d'envoi (Fcc) | `init.el:1759` | 1 |
| Requêtes notmuch (4 groupes × 2) | `init.el:1642-1667`, `1743`, `1748` | 10 |
| Ville (recherche web IA) | `init.el:2028-2030` | 1 |
| URL du mode kiosque | `init.el:1912` | 1 |
| Directive IA « assistant LA TECI » | `init.el:2095-2097` | 1 |
| Nom d'outil `rechercher_notes_lateci` | `init.el:2054,2057,2069` | 3 |
| Mentions légales (TVA 293b, délai 30 j, décrets, pénalités) | `init.el:300-311`, `424-435` | 2 |
| Plan comptable (`512-Banque`, `530-Caisse`) | `init.el:2332-2333` | 2 |
| Tiers nommés (Softerie, Fluxus, Ville de Blois, Biocoop) | `init.el:2336-2343` | 4 |
| Variable d'environnement `LATECI_STATS` / `LATECI_NO_EXWM` | `init.el:22,1096` | 2 |

Les quatre groupes de requêtes notmuch (`init.el:1642-1667`) sont dupliqués
à l'identique dans `usr-courriel-nouveaux` et `usr-courriel-boite`
(`init.el:1743,1748`) : une seule table de comptes réglerait les deux.

---

## 5. D4 — Chemins et emplacements

| Valeur | Emplacements | Occ. |
|---|---|---|
| **`~/Bureau/`** (base Denote + capture) | `init.el:67,69,70,231,355,474,1204,1277,1278,1279,2059,2071,2306,2420,2629` | **25 mentions** |
| `~/Club1` (montage SSHFS) | `init.el:960`, `home.scm:86` | 2 |
| `~/Bureau/compta/` | `init.el:2306` | 1 |
| `Notes.org`, `FP6.org` | `init.el:67,69,70` | 3 |
| `~/Bureau/.vocal_input/` | `init.el:2420` | 1 |
| Modèle whisper | `init.el:2447` | 1 |
| Dictionnaires hunspell (`~/.guix-home/...`) | `init.el:803,814` | 2 |
| Verrou GPG `~/.gnupg/.verrou.gpg` | `init.el:1887`, `home.scm:116` | 2 |
| Base EBDB `~/.emacs.d/ebdb` | `init.el:1777` | 1 |
| Corbeille `~/.local/share/Trash/` | `init.el:1531` | 1 |
| Compteurs devis / facture / reçu | `init.el:78,102,125` | 3 |

`~/Bureau/` est de très loin la valeur la plus diffuse du dépôt. À elle
seule, elle justifie l'extraction : elle est à la fois le répertoire Denote,
la cible de capture Org, la destination des exports, le dépôt des
téléchargements elfeed, la racine de la comptabilité et la boîte vocale.

---

## 6. D5 — Préférences (à passer en `defcustom`, restent versionnées)

Ces valeurs n'empêchent pas la réutilisation ; les exposer proprement suffit.

| Valeur | Actuel | Emplacement |
|---|---|---|
| Thème | `modus-operandi` | `init.el:577,583-584` |
| Intervalle de sondage système | `60` s | `init.el:963` |
| Seuil d'écho des réponses IA | `300` car. | `init.el:2140` |
| Modèle IA rapide | `gpt-5.6-luna` | `init.el:1939` |
| Backend et modèle par défaut | `openai` / `gpt-5.6-terra` | `init.el:2047-2048` |
| Listes de modèles (4 backends) | — | `init.el:2008-2045` |
| Moteur de transcription | `local` | `init.el:2441` |
| Langue de transcription | `fr` | `init.el:2450` |
| Modèle API de transcription | `gpt-4o-transcribe` | `init.el:2453` |
| Mot-clé Denote des notes vocales | `vocal` | `init.el:2429` |
| Dictionnaire | `fr-toutesvariantes` | `init.el:797,806,814` |
| Navigateur | `icecat` | `init.el:1813,1816,1819` |
| Terminal | `xterm` | `init.el:1824,1827` |
| Suite bureautique | `soffice` | `init.el:1832,1835` |
| Touches de simulation X11 | — | `init.el:992-1002` |
| Table des touches globales | — | `init.el:3722-3755` |

---

## 7. D6 — À ne pas extraire

Liste explicite, pour éviter la sur-paramétrisation :

- `/proc/net/route`, `/proc/mounts` (`init.el:910,923-925`) — interfaces
  Linux stables, pas des réglages.
- Les touches `XF86*` (`init.el:3739-3755`) — standard X11.
- Les noms de faces Emacs et leurs ratios (`init.el:609-657`) — relèvent du
  thème, pas de la machine.
- Limite de 25 Mo de l'API OpenAI (`init.el:2456`) — contrainte externe
  subie, pas une préférence.
- Colonnes d'alignement Ledger (`init.el:2319-2320`) — cosmétique locale.
- Tableaux français du calendrier (`init.el:1452-1454`) — dépendent de la
  locale, déjà couverts par `config.scm:8`.

---

## 8. Le gros morceau : la triplication des modèles LaTeX

`init.el:228-560` — 333 lignes — contient **trois en-têtes/pieds de page
quasi identiques** (DEVIS, FACTURE, REÇU). Presque toutes les valeurs de la
famille D3 y sont recopiées deux ou trois fois.

Les trois blocs `usr--get-next-*-num` (`init.el:80-140`) sont eux aussi
identiques à un nom de fichier près.

Factoriser en un en-tête et un pied paramétrés, plus une fonction de
compteur générique, retirerait de l'ordre de **200 lignes** et ramènerait
chaque donnée d'identité à une occurrence unique. C'est le meilleur rapport
lignes supprimées / risque de tout le relevé, et ça règle mécaniquement le
point 0.1.

---

## 9. Récapitulatif

| Famille | Valeurs distinctes | Occurrences |
|---|---|---|
| D1 — Sensible | 12 | ~25 |
| D2 — Machine | 14 | ~20 |
| D3 — Organisation | 16 | ~50 |
| D4 — Chemins | 11 | ~45 |
| D5 — Préférences | 16 | ~30 |
| **Total** | **~69** | **~170** |

Environ **70 valeurs distinctes**, dont **une douzaine seulement** bloquent
réellement l'installation d'une seconde machine (D1 + D2).

---

## 10. Ordre d'intervention proposé

1. **Sortir D1 du dépôt** — fichier privé non versionné, valeurs de
   démonstration versionnées. Traite le point 0.1.
2. **Factoriser les trois modèles LaTeX** (§ 8) — ~200 lignes en moins,
   identité ramenée à une occurrence unique.
3. **Extraire D2 vers un profil machine** partagé Guix ↔ Emacs — débloque la
   seconde machine.
4. **Extraire D4** (`~/Bureau/` et ses 25 mentions).
5. **Extraire D3**, table de comptes courriel comprise.
6. **D5 en `defcustom`** — cosmétique, sans urgence.

Les étapes 1 à 3 suffisent à atteindre l'objectif « plusieurs machines sans
duplication ». Le découpage de `init.el` en modules ne commence qu'après, et
reste une décision distincte.

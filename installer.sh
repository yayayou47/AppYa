#!/bin/bash
# Installation de Daftar (suivi financier, véhicule et maison) sur Ubuntu (sans sudo).
# Lancez-le avec « bash » : cela marche aussi depuis un disque externe (NTFS, exFAT, clé USB).
#
#   bash installer.sh                 installe dans ~/Daftar (démarrage automatique)
#   bash installer.sh --ici           garde le carnet et ses données dans CE dossier (ex. disque externe)
#   bash installer.sh --reseau        accessible aussi depuis le téléphone (même Wi-Fi, avec clé)
#   bash installer.sh --sans-service  pas de démarrage automatique
#
# Si un carnet existe déjà à l'emplacement choisi, seul le programme est mis à jour : vos données sont conservées.
# Sinon (nouvel ordinateur), les données et sauvegardes de donnees/ de CE dossier sont reprises.
# Ensuite, Daftar recopie ses données dans donnees/ de CE dossier à chaque modification (copie miroir) :
# ce dossier, copié tel quel sur un autre ordinateur, s'y installe avec les données à jour.
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
# dossier d'installation : ~/Daftar ; une installation faite avant le changement de nom (~/AppYa) reste où elle est
if [ -f "$HOME/AppYa/serveur.py" ]; then DEST_DEF="$HOME/AppYa"; else DEST_DEF="$HOME/Daftar"; fi
DEST="${DAFTAR_DEST:-${APPYA_DEST:-$DEST_DEF}}"
RESEAU=0; SERVICE=1; ICI=0; NOUVEAU=0
for a in "$@"; do
  case "$a" in
    --reseau) RESEAU=1 ;;
    --sans-service) SERVICE=0 ;;
    --ici) ICI=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Option inconnue : $a"; exit 1 ;;
  esac
done

[ "$ICI" = 1 ] && DEST="$SRC"
vert() { printf '\033[32m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }

echo ""
echo "  Installation de Daftar"
echo "  -------------------"

# 1. Python
if ! command -v python3 >/dev/null; then
  echo "Python 3 est introuvable. Installez-le avec :  sudo apt install python3"; exit 1
fi
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'; then
  echo "Python 3.8 ou plus récent est nécessaire (version actuelle : $(python3 -V))."; exit 1
fi
info "Python : $(python3 -V)"

# 2. Copie du programme (sans jamais écraser les données existantes)
if [ "$SRC" != "$(cd "$DEST" 2>/dev/null && pwd)" ]; then
  mkdir -p "$DEST/app" "$DEST/donnees"
  cp -f "$SRC/serveur.py" "$SRC/appya" "$SRC/installer.sh" "$SRC/desinstaller.sh" "$SRC/LISEZMOI.txt" "$DEST/"
  cp -rf "$SRC/app/." "$DEST/app/"
  if [ -f "$DEST/donnees/carnet.json" ]; then
    info "Données existantes conservées : $DEST/donnees/carnet.json"
    if [ -f "$SRC/donnees/carnet.json" ] && ! cmp -s "$SRC/donnees/carnet.json" "$DEST/donnees/carnet.json"; then
      # deux carnets différents : on garde celui de l'ordinateur, mais on signale si l'autre est plus récent
      python3 - "$SRC/donnees/carnet.json" "$DEST/donnees/carnet.json" <<'PY' || true
import json, sys
def etat(p):
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception:
        return -1, 0, "?"
    ops = d.get("operations") or d.get("depenses") or []
    return d.get("rev", 0), len(ops), max((o.get("maj") or o.get("cree") or "" for o in ops), default="")[:16]
s, c = etat(sys.argv[1]), etat(sys.argv[2])
print("  Dossier copié  : %s (%d lignes, dernière modification %s)" % (sys.argv[1], s[1], s[2] or "?"))
print("  Cet ordinateur : %s (%d lignes, dernière modification %s) : CONSERVÉ" % (sys.argv[2], c[1], c[2] or "?"))
if (s[2], s[0]) > (c[2], c[0]):
    print("  ATTENTION : le carnet du dossier copié est plus récent. Pour l'adopter :")
    print("    appya arreter && cp \"%s\" \"%s\" && appya demarrer" % (sys.argv[1], sys.argv[2]))
PY
    fi
  else
    # nouvel ordinateur : on reprend les données (et les sauvegardes) du dossier copié ;
    # sans carnet.json, Daftar démarre avec un carnet vide
    NOUVEAU=1
    if [ ! -f "$SRC/donnees/carnet.json" ]; then
      info "Aucune donnée dans $SRC/donnees : Daftar démarre avec un carnet vide."
    else
    cp "$SRC/donnees/carnet.json" "$DEST/donnees/carnet.json"
    if [ -d "$SRC/donnees/sauvegardes" ]; then
      mkdir -p "$DEST/donnees/sauvegardes"
      cp -n "$SRC/donnees/sauvegardes/"*.json "$DEST/donnees/sauvegardes/" 2>/dev/null || true
      info "Sauvegardes reprises : $(ls "$DEST/donnees/sauvegardes" | wc -l) fichier(s)"
    fi
    info "Données installées : $(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1],encoding="utf-8")).get("operations",[])))' "$DEST/donnees/carnet.json") lignes"
    fi
  fi
else
  mkdir -p "$DEST/donnees"
  [ -f "$DEST/donnees/carnet.json" ] || NOUVEAU=1
fi
# copie miroir : le dossier d'installation (ex. un second disque) reçoit une copie à jour des données à chaque
# modification ; il suffit ensuite de copier ce dossier sur un autre ordinateur et d'y relancer l'installation
if [ "$SRC" != "$(cd "$DEST" && pwd)" ]; then
  if mkdir -p "$SRC/donnees" 2>/dev/null && touch "$SRC/donnees/.test-ecriture" 2>/dev/null; then
    rm -f "$SRC/donnees/.test-ecriture"
    printf '%s\n' "$SRC/donnees" > "$DEST/donnees/.miroir"
    info "Copie miroir des données : $SRC/donnees"
  else
    rm -f "$DEST/donnees/.miroir"
    info "Copie miroir : aucune ($SRC n'est pas modifiable)"
  fi
fi
# chmod échoue sur NTFS/exFAT : sans importance, tout est lancé via python3 et bash
chmod +x "$DEST/serveur.py" "$DEST/appya" "$DEST/installer.sh" "$DEST/desinstaller.sh" 2>/dev/null || true
info "Dossier : $DEST"
# disque externe ?
FS="$(stat -f -c %T "$DEST" 2>/dev/null || echo ?)"
case "$DEST" in
  /media/*|/mnt/*|/run/media/*)
    info "Disque externe ($FS) : branchez-le avant d'ouvrir le carnet."
    info "Le service attend que le dossier soit présent ; s'il manque, le carnet vous le signale." ;;
esac
if ! touch "$DEST/donnees/.test-ecriture" 2>/dev/null; then
  echo "Impossible d'écrire dans $DEST/donnees (disque en lecture seule ?)."; exit 1
fi
rm -f "$DEST/donnees/.test-ecriture"

if [ "$RESEAU" = 1 ]; then echo "--reseau" > "$DEST/donnees/.options"; fi

# une ancienne version déjà lancée est arrêtée pour que la nouvelle prenne le relais
pkill -f "$DEST/serveur.py" 2>/dev/null || true

# 3. Commande appya
BIN="$HOME/.local/bin"; mkdir -p "$BIN"
sed "s|__DIR__|$DEST|" "$DEST/appya" > "$BIN/appya"
chmod +x "$BIN/appya"
ln -sf "$BIN/appya" "$BIN/daftar"
info "Commande : daftar  (ou appya, $BIN)"

# 4. Service utilisateur (démarrage automatique à l'ouverture de session)
UNITDIR="$HOME/.config/systemd/user"; UNIT="$UNITDIR/appya.service"
if [ "$SERVICE" = 1 ] && command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  mkdir -p "$UNITDIR"
  cat > "$UNIT" <<EOF
[Unit]
Description=Daftar (serveur local)
After=network.target

ConditionPathExists=$DEST/serveur.py

[Service]
Type=simple
WorkingDirectory=$DEST
ExecStart=/bin/sh -c 'exec /usr/bin/env python3 "$DEST/serveur.py" --sans-navigateur \$\$(cat "$DEST/donnees/.options" 2>/dev/null)'
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable appya.service >/dev/null 2>&1
  systemctl --user restart appya.service
  info "Démarrage automatique : activé (service utilisateur systemd)"
else
  rm -f "$UNIT" 2>/dev/null || true
  info "Démarrage automatique : non (il démarre quand vous l'ouvrez)"
fi

# 5. Lanceur dans le menu des applications (+ icône sur le bureau)
APPS="$HOME/.local/share/applications"; mkdir -p "$APPS"
DESKTOP_FILE="$APPS/appya.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Daftar
GenericName=Suivi financier, véhicule et maison
Comment=Dépenses, revenus, comptes, prêts, biens, véhicule et maison
Exec="$BIN/appya" ouvrir
Icon=$DEST/app/icone.svg
Terminal=false
Categories=Office;Finance;
Keywords=dépenses;budget;argent;carnet;comptes;banque;patrimoine;prêts;voiture;véhicule;vidange;carburant;
StartupNotify=false
Actions=NouvelOnglet;Dossier;Sauvegarder;

[Desktop Action NouvelOnglet]
Name=Ouvrir dans un nouvel onglet
Exec="$BIN/appya" nouvel-onglet

[Desktop Action Dossier]
Name=Ouvrir le dossier des données
Exec="$BIN/appya" dossier

[Desktop Action Sauvegarder]
Name=Sauvegarder les données dans Documents
Exec="$BIN/appya" sauvegarder
EOF
chmod +x "$DESKTOP_FILE"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" >/dev/null 2>&1 || true
info "Menu des applications : « Daftar »"

BUREAU="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [ -d "$BUREAU" ]; then
  cp "$DESKTOP_FILE" "$BUREAU/appya.desktop"
  chmod +x "$BUREAU/appya.desktop"
  command -v gio >/dev/null && gio set "$BUREAU/appya.desktop" metadata::trusted true 2>/dev/null || true
  info "Icône sur le bureau : $BUREAU"
fi

# 6. ~/.local/bin dans le PATH ?
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) info "Note : ouvrez un nouveau terminal (ou déconnectez-vous) pour que la commande appya soit reconnue." ;;
esac

echo ""
vert "  Installation terminée."
"$BIN/appya" demarrer >/dev/null 2>&1 || true
ADR="$(head -n1 "$DEST/donnees/.adresse" 2>/dev/null || echo http://localhost:8780)"
info "Adresse : $ADR"
if [ "$RESEAU" = 1 ]; then info "Depuis le téléphone (ouvrir une fois, contient la clé) : http://$(hostname -I | awk '{print $1}'):${ADR##*:}/?cle=$(head -n1 "$DEST/donnees/.cle" 2>/dev/null)"; fi
echo ""
# le navigateur n'est ouvert qu'à la première installation : une mise à jour n'ajoute pas d'onglet
if [ "$NOUVEAU" = 1 ] && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then "$BIN/appya" ouvrir >/dev/null 2>&1 || true
else info "Daftar : cliquez sur son icône (ou tapez  daftar ) ; un onglet déjà ouvert se recharge avec F5."; fi

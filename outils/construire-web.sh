#!/bin/bash
# Construit la version autonome (lien web GitHub Pages et contenu de l'APK) dans le dossier donné :
# copie de app/ avec mode.js réglé sur « autonome » (données dans l'appareil, sans ordinateur).
#   bash outils/construire-web.sh www
set -e
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
CIBLE="${1:?dossier cible}"
rm -rf "$CIBLE"; mkdir -p "$CIBLE"
cp -r "$RACINE/app/." "$CIBLE/"
echo 'window.APPYA_AUTONOME = true;   // version autonome : données dans l'"'"'appareil' > "$CIBLE/mode.js"
touch "$CIBLE/.nojekyll"
echo "Version autonome construite dans $CIBLE"

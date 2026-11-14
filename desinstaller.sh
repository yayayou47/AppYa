#!/bin/bash
# Désinstallation de Daftar.
#   bash desinstaller.sh          retire le service, la commande et les lanceurs ; GARDE vos données
#   bash desinstaller.sh --tout   supprime aussi le dossier installé (~/Daftar, ou ~/AppYa pour une installation ancienne), après une copie finale
#
# Avant de retirer quoi que ce soit, les données sont recopiées une dernière fois dans le dossier miroir
# (le dossier d'où Daftar a été installé, ex. un second disque) : ce dossier peut
# ensuite être copié sur un autre ordinateur et installé avec « bash installer.sh ».
# Lancé depuis le dossier d'origine ou depuis le dossier installé, il agit toujours sur l'installation
# réelle, et ne supprime jamais le dossier d'origine.

ICI="$(cd "$(dirname "$0")" && pwd)"
UNIT="$HOME/.config/systemd/user/appya.service"
# dossier réellement installé : variable, sinon service, sinon commande appya ; à défaut, ce dossier
DEST="${APPYA_DEST:-}"; TROUVE=1
[ -z "$DEST" ] && [ -f "$UNIT" ] && DEST="$(sed -n 's/^WorkingDirectory=//p' "$UNIT" | head -n1)"
[ -z "$DEST" ] && [ -f "$HOME/.local/bin/appya" ] && DEST="$(sed -n 's/^DIR="\(.*\)"$/\1/p' "$HOME/.local/bin/appya" | head -n1)"
[ -z "$DEST" ] && { DEST="$ICI"; TROUVE=0; }
DEST="$(cd "$DEST" 2>/dev/null && pwd || echo "$DEST")"
echo "Installation de Daftar : $DEST"

# 1. dernière copie vers le dossier miroir (si le disque est branché)
MIROIR="$(head -n1 "$DEST/donnees/.miroir" 2>/dev/null)"
if [ -f "$DEST/donnees/carnet.json" ] && [ -n "$MIROIR" ] && [ -d "$MIROIR" ] \
   && [ "$(cd "$MIROIR" && pwd)" != "$(cd "$DEST/donnees" && pwd)" ]; then
  cp "$DEST/donnees/carnet.json" "$MIROIR/carnet.json.tmp" && mv -f "$MIROIR/carnet.json.tmp" "$MIROIR/carnet.json"
  if [ -d "$DEST/donnees/sauvegardes" ]; then
    mkdir -p "$MIROIR/sauvegardes"
    cp -n "$DEST/donnees/sauvegardes/"*.json "$MIROIR/sauvegardes/" 2>/dev/null
  fi
  echo "Données recopiées dans le dossier miroir : $MIROIR"
elif [ -n "$MIROIR" ]; then
  echo "Dossier miroir absent ($MIROIR) : disque non branché ? Pas de copie miroir."
fi

# 2. service, commande, lanceurs
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user disable --now appya.service >/dev/null 2>&1
  rm -f "$UNIT"
  systemctl --user daemon-reload
fi
pkill -f "$DEST/serveur.py" 2>/dev/null
rm -f "$HOME/.local/bin/appya" "$HOME/.local/bin/daftar" "$HOME/.local/share/applications/appya.desktop"
BUREAU="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
rm -f "$BUREAU/appya.desktop" "$DEST/donnees/.adresse"
echo "Service, commande et lanceurs retirés."

# 3. dossier installé
if [ "$1" = "--tout" ]; then
  # garde-fous : on ne supprime que l'installation trouvée, jamais le dossier d'origine (miroir)
  if [ "$TROUVE" = 0 ]; then
    echo "Aucune installation trouvée (ni service ni commande appya) : rien n'est supprimé."; exit 1
  fi
  if [ -n "$MIROIR" ] && [ "$(cd "$MIROIR/.." 2>/dev/null && pwd)" = "$DEST" ]; then
    echo "Refus : $DEST est le dossier d'origine. Rien n'est supprimé."; exit 1
  fi
  if [ ! -f "$DEST/serveur.py" ]; then
    echo "Refus : $DEST ne ressemble pas à une installation de Daftar. Rien n'est supprimé."; exit 1
  fi
  DOCS="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME")"
  if [ -f "$DEST/donnees/carnet.json" ]; then
    cp "$DEST/donnees/carnet.json" "$DOCS/appya-final-$(date +%Y-%m-%d-%H%M).json"
    echo "Copie finale des données : $DOCS"
  fi
  rm -rf "$DEST"
  echo "Dossier $DEST supprimé."
else
  echo "Vos données sont conservées dans : $DEST/donnees/carnet.json"
fi

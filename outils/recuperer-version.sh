#!/bin/bash
# Copie locale des versions publiées (dossier versions/, non suivi par git), alignée sur la page « Releases » de GitHub :
# on y garde exactement les versions encore publiées (règle du ménage, outils/elaguer-versions.sh : la première,
# l'active et les 2 précédentes). Les dossiers des versions retirées de GitHub sont supprimés.
#   bash outils/recuperer-version.sh            synchronise versions/ avec GitHub (à lancer après chaque publication)
#   bash outils/recuperer-version.sh --essai    montre ce qui serait téléchargé et supprimé, sans rien faire
#   bash outils/recuperer-version.sh v1.0.0     télécharge seulement cette version
set -euo pipefail
cd "$(dirname "$0")/.."
DEPOT=yayayou47/Daftar
mkdir -p versions
if [[ "${1:-}" == v* ]]; then
  mkdir -p "versions/$1"; gh release download "$1" -R "$DEPOT" -D "versions/$1" --clobber; ls -la "versions/$1"; exit 0
fi
ESSAI=0; [ "${1:-}" = "--essai" ] && ESSAI=1
mapfile -t PUBLIEES < <(gh release list -R "$DEPOT" --limit 1000 --json tagName -q '.[].tagName' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V)
[ "${#PUBLIEES[@]}" -gt 0 ] || { echo "Aucune version publiée trouvée (connexion ? gh auth status)."; exit 1; }
declare -A GARDE; for t in "${PUBLIEES[@]}"; do GARDE["$t"]=1; done
for t in "${PUBLIEES[@]}"; do
  if [ -n "$(ls -A "versions/$t" 2>/dev/null)" ]; then echo "Déjà là : $t"
  elif [ "$ESSAI" = 1 ]; then echo "À télécharger : $t"
  else echo "Téléchargement : $t"; mkdir -p "versions/$t"; gh release download "$t" -R "$DEPOT" -D "versions/$t" --clobber; fi
done
for d in versions/v*/; do
  t=$(basename "$d"); [ -n "${GARDE[$t]:-}" ] && continue
  if [ "$ESSAI" = 1 ]; then echo "À supprimer : $t"; else echo "Suppression : $t"; rm -rf -- "versions/$t"; fi
done
echo "Gardées : ${PUBLIEES[*]}"

#!/usr/bin/env bash
# Ménage des versions publiées (page « Releases » de GitHub) : on garde
#   - la toute première version de l'application (plus petit numéro vX.Y.Z),
#   - la version active (la plus récente) et les 2 versions qui la précèdent ;
# toutes les autres sont supprimées, avec leur tag.
# Usage : bash outils/elaguer-versions.sh [--essai]   (--essai : affiche sans rien supprimer)
# Lancé automatiquement par .github/workflows/publier.yml après chaque publication.
set -euo pipefail
ESSAI=0; [ "${1:-}" = "--essai" ] && ESSAI=1
GARDER_RECENTES=3   # version active + 2 précédentes

mapfile -t TAGS < <(gh release list --limit 1000 --json tagName -q '.[].tagName' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V)
N=${#TAGS[@]}
if [ "$N" -le $((GARDER_RECENTES + 1)) ]; then echo "Rien à supprimer ($N versions)."; exit 0; fi

PREMIERE=${TAGS[0]}
declare -A GARDE=(["$PREMIERE"]=1)
for t in "${TAGS[@]: -$GARDER_RECENTES}"; do GARDE["$t"]=1; done
echo "Gardées : $PREMIERE ${TAGS[*]: -$GARDER_RECENTES}"

for t in "${TAGS[@]}"; do
  [ -n "${GARDE[$t]:-}" ] && continue
  if [ "$ESSAI" = 1 ]; then echo "À supprimer : $t"; else echo "Suppression : $t"; gh release delete "$t" --yes --cleanup-tag; fi
done

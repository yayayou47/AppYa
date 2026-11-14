#!/bin/bash
# Garde-fou : aucune donnée personnelle ne doit être suivie par git (donnees/, sauvegardes JSON).
set -e
cd "$(dirname "$0")/.."
if git ls-files | grep -E '^donnees/|(^|/)carnet[^/]*\.json$|(^|/)appya-[0-9].*\.json$|\.jks$|\.keystore$'; then
  echo "ERREUR : des fichiers de données ou de signature sont suivis par git (voir ci-dessus)." >&2; exit 1
fi
echo "Dépôt propre : aucune donnée personnelle suivie."

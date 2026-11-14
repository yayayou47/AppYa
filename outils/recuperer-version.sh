#!/bin/bash
# Copie dans versions/<tag>/ l'APK et le zip Ubuntu publiés sur GitHub (dernière version, ou celle donnée).
#   bash outils/recuperer-version.sh          dernière version
#   bash outils/recuperer-version.sh v1.0.0
set -e
cd "$(dirname "$0")/.."
TAG="${1:-$(gh release view -R yayayou47/AppYa --json tagName --jq .tagName)}"
mkdir -p "versions/$TAG"
gh release download "$TAG" -R yayayou47/AppYa -D "versions/$TAG" --clobber
ls -la "versions/$TAG"

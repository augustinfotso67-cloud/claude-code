#!/bin/bash
# Trading Algo Office - launcher macOS
# Ouvre directement index.html dans le navigateur (file://).
cd "$(dirname "$0")"

echo ""
echo " ==========================================="
echo "  Trading Algo Office - bureau virtuel 3D"
echo " ==========================================="
echo ""
echo "  Ouverture de index.html dans le navigateur..."
echo ""

open "$(pwd)/index.html"

echo "  Si rien ne s'ouvre :"
echo "    1. Va dans ce dossier avec le Finder"
echo "    2. Double-clic directement sur 'index.html'"
echo "    3. Si la page reste blanche, utilise Chrome ou Safari recent"
echo ""
echo "  Cette fenetre se ferme dans 5 secondes."
sleep 5

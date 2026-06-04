#!/bin/bash
# Trading Algo Office - launcher macOS (double-clic dans Finder)
cd "$(dirname "$0")"

echo ""
echo " ==========================================="
echo "  Trading Algo Office - bureau virtuel 3D"
echo " ==========================================="
echo ""
echo "  Le navigateur va s'ouvrir automatiquement."
echo "  Laisse ce Terminal OUVERT pendant que tu utilises le bureau."
echo "  Pour fermer : Ctrl+C ou ferme cette fenetre."
echo ""

# Ouvre le navigateur après 1s (le temps que le serveur démarre)
(sleep 1 && open "http://localhost:8765") &

# Démarre le serveur (Python 3 fourni par macOS)
if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server 8765
elif command -v python >/dev/null 2>&1; then
    python -m http.server 8765
else
    echo "[ERREUR] Python n'est pas installe."
    echo "Installe-le via Homebrew : brew install python"
    read -p "Appuie sur Entree pour fermer..."
fi

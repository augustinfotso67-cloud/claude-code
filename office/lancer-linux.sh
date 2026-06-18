#!/bin/bash
# Trading Algo Office - launcher Linux
cd "$(dirname "$0")"

echo ""
echo " ==========================================="
echo "  Trading Algo Office - bureau virtuel 3D"
echo " ==========================================="
echo ""
echo "  Le navigateur va s'ouvrir automatiquement."
echo "  Laisse ce terminal OUVERT pendant que tu utilises le bureau."
echo "  Pour fermer : Ctrl+C ou ferme cette fenetre."
echo ""

(sleep 1 && xdg-open "http://localhost:8765" 2>/dev/null) &

if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server 8765
elif command -v python >/dev/null 2>&1; then
    python -m http.server 8765
else
    echo "[ERREUR] Python n'est pas installé. Installe-le : sudo apt install python3"
    read -p "Appuie sur Entree pour fermer..."
fi

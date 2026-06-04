# Bureau virtuel 3D — Trading Algo Team

Open-space circulaire avec 8 vitrines (une par agent) + bureau du chef central.

---

## 🚀 Comment l'ouvrir (le plus simple)

### Sur Mac
1. Va dans le dossier `office/`
2. **Double-clic sur `lancer-mac.command`**
3. Une fenêtre Terminal s'ouvre + le navigateur s'ouvre automatiquement sur le bureau virtuel
4. Quand tu as fini, **ferme le Terminal** (Ctrl+C ou ⌘+W)

> ⚠️ Premier double-clic : macOS peut bloquer le fichier. Clic-droit dessus → "Ouvrir" → confirme. Une seule fois.

### Sur Windows
1. Va dans le dossier `office/`
2. **Double-clic sur `lancer-windows.bat`**
3. Une fenêtre CMD s'ouvre + le navigateur s'ouvre automatiquement
4. Quand tu as fini, **ferme la fenêtre CMD** (Ctrl+C ou la croix)

> ⚠️ Si rien ne se passe, c'est que Python n'est pas installé. Va sur https://www.python.org/downloads/ et coche "Add Python to PATH" pendant l'install. Puis re-double-clic.

### Sur Linux
```bash
cd office
./lancer-linux.sh
```

---

## 🎮 Comment l'utiliser

| Action | Effet |
|---|---|
| **Molette souris** | Tourne la pièce sur 360° |
| **Glisser souris** | Orbite libre (haut/bas + côtés) |
| **Shift + molette** | Zoom avant / arrière |
| **Hover** sur un agent ou bureau | Tooltip |
| **Clic** sur un agent | Fiche détaillée + édition du nom |
| **Clic** sur le bureau central | Panneau Direction (gestion d'équipe) |

---

## ✏️ Modifier le nom d'un agent

**Méthode 1 (via la fiche agent)** :
1. Clic sur l'agent dans la scène
2. Clic sur son nom dans le panneau qui s'ouvre
3. Tape le nouveau nom → Entrée
4. La plaque 3D se met à jour en direct

**Méthode 2 (via la Direction)** :
1. Clic sur le bureau du chef (au centre)
2. Tu vois la grille de toute l'équipe
3. Clic sur n'importe quel nom pour le modifier
4. Entrée pour valider

Les nouveaux noms sont **sauvegardés automatiquement** dans le navigateur (localStorage). Au prochain chargement, ils sont conservés.

Pour **réinitialiser tous les noms** : Direction → "Réinitialiser tous les noms".

---

## 🏢 Ce que tu vois

- **Pièce circulaire** avec sol parquet warm et murs cylindriques
- **6 "fenêtres"** lumineuses ambrées autour de la pièce (= ambiance soir/coucher de soleil)
- **8 cubicules en vitrine** disposés en cercle, parois en verre semi-transparent, encadrement orange
- À l'intérieur de chaque vitrine : bureau, chaise pivot, moniteur (mockup terminal du métier de l'agent), clavier, mug, plante perso
- **Avatar** de l'agent assis à son poste (chemise = couleur de l'agent)
- **LED de statut** flottante (verte/orange/rouge/grise selon l'état)
- **Plaque nominative** orientée toujours vers la caméra
- **Bureau du chef au centre** : podium surélevé, fauteuil haut dossier capitonné, plaque "DIRECTION", hologramme tournant
- **Tapis circulaire** sous le bureau du chef avec liseré orange
- **Enseigne murale** "TRADING ALGO" au fond

---

## ⌨️ Pilotage par console (avancé)

Ouvre la console JS (F12) et tape :

```javascript
// Mettre un agent en mission
setAgentStatus('mql5-developer', 'busy', 'Fix anti-stacking v1.6')

// Marquer disponible
setAgentStatus('quant-strategist', 'available')

// Déclencher une alerte (LED rouge clignotante)
setAgentStatus('forward-test-watchman', 'alert', 'Drift critique XAU')

// Mettre off-duty (l'avatar disparaît du bureau)
setAgentStatus('discipline-coach', 'off')

// Renommer
setAgentName('quant-strategist', 'Marie Dupont')

// Lister tous les agents
listAgents()
```

Statuts valides : `'available'`, `'busy'`, `'alert'`, `'off'`.

---

## ❓ Ça marche pas, que faire ?

- **Le navigateur s'ouvre mais c'est tout blanc** → attends 2-3 secondes, Three.js se charge depuis le CDN (besoin d'internet la 1ère fois)
- **"Address already in use"** → le port 8765 est pris. Modifie le launcher pour utiliser 8766 ou autre
- **Page blanche persiste** → ouvre la console JS (F12) pour voir l'erreur, ou essaie un autre navigateur (Chrome / Firefox récents recommandés)
- **Aucun launcher ne marche** → installe Python 3 : Mac `brew install python`, Linux `sudo apt install python3`, Windows depuis python.org

---

## 📂 Fichiers

```
office/
├── index.html              ← l'app (HTML + Three.js inline)
├── lancer-mac.command      ← double-clic Mac
├── lancer-windows.bat      ← double-clic Windows  
├── lancer-linux.sh         ← Linux
└── README.md               ← ce fichier
```

# Bureau virtuel 3D — Trading Algo Team

Open-space circulaire avec 8 vitrines (une par agent) + bureau du chef central.

---

## 🚀 Comment l'ouvrir (3 secondes)

**Double-clic sur `index.html`** → ça s'ouvre dans ton navigateur. C'est tout.

> Pas besoin de Python, pas besoin de serveur, pas besoin de rien.

### Si le double-clic n'ouvre pas le navigateur

- **Windows** → clic-droit sur `index.html` → "Ouvrir avec" → choisis Chrome ou Edge
- **Mac** → clic-droit sur `index.html` → "Ouvrir avec" → Chrome ou Safari
- Ou tu peux aussi utiliser **`lancer-windows.bat`** / **`lancer-mac.command`** qui font la même chose

### Si la page reste blanche

- **Vérifie ta connexion internet** : Three.js (la lib 3D) est téléchargée depuis un CDN au premier lancement. Une fois en cache navigateur, c'est instantané.
- **Utilise un navigateur récent** : Chrome, Edge, Firefox ou Safari version 2022+.
- Si tu vois un message d'erreur sur la page, lis-le, il te dira quoi faire.

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
2. Clic sur son nom (souligné en pointillé orange)
3. Tape le nouveau nom → Entrée
4. La plaque 3D se met à jour en direct

**Méthode 2 (via la Direction)** :
1. Clic sur le bureau du chef (au centre)
2. Tu vois la grille de toute l'équipe
3. Clic sur n'importe quel nom pour le modifier
4. Entrée pour valider

Les nouveaux noms sont **sauvegardés automatiquement** dans le navigateur. Au prochain chargement, ils sont conservés.

Pour **réinitialiser tous les noms** : Direction → "Réinitialiser tous les noms".

---

## 🏢 Ce que tu vois

- **Pièce circulaire** avec sol parquet warm et murs cylindriques
- **6 "fenêtres"** lumineuses ambrées autour de la pièce (ambiance coucher de soleil)
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

## 📂 Fichiers

```
office/
├── index.html              ← l'app (1 fichier, tout est dedans) ← DOUBLE-CLIC ICI
├── lancer-windows.bat      ← alternative si le double-clic d'index.html ne marche pas
├── lancer-mac.command      ← idem pour Mac
├── lancer-linux.sh         ← idem pour Linux
└── README.md               ← ce fichier
```

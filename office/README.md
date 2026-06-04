# Bureau virtuel 3D — Trading Algo Team

Interface 3D interactive pour visualiser les 8 agents de l'équipe trading algo comme des employés dans un open-space.

## Ouvrir

```bash
# Option 1 — Python (le plus simple)
cd office
python3 -m http.server 8000
# puis ouvrir http://localhost:8000

# Option 2 — Bun
bunx serve office

# Option 3 — direct (peut ne pas marcher selon le navigateur, ESM via file:// est restrictif)
open office/index.html
```

> Three.js est chargé depuis unpkg.com via import map. Connexion internet requise au premier chargement (cache navigateur après).

## Ce que tu vois

- **Open-space** avec sol/murs, éclairage chaud (suspensions LED ambrées)
- **8 postes de travail** : 2 rangées de 4, chaque agent à son bureau
- Chaque poste a : bureau bois, chaise, moniteur (avec mockup terminal personnalisé), clavier, mug
- **Avatar humanoid** stylisé (couleur de chemise = couleur de l'agent)
- **LED de statut** flottante au-dessus de chaque agent :
  - 🟢 Vert (fixe) = disponible
  - 🟠 Orange (pulse lente) = en mission
  - 🔴 Rouge (pulse rapide) = alerte
  - ⚫ Gris (avatar absent) = off-duty
- **Plaque nominative** flottante en permanence orientée vers la caméra
- **Plante centrale** + tapis (zone détente)
- **Enseigne murale** "TRADING ALGO"

## Interactions

| Action | Effet |
|---|---|
| Glisser souris | Orbiter autour de la scène |
| Molette | Zoom avant/arrière |
| Hover sur un agent | Tooltip nom + rôle |
| Clic sur un agent | Panneau latéral avec fiche détaillée |
| Bouton "Copier le handle" | Copie `@agent-id` dans le presse-papier |

## Mettre à jour les statuts en temps réel

Depuis la console JS du navigateur (F12) :

```javascript
// Mettre un agent en mission
setAgentStatus('mql5-developer', 'busy', 'Refactor anti-stacking EA v1.6')

// Marquer comme disponible
setAgentStatus('quant-strategist', 'available')

// Déclencher une alerte
setAgentStatus('forward-test-watchman', 'alert', 'Drift critique XAU')

// Marquer off-duty
setAgentStatus('discipline-coach', 'off')

// Lister tous les agents
listAgents()
```

Statuts valides : `available`, `busy`, `alert`, `off`.

## Architecture

Fichier unique `index.html` autonome :
- HTML/CSS pour l'interface (header, légende, panneau latéral, tooltip)
- Three.js (via CDN import map) pour la scène 3D
- Données des 8 agents synchronisées avec `.claude/agents/*.md`
- API console pour modifier les états en live

## Limitations actuelles

- Les statuts sont en mémoire (session). À chaque reload, retour aux statuts par défaut.
- Pas encore de bridge automatique avec les invocations Claude réelles (les statuts sont mis à jour manuellement).

## Évolutions possibles

- 🔄 Bridge avec un fichier `agents-status.json` lu en polling (statut persisté)
- 🪝 Hook Claude qui met à jour le statut à chaque invocation d'un agent
- 💬 Affichage en bulle du dernier rapport produit par l'agent
- 🏃 Animation : agent qui se lève et marche vers un autre quand collaboration inter-agents
- 📊 Tableau au mur affichant le PnL ou les métriques du jour

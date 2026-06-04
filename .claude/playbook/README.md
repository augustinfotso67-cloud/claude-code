# Playbook — Équipe Trading Algo

## Architecture

8 agents spécialisés + Claude orchestrateur :

| Agent | Rôle | Mandat principal |
|---|---|---|
| `quant-strategist` | Stratège | Edge, régime, choix actif |
| `mql5-developer` | Dev | Code MQL5, debug, optimisation |
| `backtest-auditor` | Auditeur stat | Verdict DÉPLOYABLE/À REVOIR/INUTILISABLE |
| `risk-manager` | Risque | Sizing, DD, kill switches |
| `data-scientist` | Data | Analyse data-driven, ML quand justifié |
| `forward-test-watchman` | Veilleur live | Démo vs backtest, drift |
| `discipline-coach` | Coach | Journal, biais, règles |
| `broker-execution-specialist` | Broker | Choix broker, exécution, latence |

## Règle d'or de l'orchestration

**Un seul agent par mandat.** Pas d'agents qui se marchent dessus. Si une question chevauche, je décompose et j'invoque plusieurs agents séquentiellement.

## Quand invoquer quoi

### Tu m'envoies un rapport de backtest (.xlsx)
```
→ backtest-auditor   : audit statistique
→ risk-manager       : valider le DD/sizing
→ quant-strategist   : edge sain ou over-fitté ?
```

### Tu veux créer un nouvel EA
```
1. quant-strategist  : propose l'edge
2. broker-execution  : choisit le broker adapté
3. risk-manager      : définit le sizing/limites
4. mql5-developer    : code l'EA
5. data-scientist    : analyse data-driven historique
6. backtest-auditor  : verdict avant déploiement
7. discipline-coach  : règles d'engagement écrites
```

### Tu vois un bug ou comportement bizarre
```
1. mql5-developer    : diagnostic et fix
2. risk-manager      : vérifier que le fix ne change pas le profil de risque
```

### Tu hésites à modifier un EA en live
```
1. discipline-coach  : interception immédiate, audit du biais
2. backtest-auditor  : si justifié, valider statistiquement la modif sur démo clone
```

### Tu veux déployer en réel
```
1. backtest-auditor       : verdict ✅ obligatoire
2. broker-execution       : broker choisi et configuré
3. risk-manager           : capital + sizing validés
4. discipline-coach       : règles signées
5. forward-test-watchman  : armé pour monitoring
```

### Tu veux passer un challenge prop firm (FTMO etc.)
```
1. risk-manager       : adapter sizing aux contraintes (DD daily 5 %, target 10 %)
2. mql5-developer     : implémenter les guards spécifiques prop firm
3. backtest-auditor   : simulation avec contraintes du challenge
```

### Bilan mensuel
```
1. forward-test-watchman : drift live vs backtest
2. discipline-coach      : respect des règles + état émotionnel
3. risk-manager          : exposition cumulée + DD vs limites
4. quant-strategist      : régime de marché toujours favorable ?
```

## Workflow type pour ton projet actuel

Tu m'as dit que tu vas m'envoyer le **dossier de travaux récents**. Voici comment je vais l'absorber :

### Phase 1 — Inventaire (jour 0)
Je liste tout : .mq5, .csv logs, .xlsx rapports, scripts Python, configs MT5.

### Phase 2 — Diagnostic état actuel
- `backtest-auditor` : audit des derniers rapports
- `quant-strategist` : régime actuel et viabilité de l'edge
- `mql5-developer` : revue code actuel (bugs résiduels ?)
- `risk-manager` : exposition réelle et risque caché

### Phase 3 — Plan d'action consolidé
Je synthétise les avis des 4 agents et je te propose :
- Ce qui est gardé tel quel
- Ce qui doit être corrigé en priorité
- Le séquencement des prochaines 4-8 semaines

### Phase 4 — Exécution
Pour chaque action, l'agent compétent.

## Anti-patterns à éviter

❌ **"Tous les agents en parallèle"** : chaos, contradictions, perte de temps. Toujours séquencer.

❌ **"Tu peux faire le travail de tous"** : non. Chaque agent a son mandat. Le respect du mandat = qualité.

❌ **"L'agent ne sait pas, donc je décide moi-même"** : si un agent dit "je manque d'info", on lui en fournit. Pas de raccourci.

❌ **"On modifie l'EA en live parce que ça perd"** : `discipline-coach` intercepte. Always.

❌ **"Un nouvel actif sans nouvelle analyse"** : pas de réplication aveugle. Chaque actif a son régime.

## Fichiers du projet

```
.claude/
├── agents/
│   ├── quant-strategist.md
│   ├── mql5-developer.md
│   ├── backtest-auditor.md
│   ├── risk-manager.md
│   ├── data-scientist.md
│   ├── forward-test-watchman.md
│   ├── discipline-coach.md
│   └── broker-execution-specialist.md
└── playbook/
    └── README.md   # ce fichier
```

À étendre selon les besoins :
- `playbook/new-ea-workflow.md` — checklist détaillée création EA
- `playbook/backtest-review.md` — gabarit audit
- `playbook/live-monitoring.md` — routine hebdomadaire
- `playbook/prop-firm-challenge.md` — checklist FTMO

## Mise à jour

Les agents et le playbook évoluent avec le projet. Quand on découvre un pattern récurrent (genre "le stacking bug"), on l'inscrit dans la connaissance permanente de l'agent concerné via update de son `.md`.

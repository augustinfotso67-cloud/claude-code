# FOTSO COMPANY — Vision, Mission, Roadmap

> Document de cadrage stratégique
> Auteur : Augustin Fotso (DG)
> Version : 0.1 — 5 juin 2026
> Statut : Vivant, à itérer

---

## 🌟 Vision

**Bâtir un écosystème de produits financiers quantitatifs** centrés sur :
- L'analyse rigoureuse des marchés
- Le développement d'Expert Advisors (EAs) statistiquement validés
- La création d'applications et de SaaS dérivés
- L'orchestration via une équipe d'agents experts (IA structurée)

FOTSO COMPANY n'est pas "un EA qui doit performer ce mois-ci". C'est une infrastructure de pensée et de production destinée à durer.

---

## 🎯 Mission

1. **Analyser** : produire des insights de marché reproductibles (XAU prioritaire, puis BTC / indices)
2. **Développer** : EAs et tools validés out-of-sample, jamais déployés sur un backtest unique
3. **Capitaliser** : compétences, infra, pipeline ML, documentation — chaque itération nourrit la suivante
4. **Diffuser** : à terme, transformer la chaîne interne (analyses + EAs) en SaaS adressables

---

## 👥 Équipe — 8 agents spécialisés + DG

| Rôle technique | Nom interne | Mandat principal |
|---|---|---|
| **DG** | **Augustin Fotso** | Vision, gouvernance, arbitrage final |
| `quant-strategist` | *(à nommer)* | Edge statistique, régime de marché, choix actif |
| `mql5-developer` | *(à nommer)* | Code MQL5, debug, optimisation EAs |
| `backtest-auditor` | *(à nommer)* | Audit statistique, verdict DÉPLOYABLE/À REVOIR/INUTILISABLE |
| `risk-manager` | *(à nommer)* | Sizing, kill switches, capital preservation |
| `data-scientist` | *(à nommer)* | Pipeline ML, feature engineering, walk-forward |
| `forward-test-watchman` | *(à nommer)* | Démo vs backtest, score de drift |
| `discipline-coach` | **Lisa** | Journal, biais, règles d'engagement |
| `broker-execution-specialist` | *(à nommer)* | Choix broker, exécution, latence, spreads |

Le DG pilote, les agents exécutent leur mandat. Aucun ne prend de décision en dehors de son périmètre.

---

## 🗺️ Roadmap juin 2026 — Mois "Convergence"

### Objectif du mois (validé Augustin)
> Sur un backtest XAU de 2 ans, **faire converger Win Rate + Profit Factor + Volume de signaux**.
> Voir ce qui marche, ce qui ne marche pas, et tracer les perspectives futures.

### Cibles mesurables
| Métrique | Cible | Status (v5.99 baseline) | Status (filtres preview) |
|---|---|---|---|
| WR | ≥ 60% | 39.1% | 45.1% (COMBO3) |
| Profit Factor | ≥ 1.8 | 0.98 | 1.30 (COMBO1) |
| Signaux | À calibrer | 463/an | 162-465/an selon filtres |
| Max DD | ≤ 10% | 16.7% | 3.0–3.9% |

### Semaines

```
S1 (cette semaine) — DIAGNOSTIC
├── Analyses A, B, C terminées le 5 juin ✓
├── Identification edges latents (filtre horaire + ADX directional)
└── Specs v6.0 rédigées par quant-strategist + risk-manager

S2 — IMPLEMENTATION
├── Implémenter filtres horaires + ADX/ATR dans v6.0 (mql5-developer)
├── Re-backtest 2 ans (2024-2026 + 2022-2024 séparément)
└── Confirmer convergence sur 2 sous-périodes

S3 — VALIDATION WALK-FORWARD
├── 12 mois IS / 3 mois OOS rolling sur 2020-2026
├── Mesurer dégradation OOS/IS sur chaque fenêtre
└── Si OOS < 50% IS → curve-fit, retour S2

S4 — DEMO PAPER TRADING
├── 1 semaine démo MT5
├── Comparer démo vs backtest récent (forward-test-watchman)
└── Décision : continuer / itérer / pivot
```

---

## 🧭 Principes non-négociables

1. **Rigueur statistique d'abord** : pas de Sharpe > 3 sur < 300 trades qui ne soit suspecté de curve-fit
2. **Walk-forward obligatoire** : aucun déploiement sans validation OOS strict
3. **Discipline en première ligne** : Lisa intercepte tout tweak émotionnel
4. **Capital preservation > performance** : kill switches sacrés, sizing prudent
5. **Itérations courtes** : pas de refonte de 6 mois, des cycles de 1-2 semaines
6. **Documentation systématique** : chaque décision a un .md qui la justifie

---

## 📂 Structure du repo (à venir)

```
claude-code/  (workspace global, infrastructure agents)
├── .claude/agents/         # 8 agents système
├── .claude/playbook/       # Orchestration
├── office/                 # Bureau virtuel 3D
├── trading-project/        # Projets concrets
│   └── Fotso-EA/           # EA actuel
└── FOTSO_COMPANY.md        # Ce document
```

Évolutions prévues :
- `fotso-company/` racine, contenant `vision/`, `roadmap/`, `meetings/`, `kpis/`
- `fotso-saas/` quand le 1er produit dérivé émergera
- `fotso-tools/` pour les utilitaires partagés (xlsx parser, etc.)

---

## 📊 Décisions stratégiques actées au 5 juin 2026

1. **v5.99 gelée** comme baseline de référence (tag `v5.99-baseline-frozen`)
2. **Brain ML désactivé en prod jusqu'à preuve d'un edge linéaire simple sans ML**
3. **L'EA n'est pas mort** — un edge latent existe, dilué par le sur-trading hors zones favorables
4. **Cap mensuel** : convergence WR + PF + Signaux via filtrage agressif, pas via refonte
5. **Pas de nouveau brain_v6 avant que les filtres simples ne soient validés walk-forward**

---

## 📌 Prochains jalons

| Date | Jalon | Responsable |
|---|---|---|
| 5 juin | Réunion de cadrage FOTSO COMPANY | DG + équipe |
| 8 juin (lundi) | Specs v6.0 finalisées | quant + risk |
| 12 juin (vendredi) | v6.0 implémentée + backtest 2 ans | mql5-developer |
| 19 juin (vendredi) | Walk-forward strict validé ou rejeté | backtest-auditor |
| 26 juin (vendredi) | Démo paper trading 1 semaine | forward-test-watchman |
| 30 juin | Bilan mensuel + roadmap juillet | DG + Lisa |

---

*Document vivant. Toute modification doit être commit avec un message explicite : `docs(fotso): <changement>`.*

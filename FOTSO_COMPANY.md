# FOTSO COMPANY — Vision, Mission, Roadmap

> Document de cadrage stratégique
> Auteur : Augustin Fotso (DG)
> Version : **0.2 — 5 juin 2026 (post-réunion de cadrage)**
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

## 👥 Équipe — la VRAIE équipe FOTSO COMPANY

L'équipe technique de FOTSO COMPANY est construite autour du président et de ses 8 frères d'arme — des camarades et amis de la vraie vie. Chaque rôle a été attribué selon les forces réelles de chacun, observées durant les années d'études ensemble.

| Rôle technique | Prénom | Bio / contexte |
|---|---|---|
| **Président · DG** | **Augustin Fotso** | Fondateur. Surnommé « président » par la promo depuis la première année. Pilote, arbitre, décide. |
| `quant-strategist` | **Louis** | Meilleur ami du président. Génie électrique niveau 3 ingénieur. Edge statistique, régime de marché, choix actif. |
| `mql5-developer` | **Mahamat** | Meilleur ami du président. Génie informatique niveau 3 ingénieur. Code, debug, optimise les EAs. |
| `backtest-auditor` | **Auréole** | Nouvelle camarade en génie électrique (promo avec Louis, Cabrel et le président). Méfiance par défaut, audit rigoureux. |
| `risk-manager` | **Fabiany** | As des paris sportifs dans la vraie vie 😅. Génie informatique niveau 3 (promo avec Mahamat et Berios). Sizing, kill switches. |
| `data-scientist` | **Berios « Docta »** | Fort en mathématiques depuis le niveau 1, surnommé « Docta » par la promo. Génie informatique niveau 3. Pipeline ML, walk-forward. |
| `forward-test-watchman` | **Aziz** | Surveille la convergence démo/live vs backtest. Détecte les drifts d'exécution. |
| `discipline-coach` | **Lisa** | Système immunitaire mental de FOTSO COMPANY. Journal, biais, règles d'engagement. |
| `broker-execution-specialist` | **Cabrel** | Camarade en génie électrique (avec Louis et Auréole). Expert reconnu des brokers — audit, choix, exécution. |

Le **président** pilote, l'équipe exécute son mandat. Aucun ne prend de décision en dehors de son périmètre.

> *« Dans ce groupe depuis la première année ils ont vu en moi quelque chose et du coup me surnomment "président". Je pouvais pas créer un tel écosystème sans les faire intervenir et attribuer à chacun le rôle qu'il mérite. »*
> — Augustin Fotso, 5 juin 2026

---

## ⏰ Deadlines personnelles du président (gravé 6 juin 2026)

Le projet FOTSO COMPANY a démarré en **février 2026**. Le président a fixé deux deadlines explicites qui structurent toutes les décisions :

| Deadline | Date butoir | Critère d'arrêt |
|---|---|---|
| **D1 : 6 mois** | **août 2026** | Si pas de **résultats concrets qui encouragent à investir mon propre argent** → pause/pivot du projet |
| **D2 : 6-24 mois** | **août 2026 → février 2028** | Si ça ne marche pas réellement → **arrêt définitif du trading** (2e tentative dans la vie) |

**Conséquences opérationnelles** :
- Chaque décision se mesure à l'aune de ces deux échéances
- Le coût mensuel (abonnement Claude 20 $/mois + temps investi) n'est pas anodin et doit être justifié par la trajectoire
- À août 2026 : revue critique sans complaisance. Si la trajectoire ne montre pas de signaux objectifs de convergence vers un edge réel → pivot ou pause.
- À tout moment d'ici là, deux pôles à distinguer mentalement :
  - **Pôle cashflow immédiat** (XM Weekly Competition, Copy Trading Strategy Provider, prop firms) : exploitation tactique de revenus, séparé du capital FOTSO
  - **Pôle edge structurel** (EA + méthodologie + équipe + walk-forward) : cœur de mission long terme

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

## 📝 Compte-rendu réunion de cadrage — 5 juin 2026

### Présents
- **Augustin Fotso** (DG)
- `quant-strategist` (Specs filtres v6.0)
- `risk-manager` (Policy v6.0 + Kelly + kill switches)
- **Lisa** (`discipline-coach` — règles mensuelles + cadre psy)

### Décisions actées (unanimité)

1. **Aucun déploiement réel ce mois-ci.** Juin = mois d'analyse, cadrage, validation. Pas de production.
2. **L'EA n'est pas mort.** Edge latent identifié : filtre horaire (skip H5,7,10-12,14,16-19) + skip jeudi transforme PF 0.98 → 1.30 sur 1967 trades.
3. **Hypothèse économique de l'edge** : microstructure des fixings (Shanghai Gold 02:15 UTC, London AM/PM, news US 12:30/14:00 UTC). Jeudi = drainage pré-NFP/CPI.
4. **Walk-forward obligatoire** avant toute confirmation : Train 2024-01→2025-06 / OOS1 2025-07→2025-12 / OOS2 2026-01→2026-05. Critère accept : PF OOS > 1.15 + DD OOS < 6% + n ≥ 100.
5. **Risk policy v6.0** : RiskPercent 0.75% (quart-Kelly réduit), Daily DD −3%, Weekly −6%, Mensuel −10% kill switch code-level non désactivable, 5 SL consécutifs = pause 48h.
6. **5 stress tests obligatoires** avant signature risk-manager : 10 SL consécutifs, gap weekend $300, flash crash −5%/5min, régime change vol×2, Monte Carlo 1000 runs (P95 DD < 15%).
7. **5 règles mensuelles Lisa** non négociables : cadence 5/2, 1 décision majeure/semaine max, stop si 3 sessions sans avancée OU sommeil dégradé, pas de code après 22h, ZÉRO déploiement réel ce mois.

### Risques identifiés
- 🚨 **Euphorie post-traumatique** : la découverte de l'edge ce soir arrive trop vite après le verdict dur de l'après-midi. Risque de "12 nouveaux filtres demain matin" pour confirmer.
- ⚠️ **Curve-fit non détecté** : les filtres ont été identifiés sur les mêmes données qui serviront au backtest. Walk-forward strict obligatoire.
- ⚠️ **Edge fragile (PF 1.30 marge mince)** : sample 691 trades sur 4.25 ans = IC large.

### Pré-requis pour valider v6.0
- [ ] Specs quant codées proprement (inputs paramétrables, hypothèse documentée)
- [ ] Walk-forward Train/OOS1/OOS2 passé avec critères stricts
- [ ] 5 stress tests risk passés
- [ ] Lisa valide qu'aucune des 5 règles mensuelles n'a été cassée
- [ ] backtest-auditor signe le verdict statistique final

---

## 🛠️ Tableau de bord des artefacts produits le 5 juin 2026

| Artefact | Localisation | Statut |
|---|---|---|
| Code v5.99 | `trading-project/Fotso-EA/` | 🔒 Gelé (baseline) |
| Audit code v5.99 | Marc Tournier — branche SELL | ✅ Livré |
| Backtest 4.25 ans v5.99 sans ML | rapport MT5 + 1967 trades CSV | ✅ Analysé |
| Audit statistique Hélène | Verdict 🔴 INUTILISABLE EN L'ÉTAT | ✅ Livré |
| Analyse régime Olivier | "Edge dans contexte, pas dans M15" | ✅ Livré |
| Cadre psy Lisa (3 règles 72h) | Session après-midi | ✅ Actif |
| **Analyses A/B/C** | Sous-période / Régime / Heatmap | ✅ Livré |
| **Découverte filtres** | Heures + jeudi + ADX directional | ✅ Documenté |
| **Specs v6.0** | Section ci-dessus | ✅ Validé quant |
| **Risk policy v6.0** | Section ci-dessus | ✅ Validé risk |
| **Règles mensuelles Lisa** | Section ci-dessus | ✅ Validé discipline |
| **FOTSO_COMPANY.md** | Repo racine | ✅ v0.2 |

---

*Document vivant. Toute modification doit être commit avec un message explicite : `docs(fotso): <changement>`.*

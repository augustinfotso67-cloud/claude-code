# Diagnostic final — Cerveau Adaptatif v5.6+D1.1 HOTFIX

**Backtest analysé** : XAUUSDm M15 / 24 mois (2024-04-24 → 2026-04-24) / Exness MT5
**Données marché** : 32 mois OHLC multi-TF (Daily / H4 / H1 / M15 / M5)

---

## 1. Performance — Verdict global : **🟢 EA solide**

### Chiffres clés
| Métrique | Valeur | Verdict |
|---|---|---|
| Profit net | +1 549.96 € (≈ **+155% sur 24 mois**) | ✅ |
| Profit factor | **1.83** | ✅ |
| Sharpe | **4.52** | ⚡ très élevé |
| Recovery factor | 7.14 | ✅ |
| DD max solde | **7.09%** | ✅ très contenu |
| DD max fonds | 8.97% | ✅ |
| Corrélation LR equity | 0.94 | ✅ croissance linéaire |
| Win rate | 49.45% | ⚖️ <50% mais compensé |
| Avg gain / Avg perte | 25.38 / -13.60 = **1.87** | ✅ |
| Espérance / trade | **+5.66 €** | ✅ |
| Durée moy / max | 13h32 / 48h00 | normal / `MaxHeuresTrade=48` |

### Alpha vs marché
- **XAU sur la période** : ~$2 380 → ~$4 708 = **+98%**
- **EA** : +155%
- **Alpha = +57%** sur 24 mois → l'EA bat clairement le buy & hold ✅

### Contexte marché (depuis l'analyse Excel)
- 32 mois XAU : +146% (gros bull market)
- Range moyen Daily : $49.22
- **Variation max -10.06%** sur une journée → testé, EA a tenu (DailyStopLoss=20% protège)
- Range max Daily : $768 (1 journée extrême)
- Prix actuel ($4 708) proche MA-200 D1 ($4 433) → **possible fin de cycle bull**

---

## 2. 🚨 ANOMALIE STRUCTURELLE — Distribution BUY/SELL

| Direction | Trades | WR | % du total |
|---|---|---|---|
| **BUY** (longues) | **270** | 49.26% | 98.9% |
| **SELL** (courtes) | **3** | 66.67% | **1.1%** |

### Lecture
L'EA est **quasi mono-directionnel** sur la période testée.

**Cause** : la stratégie suit la tendance D1. Pendant 24 mois d'uptrend continu, les SELL n'étaient autorisés que via le **DualGuard override** (HOTFIX D1.1) — qui ne s'est déclenché que ~3 fois.

### Risque
**La branche SELL n'a jamais été stress-testée.** Si le marché entre en downtrend D1 prolongé en 2026 (cycle qui se retourne, MA-200 tout proche), l'EA bascule en mode "270 SELL" — sans validation empirique.

### Recommandation
🎯 **Backtest obligatoire sur XAU 2012-2015** (downtrend confirmé, $1900 → $1050) avant déploiement sur compte réel en cas de retournement.

---

## 3. Bugs identifiés — Impact réel sur le backtest

### 🔴 Bug #1 (DG cascade) — IMPACT PROBABLE confirmé
- 138 BUY perdants, dont une fraction sont des **timeouts 48h** ou **fermetures vendredi 20h**, **pas des SL**
- Tous comptés comme cascade SL → suspensions BUY injustifiées
- **Effet caché** : invisible dans la perf finale (le pré-calibré compense), mais l'EA a manqué des trades pendant ces suspensions
- **Gain potentiel après fix : +5 à +15%** estimé sur le profit net

### 🔴 Bug #2 (apprentissage temporel décalé)
- 270 trades de durée moyenne 13h32 → `cerveau[idx].scoreHeures` apprend sur l'heure de **fermeture**
- L'EA croit qu'il "performe bien à 22h" alors qu'il est entré à 9h → biais systémique
- **Effet caché** : le pré-calibré (`scoreHeuresPreCal`) protège la décision actuelle, mais l'apprentissage runtime est toxique. Si un jour on activait `scoreHeures` adaptatif comme primary → catastrophe

### 🔴 Bug #3 (persistance binaire fragile)
- Aucun check de taille du `.dat`
- **Effet en prod** : changement de struct → corruption silencieuse de la mémoire au prochain reload

### 🟠 Fragilités confirmées
4. Cast `int(datetime)` → bug Y2038 latent
5. Handles indicateurs créés/release par tick → coût perf
6. Asymétrie seuils 1.003 vs 1.005 → à documenter
7. `OnTradeTransaction` filtre `DEAL_TYPE` au lieu de `DEAL_ENTRY` → fragile mais marche

---

## 4. Insights additionnels (charts)

### Heures d'entrée
- **Pic 43 trades à 2h** (ouverture Londres) — **suspect** : spread élevé, faux signaux. Tester `LondonStart=3` ou `4`.
- Pic secondaire 13h-15h (overlap Londres/NY) — sain

### Jours
- Vendredi : 32 trades — moins (à cause de `FermerVendredi`) ✅
- Mercredi-Jeudi : pics de profit ✅
- Mardi : pertes notables ⚠️

### MFE/MAE
- **Corr Profit/MFE = 0.78** : on capte bien le potentiel des gagnants ✅
- **Corr Profit/MAE = 0.38** : le SL coupe vraiment (les pertes ne suivent pas les MAE)
- Mais : nombreux trades MFE 90-150 → profit final 30-50 → **on laisse de l'argent dans le trailing**. Tester `Trail_ATR_Multi=2.0` (au lieu de 2.5)

---

## 5. Plan d'action — Priorisé

| # | Action | Effort | Gain estimé |
|---|---|---|---|
| **1** | Fix Bug #1 (`DEAL_REASON_SL` check) + re-backtest | 5 min code | +5 à +15% profit |
| **2** | Fix Bug #3 (versioning persistance) | 15 min | Évite crash silencieux en prod |
| **3** | Fix Bug #2 (heure ouverture) | 30 min | Apprentissage correct |
| **4** | **Backtest XAU 2012-2015** (validation branche SELL) | 1h backtest | Validation critique |
| **5** | Optimisation `LondonStart ∈ {2,3,4,5}` | 30 min walk-forward | +2 à +5% probable |
| **6** | Optimisation `Trail_ATR_Multi ∈ {1.5, 2.0, 2.5}` | 30 min | +5 à +10% probable |
| **7** | Refactor monolithe en `.mqh` modules | 2-3h | Maintenabilité long terme |

### Mon ordre conseillé
**Phase 1 (urgent — avant tout déploiement réel)** : actions 1, 2, 3, 4
**Phase 2 (optimisation)** : 5, 6
**Phase 3 (long terme)** : 7

---

## 6. Question stratégique de fond

L'EA a fait +155% sur un marché qui en a fait +98%. **L'alpha (+57%) vient principalement** :
1. Du compounding (risk 2% sur capital croissant)
2. De la sélection des entrées (filtres ContextScore + ADN + Miroir)
3. Du RR 1.5/2.5 qui maximise le profit en tendance

**Mais cet alpha repose sur la branche BUY uniquement.** Le test critique de robustesse est le marché baissier ou range. Avant de mettre en réel sur un cycle qui se retourne :
1. Backtest XAU 2012-2015 (downtrend)
2. Backtest XAU 2017-2018 (range)
3. Validation que la branche SELL produit aussi un profit factor > 1.5

---

## Fin de la phase d'analyse

Ce qu'on a maintenant :
- ✅ Audit code (`AUDIT_v5.6+D1.1.md`)
- ✅ Diagnostic backtest (ce document)
- ✅ Workspace git propre (`C:\Users\User\Fotso-EA\`)
- ✅ Outil de parsing xlsx (`tools/xlsx_dump2.py`)

**Prochaine session** : on attaque les fixes par priorité. Tu me dis "fix bug 1" et je le fais sur un branch git, on re-backtest, on commit.

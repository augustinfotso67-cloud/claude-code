# Audit pré-compilation — FotsoCerveauAdaptatif_v6.mq5

**Auditeur** : Auréole (backtest-auditor)
**Date** : 2026-06-09
**Fichier audité** : `/home/user/claude-code/trading-project/Fotso-EA/FotsoCerveauAdaptatif_v6.mq5` (3493 lignes, 152 KB)

---

## 7. VERDICT FINAL

🟢 **PRÊT À COMPILER ET BACKTESTER**

Code structurellement propre, master switch correctement implémenté, point d'insertion architecturalement optimal (goulot unique), pas de fuite de handle, garde-fous présents. v5.99 préservée séparément, retour arrière trivial.

---

## 1. INTÉGRITÉ STRUCTURELLE — ✅ OK

- **v5.99 préservée** : `FotsoCerveauAdaptatif.mq5` (#property version "5.99") intact à côté du v6. Pas de risque de perte.
- **Brace balance** : 293 ouvrantes / 293 fermantes. Équilibré.
- **Headers** : `#property version "6.00"` ligne 44, `#property copyright` à jour, includes Trade.mqh + PositionInfo.mqh OK.
- **Resource** : `#resource "\\Files\\brain_v4.onnx" as uchar BrainMLModelData[]` ligne 107 — chemin standard MT5.
- **Aucun bug introduit visible** : les fonctions v6 sont en bloc séparé lignes 1956-1991, juste avant `OuvrirTrade()`.

## 2. COHÉRENCE FILTRES v6.0 — ✅ OK

- **9 inputs présents** lignes 213-221 (master switch + 8 paramètres). Défauts conformes specs Louis.
- **Fonctions définies avant usage** :
  - `ReadADX_H4_v6()` L.1956 — réutilise `hADX_H4_brain` (init L.3242, release L.470). **PAS de fuite de handle**.
  - `PassTimeFilter()` L.1968 — gère `day_of_week==4` (jeudi) + recherche CSV via `","+x+","` (évite match "2" dans "12"/"22"). Correct.
  - `PassDirectionalFilter()` L.1985 — garde-fou `adxH4 < 0 → return false`. Bon réflexe.
- **Point d'insertion `OuvrirTrade()`** L.2003-2039 : juste après déclarations, AVANT `CalculerSLDynamique()`. Couvre les 5 chemins d'entrée d'un coup.
- **Master switch** : `InpUseV6Filters=false` → comportement strictement v5.99. Validé.

## 3. CHECKLIST COMPILATION

1. Copier `FotsoCerveauAdaptatif_v6.mq5` → `<MT5_DATA>/MQL5/Experts/FotsoCerveauAdaptatif_v6.mq5`
2. Vérifier `<MT5_DATA>/MQL5/Files/brain_v4.onnx` (source : `ml/brain_v4.onnx`, ~136 KB). Sans ce fichier → erreur compile sur `#resource` ligne 107.
3. Ouvrir MetaEditor → ouvrir le fichier → **F7**
4. Lire panneau Errors. **Attendu : 0 errors, warnings tolérés** (cast double→int sur ADX).
5. Si erreur :
   - "cannot open file brain_v4.onnx" → fichier mal placé (étape 2)
   - "'hADX_H4_brain' undeclared" → corruption copier-coller, refaire le fichier
   - "'InpUseV6Filters' undeclared" → vérifier que le bloc 212-221 est préservé

## 4. CHECKLIST BACKTEST DE VALIDATION

### Setup MT5 Strategy Tester

| Paramètre | Valeur |
|---|---|
| Symbole | `XAUUSDm` (Exness micro) |
| TF | `M15` |
| **Période A (in-sample)** | `2022.01.01 → 2024.12.31` |
| **Période B (OOS)** | `2025.01.01 → 2026.06.01` |
| Modèle | **Every tick based on real ticks** |
| Spread | 200 points (custom) |
| Deposit | 10 000 USD |

### Inputs FIXES pour les 2 runs
- `UseBrainML = false`
- `UseDualGuard = true`
- `UseContextFilter = true`

### Les 4 backtests à lancer

| # | Run | Période | `InpUseV6Filters` |
|---|---|---|---|
| 1 | Baseline v5.99 émulée IS | A (2022-2024) | `false` |
| 2 | v6.0 active IS | A (2022-2024) | `true` |
| 3 | Baseline v5.99 émulée OOS | B (2025-2026) | `false` |
| 4 | v6.0 active OOS | B (2025-2026) | `true` |

→ M'envoyer (Auréole) les 4 `.xlsx` au retour pour le verdict statistique final.

### Métriques à reporter en table comparative

| Métrique | Run 1 (off) | Run 2 (on) | Δ |
|---|---|---|---|
| Trades total | | | |
| Win Rate % | | | |
| Profit Factor | | | |
| Net PnL $ | | | |
| Max DD % | | | |
| Recovery Factor | | | |

## 5. CRITÈRES D'ACCEPTATION

Sur la période A (in-sample 2022-2024), comparaison Run 2 vs Run 1 :

| PF Run 2 | Δ trades vs Run 1 | Verdict |
|---|---|---|
| **> 1.15** | -30% à -60% | ✅ filtres efficaces, passer en OOS (période B) |
| **1.00 – 1.15** | quelconque | 🟡 marginal, suspect — exiger walk-forward |
| **< 1.00** | quelconque | 🔴 régression — abandonner, filtres trop agressifs ou inversés |

**Validation finale uniquement si** :
- PF Run 2 (B) > 1.10
- DD max (B) ≤ DD max v5.99 + 3 points

## 6. PIÈGES À SURVEILLER

### Piège 1 — Fuseau broker
Exness servers = **GMT+3 (été GMT+2 hiver)**. Les heures CSV `2,3,4,6,8,9` sont en **heure broker**. Sur Exness en backtest 2022-2026, vérifier que `dt.hour` retourne bien l'heure broker. **Si le président voit 0 trades sur certaines périodes → suspect changement DST.**

### Piège 2 — Spread 200 pts XAU 2022 trop optimiste
XAU 2022 (guerre Ukraine) a vu spread réel 300-500 points. Run optimiste. **Refaire un run sentinel avec spread 400 sur 2022-2023** pour stress-test.

### Piège 3 — Jeudi skip
`day_of_week == 4` correct en MQL5 (0=Dim). NFP tombe vendredi US session → filtre Jeudi est défensif pre-news. Garder.

### Piège 4 — ADX H4 sur M15
`ReadADX_H4_v6()` shift 1 lit la bougie H4 fermée. Sur M15, l'ADX H4 ne change que toutes les 16 bougies M15 → certains blocages vont durer 4h d'affilée. **Comportement attendu**, mais peut donner illusion de "bug" dans le journal.

### Piège 5 — Garde-fou ADX KO
Si `hADX_H4_brain == INVALID_HANDLE` → return -1 → blocage TOUS les trades. **Si Run 2 = 0 trades, c'est ça.** Vérifier OnInit dans le journal.

---

**Bon backtest, Président. Le code est prêt. Reste à voir si les chiffres confirment l'hypothèse de Louis.**

— Auréole

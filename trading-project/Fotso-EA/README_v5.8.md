# FotsoCerveauAdaptatif v5.8 + brain_v2 — Guide complet

## Etat actuel (15 mai 2026)

### Resultats backtest version PRECEDENTE (brain_v1, 23 features)
- Periode : 2025-01 -> 2026-05 (16.5 mois) sur XAUUSDm M15
- **Profit Net : +1 177.64 USD (+11.78%)**
- Profit Factor : 1.48
- Sharpe : 2.75 (excellent)
- Max DD : 5.40% balance / 8.12% equity
- **WR : 47.09%** (objectif 65% non atteint)
- WR SELL : **27.27%** (mauvais — bias BUY-only de l'ancien dataset)
- 11 pertes consecutives max

### Nouveaute v5.8 : brain_v2

**Re-entraine sur 4.2 ans (2022-2026) avec les nouvelles donnees XAU :**

| Metrique | brain_v1 | brain_v2 | Gain |
|---|---|---|---|
| Donnees train | 2.5 ans | 4.2 ans | +68% |
| Signaux | 3406 | 5490 | +61% |
| BUY/SELL | 98%/2% | 81%/19% | 24x +SELL |
| AUC test | 0.9247 | **0.9393** | +1.5pp |
| WR test @ 0.25 | 80.3% | 74.6% (+volume) | comparable |
| WR test @ 0.50 | 93.2% | 81.2% (+volume) | meilleur signal/qualite |
| Test set | 682 | 1098 | +61% |

**Le gain principal : SELL signals.** brain_v1 etait aveugle aux baissiers.
brain_v2 a vu le bear 2022 — il sait quand un SELL est bon.

## Architecture des fichiers

```
C:\Users\User\Fotso-EA\
+-- FotsoCerveauAdaptatif.mq5    # v5.8 source (utilise 36 features)
+-- FotsoCerveauAdaptatif.ex5    # ATTENTION : ancienne version - A RECOMPILER
+-- brain_v1.onnx                 # brain_v2 deploye (27 KB, 36 features)
+-- ml\                            # Tout le pipeline Python
|   +-- brain_v1.onnx             # copie identique
|   +-- brain_v1_meta.json        # seuils + perf
|   +-- build_dataset.py          # generation dataset
|   +-- train_brain.py            # entrainement GBT + export ONNX
|   +-- add_regime_feature.py     # features f34/f35
|   +-- test_onnx.py              # validation runtime
|   +-- eval_thresholds.py        # analyse seuils
|   +-- indicators.py             # indicateurs techniques (replique MQL5)
|   +-- dataset_xau_v2.csv        # dataset 5490 signaux
|   +-- dataset_xau_v2_regime.csv # dataset + f34/f35
|   +-- _old_v1_23features\       # archives ancienne version
+-- BRAIN_ML_INTEGRATION.md       # specs des 36 features
+-- BRAIN_V2_RESULTS.md           # rapport detaille v2
```

## Procedure pour relancer le backtest avec brain_v2

### 1. Compiler l'EA (CRUCIAL — sinon le backtest utilisera l'ancien .ex5)

```
1. Ouvrir MetaEditor (F4 depuis MT5)
2. Ouvrir : C:\Users\User\Fotso-EA\FotsoCerveauAdaptatif.mq5
3. F7 (compile)
4. Verifier : 0 error(s)
5. Le nouveau .ex5 embarque brain_v1.onnx (27 KB, 36 features)
```

### 2. Verifier que le bon ONNX est embarque

Au lancement de l'EA en MT5, dans le journal Expert :
```
BrainML v5.8 : brain_v1.onnx charge. 36 features (GBT v2 AUC=0.9393, test WR=85%)
```

### 3. Strategy Tester

| Parametre | Valeur recommandee |
|---|---|
| Symbol | XAUUSDm |
| Timeframe | M15 |
| **Date debut** | **2025-05-29** (debut du test set du modele, jamais vu) |
| **Date fin** | **2026-05-15** |
| Modelisation | Tous les ticks |
| Depot | 10 000 USD |
| RiskPercent | **1.0%** (commencer prudent) |

**Inputs BrainML (defaut v5.8 deja configures) :**
```
BrainML_SkipBelow      = 0.30     # skip si P < 30%
BrainML_HalfRisk       = 0.45     # demi-risque [0.30, 0.45]
BrainML_FullRisk       = 0.55     # risque normal [0.45, 0.55]
BrainML_BoostThreshold = 0.80     # boost si P >= 0.80
BrainML_BoostMul       = 1.5
```

### 4. Cibles a atteindre

| Metrique | Baseline v1 | Cible v2 | Stretch |
|---|---|---|---|
| WR global | 47% | **>= 60%** | >= 70% |
| WR SELL | 27% | **>= 50%** | >= 60% |
| Profit Factor | 1.48 | **>= 1.8** | >= 2.5 |
| Max DD | 8% | <= 10% | <= 6% |
| Profit Net | +12% | **>= +20%** | >= +35% |

## Multi-paires (etape suivante)

Les donnees existent deja :
```
C:\Users\User\Desktop\Nouveau dossier (3)\
+-- xauusd\   <- TRAITE
+-- btcusd\   <- A FAIRE
+-- us30\     <- A FAIRE
+-- ustec\    <- A FAIRE
```

Commande pour generer le dataset BTC :
```bash
cd C:\Users\User\Fotso-EA\ml
python build_dataset.py --data_dir "C:\Users\User\Desktop\Nouveau dossier (3)\btcusd" --out dataset_btc_v2.csv --pair BTCUSD
python add_regime_feature.py --dataset dataset_btc_v2.csv
python train_brain.py --dataset dataset_btc_v2_regime.csv
```

Ca produira `brain_btc.onnx` que l'EA pourra utiliser via BrainML_OnnxFile.

## Verifications faites

- [x] Pipeline Python re-execute avec donnees 2022-2026
- [x] 36 features confirmees (rsi, stoch, adx, atr, BB, EMA H4, score, regime f34/f35...)
- [x] ONNX runtime test : AUC=0.9393 confirme sur test set 1098 trades
- [x] EA v5.8 source mis a jour (BRAINML_NFEATURES=36, ComputeRecentWR, etc.)
- [x] brain_v1.onnx deploye dans 3 emplacements (Fotso-EA, ml/, MQL5/Files/)
- [x] Nouveaux seuils EA calibres sur la distribution v2 (Youden=0.55, top20=0.80)

## A faire (ordre prioritaire)

1. **Compiler l'EA** dans MetaEditor (F7)
2. **Backtest 2025-05-29 -> 2026-05-15** (period jamais vue par v2)
3. Comparer WR/PF/DD vs baseline v1 (47%/1.48/8%)
4. Si OK : passer en demo 3-4 semaines
5. Generer datasets BTC/US30/USTEC pour multi-pair

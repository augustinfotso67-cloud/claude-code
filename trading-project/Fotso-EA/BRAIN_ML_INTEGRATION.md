# BrainML Integration Guide — FotsoCerveauAdaptatif v5.8

## Résultats du modèle brain_v1.onnx

| Seuil | Val WR  | Test WR | Trades gardés |
|-------|---------|---------|----------------|
| 0.10  | 76.8%   | 63.2%   | 57%            |
| 0.25  | 87.2%   | 80.3%   | 39%            |
| 0.40  | 90.6%   | 89.1%   | 28%            |
| 0.50  | 92.4%   | **93.2%** | 20%          |

- **AUC validation : 0.9302 | AUC test : 0.9247**
- Période test : Oct 2025 – Mar 2026 (non vu pendant l'entraînement)
- WR baseline test : 37.7% → avec modèle à thr=0.25 : **80.3%**

## Paramètres EA (v5.8)

```
UseBrainML        = true
BrainML_OnnxFile  = brain_v1.onnx       // placer dans MQL5/Files/
BrainML_SkipBelow = 0.10                // skip si P(WIN) < 10%
BrainML_HalfRisk  = 0.17                // demi-risque si P in [0.10, 0.17]
BrainML_FullRisk  = 0.25                // risque normal si P >= 0.25
BrainML_BoostMul  = 1.5                 // boost si P >= 0.50 (93% WR!)
BrainML_LogProba  = true
```

## IMPORTANT : 2 nouvelles features à ajouter dans MQL5 (v5.8)

Le modèle attend **36 features** (vs 34 en v5.7.1). Les 2 nouvelles (f34, f35) sont :
- **f34** = WR des 20 derniers signaux FERMÉS
- **f35** = WR des 5 derniers signaux FERMÉS

Ces features capturent le régime de marché : si les derniers signaux ont bien
performé, le marché est en tendance favorable. C'est la feature la plus
importante (65.57% du poids du modèle).

### Code MQL5 à ajouter dans la fonction BrainML_BuildInput()

```mql5
// NOUVEAU dans v5.8 : features de regime (f34, f35)
// Calculer le WR des N derniers signaux fermes
double ComputeRecentWR(int n)
{
    int count = 0;
    int wins  = 0;
    // Parcourir gSignaux[] du plus recent au plus ancien
    for(int k = ArraySize(gSignaux) - 1; k >= 0 && count < n; k--)
    {
        if(!gSignaux[k].closed) continue;  // ignorer les signaux encore ouverts
        wins  += gSignaux[k].result_tp1 ? 1 : 0;
        count++;
    }
    return count > 0 ? (double)wins / count : 0.5;  // 0.5 si pas d'historique
}

// Dans BrainML_BuildInput() ou OuvrirTrade() avant l'appel ONNX :
input_tensor[34] = (float)ComputeRecentWR(20);  // f34 : recent_wr_20
input_tensor[35] = (float)ComputeRecentWR(5);   // f35 : recent_wr_5
```

### Structure gSignaux à vérifier/ajouter

```mql5
struct SignalRecord {
    datetime open_time;
    datetime close_time;
    bool     closed;      // trade fermé (TP1, TP2 ou SL)
    bool     result_tp1;  // TP1 atteint = WIN
    int      direction;   // 1=BUY, -1=SELL
    double   score_base;
    double   proba_ml;    // probabilité brain_v1.onnx
};
gSignaux SignalRecord[];  // tableau circulaire des derniers signaux
```

## Vecteur de features complet (36 dimensions)

| Index | Nom              | Source        | Formule |
|-------|------------------|---------------|---------|
| f00   | rsi_h1_norm      | RSI H1        | rsi / 100 |
| f01   | stoch_k_norm     | Stoch K M15   | K / 100 |
| f02   | stoch_d_norm     | Stoch D M15   | D / 100 |
| f03   | adx_h1_norm      | ADX H1        | adx / 100 |
| f04   | adxplus_h1_norm  | DI+ H1        | DI+ / 100 |
| f05   | adxminus_h1_norm | DI- H1        | DI- / 100 |
| f06   | adx_h4_norm      | ADX H4        | adx / 100 |
| f07   | atr_m15_rel      | ATR M15/Price | ATR_M15 / close |
| f08   | atr_h1_rel       | ATR H1/Price  | ATR_H1 / close |
| f09   | atr_h4_rel       | ATR H4/Price  | ATR_H4 / close |
| f10   | ema200d1_dist    | EMA200 D1     | (close - EMA200_D1) / EMA200_D1 * 100 |
| f11   | bb_pos           | BB H1         | (close - BB_mid) / (BB_up - BB_lo) |
| f12   | bb_squeeze       | BB H1         | BB_width / BB_width_avg20 |
| f13   | atr_ratio_h1     | ATR H1        | ATR_H1 / ATR_H1_avg20 |
| f14   | h4_ema200_slope  | EMA200 H4     | (EMA200_H4 - EMA200_H4[5]) / ATR_H4 |
| f15   | h4_ema50_slope   | EMA50 H4      | (EMA50_H4 - EMA50_H4[5]) / ATR_H4 |
| f16   | price_to_h4_ema200 | H4          | (close - EMA200_H4) / ATR_H4 |
| f17   | price_to_h4_ema50  | H4          | (close - EMA50_H4) / ATR_H4 |
| f18   | hour_sin         | Heure         | sin(2*pi*hour/24) |
| f19   | hour_cos         | Heure         | cos(2*pi*hour/24) |
| f20   | dow_sin          | Jour          | sin(2*pi*dow/7) |
| f21   | dow_cos          | Jour          | cos(2*pi*dow/7) |
| f22   | context_score    | ContextScore  | scoreHeure * scoreJour |
| f23   | direction        | Signal        | 1=BUY, 0=SELL |
| f24   | is_pullback      | Signal        | 1=pullback CT, 0=tendance |
| f25   | score_base_norm  | Score EA      | score_base / 6 |
| f26   | score_bonus_norm | Score EA      | score_bonus / 7 |
| f27   | adn_phase_norm   | ADN           | phase / 4 |
| f28   | psy_retour       | PSY           | 1=retournement PSY |
| f29   | psy_dir_haussier | PSY           | 1=direction haussiere PSY |
| f30   | mi_manip         | Miroir Inst.  | 1=manipulation detectee |
| f31   | bos_signal       | BOS H1        | 1=BOS dans direction du signal |
| f32   | near_level       | Niveaux H1    | 1=proche support/resistance |
| f33   | spread_ratio     | Spread        | spread_pts / ATR_M15_pts |
| **f34** | **recent_wr_20** | **REGIME** | **WR des 20 derniers signaux fermes** |
| **f35** | **recent_wr_5**  | **REGIME** | **WR des 5 derniers signaux fermes** |

## Procédure de déploiement

1. Copier `brain_v1.onnx` → `MQL5/Files/brain_v1.onnx` sur le serveur MT5
2. Modifier `FotsoCerveauAdaptatif.mq5` :
   - Changer la taille du vecteur ONNX de 34 à 36
   - Ajouter `ComputeRecentWR()` 
   - Ajouter le calcul de f34/f35 dans `OuvrirTrade()` avant l'appel ONNX
3. Paramétrer l'EA avec les valeurs ci-dessus
4. Backtest Strategy Tester : Jan 2025 – Avr 2026 pour valider

## Prochaines étapes pour améliorer le modèle

1. **Re-exporter les données MT5** depuis 2019 (5+ ans) → dataset beaucoup plus riche
2. **Signaux SELL** : avec plus de données couvrant des cycles baissiers, le modèle apprendra les régimes baissiers
3. **XGBoost** (quand pip réseau disponible) : remplacera GBT sklearn, meilleure généralisation
4. **Multi-paires** : BTCUSD, USTEC, US30 → données disponibles, lancer build_dataset.py avec --pair BTC etc.

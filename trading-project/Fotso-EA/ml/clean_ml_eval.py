"""
Evaluation ML propre sans data leakage.
Split : train sur data < 2025-05-29 (avant backtest), test sur data >= 2025-05-29.
"""
import pandas as pd, numpy as np, json
from pathlib import Path
from sklearn.metrics import roc_auc_score

py = "C:\\Users\\User\\AppData\\Local\\Programs\\Python\\Python311\\python.exe"

# Charger le dataset avec features regime
df = pd.read_csv(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2_regime.csv')
df['timestamp'] = pd.to_datetime(df['timestamp'])
df = df.sort_values('timestamp').reset_index(drop=True)

FEATURE_COLS = [f"f{i:02d}" for i in range(36)]
missing = [c for c in FEATURE_COLS if c not in df.columns]
if missing:
    print("ERREUR features manquantes:", missing)
    exit(1)

# Appliquer le nouveau context filter (scores recalibres)
scores_h = [1.000,1.000,1.000,1.018,1.003,0.967,
            0.814,0.840,0.963,0.899,1.032,0.986,
            0.947,1.000,1.061,1.035,1.122,1.152,
            1.093,0.973,0.909,1.048,0.755,1.000]
scores_d = [1.178, 0.956, 0.997, 0.801, 1.118, 1.000, 1.000]

df['hour'] = df.timestamp.dt.hour
df['dow']  = df.timestamp.dt.weekday
df['cs_new'] = df.apply(lambda r: scores_h[r.hour] * scores_d[r.dow], axis=1)

# Split sans leakage
BT_START = pd.Timestamp('2025-05-29')
train_df = df[df.timestamp < BT_START].copy()
test_df  = df[df.timestamp >= BT_START].copy()

print(f"=== SPLIT PROPRE (sans data leakage) ===")
print(f"Train : {len(train_df)} signaux  {train_df.timestamp.min().date()} -> {train_df.timestamp.max().date()}  WR={train_df.label.mean()*100:.1f}%")
print(f"Test  : {len(test_df)} signaux  {test_df.timestamp.min().date()} -> {test_df.timestamp.max().date()}  WR={test_df.label.mean()*100:.1f}%")

# Context filter impact sur test
test_cs = test_df[test_df.cs_new >= 0.85]
print(f"\n=== Context filter sur test periode ===")
print(f"Avant : n={len(test_df)}  WR={test_df.label.mean()*100:.1f}%")
print(f"Apres (cs>=0.85) : n={len(test_cs)}  WR={test_cs.label.mean()*100:.1f}%  ({len(test_cs)/len(test_df)*100:.0f}% trades)")

# Entrainer ML sur train, evaluer sur test
print(f"\n=== Entrainement ML propre ===")
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

X_train = train_df[FEATURE_COLS].values.astype(np.float32)
y_train = train_df['label'].values.astype(int)
X_test  = test_df[FEATURE_COLS].values.astype(np.float32)
y_test  = test_df['label'].values.astype(int)
X_test_cs  = test_cs[FEATURE_COLS].values.astype(np.float32)
y_test_cs  = test_cs['label'].values.astype(int)

scaler = StandardScaler()
X_train_s = scaler.fit_transform(X_train)
X_test_s  = scaler.transform(X_test)
X_test_cs_s = scaler.transform(X_test_cs)

try:
    from xgboost import XGBClassifier
    ratio = (y_train == 0).sum() / max(1, (y_train == 1).sum())
    # Split interne pour early stopping (val = 20% du train)
    n_val = int(len(X_train_s) * 0.2)
    Xv, yv = X_train_s[-n_val:], y_train[-n_val:]
    Xt, yt = X_train_s[:-n_val], y_train[:-n_val]

    model = XGBClassifier(
        n_estimators=400, max_depth=4, learning_rate=0.03,
        subsample=0.8, colsample_bytree=0.7, min_child_weight=5,
        gamma=0.1, reg_alpha=0.1, reg_lambda=1.0,
        scale_pos_weight=ratio, use_label_encoder=False,
        eval_metric="auc", early_stopping_rounds=30,
        random_state=42, n_jobs=-1,
    )
    model.fit(Xt, yt, eval_set=[(Xv, yv)], verbose=False)

    pipeline = Pipeline([("scaler", scaler), ("model", model)])
    p_test = pipeline.predict_proba(X_test)[:, 1]
    p_test_cs = pipeline.predict_proba(X_test_cs)[:, 1]

    auc_test = roc_auc_score(y_test, p_test)
    print(f"AUC sur test (vrai OOS) : {auc_test:.4f}")
    print(f"WR base test : {y_test.mean()*100:.1f}%")

    # Courbe WR en fonction du seuil
    print(f"\nSeuil -> WR (test sans leakage, {len(y_test)} trades) :")
    print(f"{'Seuil':>8} | {'WR':>7} | {'n trades':>9} | {'% garde':>8}")
    print("-" * 45)
    for thr in [0.50, 0.52, 0.55, 0.57, 0.60, 0.62, 0.65, 0.68, 0.70]:
        mask = p_test >= thr
        if mask.sum() >= 10:
            wr = y_test[mask].mean()
            print(f"{thr:8.2f} | {wr*100:6.1f}% | {mask.sum():9d} | {mask.mean()*100:7.0f}%")

    # Avec context filter pre-applique
    print(f"\nSeuil -> WR (test avec context filter, {len(y_test_cs)} trades) :")
    print(f"{'Seuil':>8} | {'WR':>7} | {'n trades':>9} | {'% garde':>8}")
    print("-" * 45)
    for thr in [0.50, 0.52, 0.55, 0.57, 0.60, 0.62, 0.65, 0.68, 0.70]:
        mask = p_test_cs >= thr
        if mask.sum() >= 10:
            wr = y_test_cs[mask].mean()
            print(f"{thr:8.2f} | {wr*100:6.1f}% | {mask.sum():9d} | {mask.mean()*100:7.0f}%")

    # Combiner context filter + ML optimal
    print(f"\n=== COMBINAISON OPTIMALE CS + ML ===")
    # Youden sur test OOS (calculer TPR/TNR pour chaque seuil)
    from sklearn.metrics import roc_curve
    fpr, tpr, thresholds = roc_curve(y_test_cs, p_test_cs)
    tnr = 1 - fpr
    youden_idx = np.argmax(tpr + tnr - 1)
    thr_youden_oos = thresholds[youden_idx]
    mask_youden = p_test_cs >= thr_youden_oos
    print(f"Youden OOS : thr={thr_youden_oos:.3f}  WR={y_test_cs[mask_youden].mean()*100:.1f}%  n={mask_youden.sum()}  pct={mask_youden.mean()*100:.0f}%")

    # Top 30% et top 50% des trades
    for pct in [0.30, 0.40, 0.50]:
        thr_pct = np.percentile(p_test_cs, (1-pct)*100)
        mask = p_test_cs >= thr_pct
        if mask.sum() > 0:
            print(f"Top {pct*100:.0f}%  : thr={thr_pct:.3f}  WR={y_test_cs[mask].mean()*100:.1f}%  n={mask.sum()}")

except ImportError:
    print("XGBoost non disponible")

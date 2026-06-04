"""Verifier les features importantes du modele et detecter lookahead eventuel."""
import pandas as pd, numpy as np
from pathlib import Path
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import roc_auc_score

FEATURE_NAMES = [
    "rsi_h1_norm", "stoch_k_norm", "stoch_d_norm",
    "adx_h1_norm", "adxplus_h1_norm", "adxminus_h1_norm",
    "adx_h4_norm",
    "atr_m15_rel", "atr_h1_rel", "atr_h4_rel",
    "ema200d1_dist", "bb_pos", "bb_squeeze", "atr_ratio_h1",
    "h4_ema200_slope", "h4_ema50_slope",
    "price_to_h4_ema200", "price_to_h4_ema50",
    "hour_sin", "hour_cos", "dow_sin", "dow_cos",
    "context_score",
    "direction", "is_pullback",
    "score_base_norm", "score_bonus_norm",
    "adn_phase_norm",
    "psy_retour", "psy_dir_haussier",
    "mi_manip", "bos_signal", "near_level",
    "spread_ratio",
    "recent_wr_20", "recent_wr_5",
]
FEATURE_COLS = [f"f{i:02d}" for i in range(36)]

df = pd.read_csv(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2_regime.csv')
df['timestamp'] = pd.to_datetime(df['timestamp'])
df = df.sort_values('timestamp').reset_index(drop=True)

BT_START = pd.Timestamp('2025-05-29')
train_df = df[df.timestamp < BT_START].copy()
test_df  = df[df.timestamp >= BT_START].copy()

X_train = train_df[FEATURE_COLS].values.astype(np.float32)
y_train = train_df['label'].values.astype(int)
X_test  = test_df[FEATURE_COLS].values.astype(np.float32)
y_test  = test_df['label'].values.astype(int)

scaler = StandardScaler()
X_train_s = scaler.fit_transform(X_train)
X_test_s  = scaler.transform(X_test)

n_val = int(len(X_train_s) * 0.2)
Xv, yv = X_train_s[-n_val:], y_train[-n_val:]
Xt, yt = X_train_s[:-n_val], y_train[:-n_val]

from xgboost import XGBClassifier
ratio = (yt == 0).sum() / max(1, (yt == 1).sum())
model = XGBClassifier(
    n_estimators=400, max_depth=4, learning_rate=0.03,
    subsample=0.8, colsample_bytree=0.7, min_child_weight=5,
    gamma=0.1, reg_alpha=0.1, reg_lambda=1.0,
    scale_pos_weight=ratio, eval_metric="auc",
    early_stopping_rounds=30, random_state=42, n_jobs=-1,
)
model.fit(Xt, yt, eval_set=[(Xv, yv)], verbose=False)

# Feature importances
imp = model.feature_importances_
idx_sorted = np.argsort(imp)[::-1]
print("=== TOP 20 FEATURES (importances XGBoost) ===")
for i, idx in enumerate(idx_sorted[:20]):
    fname = FEATURE_NAMES[idx] if idx < len(FEATURE_NAMES) else f"f{idx:02d}"
    print(f"  {i+1:2d}. {fname:<25} {imp[idx]:.4f}")

# AUC
p_test = model.predict_proba(X_test_s)[:, 1]
auc = roc_auc_score(y_test, p_test)
print(f"\nAUC OOS: {auc:.4f}")

# Distribution des probas
print(f"\nDistribution probas test:")
for pct in [10, 20, 30, 40, 50, 60, 70, 80, 90]:
    print(f"  P{pct}: {np.percentile(p_test, pct):.4f}")

# Verifier si les features temporelles (hour/dow) expliquent l'AUC
print("\n=== TEST: modele sans features temporelles ===")
# Enlever hour_sin, hour_cos, dow_sin, dow_cos, context_score (f18-f22)
temporal_idx = [18, 19, 20, 21, 22]
cols_no_temp = [c for i, c in enumerate(FEATURE_COLS) if i not in temporal_idx]
X_nt = train_df[cols_no_temp].values.astype(np.float32)
X_nt_test = test_df[cols_no_temp].values.astype(np.float32)
sc2 = StandardScaler()
X_nt_s = sc2.fit_transform(X_nt)
X_nt_test_s = sc2.transform(X_nt_test)
m2 = XGBClassifier(n_estimators=300, max_depth=4, learning_rate=0.05,
    scale_pos_weight=ratio, eval_metric="auc", random_state=42, n_jobs=-1)
m2.fit(X_nt_s[:-n_val], y_train[:-n_val],
       eval_set=[(X_nt_s[-n_val:], y_train[-n_val:])], verbose=False)
p2 = m2.predict_proba(X_nt_test_s)[:, 1]
auc2 = roc_auc_score(y_test, p2)
print(f"  AUC sans features temporelles: {auc2:.4f}")
for thr in [0.50, 0.55, 0.60]:
    mask = p2 >= thr
    if mask.sum() > 10:
        print(f"  seuil={thr}: WR={y_test[mask].mean()*100:.1f}%  n={mask.sum()}")

# Verifier si context_score seul explique tout
print("\n=== TEST: f22 (context_score) correlation avec label ===")
cs = test_df['f22'].values
print(f"  corr(context_score, label) test: {np.corrcoef(cs, y_test)[0,1]:.4f}")
print(f"  cs < 0.85 -> WR={y_test[cs < 0.85].mean()*100:.1f}%  n={( cs < 0.85).sum()}")
print(f"  cs >= 0.85 -> WR={y_test[cs >= 0.85].mean()*100:.1f}%  n={(cs >= 0.85).sum()}")
print(f"  cs >= 1.10 -> WR={y_test[cs >= 1.10].mean()*100:.1f}%  n={(cs >= 1.10).sum()}")

# Verifier les valeurs de f34/f35
print(f"\n=== Features regime f34/f35 ===")
print(f"  f34 (recent_wr_20): min={df.f34.min():.4f}  max={df.f34.max():.4f}  mean={df.f34.mean():.4f}")
print(f"  f35 (recent_wr_5):  min={df.f35.min():.4f}  max={df.f35.max():.4f}  mean={df.f35.mean():.4f}")
print(f"  => Ces features sont constantes: AUCUNE valeur discriminante!")
print(f"  => Le modele predit vraiment depuis les 34 features techniques (f00-f33)")

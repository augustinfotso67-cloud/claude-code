"""
Retrain ML sans data leakage + export ONNX pour EA v5.9.
Train: 2022-02 -> 2025-05-23 (avant backtest)
Test:  2025-05-29 -> 2026-05-12 (periode backtest = vrai OOS)

Sortie: brain_v2_clean.onnx + brain_v2_clean_meta.json
"""
import json, warnings
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import roc_auc_score, roc_curve

warnings.filterwarnings("ignore")

N_FEATURES = 36
FEATURE_COLS = [f"f{i:02d}" for i in range(N_FEATURES)]
FEATURE_NAMES = [
    "rsi_h1_norm","stoch_k_norm","stoch_d_norm",
    "adx_h1_norm","adxplus_h1_norm","adxminus_h1_norm",
    "adx_h4_norm",
    "atr_m15_rel","atr_h1_rel","atr_h4_rel",
    "ema200d1_dist","bb_pos","bb_squeeze","atr_ratio_h1",
    "h4_ema200_slope","h4_ema50_slope",
    "price_to_h4_ema200","price_to_h4_ema50",
    "hour_sin","hour_cos","dow_sin","dow_cos",
    "context_score",
    "direction","is_pullback",
    "score_base_norm","score_bonus_norm",
    "adn_phase_norm",
    "psy_retour","psy_dir_haussier",
    "mi_manip","bos_signal","near_level",
    "spread_ratio",
    "recent_wr_20","recent_wr_5",
]

# ── Charger dataset ────────────────────────────────────────────────
df = pd.read_csv(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2_regime.csv')
df['timestamp'] = pd.to_datetime(df['timestamp'])
df = df.sort_values('timestamp').reset_index(drop=True)

# Split propre : cutoff = debut backtest
BT_START = pd.Timestamp('2025-05-29')
train_df = df[df.timestamp < BT_START].copy()
test_df  = df[df.timestamp >= BT_START].copy()

print("=== SPLIT PROPRE ===")
print(f"Train: {len(train_df)} ({train_df.timestamp.min().date()} -> {train_df.timestamp.max().date()}) WR={train_df.label.mean()*100:.1f}%")
print(f"Test:  {len(test_df)} ({test_df.timestamp.min().date()} -> {test_df.timestamp.max().date()}) WR={test_df.label.mean()*100:.1f}%")

# Sur le train: 80% train / 20% val pour early stopping
n_tr = len(train_df)
n_val = int(n_tr * 0.20)
tr_df = train_df.iloc[:-n_val]
val_df = train_df.iloc[-n_val:]

X_tr  = tr_df[FEATURE_COLS].values.astype(np.float32)
y_tr  = tr_df['label'].values.astype(int)
X_val = val_df[FEATURE_COLS].values.astype(np.float32)
y_val = val_df['label'].values.astype(int)
X_tst = test_df[FEATURE_COLS].values.astype(np.float32)
y_tst = test_df['label'].values.astype(int)

scaler = StandardScaler()
X_tr_s  = scaler.fit_transform(X_tr)
X_val_s = scaler.transform(X_val)
X_tst_s = scaler.transform(X_tst)

# ── Entrainement XGB ───────────────────────────────────────────────
from xgboost import XGBClassifier
ratio = (y_tr == 0).sum() / max(1, (y_tr == 1).sum())

model = XGBClassifier(
    n_estimators=500, max_depth=4, learning_rate=0.02,
    subsample=0.8, colsample_bytree=0.7, min_child_weight=5,
    gamma=0.1, reg_alpha=0.1, reg_lambda=1.0,
    scale_pos_weight=ratio, eval_metric="auc",
    early_stopping_rounds=40, random_state=42, n_jobs=-1,
)
model.fit(X_tr_s, y_tr, eval_set=[(X_val_s, y_val)], verbose=False)
print(f"\nXGB best_iteration: {model.best_iteration}  val_AUC: {model.best_score:.4f}")

pipeline = Pipeline([("scaler", scaler), ("model", model)])
p_tst = pipeline.predict_proba(X_tst)[:, 1]
auc   = roc_auc_score(y_tst, p_tst)
print(f"AUC test OOS: {auc:.4f}")

# ── Percentiles train pour seuils production ───────────────────────
p_tr_all = pipeline.predict_proba(np.vstack([X_tr, X_val]))[:, 1]
p60 = float(np.percentile(p_tr_all, 60))
p70 = float(np.percentile(p_tr_all, 70))
p80 = float(np.percentile(p_tr_all, 80))
p90 = float(np.percentile(p_tr_all, 90))
print(f"\nDistrib train: P60={p60:.4f} P70={p70:.4f} P80={p80:.4f} P90={p90:.4f}")

# ── Youden sur test OOS ────────────────────────────────────────────
fpr, tpr, thrs = roc_curve(y_tst, p_tst)
youden_idx = np.argmax(tpr + (1-fpr) - 1)
thr_youden = float(thrs[youden_idx])
mask_y = p_tst >= thr_youden
wr_y   = y_tst[mask_y].mean() if mask_y.sum() > 0 else 0
print(f"Seuil Youden OOS: {thr_youden:.3f}  WR={wr_y*100:.1f}%  n={mask_y.sum()}  pct={mask_y.mean()*100:.0f}%")

# ── Rapports par seuil ────────────────────────────────────────────
print(f"\n{'Seuil':>8} | {'WR':>7} | {'n':>6} | {'%':>5}")
print("-"*35)
for thr in [0.48, 0.50, 0.52, 0.55, 0.57, 0.60, 0.62, 0.65, 0.68, 0.70, 0.72, 0.75]:
    mask = p_tst >= thr
    if mask.sum() >= 15:
        print(f"{thr:8.2f} | {y_tst[mask].mean()*100:6.1f}% | {mask.sum():6d} | {mask.mean()*100:4.0f}%")

# ── Feature importances ───────────────────────────────────────────
imp = model.feature_importances_
top10 = np.argsort(imp)[::-1][:10]
print("\nTop 10 features:")
for i, idx in enumerate(top10):
    nm = FEATURE_NAMES[idx] if idx < len(FEATURE_NAMES) else f"f{idx:02d}"
    print(f"  {i+1:2d}. {nm:<25} {imp[idx]:.4f}")

# ── Export ONNX ───────────────────────────────────────────────────
out_path = r'C:\Users\User\Fotso-EA\ml\brain_v2_clean.onnx'
print(f"\n=== Export ONNX -> {out_path} ===")
try:
    from skl2onnx import convert_sklearn, update_registered_converter
    from skl2onnx.common.data_types import FloatTensorType
    from skl2onnx.common.shape_calculator import calculate_linear_classifier_output_shapes
    from xgboost import XGBClassifier as _XGB
    from onnxmltools.convert.xgboost.operator_converters.XGBoost import convert_xgboost
    update_registered_converter(
        _XGB, "XGBoostXGBClassifier",
        calculate_linear_classifier_output_shapes,
        convert_xgboost,
        options={"nocl": [True, False], "zipmap": [True, False, "columns"]},
    )
    # opset 12 = max compatible MT5 (MT5 ONNX runtime supporte jusqu'à ~15,
    # mais opset 13+ peut causer des problèmes selon la version du runtime embarqué)
    onnx_model = convert_sklearn(
        pipeline,
        initial_types=[("float_input", FloatTensorType([None, N_FEATURES]))],
        options={id(pipeline): {"zipmap": False}},
        target_opset={"": 12, "ai.onnx.ml": 2},
    )
    with open(out_path, "wb") as f:
        f.write(onnx_model.SerializeToString())
    print(f"  OK: {Path(out_path).stat().st_size / 1024:.0f} KB")
    onnx_ok = True
except Exception as e:
    print(f"  ERREUR skl2onnx: {e}")
    # fallback natif XGBoost
    try:
        model.save_model(out_path)
        print(f"  OK (natif XGB): {Path(out_path).stat().st_size / 1024:.0f} KB")
        onnx_ok = True
    except Exception as e2:
        print(f"  ERREUR fallback: {e2}")
        onnx_ok = False

# ── Meta ──────────────────────────────────────────────────────────
meta = {
    "model_type": "xgb_clean",
    "n_features": N_FEATURES,
    "feature_names": FEATURE_NAMES,
    "train_cutoff": str(BT_START.date()),
    "threshold_youden": round(thr_youden, 4),
    "train_proba_p60": round(p60, 4),
    "train_proba_p70": round(p70, 4),
    "train_proba_p80": round(p80, 4),
    "train_proba_p90": round(p90, 4),
    "perf_test_youden": {
        "wr_filtered": round(float(wr_y), 4),
        "n_filtered": int(mask_y.sum()),
        "pct_kept": round(float(mask_y.mean()), 4),
        "auc": round(auc, 4),
    },
}
meta_path = r'C:\Users\User\Fotso-EA\ml\brain_v2_clean_meta.json'
with open(meta_path, "w") as f:
    json.dump(meta, f, indent=2)
print(f"Meta: {meta_path}")

# ── Sortie EA ─────────────────────────────────────────────────────
print(f"\n{'='*60}")
print("PARAMETRES EA a utiliser (brain_v2_clean.onnx):")
print(f"  BrainML_SkipBelow = {p60:.4f}  // P60 train (top 40% -> gate)")
print(f"  BrainML_HalfRisk  = {p70:.4f}  // P70 train")
print(f"  BrainML_FullRisk  = {p80:.4f}  // P80 train")
print(f"  BrainML_BoostThreshold = {p90:.4f}  // P90 train")
print(f"  Test WR@P60: {y_tst[p_tst >= p60].mean()*100:.1f}%  n={( p_tst >= p60).sum()}")
print(f"  Test WR@P70: {y_tst[p_tst >= p70].mean()*100:.1f}%  n={( p_tst >= p70).sum()}")
print(f"  Test WR@Youden({thr_youden:.3f}): {wr_y*100:.1f}%  n={mask_y.sum()}")
print(f"  AUC OOS = {auc:.4f}")
print(f"{'='*60}")

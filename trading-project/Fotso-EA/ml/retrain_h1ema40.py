"""
retrain_h1ema40.py — Ré-entraînement XGB sur signaux H1 EMA40 + export ONNX
Dataset : dataset_xau_v3_h1ema40.csv (généré par build_dataset_h1ema40.py)
Split   : train < 2025-05-29, test >= 2025-05-29 (même split que v2_clean)
Sortie  : brain_v3_h1ema40.onnx + brain_v3_h1ema40_meta.json
"""
import json, warnings
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import roc_auc_score, roc_curve
from xgboost import XGBClassifier

warnings.filterwarnings("ignore")

N_FEATURES   = 36
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
    "context_score","direction","is_pullback",
    "score_base_norm","score_bonus_norm","adn_phase_norm",
    "psy_retour","psy_dir_haussier",
    "mi_manip","bos_signal","near_level","spread_ratio",
    "recent_wr_20","recent_wr_5",
]

DATASET_PATH = r"C:\Users\User\Fotso-EA\ml\dataset_xau_v3_h1ema40.csv"
OUT_ONNX     = r"C:\Users\User\Fotso-EA\ml\brain_v3_h1ema40.onnx"
OUT_META     = r"C:\Users\User\Fotso-EA\ml\brain_v3_h1ema40_meta.json"
BT_START     = pd.Timestamp("2025-05-29")

# ── Charger dataset ──────────────────────────────────────────────────
df = pd.read_csv(DATASET_PATH)
df["timestamp"] = pd.to_datetime(df["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)

train_df = df[df.timestamp < BT_START].copy()
test_df  = df[df.timestamp >= BT_START].copy()

print("=== SPLIT ===")
print(f"Train: {len(train_df)} ({train_df.timestamp.min().date()} -> {train_df.timestamp.max().date()})")
print(f"  WR={train_df.label.mean()*100:.1f}%  "
      f"BUY={train_df[train_df.direction=='BUY'].label.mean()*100:.1f}%  "
      f"SELL={train_df[train_df.direction=='SELL'].label.mean()*100:.1f}%")
print(f"Test : {len(test_df)}  ({test_df.timestamp.min().date()} -> {test_df.timestamp.max().date()})")
print(f"  WR={test_df.label.mean()*100:.1f}%  "
      f"BUY={test_df[test_df.direction=='BUY'].label.mean()*100:.1f}%  "
      f"SELL={test_df[test_df.direction=='SELL'].label.mean()*100:.1f}%")

n_tr  = len(train_df)
n_val = int(n_tr * 0.20)
tr_df  = train_df.iloc[:-n_val]
val_df = train_df.iloc[-n_val:]

X_tr  = tr_df[FEATURE_COLS].values.astype(np.float32)
y_tr  = tr_df["label"].values.astype(int)
X_val = val_df[FEATURE_COLS].values.astype(np.float32)
y_val = val_df["label"].values.astype(int)
X_tst = test_df[FEATURE_COLS].values.astype(np.float32)
y_tst = test_df["label"].values.astype(int)

scaler = StandardScaler()
X_tr_s  = scaler.fit_transform(X_tr)
X_val_s = scaler.transform(X_val)
X_tst_s = scaler.transform(X_tst)

ratio = (y_tr == 0).sum() / max(1, (y_tr == 1).sum())
print(f"\nscale_pos_weight = {ratio:.3f}")

model = XGBClassifier(
    n_estimators=600, max_depth=4, learning_rate=0.015,
    subsample=0.8, colsample_bytree=0.7, min_child_weight=5,
    gamma=0.1, reg_alpha=0.1, reg_lambda=1.0,
    scale_pos_weight=ratio, eval_metric="auc",
    early_stopping_rounds=50, random_state=42, n_jobs=-1,
)
model.fit(X_tr_s, y_tr, eval_set=[(X_val_s, y_val)], verbose=False)
print(f"XGB best_iteration={model.best_iteration}  val_AUC={model.best_score:.4f}")

pipeline = Pipeline([("scaler", scaler), ("model", model)])
p_tst = pipeline.predict_proba(X_tst)[:, 1]
auc   = roc_auc_score(y_tst, p_tst)
print(f"AUC test OOS: {auc:.4f}")

# ── Percentiles train ────────────────────────────────────────────────
p_tr_all = pipeline.predict_proba(np.vstack([X_tr, X_val]))[:, 1]
p50 = float(np.percentile(p_tr_all, 50))
p60 = float(np.percentile(p_tr_all, 60))
p70 = float(np.percentile(p_tr_all, 70))
p80 = float(np.percentile(p_tr_all, 80))
p90 = float(np.percentile(p_tr_all, 90))
print(f"Distrib train: P50={p50:.4f} P60={p60:.4f} P70={p70:.4f} P80={p80:.4f} P90={p90:.4f}")

# ── Youden sur test OOS ──────────────────────────────────────────────
fpr, tpr, thrs = roc_curve(y_tst, p_tst)
youden_idx  = np.argmax(tpr + (1-fpr) - 1)
thr_youden  = float(thrs[youden_idx])
mask_y      = p_tst >= thr_youden
wr_y        = y_tst[mask_y].mean() if mask_y.sum() > 0 else 0
print(f"Seuil Youden: {thr_youden:.3f}  WR={wr_y*100:.1f}%  n={mask_y.sum()}  pct={mask_y.mean()*100:.0f}%")

# ── Table WR par gate ─────────────────────────────────────────────────
N_BASE   = len(test_df)
print(f"\n=== VOLUME vs WR (base = {N_BASE} signaux H1 EMA40 OOS) ===")
print(f"{'Gate':>6} | {'WR':>7} | {'WR BUY':>8} | {'WR SELL':>8} | {'%pass':>6} | {'n':>5}")
print("-"*58)
buy_mask_tst  = test_df["direction"].values == "BUY"
sell_mask_tst = ~buy_mask_tst
for thr in [0.35, 0.38, 0.40, 0.42, 0.45, 0.48, 0.50, 0.52, 0.55, 0.58, 0.60]:
    mask = p_tst >= thr
    if mask.sum() >= 10:
        wr_all  = y_tst[mask].mean()
        wr_buy  = y_tst[mask & buy_mask_tst].mean()  if (mask & buy_mask_tst).sum() > 0 else float("nan")
        wr_sell = y_tst[mask & sell_mask_tst].mean() if (mask & sell_mask_tst).sum() > 0 else float("nan")
        pct     = mask.mean()
        n       = mask.sum()
        print(f"{thr:6.2f} | {wr_all*100:6.1f}% | {wr_buy*100:7.1f}% | {wr_sell*100:7.1f}% | {pct*100:5.1f}% | {n:5d}")

# ── Feature importances ──────────────────────────────────────────────
imp  = model.feature_importances_
top10 = np.argsort(imp)[::-1][:10]
print("\nTop 10 features:")
for k, idx in enumerate(top10):
    nm = FEATURE_NAMES[idx] if idx < len(FEATURE_NAMES) else f"f{idx:02d}"
    print(f"  {k+1:2d}. {nm:<25} {imp[idx]:.4f}")

# ── Export ONNX ──────────────────────────────────────────────────────
print(f"\n=== Export ONNX -> {OUT_ONNX} ===")
onnx_ok = False
try:
    from skl2onnx import convert_sklearn, update_registered_converter
    from skl2onnx.common.data_types import FloatTensorType
    from skl2onnx.common.shape_calculator import calculate_linear_classifier_output_shapes
    from xgboost import XGBClassifier as _XGB
    from onnxmltools.convert.xgboost.operator_converters.XGBoost import convert_xgboost
    update_registered_converter(
        _XGB, "XGBoostXGBClassifier",
        calculate_linear_classifier_output_shapes, convert_xgboost,
        options={"nocl": [True, False], "zipmap": [True, False, "columns"]},
    )
    onnx_model = convert_sklearn(
        pipeline,
        initial_types=[("float_input", FloatTensorType([None, N_FEATURES]))],
        options={id(pipeline): {"zipmap": False}},
        target_opset={"": 12, "ai.onnx.ml": 2},
    )
    with open(OUT_ONNX, "wb") as f:
        f.write(onnx_model.SerializeToString())
    print(f"  OK: {Path(OUT_ONNX).stat().st_size / 1024:.0f} KB")
    onnx_ok = True
except Exception as e:
    print(f"  ERREUR skl2onnx: {e}")
    try:
        model.save_model(OUT_ONNX)
        print(f"  OK (natif XGB): {Path(OUT_ONNX).stat().st_size / 1024:.0f} KB")
        onnx_ok = True
    except Exception as e2:
        print(f"  ERREUR fallback: {e2}")

# ── Meta ──────────────────────────────────────────────────────────────
meta = {
    "model_type"     : "xgb_h1ema40_v3",
    "n_features"     : N_FEATURES,
    "feature_names"  : FEATURE_NAMES,
    "train_cutoff"   : str(BT_START.date()),
    "direction_filter": "H1_EMA40",
    "threshold_youden": round(thr_youden, 4),
    "train_proba_p50": round(p50, 4),
    "train_proba_p60": round(p60, 4),
    "train_proba_p70": round(p70, 4),
    "train_proba_p80": round(p80, 4),
    "train_proba_p90": round(p90, 4),
    "auc_oos"        : round(auc, 4),
    "perf_test_youden": {
        "wr_filtered": round(float(wr_y), 4),
        "n_filtered" : int(mask_y.sum()),
        "pct_kept"   : round(float(mask_y.mean()), 4),
    },
}
with open(OUT_META, "w") as f:
    json.dump(meta, f, indent=2)
print(f"Meta: {OUT_META}")

print(f"\n{'='*60}")
print("PARAMETRES EA à utiliser (brain_v3_h1ema40.onnx):")
print(f"  BrainML_SkipBelow       = {p60:.4f}  // P60 train (top 40%)")
print(f"  BrainML_HalfRisk        = {p70:.4f}  // P70 train")
print(f"  BrainML_FullRisk        = {p80:.4f}  // P80 train")
print(f"  BrainML_BoostThreshold  = {p90:.4f}  // P90 train")
print(f"  Youden gate             = {thr_youden:.4f}")
print(f"  WR@Youden OOS           = {wr_y*100:.1f}%  n={mask_y.sum()}")
print(f"  AUC OOS                 = {auc:.4f}")
print(f"{'='*60}")

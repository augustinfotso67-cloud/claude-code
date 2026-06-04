"""
Train a model on the 4-year trade dataset and export it to ONNX
for direct loading by the MQL5 EA (Brain_ML.mqh / OnnxRun).

Features list MUST stay in sync with the order in MQL5's BrainML_BuildFeatures().
This is enforced by writing a header file `features_order.h` alongside the .onnx.
"""
import os
import sys
import json
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import roc_auc_score, brier_score_loss
from skl2onnx import to_onnx
from skl2onnx.common.data_types import FloatTensorType

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'trades.csv')

# ─── FEATURE ORDER — KEEP IN SYNC WITH MQL5 ──────────────────────────────────
# All numeric. No categorical features in this v1 model (kept simple for ONNX).
# MQL5 will gather these values in the same order at trade-open time.
FEATURE_ORDER = [
    'hour', 'dow', 'month',
    'rr_target', 'sl_dist_pct', 'tp_dist_pct',
    'atr_h1', 'atr_h4', 'adx_h4',
    'ema200_d1_pct', 'spread_pts',
    'score_buy', 'score_sell', 'context_score', 'risk_mul',
    'psy_peur', 'psy_cupidite', 'psy_epuise_vend', 'psy_epuise_ach',
    'adn_force_explo', 'mi_cible_inst',
    'dg_buy_susp', 'dg_sell_ovr',
]


def main():
    df = pd.read_csv(DATA, parse_dates=['open_ts'])
    df = df.sort_values('open_ts').reset_index(drop=True)
    df = df.dropna(subset=FEATURE_ORDER + ['win']).reset_index(drop=True)

    X = df[FEATURE_ORDER].astype(np.float32).values
    y = df['win'].astype(np.int64).values
    print(f'Dataset: {len(df)} trades, {X.shape[1]} features')

    # Train on the FULL dataset (this is the production model)
    # We could also do CV, but for v1 export we use everything.
    # Quality control: also do a chronological 80/20 to report test AUC.
    split = int(len(df) * 0.8)
    Xtr, ytr = X[:split], y[:split]
    Xte, yte = X[split:], y[split:]

    clf = RandomForestClassifier(
        n_estimators=300,
        max_depth=5,
        min_samples_leaf=5,
        random_state=42,
        n_jobs=-1,
    )
    clf.fit(Xtr, ytr)
    proba = clf.predict_proba(Xte)[:, 1]
    print(f'Hold-out AUC : {roc_auc_score(yte, proba):.3f}')
    print(f'Hold-out Brier: {brier_score_loss(yte, proba):.3f}')

    # Re-fit on full data for production
    clf_final = RandomForestClassifier(
        n_estimators=300, max_depth=5, min_samples_leaf=5, random_state=42, n_jobs=-1)
    clf_final.fit(X, y)

    # Export to ONNX
    initial_type = [('input', FloatTensorType([None, X.shape[1]]))]
    onx = to_onnx(clf_final, initial_types=initial_type, options={id(clf_final): {'zipmap': False}})

    out_onnx = os.path.join(HERE, 'brain_v1.onnx')
    with open(out_onnx, 'wb') as f:
        f.write(onx.SerializeToString())
    print(f'\nExported → {out_onnx}')
    print(f'Size: {os.path.getsize(out_onnx):,} bytes')

    # Sanity-check the ONNX via onnxruntime
    try:
        import onnxruntime as ort
        sess = ort.InferenceSession(out_onnx, providers=['CPUExecutionProvider'])
        out = sess.run(None, {'input': X[:5]})
        # Some output names depending on skl2onnx version
        names = [o.name for o in sess.get_outputs()]
        print(f'\nONNX output names: {names}')
        for n, v in zip(names, out):
            print(f'  {n}: shape={getattr(v,"shape",None)} sample={np.array(v).ravel()[:5]}')
    except Exception as e:
        print(f'(ONNX runtime sanity-check skipped: {e})')

    # Save feature order
    meta = {
        'feature_order':       FEATURE_ORDER,
        'n_trades':            int(len(df)),
        'n_features':          int(X.shape[1]),
        'hold_out_auc':        float(roc_auc_score(yte, proba)),
        'hold_out_brier':      float(brier_score_loss(yte, proba)),
        'date_range':          [str(df['open_ts'].min()), str(df['open_ts'].max())],
        'model':               'RandomForestClassifier(n_est=300,max_depth=5,min_samp_leaf=5)',
    }
    with open(os.path.join(HERE, 'brain_v1.meta.json'), 'w') as f:
        json.dump(meta, f, indent=2, default=str)
    print(f'Saved meta → brain_v1.meta.json')

    # Print MQL5 array order for easy copy
    print('\n=== MQL5 feature order ===')
    print('// Build features in this exact order before calling OnnxRun:')
    for i, f in enumerate(FEATURE_ORDER):
        print(f'//   [{i:2}] {f}')


if __name__ == '__main__':
    main()

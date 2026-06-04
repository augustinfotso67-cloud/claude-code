"""
eval_thresholds.py
Analyse detaillee du modele brain_v1.onnx sur les donnees de test
pour determiner les seuils de production optimaux.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import json
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import roc_auc_score

N_FEATURES = 36
FEAT = [f"f{i:02d}" for i in range(N_FEATURES)]

df = pd.read_csv("dataset_xau_regime.csv", parse_dates=["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)

n = len(df)
i_train = int(n * 0.60)
i_val   = int(n * 0.80)

train = df.iloc[:i_train]
val   = df.iloc[i_train:i_val]
test  = df.iloc[i_val:]

X_train = train[FEAT].values.astype(np.float32)
y_train = train["label"].values.astype(int)
X_val   = val[FEAT].values.astype(np.float32)
y_val   = val["label"].values.astype(int)
X_test  = test[FEAT].values.astype(np.float32)
y_test  = test["label"].values.astype(int)

scaler = StandardScaler()
X_tr_s = scaler.fit_transform(X_train)
X_v_s  = scaler.transform(X_val)
X_te_s = scaler.transform(X_test)

# Reproduire le meme modele
n_pos = y_train.sum(); n_neg = len(y_train)-n_pos
sw = np.where(y_train==1, n_neg/max(1,n_pos), 1.0)

m = GradientBoostingClassifier(n_estimators=150, max_depth=3,
                                 learning_rate=0.05, subsample=0.8,
                                 min_samples_leaf=20, max_features=0.7,
                                 random_state=42, verbose=0)
m.fit(X_tr_s, y_train, sample_weight=sw)

p_val  = m.predict_proba(X_v_s)[:,1]
p_test = m.predict_proba(X_te_s)[:,1]

print(f"AUC val : {roc_auc_score(y_val, p_val):.4f}")
print(f"AUC test: {roc_auc_score(y_test, p_test):.4f}")
print()

# Courbe WR vs threshold sur test
print("Seuil      Val_WR  Val_N  Test_WR  Test_N  Test_pct")
print("-"*57)
for thr in np.arange(0.10, 0.96, 0.05):
    mv = p_val  >= thr
    mt = p_test >= thr
    nv = mv.sum(); nt = mt.sum()
    if nv < 5 or nt < 5:
        continue
    wrv = y_val[mv].mean() * 100
    wrt = y_test[mt].mean() * 100
    pct = nt / len(y_test) * 100
    print(f"  {thr:.2f}  ->  {wrv:5.1f}%  {nv:4d}    {wrt:5.1f}%   {nt:4d}   {pct:4.0f}%")

print()
# Feature importance
imp = m.feature_importances_
NAMES = [
    "rsi_h1","stoch_k","stoch_d","adx_h1","adxp_h1","adxm_h1","adx_h4",
    "atr_m15","atr_h1","atr_h4","ema200d1","bb_pos","bb_sq","atr_rat",
    "h4_200sl","h4_50sl","h4_200pr","h4_50pr","h_sin","h_cos","d_sin","d_cos",
    "ctx_sc","dir","is_pb","sb_n","sbo_n","adn_ph","psy_ret","psy_dir",
    "mi","bos","near","spread","recent_wr20","recent_wr5"
]
idx = np.argsort(imp)[::-1]
print("Top 15 features les plus importantes :")
for rank, i in enumerate(idx[:15], 1):
    name = NAMES[i] if i < len(NAMES) else f"f{i:02d}"
    print(f"  {rank:2d}. {name:<15} {imp[i]*100:.2f}%")

print()
# Recommandation finale pour le EA
print("="*60)
print("RECOMMANDATION PRODUCTION (brain_v1.onnx a 36 features) :")
print()

# Find threshold for ~65% WR on test with max volume
for thr in np.arange(0.10, 0.90, 0.01):
    mt = p_test >= thr
    if mt.sum() >= 20:
        wrt = y_test[mt].mean()
        if wrt >= 0.65:
            pct = mt.sum() / len(y_test) * 100
            print(f"  Seuil {thr:.2f}: Test WR={wrt*100:.1f}%  Trades={mt.sum()} ({pct:.0f}%)")
            break

# Seuil optimal (Youden)
best_j, best_thr = 0, 0.5
for thr in np.arange(0.05, 0.95, 0.01):
    mv = p_val >= thr
    if mv.sum() < 20: continue
    tp = y_val[mv].sum()
    n_p = y_val.sum()
    n_n = len(y_val) - n_p
    fp = mv.sum() - tp
    tn = n_n - fp
    tpr = tp / max(1, n_p)
    tnr = tn / max(1, n_n)
    j = tpr + tnr - 1
    if j > best_j:
        best_j = j
        best_thr = thr

mt = p_test >= best_thr
wr_t = y_test[mt].mean() * 100 if mt.sum() > 0 else 0
print()
print(f"  Seuil Youden J={best_j:.3f}: thr={best_thr:.2f}")
print(f"  Val  WR={y_val[p_val>=best_thr].mean()*100:.1f}% ({(p_val>=best_thr).sum()} trades)")
print(f"  Test WR={wr_t:.1f}% ({mt.sum()} trades, {mt.mean()*100:.0f}%)")
print()
print("Parametres EA recommandes :")
print(f"  BrainML_OnnxFile  = brain_v1.onnx")
print(f"  BrainML_SkipBelow = {max(0.05, best_thr - 0.15):.2f}  // skip si P < X")
print(f"  BrainML_HalfRisk  = {max(0.05, best_thr - 0.08):.2f}  // demi-risque")
print(f"  BrainML_FullRisk  = {best_thr:.2f}  // risque normal")
print(f"  BrainML_BoostMul  = 1.5  // boost si P >= {min(0.95, best_thr + 0.25):.2f}")
print("="*60)
print()
print("IMPORTANT : features f34 et f35 calculees dans EA v5.8 :")
print("  f34 = WR des 20 derniers signaux fermes")
print("  f35 = WR des 5  derniers signaux fermes")
print("  -> utiliser gHistoriqueSignaux[] pour les calculer en MQL5")

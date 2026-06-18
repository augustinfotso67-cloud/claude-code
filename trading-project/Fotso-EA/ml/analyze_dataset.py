"""
Analyse rapide du dataset pour comprendre la structure temporelle.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import pandas as pd
import numpy as np
from sklearn.metrics import roc_auc_score
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler

df = pd.read_csv("dataset_xau_full.csv", parse_dates=["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)

FEAT = [f"f{i:02d}" for i in range(34)]

print("=== ANALYSE TEMPORELLE DU DATASET ===")
print(f"Total: {len(df)} signaux")
print(f"Periode: {df.timestamp.min().date()} -> {df.timestamp.max().date()}")
print()

# Analyse WR par mois
df["month"] = df.timestamp.dt.to_period("M")
monthly = df.groupby("month").agg(
    n=("label","count"),
    wr=("label","mean"),
    n_buy=("direction", lambda x: (x=="BUY").sum()),
    n_sell=("direction", lambda x: (x=="SELL").sum()),
).reset_index()
monthly["wr_pct"] = monthly["wr"].mul(100).round(1)
print("WR mensuel :")
print(monthly[["month","n","wr_pct","n_buy","n_sell"]].to_string(index=False))
print()

# Analyse WR par trimestre
df["quarter"] = df.timestamp.dt.to_period("Q")
quarterly = df.groupby("quarter").agg(
    n=("label","count"),
    wr=("label","mean"),
).reset_index()
quarterly["wr_pct"] = quarterly["wr"].mul(100).round(1)
print("WR trimestriel :")
print(quarterly.to_string(index=False))
print()

# Cross-validation temporelle : rolling 3-mois
print("=== CROSS-VALIDATION TEMPORELLE (rolling 3 mois) ===")
# Train sur tout sauf les 3 derniers mois, test sur les 3 derniers mois
periods = sorted(df["month"].unique())
results = []
for test_end_idx in range(6, len(periods)):
    test_months = periods[max(0, test_end_idx-3):test_end_idx]
    train_mask = ~df["month"].isin(test_months)
    test_mask  =  df["month"].isin(test_months)
    if train_mask.sum() < 200 or test_mask.sum() < 30:
        continue
    X_tr = df.loc[train_mask, FEAT].values.astype(float)
    y_tr = df.loc[train_mask, "label"].values.astype(int)
    X_te = df.loc[test_mask,  FEAT].values.astype(float)
    y_te = df.loc[test_mask,  "label"].values.astype(int)

    sc = StandardScaler()
    X_tr = sc.fit_transform(X_tr)
    X_te = sc.transform(X_te)

    n_pos = y_tr.sum(); n_neg = len(y_tr) - n_pos
    sw = np.where(y_tr==1, n_neg/max(1,n_pos), 1.0)

    m = GradientBoostingClassifier(n_estimators=100, max_depth=3,
                                    learning_rate=0.05, subsample=0.8,
                                    min_samples_leaf=20, random_state=42)
    m.fit(X_tr, y_tr, sample_weight=sw)
    p_te = m.predict_proba(X_te)[:,1]
    auc  = roc_auc_score(y_te, p_te) if len(np.unique(y_te))>1 else 0.5
    # WR at top-30% threshold
    thr30 = np.percentile(p_te, 70)
    mask  = p_te >= thr30
    wr30  = y_te[mask].mean() if mask.sum() > 0 else 0
    wr_bl = y_te.mean()
    results.append({
        "test_window": f"{test_months[0]}..{test_months[-1]}",
        "n_train": train_mask.sum(),
        "n_test": test_mask.sum(),
        "wr_baseline": round(wr_bl*100,1),
        "wr_top30": round(wr30*100,1),
        "gain": round((wr30-wr_bl)*100,1),
        "auc": round(auc,3),
    })

rdf = pd.DataFrame(results)
print(rdf.to_string(index=False))
print()
print(f"AUC moyen (rolling): {rdf['auc'].mean():.3f}")
print(f"Gain WR moyen (top 30%): {rdf['gain'].mean():.1f}pp")
print(f"Gain WR median (top 30%): {rdf['gain'].median():.1f}pp")

"""diag_features.py — diagnostic qualite/edge des 36 features du dataset live."""
import pandas as pd, numpy as np

df = pd.read_csv(r"C:\Users\User\Fotso-EA\ml\dataset_live.csv")
feats = [f"f{i:02d}" for i in range(36)]
y = df["label"].values
print(f"n={len(df)}  WR={y.mean()*100:.1f}%\n")

rows = []
for f in feats:
    x = pd.to_numeric(df[f], errors="coerce").values
    std = np.nanstd(x)
    nuniq = len(np.unique(x[~np.isnan(x)]))
    # correlation point-biseriale avec label
    if std > 1e-9:
        c = np.corrcoef(x, y)[0, 1]
    else:
        c = 0.0
    # WR top-quartile vs bottom-quartile de la feature
    rows.append((f, std, nuniq, c))

d = pd.DataFrame(rows, columns=["feat", "std", "n_uniq", "corr_label"])
d["abs_corr"] = d["corr_label"].abs()

print("=== Features DEGENERES (std~0 ou <=2 valeurs uniques) ===")
deg = d[(d["std"] < 1e-6) | (d["n_uniq"] <= 2)]
print(deg[["feat", "std", "n_uniq", "corr_label"]].to_string(index=False) if len(deg) else "  aucune")

print("\n=== TOP 10 features par |correlation| avec le label ===")
print(d.sort_values("abs_corr", ascending=False).head(10)[["feat","std","n_uniq","corr_label"]].round(4).to_string(index=False))

print(f"\nCorrelation absolue MAX = {d.abs_corr.max():.4f}  (moy={d.abs_corr.mean():.4f})")
print(f"Nb features |corr|>0.05 : {(d.abs_corr>0.05).sum()} / 36")

# importance GBT rapide (sur tout le dataset, juste pour voir si du signal existe)
try:
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.model_selection import cross_val_score
    X = df[feats].apply(pd.to_numeric, errors="coerce").fillna(0).values
    gb = GradientBoostingClassifier(n_estimators=100, max_depth=3, learning_rate=0.05)
    auc = cross_val_score(gb, X, y, cv=5, scoring="roc_auc")
    print(f"\nAUC 5-fold CV (melange, optimiste) = {auc.mean():.4f} +/- {auc.std():.4f}")
except Exception as e:
    print("skip CV:", e)

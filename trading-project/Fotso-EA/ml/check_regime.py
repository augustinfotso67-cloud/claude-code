import pandas as pd
import numpy as np

df = pd.read_csv("dataset_xau_regime.csv", parse_dates=["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)

n = len(df)
i_train = int(n * 0.60)
i_val   = int(n * 0.80)

train = df.iloc[:i_train]
val   = df.iloc[i_train:i_val]
test  = df.iloc[i_val:]

print("Correlations f34/f35 par periode :")
for name, part in [("Train", train), ("Val", val), ("Test", test)]:
    c20 = np.corrcoef(part["f34"], part["label"])[0, 1]
    c5  = np.corrcoef(part["f35"], part["label"])[0, 1]
    print(f"  {name}: corr(f34)={c20:.3f}  corr(f35)={c5:.3f}  WR={part.label.mean()*100:.1f}%  n={len(part)}")

# Distribution de recent_wr par label sur test
tw = test[test.label == 1]["f34"].mean()
tl = test[test.label == 0]["f34"].mean()
print(f"\nTest: f34 mean WINS={tw:.3f}  LOSSES={tl:.3f}  diff={tw-tl:.3f}")
tw5 = test[test.label == 1]["f35"].mean()
tl5 = test[test.label == 0]["f35"].mean()
print(f"Test: f35 mean WINS={tw5:.3f}  LOSSES={tl5:.3f}  diff={tw5-tl5:.3f}")

# Simple classifier: if recent_wr_20 >= 0.5 -> predict WIN
thr_vals = [0.3, 0.4, 0.5, 0.6, 0.7]
print("\nPerf test avec seuil simple sur f34 (recent_wr_20) :")
for thr in thr_vals:
    mask = test["f34"] >= thr
    n_k = mask.sum()
    if n_k > 0:
        wr = test.loc[mask, "label"].mean()
        print(f"  f34 >= {thr}: n={n_k} ({n_k/len(test)*100:.0f}%)  WR={wr*100:.1f}%  baseline={test.label.mean()*100:.1f}%")
print()
print("Perfs test avec seuil sur f35 (recent_wr_5) :")
for thr in thr_vals:
    mask = test["f35"] >= thr
    n_k = mask.sum()
    if n_k > 0:
        wr = test.loc[mask, "label"].mean()
        print(f"  f35 >= {thr}: n={n_k} ({n_k/len(test)*100:.0f}%)  WR={wr*100:.1f}%  baseline={test.label.mean()*100:.1f}%")

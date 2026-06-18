import numpy as np, pandas as pd
import onnxruntime as rt
from sklearn.metrics import roc_auc_score

df = pd.read_csv(r"C:\Users\User\Fotso-EA\ml\dataset_xau_v4.csv", parse_dates=["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)
N = len(df); test = df.iloc[int(N*0.80):]
FEAT = [f"f{i:02d}" for i in range(36)]
X = test[FEAT].values.astype(np.float32)
y = test["label"].values.astype(int)

sess = rt.InferenceSession(r"C:\Users\User\Fotso-EA\ml\brain_v4.onnx")
inn = sess.get_inputs()[0].name
outs = [o.name for o in sess.get_outputs()]
print("ONNX OK. input", inn, sess.get_inputs()[0].shape, "outputs", outs)
r = sess.run(outs, {inn: X})
pw = r[1][:, 1]
print(f"P(win) min={pw.min():.3f} max={pw.max():.3f} mean={pw.mean():.3f}  AUC={roc_auc_score(y, pw):.4f}")
print("Direction split test:", (test.direction == "BUY").sum(), "BUY /", (test.direction == "SELL").sum(), "SELL")
for thr in [0.375, 0.40, 0.45, 0.566, 0.693, 0.726]:
    m = pw >= thr
    if m.sum() > 0:
        sub = test[m]
        wr_buy = sub[sub.direction == "BUY"]["label"].mean() * 100 if (sub.direction == "BUY").any() else 0
        wr_sell = sub[sub.direction == "SELL"]["label"].mean() * 100 if (sub.direction == "SELL").any() else 0
        print(f"  gate {thr:.3f}: WR={y[m].mean()*100:.1f}%  trades={int(m.sum())} ({m.mean()*100:.0f}%)  "
              f"WR_BUY={wr_buy:.1f}% WR_SELL={wr_sell:.1f}%")

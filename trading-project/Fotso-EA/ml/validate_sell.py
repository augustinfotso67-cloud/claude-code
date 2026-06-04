import numpy as np, pandas as pd
import onnxruntime as rt

df = pd.read_csv(r"C:\Users\User\Fotso-EA\ml\dataset_xau_v4.csv", parse_dates=["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)
N = len(df)
split80 = int(N * 0.80)
oos_start = df["timestamp"].iloc[split80]
print(f"Dataset: {N} signaux, {df.timestamp.min()} -> {df.timestamp.max()}")
print(f"Frontiere OOS (test = derniers 20%): a partir de {oos_start}")
print(f"  => 2022 = IN-SAMPLE (train) ; verifier si 2026 tombe en OOS\n")

FEAT = [f"f{i:02d}" for i in range(36)]
X = df[FEAT].values.astype(np.float32)
sess = rt.InferenceSession(r"C:\Users\User\Fotso-EA\ml\brain_v4.onnx")
inn = sess.get_inputs()[0].name
outs = [o.name for o in sess.get_outputs()]
pw = sess.run(outs, {inn: X})[1][:, 1]
df["pwin"] = pw
df["is_oos"] = df.index >= split80

GATE = 0.40  # gate "volume d'abord" v6.2

def stats(sub, gate=GATE):
    g = sub[sub.pwin >= gate]
    n = len(g)
    if n == 0:
        return None
    wr = g.label.mean()
    nw = int(g.label.sum()); nl = n - nw
    pf = (nw * 1.5) / (nl * 1.0) if nl > 0 else float("inf")
    return dict(n_sig=len(sub), n=n, pct=n/len(sub)*100, wr=wr*100, pf=pf,
                oos=g.is_oos.mean()*100)

def show(title, sub):
    s = stats(sub)
    if s is None:
        print(f"  {title:28s}: aucun SELL au gate {GATE}")
        return
    print(f"  {title:28s}: trades={s['n']:4d}/{s['n_sig']:4d} ({s['pct']:4.0f}%)  "
          f"WR={s['wr']:5.1f}%  PF~{s['pf']:4.2f}  (OOS={s['oos']:3.0f}%)")

sell = df[df.direction == "SELL"].copy()
buy  = df[df.direction == "BUY"].copy()
print(f"Repartition signaux: {len(buy)} BUY / {len(sell)} SELL ({len(sell)/N*100:.0f}% SELL)\n")

print(f"=== BRANCHE SELL au gate {GATE} (PF~ = nW*1.5 / nL*1.0, TP1=1.5R) ===")
show("TOUS SELL", sell)
print()
# Par annee
for yr in sorted(sell.timestamp.dt.year.unique()):
    show(f"SELL {yr}", sell[sell.timestamp.dt.year == yr])
print()
# Jambe baissiere 2022 (mars->oct, l'or chute ~-20%)
bear22 = sell[(sell.timestamp >= "2022-03-01") & (sell.timestamp <= "2022-11-01")]
show("SELL 2022 bear (mar-oct)", bear22)
# 2026 volatil
y2026 = sell[sell.timestamp >= "2026-01-01"]
show("SELL 2026 (volatil)", y2026)
print()
print(f"=== Reference BUY au meme gate ===")
show("TOUS BUY", buy)
for yr in sorted(buy.timestamp.dt.year.unique()):
    show(f"BUY {yr}", buy[buy.timestamp.dt.year == yr])

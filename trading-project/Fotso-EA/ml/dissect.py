"""
dissect.py — Trouve les poches rentables dans les 3094 trades.
Calcule le R reel par trade (meme moteur que sim_pnl) puis segmente sur
direction, heure, jour, annee, ADX, volatilite, pente tendance, pullback, phase...
Pour chaque segment : n, WR(net), expectancy R, profit factor.
"""
from pathlib import Path
import numpy as np, pandas as pd
import sys
sys.path.insert(0, r"C:\Users\User\Fotso-EA\ml")
from sim_pnl import load_m15, sim_trade

DATASET = r"C:\Users\User\Fotso-EA\ml\dataset_live.csv"
M15DIR  = r"C:\Users\User\Desktop\Nouveau dossier (3)\xauusd"

df = pd.read_csv(DATASET)
df["timestamp"] = pd.to_datetime(df["timestamp"])
m15 = load_m15(Path(M15DIR))
hi, lo, cl = m15["high"].values, m15["low"].values, m15["close"].values
idx = m15.index

Rs = []
for _, r in df.iterrows():
    pos = idx.searchsorted(r["timestamp"], side="left")
    if pos >= len(idx):
        Rs.append(np.nan); continue
    ib = (r["direction"] == "BUY")
    Ra, Rb = sim_trade(hi, lo, cl, int(pos), ib,
                       float(r["entry"]), float(r["sl"]), float(r["tp1"]), float(r["tp2"]))
    Rs.append((Ra + Rb) / 2.0)
df["R"] = Rs
df = df.dropna(subset=["R"]).copy()

# dimensions derivees
df["hour"] = df["timestamp"].dt.hour
df["dow"]  = df["timestamp"].dt.dayofweek      # 0=lundi
df["year"] = df["timestamp"].dt.year
df["adx_h4"]  = df["f06"] * 100
df["adx_h1"]  = df["f03"] * 100
df["atr_rel"] = df["f07"]                       # atr_m15/close
df["slope"]   = df["f14"]                        # pente H4 EMA200
df["ctx"]     = df["f22"]
df["pullback"] = df["f24"].astype(int)
df["phase"]   = (df["f27"] * 4).round().astype(int)
df["bos"]     = df["f31"].astype(int)
df["near"]    = df["f32"].astype(int)

def terciles(s, labels=("bas", "moy", "haut")):
    try:
        return pd.qcut(s, 3, labels=labels, duplicates="drop")
    except Exception:
        return pd.cut(s, 3, labels=labels)

df["adx_h4_t"] = terciles(df["adx_h4"])
df["adx_h1_t"] = terciles(df["adx_h1"])
df["atr_t"]    = terciles(df["atr_rel"])
df["slope_t"]  = terciles(df["slope"], ("baissier", "plat", "haussier"))
df["ctx_t"]    = terciles(df["ctx"])

def stats(g):
    R = g["R"].values
    n = len(R)
    wins = R[R > 0]; loss = R[R < 0]
    wr = (R > 0).mean() * 100
    exp = R.mean()
    pf = wins.sum() / abs(loss.sum()) if loss.sum() != 0 else np.inf
    return pd.Series({"n": n, "WR%": round(wr, 1), "exp_R": round(exp, 3),
                      "PF": round(pf, 2), "R_tot": round(R.sum(), 1)})

print(f"GLOBAL : n={len(df)}  exp={df.R.mean():+.3f}R  PF={df[df.R>0].R.sum()/abs(df[df.R<0].R.sum()):.2f}\n")

DIMS = ["direction", "pullback", "year", "hour", "dow", "phase", "bos", "near",
        "adx_h4_t", "adx_h1_t", "atr_t", "slope_t", "ctx_t"]
for dim in DIMS:
    print(f"===== par {dim} =====")
    g = df.groupby(dim, observed=True).apply(stats).sort_values("exp_R", ascending=False)
    print(g.to_string())
    print()

# meilleures COMBINAISONS direction x slope x adx (volume>=80)
print("===== TOP combinaisons (direction x slope_t x adx_h4_t, n>=60) =====")
c = df.groupby(["direction", "slope_t", "adx_h4_t"], observed=True).apply(stats)
c = c[c["n"] >= 60].sort_values("exp_R", ascending=False)
print(c.to_string())

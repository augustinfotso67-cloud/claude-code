"""
filter_test.py — Teste des filtres d'entree candidats et verifie la ROBUSTESSE
annee par annee (anti-overfit) + drawdown. Calcule R reel par trade.
"""
from pathlib import Path
import numpy as np, pandas as pd, sys
sys.path.insert(0, r"C:\Users\User\Fotso-EA\ml")
from sim_pnl import load_m15, sim_trade

df = pd.read_csv(r"C:\Users\User\Fotso-EA\ml\dataset_live.csv")
df["timestamp"] = pd.to_datetime(df["timestamp"])
m15 = load_m15(Path(r"C:\Users\User\Desktop\Nouveau dossier (3)\xauusd"))
hi, lo, cl = m15["high"].values, m15["low"].values, m15["close"].values
idx = m15.index
R = []
for _, r in df.iterrows():
    pos = idx.searchsorted(r["timestamp"], side="left")
    if pos >= len(idx): R.append(np.nan); continue
    ib = r["direction"] == "BUY"
    Ra, Rb = sim_trade(hi, lo, cl, int(pos), ib, float(r["entry"]), float(r["sl"]), float(r["tp1"]), float(r["tp2"]))
    R.append((Ra+Rb)/2)
df["R"] = R
df = df.dropna(subset=["R"]).copy()
df["hour"] = df.timestamp.dt.hour
df["dow"]  = df.timestamp.dt.dayofweek
df["year"] = df.timestamp.dt.year
df["adx_h4"] = df.f06*100
df["ctx"] = df.f22
# seuils terciles context & atr
ctx_hi = df.ctx.quantile(2/3)
atr_lo = df.f07.quantile(1/3)
adx_lo = df.adx_h4.quantile(1/3)

def maxdd(R, risk=1.0):
    eq=10000.0; peak=eq; dd=0.0
    for r in R:
        eq*=(1+r*risk/100); peak=max(peak,eq); dd=max(dd,(peak-eq)/peak)
    return dd*100

def report(name, mask):
    sub = df[mask]
    if len(sub)==0: print(f"\n### {name}: 0 trade"); return
    Rv = sub.R.values
    wr=(Rv>0).mean()*100; exp=Rv.mean()
    pf=Rv[Rv>0].sum()/abs(Rv[Rv<0].sum()) if (Rv<0).any() else np.inf
    print(f"\n### {name}")
    print(f"  n={len(sub)} ({len(sub)/len(df)*100:.0f}% gardes)  WR={wr:.1f}%  exp={exp:+.3f}R  PF={pf:.2f}  DD={maxdd(Rv):.0f}%")
    pa = sub.groupby("year").apply(lambda g: pd.Series({
        "n":len(g),"PF":round(g.R[g.R>0].sum()/abs(g.R[g.R<0].sum()),2) if (g.R<0).any() else np.inf,
        "exp":round(g.R.mean(),3)}))
    print("  par annee:"); print("   " + pa.to_string().replace("\n","\n   "))

report("BASELINE (tout)", df.index>=0)
report("F1 context_score haut", df.ctx>=ctx_hi)
report("F2 ctx haut + ATR>=bas + heures 5-13", (df.ctx>=ctx_hi)&(df.f07>=atr_lo)&(df.hour.between(5,13)))
report("F3 F2 + exclure Mer/Jeu", (df.ctx>=ctx_hi)&(df.f07>=atr_lo)&(df.hour.between(5,13))&(~df.dow.isin([2,3])))
report("F4 ctx haut + exclure heures pourries(22,4,20,0,1,23)", (df.ctx>=ctx_hi)&(~df.hour.isin([22,4,20,0,1,23])))
report("F5 ADX_h4 bas + ATR>=bas", (df.adx_h4<=adx_lo)&(df.f07>=atr_lo))
report("F6 ctx haut + ADX bas", (df.ctx>=ctx_hi)&(df.adx_h4<=adx_lo))
report("F7 BUY only + ctx haut", (df.direction=="BUY")&(df.ctx>=ctx_hi))

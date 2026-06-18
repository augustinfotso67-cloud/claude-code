"""
tp_variants.py — Sur le sous-ensemble F6 (ctx haut + ADX bas), teste differents
couples (TP1_RR, TP2_RR) pour voir si des cibles plus serrees remontent le WR
vers 60% tout en gardant un PF correct. Memes entrees/SL, on recalcule les TP.
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

df["adx_h4"]=df.f06*100; df["ctx"]=df.f22
mask = (df.ctx>=df.ctx.quantile(2/3)) & (df.adx_h4<=df.adx_h4.quantile(1/3))
sub = df[mask].copy()
sub["year"]=sub.timestamp.dt.year
print(f"Sous-ensemble F6 : {len(sub)} trades\n")

def maxdd(R):
    eq=1.0; peak=1.0; dd=0
    for r in R: eq*=(1+r*0.01); peak=max(peak,eq); dd=max(dd,(peak-eq)/peak)
    return dd*100

CONFIGS = [(0.8,1.5),(1.0,1.5),(1.0,2.0),(1.2,2.0),(1.5,2.5),(2.0,3.0)]
print(f"{'TP1/TP2':>10} | {'WR%':>5} | {'exp_R':>6} | {'PF':>5} | {'DD%':>4} | annees PF (positives/5)")
for rr1, rr2 in CONFIGS:
    Rall=[]; yrR={}
    for _, r in sub.iterrows():
        pos=idx.searchsorted(r["timestamp"],side="left")
        if pos>=len(idx): continue
        ib=r["direction"]=="BUY"; e=float(r["entry"]); s=float(r["sl"]); sld=abs(e-s)
        tp1 = e+rr1*sld if ib else e-rr1*sld
        tp2 = e+rr2*sld if ib else e-rr2*sld
        Ra,Rb=sim_trade(hi,lo,cl,int(pos),ib,e,s,tp1,tp2)
        R=(Ra+Rb)/2; Rall.append(R); yrR.setdefault(r["timestamp"].year,[]).append(R)
    Rall=np.array(Rall)
    wr=(Rall>0).mean()*100; exp=Rall.mean()
    pf=Rall[Rall>0].sum()/abs(Rall[Rall<0].sum()) if (Rall<0).any() else np.inf
    pos_years=sum(1 for y,v in yrR.items() if np.mean(v)>0)
    pfy=" ".join(f"{y}:{(np.array(v)[np.array(v)>0].sum()/abs(np.array(v)[np.array(v)<0].sum()) if (np.array(v)<0).any() else 9.9):.2f}" for y,v in sorted(yrR.items()))
    print(f"{rr1:.1f}/{rr2:.1f}".rjust(10) + f" | {wr:5.1f} | {exp:+.3f} | {pf:5.2f} | {maxdd(Rall):4.0f} | {pos_years}/5  [{pfy}]")

"""
compare_sim_vs_ea.py — Pourquoi le Python dit +32% et l'EA -9% ?
Matche les trades REELS de l'EA (journal v58) a ma simulation, sur les MEMES entrees.
Isole : (a) jeu de trades different  vs  (b) meme trade, resultat different (spread/intrabar).
"""
from pathlib import Path
import numpy as np, pandas as pd, re, sys
sys.path.insert(0, r"C:\Users\User\Fotso-EA\ml")
from sim_pnl import load_m15, sim_trade

EA = r"C:\Users\User\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files\Fotso_Cerveau_log_v58.csv"
DS = r"C:\Users\User\Fotso-EA\ml\dataset_live.csv"
M15 = r"C:\Users\User\Desktop\Nouveau dossier (3)\xauusd"
RR1, RR2 = 0.8, 1.5

df = pd.read_csv(EA, encoding="cp1252", engine="python", on_bad_lines="skip")
df.columns = [c.strip() for c in df.columns]

# --- reconstruire les trades (1 a la fois : OUVERTURE puis FERMETURE(s)) ---
trades = []; cur = None
for _, r in df.iterrows():
    typ = str(r.get("Type",""))
    prof = str(r.get("Profit",""))
    if prof == "OUVERT":   # ouverture
        if cur: trades.append(cur)
        sl = re.search(r"SL=([\d.]+)", str(r.get("NiveauSL","")))
        ts = pd.to_datetime(str(r["Date"]).strip()+" "+str(r["Heure"]).strip(),
                            format="%Y.%m.%d %H:%M", errors="coerce")
        cur = dict(ts=ts, dir=str(r["Direction"]).strip(),
                   entry=float(r["Entry"]), sl=float(sl.group(1)) if sl else np.nan, pnl=0.0, nf=0)
    elif typ == "FERMETURE" and cur is not None:
        p = pd.to_numeric(r.get("Profit"), errors="coerce")
        if not np.isnan(p): cur["pnl"] += p; cur["nf"] += 1
if cur: trades.append(cur)
t = pd.DataFrame(trades).dropna(subset=["ts","sl"])
t["ea_win"] = t["pnl"] > 0
print(f"Trades EA reconstruits : {len(t)}  (WR={t.ea_win.mean()*100:.1f}%, net={t.pnl.sum():.0f}$)")

# --- simulation sur les MEMES entrees/SL (TP recalcules 0.8/1.5) ---
m15 = load_m15(Path(M15)); hi,lo,cl = m15["high"].values, m15["low"].values, m15["close"].values; idx = m15.index
simR=[]; simWin=[]
for _, r in t.iterrows():
    pos = idx.searchsorted(r["ts"], side="left")
    if pos>=len(idx): simR.append(np.nan); simWin.append(None); continue
    ib = r["dir"]=="BUY"; e=r["entry"]; s=r["sl"]; sld=abs(e-s)
    tp1 = e+RR1*sld if ib else e-RR1*sld
    tp2 = e+RR2*sld if ib else e-RR2*sld
    Ra,Rb = sim_trade(hi,lo,cl,int(pos),ib,e,s,tp1,tp2)
    R=(Ra+Rb)/2; simR.append(R); simWin.append(R>0)
t["sim_R"]=simR; t["sim_win"]=simWin
tv = t.dropna(subset=["sim_R"]).copy()

print(f"\n=== SUR LES MEMES {len(tv)} ENTREES (entry+SL identiques EA) ===")
print(f"  WR simul  : {tv.sim_win.mean()*100:.1f}%   (sim_R moyen {tv.sim_R.mean():+.3f}R)")
print(f"  WR reel EA: {tv.ea_win.mean()*100:.1f}%")
# matrice d'accord
both = pd.crosstab(tv.sim_win, tv.ea_win)
print("\n  Accord sim vs EA (lignes=sim_win, col=ea_win):")
print(both.to_string())
agree = (tv.sim_win==tv.ea_win).mean()*100
print(f"  -> accord : {agree:.1f}%")
# trades ou sim gagne mais EA perd (= optimisme sim : spread/intrabar)
opt = tv[(tv.sim_win==True)&(tv.ea_win==False)]
pes = tv[(tv.sim_win==False)&(tv.ea_win==True)]
print(f"\n  Sim GAGNE / EA PERD : {len(opt)}  (sim trop optimiste ici)")
print(f"  Sim PERD  / EA GAGNE: {len(pes)}")

# --- recouvrement des jeux : entrees EA presentes dans mon dataset F6 ? ---
ds = pd.read_csv(DS); ds["timestamp"]=pd.to_datetime(ds["timestamp"])
ds["adx_h4"]=ds.f06*100; ds["ctx"]=ds.f22
f6 = ds[(ds.ctx>=1.10)&(ds.adx_h4<=25.4)]
ea_ts = set(t.ts.dropna()); f6_ts = set(f6.timestamp)
inter = ea_ts & f6_ts
print(f"\n=== RECOUVREMENT DES JEUX ===")
print(f"  Trades EA : {len(ea_ts)} | F6 dataset : {len(f6_ts)} | en commun : {len(inter)}")
print(f"  EA hors F6-dataset : {len(ea_ts-f6_ts)} | F6-dataset non trades par EA : {len(f6_ts-ea_ts)}")

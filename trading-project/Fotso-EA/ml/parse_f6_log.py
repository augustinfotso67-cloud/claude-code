"""parse_f6_log.py — WR/PF/DD/profit du backtest F6 depuis le journal de trades EA."""
import pandas as pd, numpy as np, sys

P = r"C:\Users\User\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files\Fotso_Cerveau_log_v58.csv"
df = pd.read_csv(P, encoding="cp1252", engine="python", on_bad_lines="skip")
df.columns = [c.strip() for c in df.columns]

closes = df[df["Type"] == "FERMETURE"].copy()
# PAS de dedup : chaque demi-lot ferme separement (meme instant/prix/profit) = 2 fills reels
closes["pnl"] = pd.to_numeric(closes["Profit"], errors="coerce")
closes = closes.dropna(subset=["pnl"])
closes["dt"] = pd.to_datetime(closes["Date"], format="%Y.%m.%d", errors="coerce")
closes["year"] = closes["dt"].dt.year

def block(name, g):
    n=len(g); w=g[g.pnl>0]; l=g[g.pnl<0]; be=g[g.pnl==0]
    wr=len(w)/n*100 if n else 0
    pf=w.pnl.sum()/abs(l.pnl.sum()) if l.pnl.sum()!=0 else np.inf
    print(f"{name:14s} n={n:4d}  WR={wr:5.1f}%  gains={w.pnl.sum():9.0f}  pertes={l.pnl.sum():9.0f}  "
          f"net={g.pnl.sum():9.0f}  PF={pf:4.2f}  BE={len(be)}")

print("=== BACKTEST F6 (journal trades EA) ===")
print(f"Periode: {closes.dt.min().date()} -> {closes.dt.max().date()}\n")
block("GLOBAL", closes)
print()
for y in sorted(closes.year.dropna().unique()):
    block(f"  {int(y)}", closes[closes.year==y])

# equity / drawdown depuis la colonne Balance
bal = pd.to_numeric(closes["Balance"], errors="coerce").dropna().values
if len(bal):
    peak=bal[0]; mdd=0
    for b in bal:
        peak=max(peak,b); mdd=max(mdd,(peak-b)/peak)
    print(f"\nBalance finale: {bal[-1]:.0f}  (depart 10000)  =>  {(bal[-1]/10000-1)*100:+.1f}%")
    print(f"Max Drawdown (sur balance): {mdd*100:.1f}%")

# repartition raisons de sortie
print("\n=== Raisons de sortie (TP/SL/BE) ===")
def rcat(r):
    t=(str(r.get("RaisonTP",""))+" "+str(r.get("RaisonSL",""))).upper()
    if "TP" in t and "WIN" in t: return "TP (win)"
    if "WIN" in t: return "WIN autre"
    if "SL_TOUCHE" in t or "LOSS" in t: return "SL/LOSS"
    if "BE" in t or "BREAK" in t: return "BreakEven"
    return "autre"
closes["cat"]=closes.apply(rcat,axis=1)
print(closes.groupby("cat")["pnl"].agg(["count","sum","mean"]).round(1).to_string())

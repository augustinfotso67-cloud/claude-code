"""parse_compare.py — compare les variantes F6 (base / notrail / naked)."""
import pandas as pd, numpy as np, glob, os

ROOT = r"C:\Users\User\AppData\Roaming\MetaQuotes\Tester"

def find(name):
    hits = glob.glob(os.path.join(ROOT, "**", name), recursive=True)
    hits = [h for h in hits if os.path.getsize(h) > 200]
    return max(hits, key=os.path.getmtime) if hits else None

def stats(path):
    df = pd.read_csv(path, encoding="cp1252", engine="python", on_bad_lines="skip")
    df.columns = [c.strip() for c in df.columns]
    c = df[df["Type"] == "FERMETURE"].copy()
    c["pnl"] = pd.to_numeric(c["Profit"], errors="coerce")
    c = c.dropna(subset=["pnl"])
    n = len(c); wr = (c.pnl > 0).mean()*100
    g = c[c.pnl > 0].pnl.sum(); l = c[c.pnl < 0].pnl.sum()
    pf = g/abs(l) if l != 0 else np.inf
    bal = pd.to_numeric(c["Balance"], errors="coerce").dropna().values
    dd = 0; peak = bal[0] if len(bal) else 10000
    for b in bal: peak = max(peak, b); dd = max(dd, (peak-b)/peak)
    net = (bal[-1]/10000-1)*100 if len(bal) else 0
    cc = c.copy(); cc["dt"] = pd.to_datetime(cc["Date"], format="%Y.%m.%d", errors="coerce")
    cc["y"] = cc["dt"].dt.year
    yrs = []
    for y in sorted(cc.y.dropna().unique()):
        gy = cc[cc.y == y]; lo = gy[gy.pnl<0].pnl.sum()
        pfy = gy[gy.pnl>0].pnl.sum()/abs(lo) if lo != 0 else 9.9
        yrs.append(f"{int(y)}:{pfy:.2f}")
    return n, wr, pf, dd*100, net, " ".join(yrs)

print(f"{'variante':10s} | {'n':>4} | {'WR%':>5} | {'PF':>5} | {'DD%':>5} | {'net%':>6} | PF/an")
for v in ["base","notrail","naked"]:
    p = find(f"Fotso_F6_{v}.csv")
    if not p: print(f"{v:10s} | introuvable"); continue
    n,wr,pf,dd,net,yrs = stats(p)
    print(f"{v:10s} | {n:4d} | {wr:5.1f} | {pf:5.2f} | {dd:5.1f} | {net:+6.1f} | {yrs}")

"""
sim_pnl.py — Simule le PnL REEL de la strategie (sans ML) sur les 3094 trades collectes.
Replique la gestion EA : 2 demi-lots (TP1=1.5R, TP2=2.5R), break-even a +0.8R (2.0 ATR),
SL prioritaire intrabar. Trailing simplifie (ignore -> conservateur). Timeout 200 barres M15.

Sortie : WR, expectancy (R/trade), profit factor, retour total (risque 1%/trade).
"""
import argparse
from pathlib import Path
import numpy as np, pandas as pd

MAX_BARS = 200
BE_R = 0.8   # break-even declenche a +0.8R (2.0 ATR / SL 2.5 ATR)


def load_m15(data_dir: Path) -> pd.DataFrame:
    f = [x for x in data_dir.iterdir() if "m15" in x.name.lower() and x.suffix == ".csv"][0]
    cols = ["datetime", "open", "high", "low", "close", "volume", "x"]
    try:
        df = pd.read_csv(f, header=0, names=cols, encoding="utf-16")
    except Exception:
        df = pd.read_csv(f, header=0, names=cols, encoding="utf-8")
    df["datetime"] = pd.to_datetime(df["datetime"], format="%Y.%m.%d %H:%M")
    df = df.set_index("datetime").sort_index()
    return df[~df.index.duplicated(keep="first")]


def sim_trade(hi, lo, cl, i0, is_buy, entry, sl, tp1, tp2):
    """Retourne (R_tp1half, R_tp2half). Demi-lots egaux. SL prioritaire."""
    sld = abs(entry - sl)
    if sld <= 0:
        return 0.0, 0.0
    be_trig = entry + BE_R * sld if is_buy else entry - BE_R * sld
    sl_a = sl_b = sl            # stops courants des 2 moities
    a_done = b_done = False     # moities cloturees ?
    Ra = Rb = None
    n = len(cl)
    for k in range(1, min(MAX_BARS, n - i0)):
        h = hi[i0 + k]; l = lo[i0 + k]
        if is_buy:
            # 1) SL prioritaire (moitie A puis B)
            if not a_done and l <= sl_a:
                Ra = (sl_a - entry) / sld; a_done = True
            if not b_done and l <= sl_b:
                Rb = (sl_b - entry) / sld; b_done = True
            # 2) break-even (deplace les stops a l'entree)
            if h >= be_trig:
                if not a_done and sl_a < entry: sl_a = entry
                if not b_done and sl_b < entry: sl_b = entry
            # 3) TP
            if not a_done and h >= tp1:
                Ra = (tp1 - entry) / sld; a_done = True      # +1.5R
            if not b_done and h >= tp2:
                Rb = (tp2 - entry) / sld; b_done = True      # +2.5R
        else:  # SELL
            if not a_done and h >= sl_a:
                Ra = (entry - sl_a) / sld; a_done = True
            if not b_done and h >= sl_b:
                Rb = (entry - sl_b) / sld; b_done = True
            if l <= be_trig:
                if not a_done and sl_a > entry: sl_a = entry
                if not b_done and sl_b > entry: sl_b = entry
            if not a_done and l <= tp1:
                Ra = (entry - tp1) / sld; a_done = True
            if not b_done and l <= tp2:
                Rb = (entry - tp2) / sld; b_done = True
        if a_done and b_done:
            break
    # timeout : cloture au dernier close (mark-to-market)
    last = cl[min(i0 + MAX_BARS, n - 1)]
    if Ra is None: Ra = ((last - entry) if is_buy else (entry - last)) / sld
    if Rb is None: Rb = ((last - entry) if is_buy else (entry - last)) / sld
    return Ra, Rb


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default=r"C:\Users\User\Fotso-EA\ml\dataset_live.csv")
    ap.add_argument("--m15", default=r"C:\Users\User\Desktop\Nouveau dossier (3)\xauusd")
    ap.add_argument("--risk", type=float, default=1.0, help="%% risque par trade")
    ap.add_argument("--spread_pts", type=float, default=0.0, help="spread en points (3 digits) a deduire")
    a = ap.parse_args()

    df = pd.read_csv(a.dataset)
    df["timestamp"] = pd.to_datetime(df["timestamp"])
    m15 = load_m15(Path(a.m15))
    hi, lo, cl = m15["high"].values, m15["low"].values, m15["close"].values
    idx = m15.index

    tot = []
    for _, r in df.iterrows():
        pos = idx.searchsorted(r["timestamp"], side="left")
        if pos >= len(idx):
            continue
        is_buy = (r["direction"] == "BUY")
        Ra, Rb = sim_trade(hi, lo, cl, int(pos), is_buy,
                           float(r["entry"]), float(r["sl"]), float(r["tp1"]), float(r["tp2"]))
        R = (Ra + Rb) / 2.0
        # cout spread : ~ spread/slDist en R, applique a l'entree
        if a.spread_pts > 0:
            sld_pts = abs(float(r["entry"]) - float(r["sl"])) / 0.001
            R -= a.spread_pts / sld_pts
        tot.append(R)

    R = np.array(tot)
    n = len(R)
    wins = R[R > 0]; losses = R[R < 0]
    wr = (R > 0).mean() * 100
    exp = R.mean()
    pf = wins.sum() / abs(losses.sum()) if losses.sum() != 0 else float("inf")

    # equite : risque fixe a.risk% par trade, compose
    eq = 10000.0; curve = [eq]; peak = eq; maxdd = 0.0
    for r in R:
        eq *= (1 + r * a.risk / 100.0)
        curve.append(eq)
        peak = max(peak, eq)
        maxdd = max(maxdd, (peak - eq) / peak)
    ret = (eq / 10000.0 - 1) * 100

    print(f"=== SIMULATION PnL strategie BRUTE (sans ML) — {n} trades ===")
    print(f"  Spread deduit : {a.spread_pts} pts | Risque/trade : {a.risk}%\n")
    print(f"  Win rate (R>0)      : {wr:.1f}%")
    print(f"  Expectancy          : {exp:+.3f} R / trade")
    print(f"  Profit factor       : {pf:.2f}")
    print(f"  R total cumule      : {R.sum():+.1f} R")
    print(f"  Gain moy / Perte moy: {wins.mean():+.2f}R / {losses.mean():+.2f}R" if len(wins) and len(losses) else "")
    print(f"\n  Retour total (compose {a.risk}%/trade) : {ret:+.1f}%")
    print(f"  Max drawdown        : {maxdd*100:.1f}%")

    # par direction
    for d in ("BUY", "SELL"):
        mask = (df["direction"].values[:n] == d)
        if mask.sum():
            rd = R[mask]
            print(f"  [{d}] n={mask.sum()} WR={ (rd>0).mean()*100:.1f}% exp={rd.mean():+.3f}R PF={rd[rd>0].sum()/abs(rd[rd<0].sum()):.2f}")


if __name__ == "__main__":
    main()

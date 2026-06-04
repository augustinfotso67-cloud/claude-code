"""Profilage marche XAUUSD multi-timeframe.

Pour chaque fichier OHLC (format MT5 export: date,open,high,low,close,vol,spread)
produit:
  - regime annuel (bull/bear/range) + drawdown intra-annuel
  - profil par jour de semaine
  - profil horaire + sessions (uniquement sur la partie intraday reelle)
  - saisonnalite mensuelle
  - equilibre haussier/baissier (opportunite BUY vs SELL)
  - CSV journalier (1 ligne = 1 jour: ce qui s'est passe)

Usage:
  python analyze_market.py --file <chemin.csv> --name H1 --outdir analysis
"""
import argparse
import os
import numpy as np
import pandas as pd


def _detect_encoding(path):
    with open(path, "rb") as f:
        head = f.read(4)
    if head[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return "utf-16"
    if head[:3] == b"\xef\xbb\xbf":
        return "utf-8-sig"
    return "utf-8"


def load(path):
    df = pd.read_csv(
        path,
        header=None,
        names=["dt", "open", "high", "low", "close", "vol", "spread"],
        encoding=_detect_encoding(path),
    )
    df["dt"] = pd.to_datetime(df["dt"], format="%Y.%m.%d %H:%M")
    df = df.sort_values("dt").reset_index(drop=True)
    return df


def first_intraday_idx(df):
    """Index de la 1ere barre dont l'heure n'est pas 00:00 (debut vrai intraday)."""
    mask = (df["dt"].dt.hour != 0) | (df["dt"].dt.minute != 0)
    if mask.any():
        return df.index[mask][0]
    return None


def to_daily(df):
    """Resample en barres journalieres OHLC (peu importe la granularite source)."""
    d = df.set_index("dt").resample("1D").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last", "vol": "sum"}
    ).dropna(subset=["open"])
    return d


def daily_record(d):
    """1 ligne par jour: ce qui s'est passe."""
    out = pd.DataFrame(index=d.index)
    out["dow"] = d.index.day_name()
    out["open"] = d["open"]
    out["high"] = d["high"]
    out["low"] = d["low"]
    out["close"] = d["close"]
    out["ret_oc_pct"] = (d["close"] - d["open"]) / d["open"] * 100.0   # open->close intra-jour
    out["ret_cc_pct"] = d["close"].pct_change() * 100.0                # close->close veille
    out["range_usd"] = d["high"] - d["low"]
    out["range_pct"] = (d["high"] - d["low"]) / d["open"] * 100.0
    prev_close = d["close"].shift(1)
    tr = np.maximum(d["high"] - d["low"],
                    np.maximum((d["high"] - prev_close).abs(),
                               (d["low"] - prev_close).abs()))
    out["true_range"] = tr
    out["dir"] = np.where(out["ret_oc_pct"] >= 0, "UP", "DOWN")
    out["vol"] = d["vol"]
    return out


def yearly_regime(d):
    rows = []
    for year, g in d.groupby(d.index.year):
        first_c = g["close"].iloc[0]
        last_c = g["close"].iloc[-1]
        ret = (last_c - first_c) / first_c * 100.0
        # max drawdown intra-annuel sur la cloture
        roll_max = g["close"].cummax()
        dd = ((g["close"] - roll_max) / roll_max * 100.0).min()
        # max run-up depuis plus bas
        roll_min = g["close"].cummin()
        ru = ((g["close"] - roll_min) / roll_min * 100.0).max()
        rng = (g["high"] - g["low"])
        oc = (g["close"] - g["open"]) / g["open"] * 100.0
        up = (oc >= 0).mean() * 100.0
        if ret > 12:
            reg = "BULL"
        elif ret < -12:
            reg = "BEAR"
        else:
            reg = "RANGE"
        rows.append({
            "year": year, "regime": reg, "n_days": len(g),
            "open": round(first_c, 1), "close": round(last_c, 1),
            "ret_pct": round(ret, 1), "max_dd_pct": round(dd, 1),
            "max_runup_pct": round(ru, 1),
            "avg_range_usd": round(rng.mean(), 1),
            "max_range_usd": round(rng.max(), 1),
            "avg_abs_oc_pct": round(oc.abs().mean(), 2),
            "pct_up_days": round(up, 1),
        })
    return pd.DataFrame(rows)


def dow_profile(rec):
    order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Sunday"]
    g = rec.groupby("dow")
    prof = pd.DataFrame({
        "n": g.size(),
        "mean_ret_oc_pct": g["ret_oc_pct"].mean().round(3),
        "median_ret_oc_pct": g["ret_oc_pct"].median().round(3),
        "pct_up": (g["dir"].apply(lambda s: (s == "UP").mean() * 100)).round(1),
        "mean_range_usd": g["range_usd"].mean().round(1),
        "mean_range_pct": g["range_pct"].mean().round(2),
    })
    prof = prof.reindex([d for d in order if d in prof.index])
    return prof


def hour_profile(intraday):
    """Profil par heure broker sur barres intraday (open->close de chaque barre)."""
    x = intraday.copy()
    x["hour"] = x["dt"].dt.hour
    x["ret"] = (x["close"] - x["open"]) / x["open"] * 100.0
    x["rng"] = (x["high"] - x["low"])
    g = x.groupby("hour")
    prof = pd.DataFrame({
        "n": g.size(),
        "mean_ret_pct": g["ret"].mean().round(4),
        "std_ret_pct": g["ret"].std().round(4),
        "pct_up": (g["ret"].apply(lambda s: (s >= 0).mean() * 100)).round(1),
        "mean_range_usd": g["rng"].mean().round(2),
    })
    return prof


def session_profile(hourprof):
    """Aggrege les heures en sessions (heure broker; offset suppose GMT+2/+3)."""
    buckets = {
        "Asie (0-6)": range(0, 7),
        "Londres (7-12)": range(7, 13),
        "Overlap LDN/NY (13-16)": range(13, 17),
        "New York (17-21)": range(17, 22),
        "Tardif (22-23)": range(22, 24),
    }
    rows = []
    for name, hrs in buckets.items():
        sub = hourprof[hourprof.index.isin(list(hrs))]
        if sub.empty:
            continue
        n = sub["n"].sum()
        # moyenne ponderee par n
        mean_ret = np.average(sub["mean_ret_pct"], weights=sub["n"])
        vol = np.average(sub["std_ret_pct"], weights=sub["n"])
        rng = np.average(sub["mean_range_usd"], weights=sub["n"])
        pct_up = np.average(sub["pct_up"], weights=sub["n"])
        rows.append({
            "session": name, "n_barres": int(n),
            "mean_ret_pct": round(mean_ret, 4),
            "volatilite_std": round(vol, 4),
            "pct_up": round(pct_up, 1),
            "mean_range_usd": round(rng, 2),
        })
    return pd.DataFrame(rows)


def monthly_seasonality(d):
    m = d["close"].resample("1ME").last()
    ret = m.pct_change() * 100.0
    df = pd.DataFrame({"month": ret.index.month, "ret": ret.values}).dropna()
    g = df.groupby("month")["ret"]
    prof = pd.DataFrame({
        "n_annees": g.size(),
        "mean_ret_pct": g.mean().round(2),
        "pct_positifs": (g.apply(lambda s: (s >= 0).mean() * 100)).round(1),
    })
    return prof


def balance(rec):
    up = (rec["dir"] == "UP").sum()
    down = (rec["dir"] == "DOWN").sum()
    tot = up + down
    return up, down, tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--outdir", default="analysis")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    df = load(args.file)

    fi = first_intraday_idx(df)
    if fi is not None and fi > 0:
        intraday = df.loc[fi:].copy()
        daily_prefix_end = df.loc[fi - 1, "dt"]
    else:
        intraday = df.copy()
        daily_prefix_end = None

    d = to_daily(df)
    rec = daily_record(d)
    rec.to_csv(os.path.join(args.outdir, f"{args.name}_daily.csv"))

    yr = yearly_regime(d)
    dow = dow_profile(rec)
    hp = hour_profile(intraday)
    sp = session_profile(hp)
    ms = monthly_seasonality(d)
    up, down, tot = balance(rec)

    lines = []
    P = lines.append
    P(f"# Profil marche XAUUSD - {args.name}\n")
    P(f"- Fichier: `{os.path.basename(args.file)}`")
    P(f"- Barres brutes: {len(df):,}")
    P(f"- Periode: {df['dt'].iloc[0]} -> {df['dt'].iloc[-1]}")
    P(f"- Jours couverts: {len(d):,}")
    if daily_prefix_end is not None:
        P(f"- ATTENTION: barres journalieres (1/jour) jusqu'a {daily_prefix_end}, "
          f"vrai intraday ensuite ({len(intraday):,} barres). "
          f"Analyse horaire/sessions valide uniquement sur la partie intraday.")
    else:
        P(f"- Intraday sur toute la periode ({len(intraday):,} barres).")
    P("")

    P("## 1. Regime annuel (bull / bear / range)\n")
    P(yr.to_markdown(index=False))
    P("")

    P("## 2. Equilibre haussier / baissier (opportunite BUY vs SELL)\n")
    P(f"- Jours UP (open->close): {up:,} ({up/tot*100:.1f}%)")
    P(f"- Jours DOWN: {down:,} ({down/tot*100:.1f}%)")
    P("")

    P("## 3. Profil par jour de semaine (open->close intra-jour)\n")
    P(dow.to_markdown())
    P("")

    P("## 4. Saisonnalite mensuelle (close->close)\n")
    P(ms.to_markdown())
    P("")

    if not hp.empty and intraday is not None and len(intraday) > 100:
        P("## 5. Profil horaire (heure broker, barres intraday)\n")
        P(hp.to_markdown())
        P("")
        P("## 6. Profil par session\n")
        P(sp.to_markdown(index=False))
        P("")

    report_path = os.path.join(args.outdir, f"{args.name}_report.md")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    # echo console
    print("\n".join(lines))
    print(f"\n[OK] {report_path}")
    print(f"[OK] {os.path.join(args.outdir, f'{args.name}_daily.csv')}")


if __name__ == "__main__":
    main()

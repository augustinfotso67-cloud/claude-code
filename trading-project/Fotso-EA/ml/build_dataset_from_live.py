"""
build_dataset_from_live.py — Construit un dataset ML a partir des features
REELLES exportees par l'EA (Fotso_ml_features.csv, mode BrainML_CollectFeatures).

But : garantir l'alignement train == live. Les 36 features viennent directement
du MQL5 (iADX/iATR natifs MT5). On (re)calcule seulement le label depuis les prix
M15 (TP1 avant SL, SL prioritaire intrabar) — identique a build_dataset_v4.py.

Sortie : dataset_live.csv (colonnes f00..f35 + label + direction + timestamp),
compatible avec train_brain.py.

Usage :
  python build_dataset_from_live.py \
    --features "C:/Users/User/Desktop/Nouveau dossier (3)/Fotso_ml_features.csv" \
    --m15      "C:/Users/User/Desktop/Nouveau dossier (3)/xauusd" \
    --out      "C:/Users/User/Fotso-EA/ml/dataset_live.csv"
"""
import argparse, sys
from pathlib import Path
import numpy as np, pandas as pd

N_FEAT = 36
MAX_BARS = 200


def load_m15(data_dir: Path) -> pd.DataFrame:
    f = [x for x in data_dir.iterdir() if "m15" in x.name.lower() and x.suffix == ".csv"][0]
    cols = ["datetime", "open", "high", "low", "close", "volume", "x"]
    try:
        df = pd.read_csv(f, header=0, names=cols, encoding="utf-16")
    except Exception:
        df = pd.read_csv(f, header=0, names=cols, encoding="utf-8")
    df["datetime"] = pd.to_datetime(df["datetime"], format="%Y.%m.%d %H:%M")
    df = df.set_index("datetime").sort_index()
    df = df[~df.index.duplicated(keep="first")]
    return df


def simulate_outcome(m15, entry_idx, direction, entry, sl, tp1, tp2, max_bars=MAX_BARS):
    """SL prioritaire intrabar, BE apres TP1. label = TP1 avant SL. (= build_dataset_v4)"""
    n = len(m15)
    label_tp1 = 0; label_tp2 = 0; tp1_hit = False
    hi_arr = m15["high"].values; lo_arr = m15["low"].values
    for k in range(1, min(max_bars, n - entry_idx)):
        hi = hi_arr[entry_idx + k]; lo = lo_arr[entry_idx + k]
        if direction:  # BUY
            if not tp1_hit:
                if lo <= sl:   break
                if hi >= tp1:  label_tp1 = 1; tp1_hit = True
            else:
                if lo <= entry: break
                if hi >= tp2:   label_tp2 = 1; break
        else:          # SELL
            if not tp1_hit:
                if hi >= sl:   break
                if lo <= tp1:  label_tp1 = 1; tp1_hit = True
            else:
                if hi >= entry: break
                if lo <= tp2:   label_tp2 = 1; break
    return label_tp1, label_tp2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", required=True)
    ap.add_argument("--m15", required=True, help="dossier contenant XAUUSDm M15 CSV")
    ap.add_argument("--out", default=r"C:\Users\User\Fotso-EA\ml\dataset_live.csv")
    a = ap.parse_args()

    feats = pd.read_csv(a.features)
    feats.columns = [c.strip() for c in feats.columns]
    feats["timestamp"] = pd.to_datetime(feats["timestamp"], format="%Y.%m.%d %H:%M", errors="coerce")
    feats = feats.dropna(subset=["timestamp"]).reset_index(drop=True)
    print(f"Features collectees : {len(feats)} signaux, "
          f"{feats.timestamp.min()} -> {feats.timestamp.max()}")
    print(f"  Direction : {(feats.direction=='BUY').sum()} BUY / {(feats.direction=='SELL').sum()} SELL")

    m15 = load_m15(Path(a.m15))
    idx = m15.index

    l1s = []; l2s = []
    for _, r in feats.iterrows():
        pos = idx.searchsorted(r["timestamp"], side="left")
        if pos >= len(idx):
            l1s.append(np.nan); l2s.append(np.nan); continue
        is_buy = (r["direction"] == "BUY")
        a1, a2 = simulate_outcome(m15, int(pos), is_buy,
                                  float(r["entry"]), float(r["sl"]),
                                  float(r["tp1"]), float(r["tp2"]))
        l1s.append(a1); l2s.append(a2)
    feats["label"] = l1s
    feats["label_tp2"] = l2s
    before = len(feats)
    feats = feats.dropna(subset=["label"]).copy()
    feats["label"] = feats["label"].astype(int)
    feats["label_tp2"] = feats["label_tp2"].astype(int)
    print(f"  Labels calcules : {len(feats)} (drop {before-len(feats)} hors plage M15)")

    wr = feats.label.mean() * 100
    wb = feats[feats.direction == "BUY"]; ws = feats[feats.direction == "SELL"]
    print(f"\n=== Dataset live : WR global={wr:.1f}% ===")
    if len(wb): print(f"  BUY  : {len(wb)} signaux, WR={wb.label.mean()*100:.1f}%")
    if len(ws): print(f"  SELL : {len(ws)} signaux, WR={ws.label.mean()*100:.1f}%")

    # verif distribution pwin_live (doit etre large si le brain courant marchait)
    if "pwin_live" in feats.columns:
        pw = pd.to_numeric(feats["pwin_live"], errors="coerce")
        print(f"  pwin_live (brain courant) : min={pw.min():.3f} max={pw.max():.3f} mean={pw.mean():.3f}")

    cols = ["timestamp", "direction", "entry", "sl", "tp1", "tp2", "label", "label_tp2"] + \
           [f"f{i:02d}" for i in range(N_FEAT)]
    feats[cols].to_csv(a.out, index=False)
    print(f"\nDataset ecrit : {a.out}  ({len(feats)} lignes)")


if __name__ == "__main__":
    main()

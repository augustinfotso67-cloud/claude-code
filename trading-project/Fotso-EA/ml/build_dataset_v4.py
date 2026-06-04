"""
build_dataset_h1ema40.py — Dataset ML avec direction H1 EMA40 (EA v6.1)

Identique à build_dataset.py SAUF :
  - Direction gate : H1 EMA40 slope (5 barres) au lieu de H4 EMA200
  - d1_bull_fort / d1_bear_fort : H1 EMA40 ±0.3% (au lieu de D1 ±1.5%)
  - d1_ultra_h : H1 EMA40 +1.0% (au lieu de D1 +0.5%)
  - CS_SkipThreshold : 0.75 (au lieu de 0.85) — correspond à EA v6.1
  - N_FEATURES reste 36 (f00-f35 identiques, H4 features gardés comme features ML)

Usage :
    python build_dataset_h1ema40.py \
        --data_dir "C:/Users/User/Desktop/Nouveau dossier (3)/xauusd" \
        --out "C:/Users/User/Fotso-EA/ml/dataset_xau_v3_h1ema40.csv"
"""

import argparse
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
import indicators as ind

DEFAULTS = {
    "atr_mul"     : 1.8,
    "tp1_rr"      : 1.5,
    "tp2_rr"      : 2.5,
    "min_score"   : 2,     # EA v6.1 : seuilBonus >= 2
    "max_bars_fwd": 200,
    "warmup_bars" : 250,
    "spread_pts"  : 200,
    "adx_min"     : 22.0,
    "range_adx_h4": 20.0,
    "cs_thresh"   : 0.75,  # EA v6.1 : CS_SkipThreshold = 0.75 (vs 0.85 avant)
}

N_FEATURES = 36  # f00-f35 (identique au modèle actuel)


def load_mt5_csv(path: str, tf_name: str) -> pd.DataFrame:
    cols = ["datetime", "open", "high", "low", "close", "volume", "x"]
    try:
        df = pd.read_csv(path, header=0, names=cols, parse_dates=False, encoding="utf-16")
    except Exception:
        df = pd.read_csv(path, header=0, names=cols, parse_dates=False, encoding="utf-16-le")
    sample = str(df["datetime"].iloc[0])
    if " " in sample:
        df["datetime"] = pd.to_datetime(df["datetime"], format="%Y.%m.%d %H:%M")
    else:
        df["datetime"] = pd.to_datetime(df["datetime"], format="%Y.%m.%d")
    df = df.set_index("datetime").drop(columns=["x"])
    df = df.sort_index()
    df = df[~df.index.duplicated(keep="first")]
    print(f"  Loaded {tf_name}: {len(df)} bars  [{df.index[0].date()} -- {df.index[-1].date()}]")
    return df


def compute_tf_indicators(df: pd.DataFrame, tf: str) -> pd.DataFrame:
    o, h, l, c = df["open"], df["high"], df["low"], df["close"]
    df[f"ema200"] = ind.ema(c, 200)
    df[f"ema50"]  = ind.ema(c, 50)
    df[f"atr14"]  = ind.atr(h, l, c, 14)
    df[f"adx14"], df[f"diplus14"], df[f"diminus14"] = ind.adx(h, l, c, 14)

    if tf in ("m15", "m5"):
        df["stoch_k"], df["stoch_d"] = ind.stochastic(h, l, c, 5, 3, 3)
        df["pb_bull"]  = ind.pinbar_bull(o, h, l, c, df["atr14"])
        df["pb_bear"]  = ind.pinbar_bear(o, h, l, c, df["atr14"])
        df["eng_bull"] = ind.engulfing_bull(o, c)
        df["eng_bear"] = ind.engulfing_bear(o, c)

    if tf == "h1":
        df["ema40"]    = ind.ema(c, 40)   # v6.1 : EMA40 H1 = nouvelle direction gate
        df["rsi14"]    = ind.rsi(c, 14)
        df["bb_up"], df["bb_mid"], df["bb_lo"] = ind.bollinger(c, 20, 2.0)
        df["atr_ratio"]  = ind.atr_ratio(df["atr14"], 20)
        df["bb_squeeze"] = ind.bb_squeeze(df["bb_up"], df["bb_lo"], 20)
        df["bos_bull"]   = ind.bos_bull(h, o, c, df["atr14"], 15)
        df["bos_bear"]   = ind.bos_bear(l, o, c, df["atr14"], 15)
        df["near_sup"]   = ind.near_support(l, c, df["atr14"], 40)
        df["near_res"]   = ind.near_resistance(h, c, df["atr14"], 40)
        df["ctx_score"]  = ind.context_score(df.index)
    return df


def compute_adn_phase(adx_h1, atr_ratio, bb_squeeze):
    if adx_h1 < 18 and atr_ratio < 0.8 and bb_squeeze < 0.7:
        return 1
    if adx_h1 < 22 and bb_squeeze < 0.5 and atr_ratio < 0.7:
        return 2
    if 22 <= adx_h1 < 30 and atr_ratio >= 0.9 and bb_squeeze >= 0.7:
        return 3
    if adx_h1 >= 28 and atr_ratio >= 1.2 and bb_squeeze >= 0.9:
        return 4
    return 0


def compute_psy(h1_df, idx):
    if idx < 3:
        return False, False
    rsi_val = h1_df["rsi14"].iloc[idx]
    def lw(i): o=h1_df["open"].iloc[i]; c=h1_df["close"].iloc[i]; l=h1_df["low"].iloc[i]; return min(o,c)-l
    def uw(i): o=h1_df["open"].iloc[i]; c=h1_df["close"].iloc[i]; h=h1_df["high"].iloc[i]; return h-max(o,c)
    atr_ref = h1_df["atr14"].iloc[idx]
    mb1,mb2,mb3 = lw(idx),lw(idx-1),lw(idx-2)
    mh1,mh2,mh3 = uw(idx),uw(idx-1),uw(idx-2)
    lw_growing = (mb1>mb2>mb3) and (mb1>atr_ref*0.20)
    hw_growing = (mh1>mh2>mh3) and (mh1>atr_ref*0.20)
    if lw_growing and rsi_val < 45: return True, True
    if hw_growing and rsi_val > 55: return True, False
    return False, False


def compute_miroir(h1_df, idx, atr_ref):
    if idx < 5:
        return False, False
    prev_high = h1_df["high"].iloc[idx-4:idx-1].max()
    prev_low  = h1_df["low"].iloc[idx-4:idx-1].min()
    close_h1  = h1_df["close"].iloc[idx]
    high_h1   = h1_df["high"].iloc[idx]
    low_h1    = h1_df["low"].iloc[idx]
    faux_bull = (high_h1 > prev_high*1.0005 and close_h1 < prev_high*1.002)
    faux_bear = (low_h1  < prev_low *0.9995 and close_h1 > prev_low *0.998)
    if faux_bull or faux_bear:
        return True, faux_bull
    return False, False


def compute_signal_score(direction, h1_bull, h1_bear,
                          rsi_h1, stoch_k, stoch_k_prev, stoch_d, stoch_d_prev,
                          bos_bull, bos_bear, near_sup, near_res,
                          adx_h1, adx_plus_h1, adx_minus_h1,
                          eng_bull, eng_bear, pb_bull, pb_bear,
                          d1_bull_fort, d1_bear_fort,
                          psy_retour, psy_dir, adn_phase, adn_bullish,
                          mi_manip, mi_piege_haussier,
                          ctx_score, brain_score_h,
                          price_to_h4_ema200, price_to_h4_ema50, atr_h4,
                          adx_min=22.0):
    """v4 : la direction H1 EMA40 n'est plus un veto (contre-tendance ouverte).
    La tendance H1 reste un composant de score (c1) ; c'est le ML qui tranche le sens.
    """
    # v4 : plus de hard-reject sur h1_bull/h1_bear -> BUY et SELL evalues tous deux.
    if adn_phase == 0:
        return 0, 0, False, False, False
    if adn_phase == 1:
        if direction and not (psy_retour and psy_dir):
            return 0, 0, False, False, False
        if not direction and not (psy_retour and not psy_dir):
            return 0, 0, False, False, False

    c1 = h1_bull if direction else h1_bear
    c2 = (38 <= rsi_h1 <= 72) if direction else (28 <= rsi_h1 <= 62)
    c3_class = (
        (stoch_k_prev < stoch_d_prev) and (stoch_k >= stoch_d) and (stoch_k_prev < 30)
    ) if direction else (
        (stoch_k_prev > stoch_d_prev) and (stoch_k <= stoch_d) and (stoch_k_prev > 70)
    )
    c3_pb = (
        (stoch_k_prev < stoch_d_prev) and (stoch_k >= stoch_d) and (20 <= stoch_k_prev <= 55)
    ) if direction else (
        (stoch_k_prev > stoch_d_prev) and (stoch_k <= stoch_d) and (45 <= stoch_k_prev <= 80)
    )
    c3 = c3_class or c3_pb
    pb_zone = c3_pb and not c3_class

    c4 = adx_h1 >= adx_min
    c5 = (adx_plus_h1 > adx_minus_h1) if direction else (adx_minus_h1 > adx_plus_h1)
    c6 = (bos_bull > 0) if direction else (bos_bear > 0)
    c6 = c6 or ((near_sup > 0) if direction else (near_res > 0))

    score_base = int(c1) + int(c2) + int(c3) + int(c4) + int(c5) + int(c6)

    # Bonus
    b1 = d1_bull_fort if direction else d1_bear_fort
    b2 = psy_retour
    b3 = (adn_phase >= 3)
    b4 = mi_manip
    b5 = (eng_bull > 0) if direction else (eng_bear > 0)
    b6 = (pb_bull > 0)  if direction else (pb_bear > 0)
    b7 = ctx_score >= 1.0

    score_bonus = int(b1)+int(b2)+int(b3)+int(b4)+int(b5)+int(b6)+int(b7)

    is_pb = (
        (rsi_h1 <= 48 and c3_pb and True) if direction
        else (rsi_h1 >= 52 and c3_pb and True)
    ) or pb_zone

    valid = (score_base >= 3) and (score_bonus >= 3) and (score_base + score_bonus >= 3)
    return score_base, score_bonus, is_pb, valid, True


def simulate_outcome(m15, entry_idx, direction, entry, sl, tp1, tp2, max_bars=200):
    """Sortie REALISTE (v4) :
      - SL prioritaire en cas d'ambiguite intra-bougie (pessimiste) :
        si une bougie touche a la fois SL et TP, on suppose le SL touche en premier.
      - Apres TP1 (partiel), le SL remonte au break-even (entree) -> au pire 0.
      - label = TP1 atteint avant SL (= trade clos en profit, comme l'EA reel).
    """
    n = len(m15)
    label_tp1 = 0; label_tp2 = 0; tp1_hit = False; bars_out = max_bars
    for k in range(1, min(max_bars, n - entry_idx)):
        row = m15.iloc[entry_idx + k]
        hi, lo = row["high"], row["low"]
        if direction:  # BUY
            if not tp1_hit:
                if lo <= sl:        bars_out = k; break           # SL d'abord
                if hi >= tp1:       label_tp1 = 1; tp1_hit = True  # partiel pris
            else:
                if lo <= entry:     bars_out = k; break           # sorti au break-even
                if hi >= tp2:       label_tp2 = 1; bars_out = k; break
        else:          # SELL
            if not tp1_hit:
                if hi >= sl:        bars_out = k; break
                if lo <= tp1:       label_tp1 = 1; tp1_hit = True
            else:
                if hi >= entry:     bars_out = k; break
                if lo <= tp2:       label_tp2 = 1; bars_out = k; break
    return label_tp1, label_tp2, bars_out


def get_prev_idx(ts_ns, tf_timestamps):
    pos = np.searchsorted(tf_timestamps, ts_ns, side="left") - 1
    return max(0, pos)


def build_dataset(data_dir: str, out_path: str, cfg: dict) -> pd.DataFrame:
    data_dir = Path(data_dir)

    def find_csv(tf_suffix):
        for f in data_dir.iterdir():
            if tf_suffix.lower() in f.name.lower() and f.suffix == ".csv":
                return str(f)
        raise FileNotFoundError(f"CSV non trouvé pour {tf_suffix} dans {data_dir}")

    print("=== Chargement ===")
    m15 = load_mt5_csv(find_csv("M15"),    "M15")
    h1  = load_mt5_csv(find_csv("H1"),     "H1")
    h4  = load_mt5_csv(find_csv("H4"),     "H4")
    try:
        d1 = load_mt5_csv(find_csv("Daily"), "Daily")
    except FileNotFoundError:
        print("  Daily non trouvé, création depuis H4...")
        d1 = h4.resample("D").agg({"open":"first","high":"max","low":"min","close":"last","volume":"sum"}).dropna()

    print("\n=== Indicateurs ===")
    m15 = compute_tf_indicators(m15, "m15")
    h1  = compute_tf_indicators(h1,  "h1")
    h4  = compute_tf_indicators(h4,  "h4")
    d1["ema200"] = ind.ema(d1["close"], 200)
    d1["atr14"]  = ind.atr(d1["high"], d1["low"], d1["close"], 14)

    h4["ema200_slope"] = h4["ema200"].diff(5)
    h4["ema50_slope"]  = h4["ema50"].diff(5)

    h1_ts  = h1.index.values.astype("int64")
    h4_ts  = h4.index.values.astype("int64")
    d1_ts  = d1.index.values.astype("int64")
    m15_ts = m15.index.values.astype("int64")

    atr_mul   = cfg.get("atr_mul",   DEFAULTS["atr_mul"])
    tp1_rr    = cfg.get("tp1_rr",    DEFAULTS["tp1_rr"])
    tp2_rr    = cfg.get("tp2_rr",    DEFAULTS["tp2_rr"])
    max_fwd   = cfg.get("max_bars_fwd", DEFAULTS["max_bars_fwd"])
    warmup    = cfg.get("warmup_bars",  DEFAULTS["warmup_bars"])
    adx_min   = cfg.get("adx_min",   DEFAULTS["adx_min"])
    min_score = cfg.get("min_score",  DEFAULTS["min_score"])
    cs_thresh = cfg.get("cs_thresh",  DEFAULTS["cs_thresh"])

    records = []
    n_m15 = len(m15)
    progress_step = max(1, (n_m15 - warmup) // 20)
    print(f"\n=== Scan signaux H1 EMA40 ({n_m15 - warmup} barres M15) ===")

    for i in range(warmup, n_m15 - max_fwd - 1):
        if (i - warmup) % progress_step == 0:
            pct = (i - warmup) / (n_m15 - warmup - max_fwd) * 100
            print(f"  {pct:.0f}%  bar {i}/{n_m15}  signals={len(records)}")

        ts_ns    = m15_ts[i]
        bar_m15  = m15.iloc[i]
        hour     = bar_m15.name.hour
        dow      = bar_m15.name.weekday()

        # Session filter (identique EA)
        if not ((2 <= hour < 13) or (14 <= hour < 23)):
            continue
        if dow >= 5:
            continue

        ih1 = get_prev_idx(ts_ns, h1_ts)
        ih4 = get_prev_idx(ts_ns, h4_ts)
        id1 = get_prev_idx(ts_ns, d1_ts)

        if ih1 < 50 or ih4 < 50 or id1 < 50:
            continue

        r_h1 = h1.iloc[ih1]
        r_h4 = h4.iloc[ih4]
        r_d1 = d1.iloc[id1]

        if pd.isna(r_h1.get("rsi14", np.nan)):
            continue
        if pd.isna(r_h1.get("ema40", np.nan)):
            continue
        if pd.isna(r_h4["ema200"]):
            continue
        if pd.isna(r_d1["ema200"]):
            continue

        close      = bar_m15["close"]
        atr_h1_val = r_h1["atr14"]
        atr_h4_val = r_h4["atr14"]
        atr_m15_val = bar_m15["atr14"]

        if atr_h1_val <= 0 or atr_h4_val <= 0 or atr_m15_val <= 0:
            continue

        # Range filter H4
        if ih4 >= 3:
            adx_h4_vals = [h4["adx14"].iloc[ih4-k] for k in range(1, 4)]
            if all(a < cfg.get("range_adx_h4", DEFAULTS["range_adx_h4"]) for a in adx_h4_vals):
                continue

        # ── H1 EMA40 direction gate (v6.1) ──────────────────────────────
        h1_ema40       = r_h1["ema40"]
        h1_ema40_5bars = h1["ema40"].iloc[max(0, ih1 - 5)]
        h1_ema40_10b   = h1["ema40"].iloc[max(0, ih1 - 10)]
        h1_bull = (h1_ema40 > h1_ema40_5bars) and h1_ema40 > 0
        h1_bear = (h1_ema40 < h1_ema40_5bars) and h1_ema40 > 0

        # d1_bull_fort/bear_fort : H1 EMA40 ±0.3% (EA v6.1)
        d1_bull_f = close > h1_ema40 * 1.003
        d1_bear_f = close < h1_ema40 * 0.997
        # d1_ultra_h : H1 EMA40 +1.0% blocks SELL (EA v6.1)
        d1_ultra_h = close > h1_ema40 * 1.010

        # ── H4 EMA200 (gardé uniquement pour features ML f14/f16/f17) ──
        ema200_h4       = r_h4["ema200"]
        ema50_h4        = r_h4["ema50"]
        ema200_h4_5bars = h4["ema200"].iloc[max(0, ih4 - 5)]
        ema50_h4_5bars  = h4["ema50"].iloc[max(0, ih4 - 5)]

        # D1 EMA200 distance (feature f10)
        ema200_d1   = r_d1["ema200"]
        d1_dist_pct = (close - ema200_d1) / ema200_d1 * 100 if ema200_d1 > 0 else 0

        # ADN
        adn_phase = compute_adn_phase(r_h1["adx14"], r_h1.get("atr_ratio", 1.0), r_h1.get("bb_squeeze", 1.0))
        adn_bull  = r_h1["diplus14"] > r_h1["diminus14"]

        # PSY, Miroir
        psy_retour, psy_dir = compute_psy(h1, ih1)
        mi_manip, mi_piege_h = compute_miroir(h1, ih1, atr_h1_val)

        # Context score
        ctx_sc = r_h1.get("ctx_score",
                           ind.SCORE_HEURES[bar_m15.name.hour] *
                           ind.SCORE_JOURS[bar_m15.name.weekday()])

        # CS threshold EA v6.1 = 0.75
        if ctx_sc < cs_thresh:
            continue

        # Stoch M15
        rsi_h1_val = r_h1["rsi14"]
        stk     = bar_m15.get("stoch_k", float("nan"))
        std_val = bar_m15.get("stoch_d", float("nan"))
        stk_pr  = m15["stoch_k"].iloc[i-1] if i > 0 else stk
        std_pr  = m15["stoch_d"].iloc[i-1] if i > 0 else std_val
        if pd.isna(stk) or pd.isna(std_val):
            continue

        adx_h4_val     = r_h4["adx14"]
        price_to_h4_200 = (close - ema200_h4) / atr_h4_val if atr_h4_val > 0 else 0
        price_to_h4_50  = (close - ema50_h4)  / atr_h4_val if atr_h4_val > 0 else 0

        bb_up  = r_h1.get("bb_up",  close)
        bb_mid = r_h1.get("bb_mid", close)
        bb_lo  = r_h1.get("bb_lo",  close)
        bb_pos_val = (close - bb_mid) / (bb_up - bb_lo + 1e-9)
        bb_sq_val  = r_h1.get("bb_squeeze", 1.0)
        atr_rat_val = r_h1.get("atr_ratio", 1.0)

        eng_b  = int(bar_m15.get("eng_bull", 0))
        eng_br = int(bar_m15.get("eng_bear", 0))
        pb_b   = int(bar_m15.get("pb_bull",  0))
        pb_br  = int(bar_m15.get("pb_bear",  0))
        bos_b  = int(r_h1.get("bos_bull", 0))
        bos_br = int(r_h1.get("bos_bear", 0))
        ns     = int(r_h1.get("near_sup", 0))
        nr     = int(r_h1.get("near_res", 0))

        for direction in [True, False]:  # True=BUY, False=SELL
            # v4 : blocage d1_ultra_h retire -> SELL contre-tendance autorise, le ML filtre.

            sb, sbo, is_pb, valid, _ = compute_signal_score(
                direction,
                h1_bull, h1_bear,
                rsi_h1_val, stk, stk_pr, std_val, std_pr,
                bos_b, bos_br, ns, nr,
                r_h1["adx14"], r_h1["diplus14"], r_h1["diminus14"],
                eng_b, eng_br, pb_b, pb_br,
                d1_bull_f, d1_bear_f,
                psy_retour, psy_dir, adn_phase, adn_bull,
                mi_manip, mi_piege_h,
                ctx_sc, ctx_sc,
                price_to_h4_200, price_to_h4_50, atr_h4_val,
                adx_min=adx_min
            )

            if sb < min_score:
                continue

            atr_mul_final = min(atr_mul, 1.5) if is_pb else atr_mul
            sl_dist = atr_h1_val * atr_mul_final

            if direction:
                entry = close; sl = entry - sl_dist
                tp1 = entry + sl_dist * tp1_rr; tp2 = entry + sl_dist * tp2_rr
            else:
                entry = close; sl = entry + sl_dist
                tp1 = entry - sl_dist * tp1_rr; tp2 = entry - sl_dist * tp2_rr

            lbl_tp1, lbl_tp2, bars_out = simulate_outcome(m15, i, direction, entry, sl, tp1, tp2, max_fwd)

            h_sin = np.sin(2*np.pi*hour/24); h_cos = np.cos(2*np.pi*hour/24)
            d_sin = np.sin(2*np.pi*dow/7);   d_cos = np.cos(2*np.pi*dow/7)

            # Feature vector f00-f35 (IDENTIQUE au modèle actuel)
            feat = [
                rsi_h1_val / 100.0,                                                    # 0  rsi_h1_norm
                stk    / 100.0,                                                         # 1  stoch_k_norm (M15)
                std_val / 100.0,                                                        # 2  stoch_d_norm (M15)
                r_h1["adx14"] / 100.0,                                                  # 3  adx_h1_norm
                r_h1["diplus14"] / 100.0,                                               # 4  adxplus_h1_norm
                r_h1["diminus14"] / 100.0,                                              # 5  adxminus_h1_norm
                adx_h4_val / 100.0,                                                     # 6  adx_h4_norm
                atr_m15_val / (close + 1e-9),                                           # 7  atr_m15_rel
                atr_h1_val  / (close + 1e-9),                                           # 8  atr_h1_rel
                atr_h4_val  / (close + 1e-9),                                           # 9  atr_h4_rel
                float(np.clip(d1_dist_pct, -20, 20)),                                   # 10 ema200d1_dist
                float(np.clip(bb_pos_val,  -2,  2)),                                    # 11 bb_pos
                float(np.clip(bb_sq_val,    0,  3)),                                    # 12 bb_squeeze
                float(np.clip(atr_rat_val,  0,  5)),                                    # 13 atr_ratio_h1
                float(np.clip((ema200_h4 - ema200_h4_5bars) / (atr_h4_val+1e-9), -5,5)),# 14 h4_ema200_slope
                float(np.clip((ema50_h4  - ema50_h4_5bars)  / (atr_h4_val+1e-9), -5,5)),# 15 h4_ema50_slope
                float(np.clip(price_to_h4_200, -10, 10)),                               # 16 price_to_h4_ema200
                float(np.clip(price_to_h4_50,  -10, 10)),                               # 17 price_to_h4_ema50
                float(h_sin), float(h_cos),                                             # 18-19 hour
                float(d_sin), float(d_cos),                                             # 20-21 dow
                float(np.clip(ctx_sc, 0.5, 1.5)),                                      # 22 context_score
                1.0 if direction else 0.0,                                              # 23 direction
                1.0 if is_pb else 0.0,                                                  # 24 is_pullback
                sb  / 6.0,                                                              # 25 score_base_norm
                sbo / 7.0,                                                              # 26 score_bonus_norm
                adn_phase / 4.0,                                                        # 27 adn_phase_norm
                1.0 if psy_retour else 0.0,                                             # 28 psy_retour
                1.0 if psy_dir    else 0.0,                                             # 29 psy_dir_haussier
                1.0 if mi_manip   else 0.0,                                             # 30 mi_manip
                1.0 if (bos_b if direction else bos_br) else 0.0,                      # 31 bos_signal
                1.0 if (ns   if direction else nr)     else 0.0,                       # 32 near_level
                float(np.clip(atr_m15_val / (atr_h1_val + 1e-9), 0, 2)),              # 33 spread_ratio (ATR ratio)
                0.5,  # 34 recent_wr_20 — sera recalculé par add_regime_feature.py
                0.5,  # 35 recent_wr_5  — sera recalculé
            ]

            assert len(feat) == N_FEATURES, f"Feature vector size mismatch: {len(feat)}"

            records.append({
                "timestamp"    : bar_m15.name,
                "direction"    : "BUY" if direction else "SELL",
                "entry"        : round(entry, 5),
                "sl"           : round(sl, 5),
                "tp1"          : round(tp1, 5),
                "tp2"          : round(tp2, 5),
                "sl_dist"      : round(sl_dist, 5),
                "label_tp1"    : lbl_tp1,
                "label_tp2"    : lbl_tp2,
                "label"        : lbl_tp1,
                "bars_to_close": bars_out,
                "score_base"   : sb,
                "score_bonus"  : sbo,
                "valid_signal" : int(valid),
                "is_pullback"  : int(is_pb),
                **{f"f{i:02d}": v for i, v in enumerate(feat)},
                "hour"         : hour,
                "dow"          : dow,
                "atn_h1"       : round(atr_h1_val, 5),
                "atr_h4"       : round(atr_h4_val, 5),
                "adx_h1"       : round(r_h1["adx14"], 3),
                "adx_h4"       : round(adx_h4_val, 3),
                "rsi_h1"       : round(rsi_h1_val, 2),
                "ctx_score"    : round(ctx_sc, 4),
                "d1_dist_pct"  : round(d1_dist_pct, 4),
                "adn_phase"    : adn_phase,
            })

    df_out = pd.DataFrame(records)
    if len(df_out) == 0:
        print("ERREUR : aucun signal trouvé !")
        return df_out

    print(f"\n=== Dataset H1 EMA40 : {len(df_out)} signaux ===")
    print(f"  Periode : {df_out.timestamp.min().date()} -> {df_out.timestamp.max().date()}")
    print(f"  WR global : {df_out.label.mean()*100:.1f}%")
    buy_mask  = df_out.direction == "BUY"
    sell_mask = df_out.direction == "SELL"
    print(f"  BUY  : {buy_mask.sum()} signaux, WR={df_out.loc[buy_mask,'label'].mean()*100:.1f}%")
    print(f"  SELL : {sell_mask.sum()} signaux, WR={df_out.loc[sell_mask,'label'].mean()*100:.1f}%")

    # Ajouter les features de régime f34/f35
    from add_regime_feature import add_regime_features
    df_out = add_regime_features(df_out)

    df_out.to_csv(out_path, index=False)
    print(f"\nSauvegardé : {out_path}")
    return df_out


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", default=r"C:\Users\User\Desktop\Nouveau dossier (3)\xauusd")
    parser.add_argument("--out",      default=r"C:\Users\User\Fotso-EA\ml\dataset_xau_v3_h1ema40.csv")
    args = parser.parse_args()

    cfg = dict(DEFAULTS)
    df = build_dataset(args.data_dir, args.out, cfg)
    print(f"\nTerminé. {len(df)} signaux dans {args.out}")

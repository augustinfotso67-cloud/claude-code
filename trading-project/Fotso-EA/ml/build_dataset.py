"""
build_dataset.py — Pipeline complet : CSV multi-TF -> dataset ML labellisé

Usage :
    python build_dataset.py --data_dir "C:/Users/User/Desktop/Nouveau dossier (3)/xa"
                            --out dataset_xau.csv
                            [--pair xau]
                            [--atr_mul 1.8]
                            [--tp1_rr 1.5] [--tp2_rr 2.5]
                            [--min_score 2]   # seuil bas pour capturer plus de candidats

Sortie :
    dataset_xau.csv   — une ligne par trade candidat (signal EA détecté)
    Colonnes : [features...] + label (1=WIN_TP1, 0=LOSS_SL) + meta

Stratégie anti-lookahead :
    - Pour chaque barre M15 fermée à l'index i, on utilise :
      * H1 : dernière barre H1 fermée AVANT le début de la barre M15[i]
      * H4 : idem
      * D1 : idem
    - La labellisation se fait sur les barres M15 SUIVANTES (i+1 ...) -> pas de fuite

Vecteur de features ONNX (34 dimensions, float32) :
    0  rsi_h1_norm          RSI H1 / 100
    1  stoch_k_norm         Stoch K M15 / 100
    2  stoch_d_norm         Stoch D M15 / 100
    3  adx_h1_norm          ADX H1 / 100
    4  adxplus_h1_norm      DI+ H1 / 100
    5  adxminus_h1_norm     DI- H1 / 100
    6  adx_h4_norm          ADX H4 / 100
    7  atr_m15_rel          ATR M15 / close
    8  atr_h1_rel           ATR H1 / close
    9  atr_h4_rel           ATR H4 / close
    10 ema200d1_dist        (close - EMA200_D1) / EMA200_D1 * 100
    11 bb_pos               (close - BB_mid) / (BB_upper - BB_lower + eps)
    12 bb_squeeze           BB_width / BB_width_avg20
    13 atr_ratio_h1         ATR_H1 / ATR_H1_avg20
    14 h4_ema200_slope      (EMA200_H4 - EMA200_H4[5bars]) / ATR_H4
    15 h4_ema50_slope       (EMA50_H4  - EMA50_H4[5bars])  / ATR_H4
    16 price_to_h4_ema200   (close - EMA200_H4) / ATR_H4
    17 price_to_h4_ema50    (close - EMA50_H4)  / ATR_H4
    18 hour_sin             sin(2π * hour / 24)
    19 hour_cos             cos(2π * hour / 24)
    20 dow_sin              sin(2π * dow / 7)
    21 dow_cos              cos(2π * dow / 7)
    22 context_score        score heure × score jour (pré-calibré)
    23 direction            1=BUY, 0=SELL
    24 is_pullback           1=pullback, 0=tendance
    25 score_base_norm      score base / 6
    26 score_bonus_norm     score bonus / 7
    27 adn_phase_norm       phase ADN / 4  (0=INCONNUE..4=EXPLOSION)
    28 psy_retour           1=retournement imminent PSY
    29 psy_dir_haussier     1=direction haussière PSY
    30 mi_manip             1=manipulation institutionnelle détectée
    31 bos_signal           1=BOS dans direction du signal
    32 near_level           1=proche support/résistance
    33 spread_ratio         spread_pts / ATR_M15_pts (coût relatif)
"""

import argparse
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd

# Ajouter le dossier tools au path
sys.path.insert(0, str(Path(__file__).parent))
import indicators as ind

# ─────────────────────────────────────────────────────────────
# PARAMÈTRES PAR DÉFAUT (identiques à l'EA v5.6+D1.1)
# ─────────────────────────────────────────────────────────────
DEFAULTS = {
    "atr_mul"     : 1.8,   # XAU : min(ATRmul, 1.8) pour tendance
    "tp1_rr"      : 1.5,
    "tp2_rr"      : 2.5,
    "min_score"   : 2,     # seuil bas (EA = 3) pour capturer candidats borderline
    "max_bars_fwd": 200,   # barres M15 max pour trouver outcome
    "warmup_bars" : 250,   # barres M15 initiales ignorées (warmup indicateurs)
    "spread_pts"  : 200,   # spread XAU moyen (points)
    "adx_min"     : 22.0,  # seuil ADX identique EA
    "range_adx_h4": 20.0,  # seuil range filter H4
}

N_FEATURES = 34  # taille du vecteur ONNX


# ─────────────────────────────────────────────────────────────
# LECTURE CSV MT5
# Format : "2023.08.13 22:00,open,high,low,close,vol,0"
#       ou "2023.08.13,open,high,low,close,vol,0"  (daily)
# ─────────────────────────────────────────────────────────────
def load_mt5_csv(path: str, tf_name: str) -> pd.DataFrame:
    cols = ["datetime", "open", "high", "low", "close", "volume", "x"]
    # MT5 exporte en UTF-16 LE avec BOM (0xFF 0xFE)
    # encoding="utf-16" gère le BOM automatiquement
    try:
        df = pd.read_csv(path, header=0, names=cols, parse_dates=False,
                         encoding="utf-16")
    except Exception:
        df = pd.read_csv(path, header=0, names=cols, parse_dates=False,
                         encoding="utf-16-le")

    # Parser la date selon le format
    sample = str(df["datetime"].iloc[0])
    if " " in sample:
        df["datetime"] = pd.to_datetime(df["datetime"], format="%Y.%m.%d %H:%M")
    else:
        df["datetime"] = pd.to_datetime(df["datetime"], format="%Y.%m.%d")

    df = df.set_index("datetime").drop(columns=["x"])
    df = df.sort_index()
    df = df[~df.index.duplicated(keep="first")]
    print(f"  Loaded {tf_name}: {len(df)} bars  "
          f"[{df.index[0].date()} -- {df.index[-1].date()}]")
    return df


# ─────────────────────────────────────────────────────────────
# CALCUL INDICATEURS PAR TIMEFRAME
# ─────────────────────────────────────────────────────────────
def compute_tf_indicators(df: pd.DataFrame, tf: str) -> pd.DataFrame:
    """Ajoute toutes les colonnes d'indicateurs au DataFrame."""
    o, h, l, c = df["open"], df["high"], df["low"], df["close"]

    df[f"ema200"]     = ind.ema(c, 200)
    df[f"ema50"]      = ind.ema(c, 50)
    df[f"atr14"]      = ind.atr(h, l, c, 14)
    df[f"adx14"], df[f"diplus14"], df[f"diminus14"] = ind.adx(h, l, c, 14)

    if tf in ("m15", "m5"):
        df["stoch_k"], df["stoch_d"] = ind.stochastic(h, l, c, 5, 3, 3)
        df["pb_bull"]  = ind.pinbar_bull(o, h, l, c, df["atr14"])
        df["pb_bear"]  = ind.pinbar_bear(o, h, l, c, df["atr14"])
        df["eng_bull"] = ind.engulfing_bull(o, c)
        df["eng_bear"] = ind.engulfing_bear(o, c)

    if tf == "h1":
        df["rsi14"]    = ind.rsi(c, 14)
        df["bb_up"], df["bb_mid"], df["bb_lo"] = ind.bollinger(c, 20, 2.0)
        df["atr_ratio"]  = ind.atr_ratio(df["atr14"], 20)
        df["bb_squeeze"] = ind.bb_squeeze(df["bb_up"], df["bb_lo"], 20)
        df["bos_bull"]   = ind.bos_bull(h, o, c, df["atr14"], 15)
        df["bos_bear"]   = ind.bos_bear(l, o, c, df["atr14"], 15)
        # near_support / near_resistance : coûteux -> calculé par batch
        # on les compute ici avec la fonction vectorisée optimisée
        df["near_sup"]   = ind.near_support(l, c, df["atr14"], 40)
        df["near_res"]   = ind.near_resistance(h, c, df["atr14"], 40)
        df["ctx_score"]  = ind.context_score(df.index)

    return df


# ─────────────────────────────────────────────────────────────
# ADN DU MOUVEMENT (réplique identique MQL5)
# Phase 0=INCONNUE 1=ACCUMULATION 2=COMPRESSION 3=DECLENCHEUR 4=EXPLOSION
# ─────────────────────────────────────────────────────────────
def compute_adn_phase(adx_h1: float, atr_ratio: float,
                      bb_squeeze: float) -> int:
    if adx_h1 < 18 and atr_ratio < 0.8 and bb_squeeze < 0.7:
        return 1  # ACCUMULATION
    if adx_h1 < 22 and bb_squeeze < 0.5 and atr_ratio < 0.7:
        return 2  # COMPRESSION
    if 22 <= adx_h1 < 30 and atr_ratio >= 0.9 and bb_squeeze >= 0.7:
        return 3  # DECLENCHEUR
    if adx_h1 >= 28 and atr_ratio >= 1.2 and bb_squeeze >= 0.9:
        return 4  # EXPLOSION
    return 0  # INCONNUE


def adn_is_bullish(adx_plus: float, adx_minus: float) -> bool:
    return adx_plus > adx_minus


# ─────────────────────────────────────────────────────────────
# PSY RETOURNEMENT (réplique simplifiée MQL5)
# ─────────────────────────────────────────────────────────────
def compute_psy(h1_df: pd.DataFrame, idx: int):
    """
    Retourne (retour_imm: bool, dir_haussier: bool)
    Condition MQL5 : mèches basses croissantes sur 2 barres consécutives
    + RSI < 45 (bullish) ou mèches hautes croissantes + RSI > 55 (bearish)
    """
    if idx < 3:
        return False, False

    rsi_val = h1_df["rsi14"].iloc[idx]

    def lower_wick(i):
        o = h1_df["open"].iloc[i]
        c = h1_df["close"].iloc[i]
        l = h1_df["low"].iloc[i]
        return min(o, c) - l

    def upper_wick(i):
        o = h1_df["open"].iloc[i]
        c = h1_df["close"].iloc[i]
        h = h1_df["high"].iloc[i]
        return h - max(o, c)

    atr_ref = h1_df["atr14"].iloc[idx]
    mb1, mb2, mb3 = lower_wick(idx), lower_wick(idx-1), lower_wick(idx-2)
    mh1, mh2, mh3 = upper_wick(idx), upper_wick(idx-1), upper_wick(idx-2)

    lw_growing = (mb1 > mb2 > mb3) and (mb1 > atr_ref * 0.20)
    hw_growing = (mh1 > mh2 > mh3) and (mh1 > atr_ref * 0.20)

    if lw_growing and rsi_val < 45:
        return True, True   # retournement haussier imminent
    if hw_growing and rsi_val > 55:
        return True, False  # retournement baissier imminent
    return False, False


# ─────────────────────────────────────────────────────────────
# MIROIR INSTITUTIONNEL (réplique simplifiée MQL5)
# Faux break : bougie H1 brise prev high/low mais re-clôture dedans
# ─────────────────────────────────────────────────────────────
def compute_miroir(h1_df: pd.DataFrame, idx: int, atr_ref: float):
    """
    Retourne (manipulation: bool, piege_haussier: bool)
    """
    if idx < 5:
        return False, False

    prev_high = h1_df["high"].iloc[idx-4:idx-1].max()
    prev_low  = h1_df["low"].iloc[idx-4:idx-1].min()
    close_h1  = h1_df["close"].iloc[idx]
    high_h1   = h1_df["high"].iloc[idx]
    low_h1    = h1_df["low"].iloc[idx]

    faux_bull = (high_h1  > prev_high * 1.0005 and
                 close_h1 < prev_high * 1.002)
    faux_bear = (low_h1   < prev_low  * 0.9995 and
                 close_h1 > prev_low  * 0.998)

    if faux_bull or faux_bear:
        return True, faux_bull
    return False, False


# ─────────────────────────────────────────────────────────────
# SCORE SIGNAL (réplique EvaluerCerveau MQL5)
# ─────────────────────────────────────────────────────────────
def compute_signal_score(direction: bool,  # True=BUY
                         h4_bullish: bool, h4_bearish: bool,
                         h4_bull_strong: bool, h4_bear_strong: bool,
                         rsi_h1: float,
                         stoch_k: float, stoch_k_prev: float,
                         stoch_d: float, stoch_d_prev: float,
                         bos_bull: int, bos_bear: int,
                         near_sup: int, near_res: int,
                         adx_h1: float, adx_plus_h1: float, adx_minus_h1: float,
                         eng_bull: int, eng_bear: int,
                         pb_bull: int, pb_bear: int,
                         # Bonus
                         d1_bull_fort: bool, d1_bear_fort: bool,
                         psy_retour: bool, psy_dir: bool,
                         adn_phase: int, adn_bullish: bool,
                         mi_manip: bool, mi_piege_haussier: bool,
                         ctx_score: float,
                         brain_score_h: float,  # cerveau adaptatif scoreHeures×scoreJours
                         price_to_h4_ema200: float,
                         price_to_h4_ema50: float,
                         atr_h4: float,
                         adx_min: float = 22.0):
    """
    Calcule (score_base, score_bonus, is_pullback, signal_valid)
    Réplique EvaluerCerveau() de FotsoCerveauAdaptatif.mq5 v5.6+D1.1

    score_base  : 6 critères obligatoires (c1-c6)
    score_bonus : 7 critères bonus
    signal_valid: True si score_base>=3 ET score_bonus>=3 ET total>=3

    Retour : (score_base, score_bonus, is_pullback, valid_buy, valid_sell)
    """
    # ── Filtres bloquants ──────────────────────────────────────
    if direction and not h4_bullish:
        return 0, 0, False, False, False
    if not direction and not h4_bearish:
        return 0, 0, False, False, False

    # Phase ADN inconnue -> bloqué
    if adn_phase == 0:
        return 0, 0, False, False, False

    # ADN Accumulation : PSY requis
    if adn_phase == 1:
        if direction and not (psy_retour and psy_dir):
            return 0, 0, False, False, False
        if not direction and not (psy_retour and not psy_dir):
            return 0, 0, False, False, False

    # ── c1 : direction H4 ─────────────────────────────────────
    c1 = h4_bullish if direction else h4_bearish

    # ── c2 : RSI H1 dans zone valide ─────────────────────────
    c2 = (38 <= rsi_h1 <= 72) if direction else (28 <= rsi_h1 <= 62)

    # ── c3 : Stochastic crossover ────────────────────────────
    # Classique BUY: K croise D vers le haut, K_prev < 30
    c3_class = (
        (stoch_k_prev < stoch_d_prev) and
        (stoch_k >= stoch_d) and
        (stoch_k_prev < 30)
    ) if direction else (
        (stoch_k_prev > stoch_d_prev) and
        (stoch_k <= stoch_d) and
        (stoch_k_prev > 70)
    )
    # Pullback : zone élargie
    c3_pb = (
        (stoch_k_prev < stoch_d_prev) and
        (stoch_k >= stoch_d) and
        (20 <= stoch_k_prev <= 55)
    ) if direction else (
        (stoch_k_prev > stoch_d_prev) and
        (stoch_k <= stoch_d) and
        (45 <= stoch_k_prev <= 80)
    )
    c3 = c3_class or c3_pb

    # ── c4 : BOS ou niveau ───────────────────────────────────
    c4 = bool(bos_bull or near_sup) if direction else bool(bos_bear or near_res)

    # ── c5 : ADX fort ────────────────────────────────────────
    c5_adx = (adx_h1 >= adx_min and adx_plus_h1 > adx_minus_h1) if direction \
        else (adx_h1 >= adx_min and adx_minus_h1 > adx_plus_h1)
    h4_et_adn_forts = (h4_bull_strong if direction else h4_bear_strong) and \
                      (adn_phase in (1, 2, 3, 4)) and \
                      (adn_bullish == direction)
    c5 = c5_adx or h4_et_adn_forts

    # ── c6 : Pattern chandelier ──────────────────────────────
    c6 = bool(eng_bull or pb_bull) if direction else bool(eng_bear or pb_bear)

    score_base = sum([c1, c2, c3, c4, c5, c6])
    if not c1:
        return 0, 0, False, False, False
    if not c5 and not h4_et_adn_forts:
        return 0, 0, False, False, False

    # ── BONUS ────────────────────────────────────────────────
    bonus_d1   = d1_bull_fort if direction else d1_bear_fort
    bonus_psy  = (psy_retour and psy_dir == direction)
    bonus_adn  = (adn_phase in (1, 2, 3, 4)) and (adn_bullish == direction)

    bonus_mi   = False
    if mi_manip:
        mi_ok = (not mi_piege_haussier) if direction else mi_piege_haussier
        bonus_mi = mi_ok

    bonus_temp = (brain_score_h >= 1.2)

    bonus_h4f  = h4_bull_strong if direction else h4_bear_strong

    # PullbackZoneH4 : proche EMA200 ou EMA50 H4
    near_ema200 = abs(price_to_h4_ema200) <= 1.5 and atr_h4 > 0
    near_ema50  = abs(price_to_h4_ema50)  <= 1.2 and atr_h4 > 0
    pb_zone     = (near_ema200 or near_ema50) and \
                  (price_to_h4_ema200 > -1.0 if direction else price_to_h4_ema200 < 1.0)

    score_bonus = sum([bonus_d1, bonus_psy, bonus_adn,
                       bonus_mi * 2,   # miroir compte double
                       bonus_temp, bonus_h4f, pb_zone])
    score_bonus = min(score_bonus, 7)

    total = score_base + score_bonus

    # is_pullback
    is_pb = (
        (rsi_h1 <= 48 and c3_pb and (near_sup or True)) if direction
        else (rsi_h1 >= 52 and c3_pb and (near_res or True))
    ) or pb_zone

    valid = (score_base >= 3) and (score_bonus >= 3) and (total >= 3)

    return score_base, score_bonus, is_pb, valid, True


# ─────────────────────────────────────────────────────────────
# SIMULATION LABEL : TP1 ou SL atteint en premier ?
# ─────────────────────────────────────────────────────────────
def simulate_outcome(m15: pd.DataFrame, entry_idx: int, direction: bool,
                     sl: float, tp1: float, tp2: float,
                     max_bars: int = 200):
    """
    Parcourt les barres M15 suivantes et retourne:
      'TP1'     si tp1 atteint avant sl
      'TP2'     si tp2 atteint avant sl (après TP1)
      'SL'      si sl atteint avant tp1
      'TIMEOUT' si aucun des deux dans max_bars
    WR compte chaque sous-position séparément : 2 trades par signal
    -> label_tp1 (0/1), label_tp2 (0/1), bars_to_close
    """
    n = len(m15)
    label_tp1 = 0
    label_tp2 = 0
    tp1_hit   = False
    bars_out  = max_bars

    for k in range(1, min(max_bars, n - entry_idx)):
        row = m15.iloc[entry_idx + k]
        hi, lo = row["high"], row["low"]

        if direction:  # BUY
            if hi >= tp1 and not tp1_hit:
                label_tp1 = 1
                tp1_hit   = True
            if hi >= tp2 and tp1_hit:
                label_tp2 = 1
                bars_out  = k
                break
            if lo <= sl:
                bars_out = k
                break
        else:  # SELL
            if lo <= tp1 and not tp1_hit:
                label_tp1 = 1
                tp1_hit   = True
            if lo <= tp2 and tp1_hit:
                label_tp2 = 1
                bars_out  = k
                break
            if hi >= sl:
                bars_out = k
                break

    return label_tp1, label_tp2, bars_out


# ─────────────────────────────────────────────────────────────
# ALIGNEMENT MULTI-TF : trouver l'index H1/H4/D1 pour un
# timestamp M15 donné (dernière barre fermée avant T)
# ─────────────────────────────────────────────────────────────
def build_tf_lookup(df: pd.DataFrame) -> np.ndarray:
    """Retourne les timestamps comme array numpy pour searchsorted rapide."""
    return df.index.values.astype("int64")


def get_prev_idx(ts_ns: int, tf_timestamps: np.ndarray) -> int:
    """Index de la dernière barre TF fermée strictement avant ts_ns."""
    pos = np.searchsorted(tf_timestamps, ts_ns, side="left") - 1
    return max(0, pos)


# ─────────────────────────────────────────────────────────────
# PIPELINE PRINCIPAL
# ─────────────────────────────────────────────────────────────
def build_dataset(data_dir: str, out_path: str, cfg: dict) -> pd.DataFrame:
    data_dir = Path(data_dir)

    # ── Charger les CSV ──────────────────────────────────────
    print("=== Chargement des données ===")
    pair_upper = cfg.get("pair", "XAUUSD").upper()

    def find_csv(tf_suffix):
        for f in data_dir.iterdir():
            if tf_suffix.lower() in f.name.lower() and f.suffix == ".csv":
                return str(f)
        raise FileNotFoundError(f"CSV non trouvé pour {tf_suffix} dans {data_dir}")

    m15_path = find_csv("M15")
    h1_path  = find_csv("H1")
    h4_path  = find_csv("H4")
    d1_path  = find_csv("Daily") if (data_dir / f"{pair_upper}mDaily.csv").exists() \
               else find_csv("Daily")

    print("Chargement M15...")
    m15 = load_mt5_csv(m15_path, "M15")
    print("Chargement H1...")
    h1  = load_mt5_csv(h1_path,  "H1")
    print("Chargement H4...")
    h4  = load_mt5_csv(h4_path,  "H4")
    print("Chargement Daily...")
    d1  = load_mt5_csv(d1_path,  "Daily")

    # ── Calcul des indicateurs ───────────────────────────────
    print("\n=== Calcul des indicateurs ===")
    print("  M15...")
    m15 = compute_tf_indicators(m15, "m15")
    print("  H1...")
    h1  = compute_tf_indicators(h1,  "h1")
    print("  H4...")
    h4  = compute_tf_indicators(h4,  "h4")
    print("  D1 (EMA200 seulement)...")
    d1["ema200"] = ind.ema(d1["close"], 200)
    d1["atr14"]  = ind.atr(d1["high"], d1["low"], d1["close"], 14)

    # Pentes EMA H4 sur 5 barres (slope)
    h4["ema200_slope"] = h4["ema200"].diff(5)
    h4["ema50_slope"]  = h4["ema50"].diff(5)

    # ── Lookup arrays pour searchsorted ─────────────────────
    h1_ts  = h1.index.values.astype("int64")
    h4_ts  = h4.index.values.astype("int64")
    d1_ts  = d1.index.values.astype("int64")
    m15_ts = m15.index.values.astype("int64")

    min_score = cfg.get("min_score", DEFAULTS["min_score"])
    atr_mul   = cfg.get("atr_mul",   DEFAULTS["atr_mul"])
    tp1_rr    = cfg.get("tp1_rr",    DEFAULTS["tp1_rr"])
    tp2_rr    = cfg.get("tp2_rr",    DEFAULTS["tp2_rr"])
    max_fwd   = cfg.get("max_bars_fwd", DEFAULTS["max_bars_fwd"])
    warmup    = cfg.get("warmup_bars",  DEFAULTS["warmup_bars"])
    spread_pts = cfg.get("spread_pts",  DEFAULTS["spread_pts"])
    adx_min   = cfg.get("adx_min",   DEFAULTS["adx_min"])

    records = []
    n_m15 = len(m15)

    print(f"\n=== Scan des signaux ({n_m15 - warmup} barres M15) ===")
    progress_step = max(1, (n_m15 - warmup) // 20)

    for i in range(warmup, n_m15 - max_fwd - 1):
        if (i - warmup) % progress_step == 0:
            pct = (i - warmup) / (n_m15 - warmup - max_fwd) * 100
            print(f"  {pct:.0f}%  bar {i}/{n_m15}  signals={len(records)}")

        ts_ns = m15_ts[i]
        bar_m15 = m15.iloc[i]

        # ── Aligner les TF ───────────────────────────────────
        ih1 = get_prev_idx(ts_ns, h1_ts)
        ih4 = get_prev_idx(ts_ns, h4_ts)
        id1 = get_prev_idx(ts_ns, d1_ts)

        # Sécurité warmup par TF
        # D1 : 50 barres suffisent pour EMA200 utilisable comme feature ML
        # (210 serait idéal pour convergence parfaite mais réduit la fenêtre de 7 mois)
        if ih1 < 50 or ih4 < 50 or id1 < 50:
            continue

        r_h1 = h1.iloc[ih1]
        r_h4 = h4.iloc[ih4]
        r_d1 = d1.iloc[id1]

        # ── Vérifications données valides ────────────────────
        if pd.isna(r_h1.get("rsi14", np.nan)):
            continue
        if pd.isna(r_h4["ema200"]):
            continue
        if pd.isna(r_d1["ema200"]):
            continue

        close = bar_m15["close"]
        atr_h1_val = r_h1["atr14"]
        atr_h4_val = r_h4["atr14"]
        atr_m15_val = bar_m15["atr14"]

        if atr_h1_val <= 0 or atr_h4_val <= 0 or atr_m15_val <= 0:
            continue

        # ── Range filter H4 (ADX H4 < 20 sur 3 barres) ──────
        if ih4 >= 3:
            adx_h4_vals = [h4["adx14"].iloc[ih4 - k] for k in range(1, 4)]
            if all(a < cfg.get("range_adx_h4", DEFAULTS["range_adx_h4"])
                   for a in adx_h4_vals):
                continue  # marché en range -> EA ne trade pas

        # ── Spread filter ────────────────────────────────────
        spread_ratio = spread_pts / (atr_m15_val / 0.01)  # normaliser en points
        # (simplifié : juste stocker le ratio pour la feature)

        # ── Direction EMA H4 ─────────────────────────────────
        ema200_h4 = r_h4["ema200"]
        ema50_h4  = r_h4["ema50"]
        ema200_h4_5bars = h4["ema200"].iloc[max(0, ih4 - 5)]
        ema50_h4_5bars  = h4["ema50"].iloc[max(0, ih4 - 5)]

        h4_bull     = (ema200_h4 > ema200_h4_5bars) and ema200_h4 > 0
        h4_bear     = (ema200_h4 < ema200_h4_5bars) and ema200_h4 > 0
        h4_5back    = h4["ema200"].iloc[max(0, ih4 - 5)]
        h4_10back   = h4["ema200"].iloc[max(0, ih4 - 10)]
        h4_bull_str = h4_bull and (ema200_h4_5bars > h4_10back)
        h4_bear_str = h4_bear and (ema200_h4_5bars < h4_10back)

        # ── EMA200 D1 ────────────────────────────────────────
        ema200_d1   = r_d1["ema200"]
        d1_dist_pct = (close - ema200_d1) / ema200_d1 * 100 if ema200_d1 > 0 else 0
        d1_bull_f   = close > ema200_d1 * 1.015
        d1_bear_f   = close < ema200_d1 * 0.985
        d1_ultra_h  = close > ema200_d1 * 1.005

        # ── ADN phase ────────────────────────────────────────
        adn_phase = compute_adn_phase(
            r_h1["adx14"],
            r_h1.get("atr_ratio", 1.0),
            r_h1.get("bb_squeeze", 1.0)
        )
        adn_bull = adn_is_bullish(r_h1["diplus14"], r_h1["diminus14"])

        # ── PSY ──────────────────────────────────────────────
        psy_retour, psy_dir = compute_psy(h1, ih1)

        # ── Miroir Institutionnel ────────────────────────────
        mi_manip, mi_piege_h = compute_miroir(h1, ih1, atr_h1_val)

        # ── Context Score ────────────────────────────────────
        ctx_sc = r_h1.get("ctx_score",
                           ind.SCORE_HEURES[bar_m15.name.hour] *
                           ind.SCORE_JOURS[bar_m15.name.weekday()])

        # Skip si contexte très défavorable (< 0.85, identique EA)
        if ctx_sc < 0.85:
            continue

        # ── Session filter (Londres 2-13h / NY 14-23h) ──────
        hour = bar_m15.name.hour
        dow  = bar_m15.name.weekday()  # 0=Lun, 6=Dim
        in_session = ((2 <= hour < 13) or (14 <= hour < 23))
        if not in_session:
            continue
        if dow >= 5:  # week-end
            continue

        # ── Scores M15 courants ──────────────────────────────
        rsi_h1_val = r_h1["rsi14"]
        stk     = bar_m15.get("stoch_k", float("nan"))
        std_val = bar_m15.get("stoch_d", float("nan"))
        stk_pr  = m15["stoch_k"].iloc[i-1] if i > 0 else stk
        std_pr  = m15["stoch_d"].iloc[i-1] if i > 0 else std_val

        if pd.isna(stk) or pd.isna(std_val):
            continue

        # Indicateurs H4
        adx_h4_val  = r_h4["adx14"]
        price_to_h4_200 = (close - ema200_h4) / atr_h4_val if atr_h4_val > 0 else 0
        price_to_h4_50  = (close - ema50_h4)  / atr_h4_val if atr_h4_val > 0 else 0

        # BB H1
        bb_up  = r_h1.get("bb_up",  close)
        bb_mid = r_h1.get("bb_mid", close)
        bb_lo  = r_h1.get("bb_lo",  close)
        bb_w   = bb_up - bb_lo
        bb_pos_val  = (close - bb_mid) / (bb_w + 1e-9)
        bb_sq_val   = r_h1.get("bb_squeeze", 1.0)
        atr_rat_val = r_h1.get("atr_ratio", 1.0)

        # Patterns M15
        eng_b  = int(bar_m15.get("eng_bull", 0))
        eng_br = int(bar_m15.get("eng_bear", 0))
        pb_b   = int(bar_m15.get("pb_bull",  0))
        pb_br  = int(bar_m15.get("pb_bear",  0))

        # BOS H1, near levels
        bos_b  = int(r_h1.get("bos_bull", 0))
        bos_br = int(r_h1.get("bos_bear", 0))
        ns     = int(r_h1.get("near_sup", 0))
        nr     = int(r_h1.get("near_res", 0))

        # Cerveau adaptatif (temps) : ici on utilise le context score
        brain_score_h = ctx_sc

        # ── Évaluer signaux BUY et SELL ──────────────────────
        for direction in [True, False]:  # True=BUY, False=SELL
            # Filtre D1 (EA bloque SELL si D1 ultra haussier, sauf DualGuard)
            if not direction and d1_ultra_h:
                continue

            sb, sbo, is_pb, valid, _ = compute_signal_score(
                direction,
                h4_bull, h4_bear, h4_bull_str, h4_bear_str,
                rsi_h1_val,
                stk, stk_pr, std_val, std_pr,
                bos_b, bos_br, ns, nr,
                r_h1["adx14"], r_h1["diplus14"], r_h1["diminus14"],
                eng_b, eng_br, pb_b, pb_br,
                d1_bull_f, d1_bear_f,
                psy_retour, psy_dir,
                adn_phase, adn_bull,
                mi_manip, mi_piege_h,
                ctx_sc, brain_score_h,
                price_to_h4_200, price_to_h4_50, atr_h4_val,
                adx_min=adx_min
            )

            # On garde les signaux avec score_base >= min_score
            if sb < min_score:
                continue

            # ── Calculer SL/TP ───────────────────────────────
            atr_mul_final = atr_mul
            if is_pb:
                atr_mul_final = min(atr_mul, 1.5)
            sl_dist = atr_h1_val * atr_mul_final

            if direction:
                entry = close
                sl    = entry - sl_dist
                tp1   = entry + sl_dist * tp1_rr
                tp2   = entry + sl_dist * tp2_rr
            else:
                entry = close
                sl    = entry + sl_dist
                tp1   = entry - sl_dist * tp1_rr
                tp2   = entry - sl_dist * tp2_rr

            # ── Labelisation ─────────────────────────────────
            lbl_tp1, lbl_tp2, bars_out = simulate_outcome(
                m15, i, direction, sl, tp1, tp2, max_fwd
            )

            # ── Construire le vecteur de features (34 dim) ───
            h_sin = np.sin(2 * np.pi * hour / 24)
            h_cos = np.cos(2 * np.pi * hour / 24)
            d_sin = np.sin(2 * np.pi * dow  / 7)
            d_cos = np.cos(2 * np.pi * dow  / 7)

            feat = [
                rsi_h1_val / 100.0,                    # 0
                stk    / 100.0,                         # 1
                std_val / 100.0,                        # 2
                r_h1["adx14"] / 100.0,                  # 3
                r_h1["diplus14"] / 100.0,               # 4
                r_h1["diminus14"] / 100.0,              # 5
                adx_h4_val / 100.0,                     # 6
                atr_m15_val / (close + 1e-9),           # 7
                atr_h1_val  / (close + 1e-9),           # 8
                atr_h4_val  / (close + 1e-9),           # 9
                float(np.clip(d1_dist_pct, -20, 20)),   # 10
                float(np.clip(bb_pos_val,  -2,  2)),    # 11
                float(np.clip(bb_sq_val,    0,  3)),    # 12
                float(np.clip(atr_rat_val,  0,  5)),    # 13
                float(np.clip((ema200_h4 - ema200_h4_5bars) / (atr_h4_val + 1e-9), -5, 5)),  # 14
                float(np.clip((ema50_h4  - ema50_h4_5bars)  / (atr_h4_val + 1e-9), -5, 5)),  # 15
                float(np.clip(price_to_h4_200, -10, 10)),  # 16
                float(np.clip(price_to_h4_50,  -10, 10)),  # 17
                float(h_sin),                            # 18
                float(h_cos),                            # 19
                float(d_sin),                            # 20
                float(d_cos),                            # 21
                float(np.clip(ctx_sc, 0.5, 1.5)),        # 22
                1.0 if direction else 0.0,               # 23
                1.0 if is_pb else 0.0,                   # 24
                sb  / 6.0,                               # 25
                sbo / 7.0,                               # 26
                adn_phase / 4.0,                         # 27
                1.0 if psy_retour else 0.0,              # 28
                1.0 if psy_dir else 0.0,                 # 29
                1.0 if mi_manip else 0.0,                # 30
                1.0 if (bos_b if direction else bos_br) else 0.0,  # 31
                1.0 if (ns if direction else nr) else 0.0,         # 32
                float(np.clip(atr_m15_val / (atr_h1_val + 1e-9), 0, 2)),  # 33
            ]

            assert len(feat) == N_FEATURES, f"Feature vector size: {len(feat)}"

            # ── Enregistrer le trade ─────────────────────────
            records.append({
                "timestamp"   : bar_m15.name,
                "direction"   : "BUY" if direction else "SELL",
                "entry"       : round(entry, 5),
                "sl"          : round(sl, 5),
                "tp1"         : round(tp1, 5),
                "tp2"         : round(tp2, 5),
                "sl_dist"     : round(sl_dist, 5),
                "label_tp1"   : lbl_tp1,
                "label_tp2"   : lbl_tp2,
                "label"       : lbl_tp1,  # target principal : TP1 atteint ?
                "bars_to_close": bars_out,
                "score_base"  : sb,
                "score_bonus" : sbo,
                "valid_signal": int(valid),
                "is_pullback" : int(is_pb),
                # Features ONNX (f00..f33)
                **{f"f{j:02d}": feat[j] for j in range(N_FEATURES)},
                # Meta (non utilisé dans ONNX, mais utile pour analyse)
                "hour"        : hour,
                "dow"         : dow,
                "atn_h1"      : atr_h1_val,
                "atr_h4"      : atr_h4_val,
                "adx_h1"      : r_h1["adx14"],
                "adx_h4"      : adx_h4_val,
                "rsi_h1"      : rsi_h1_val,
                "ctx_score"   : ctx_sc,
                "d1_dist_pct" : d1_dist_pct,
                "adn_phase"   : adn_phase,
            })

    # ── Sauvegarder ─────────────────────────────────────────
    df = pd.DataFrame(records)
    if df.empty:
        print("\n⚠️  Aucun signal détecté. Vérifier les données et paramètres.")
        return df

    df.to_csv(out_path, index=False)
    print(f"\n{'='*60}")
    print(f"Dataset sauvegardé : {out_path}")
    print(f"  Signaux totaux  : {len(df)}")
    print(f"  BUY / SELL      : {(df.direction=='BUY').sum()} / {(df.direction=='SELL').sum()}")
    print(f"  WIN (TP1)       : {df.label.sum()} ({df.label.mean()*100:.1f}%)")
    print(f"  WIN (TP2)       : {df.label_tp2.sum()} ({df.label_tp2.mean()*100:.1f}%)")
    print(f"  Signaux valid   : {df.valid_signal.sum()} (score EA atteint)")
    print(f"  WR signals valid: "
          f"{df[df.valid_signal==1].label.mean()*100:.1f}% "
          f"(n={df.valid_signal.sum()})")
    print(f"  Période         : {df.timestamp.min()} -> {df.timestamp.max()}")
    print(f"{'='*60}")
    return df


# ─────────────────────────────────────────────────────────────
# POINT D'ENTRÉE
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Pipeline ML : CSV MT5 -> dataset labellisé pour brain_v1")
    parser.add_argument("--data_dir", required=True,
                        help="Dossier contenant les CSV MT5 (M15, H1, H4, Daily)")
    parser.add_argument("--out",      default="dataset_xau.csv",
                        help="Chemin du fichier de sortie")
    parser.add_argument("--pair",     default="XAUUSD")
    parser.add_argument("--atr_mul",  type=float, default=DEFAULTS["atr_mul"])
    parser.add_argument("--tp1_rr",   type=float, default=DEFAULTS["tp1_rr"])
    parser.add_argument("--tp2_rr",   type=float, default=DEFAULTS["tp2_rr"])
    parser.add_argument("--min_score",type=int,   default=DEFAULTS["min_score"])
    parser.add_argument("--max_bars_fwd", type=int, default=DEFAULTS["max_bars_fwd"])
    parser.add_argument("--spread_pts",   type=int, default=DEFAULTS["spread_pts"])
    args = parser.parse_args()

    cfg = {
        "pair"         : args.pair,
        "atr_mul"      : args.atr_mul,
        "tp1_rr"       : args.tp1_rr,
        "tp2_rr"       : args.tp2_rr,
        "min_score"    : args.min_score,
        "max_bars_fwd" : args.max_bars_fwd,
        "spread_pts"   : args.spread_pts,
    }

    build_dataset(args.data_dir, args.out, cfg)

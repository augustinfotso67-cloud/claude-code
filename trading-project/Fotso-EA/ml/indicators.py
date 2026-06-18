"""
indicators.py — Calcul vectorisé des indicateurs techniques (pandas/numpy)
Réplique fidèle des indicateurs utilisés par FotsoCerveauAdaptatif.mq5

Conventions :
  - Toutes les fonctions prennent des pd.Series en entrée, retournent des pd.Series
  - Les indices temporels sont conservés
  - Wilder smoothing = ewm(alpha=1/period, adjust=False)  (identique MQL5)
  - Pas de lookahead : chaque valeur n'utilise que les barres passées
"""
import numpy as np
import pandas as pd


# ─────────────────────────────────────────────
# EMA  (identique iMA MODE_EMA dans MQL5)
# ─────────────────────────────────────────────
def ema(close: pd.Series, period: int) -> pd.Series:
    return close.ewm(span=period, adjust=False).mean()


# ─────────────────────────────────────────────
# ATR  (Wilder 14 — identique iATR MQL5)
# True Range = max(H-L, |H-Cprev|, |L-Cprev|)
# ─────────────────────────────────────────────
def atr(high: pd.Series, low: pd.Series, close: pd.Series,
        period: int = 14) -> pd.Series:
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low  - prev_close).abs()
    ], axis=1).max(axis=1)
    return tr.ewm(alpha=1.0 / period, adjust=False).mean()


# ─────────────────────────────────────────────
# RSI  (Wilder — identique iRSI MQL5)
# ─────────────────────────────────────────────
def rsi(close: pd.Series, period: int = 14) -> pd.Series:
    delta = close.diff()
    gain  = delta.clip(lower=0)
    loss  = (-delta).clip(lower=0)
    avg_g = gain.ewm(alpha=1.0 / period, adjust=False).mean()
    avg_l = loss.ewm(alpha=1.0 / period, adjust=False).mean()
    rs    = avg_g / avg_l.replace(0, 1e-9)
    return 100.0 - 100.0 / (1.0 + rs)


# ─────────────────────────────────────────────
# ADX  (Wilder — identique iADX MQL5)
# Retourne (adx, plus_di, minus_di)
# ─────────────────────────────────────────────
def adx(high: pd.Series, low: pd.Series, close: pd.Series,
        period: int = 14):
    prev_high  = high.shift(1)
    prev_low   = low.shift(1)
    prev_close = close.shift(1)

    up_move   = high  - prev_high
    down_move = prev_low - low

    plus_dm  = np.where((up_move > down_move) & (up_move > 0),   up_move,   0.0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)

    tr_raw = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low  - prev_close).abs()
    ], axis=1).max(axis=1)

    alpha = 1.0 / period
    atr_s  = tr_raw.ewm(alpha=alpha, adjust=False).mean()
    pdm_s  = pd.Series(plus_dm,  index=high.index).ewm(alpha=alpha, adjust=False).mean()
    mdm_s  = pd.Series(minus_dm, index=high.index).ewm(alpha=alpha, adjust=False).mean()

    plus_di  = 100.0 * pdm_s  / atr_s.replace(0, 1e-9)
    minus_di = 100.0 * mdm_s  / atr_s.replace(0, 1e-9)

    dx  = 100.0 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, 1e-9)
    adx_val = dx.ewm(alpha=alpha, adjust=False).mean()

    return adx_val, plus_di, minus_di


# ─────────────────────────────────────────────
# Stochastic (5-3-3 STO_LOWHIGH — identique iStochastic MQL5)
# K_raw = (close - lowest_low(k)) / (highest_high(k) - lowest_low(k))
# K     = SMA(K_raw, slow)
# D     = SMA(K, d)
# ─────────────────────────────────────────────
def stochastic(high: pd.Series, low: pd.Series, close: pd.Series,
               k_period: int = 5, slow: int = 3,
               d_period: int = 3):
    ll = low.rolling(k_period).min()
    hh = high.rolling(k_period).max()
    k_raw = 100.0 * (close - ll) / (hh - ll + 1e-9)
    k     = k_raw.rolling(slow).mean()
    d     = k.rolling(d_period).mean()
    return k, d


# ─────────────────────────────────────────────
# Bollinger Bands  (identique iBands MQL5)
# ─────────────────────────────────────────────
def bollinger(close: pd.Series, period: int = 20,
              std_mul: float = 2.0):
    mid   = close.rolling(period).mean()
    std   = close.rolling(period).std(ddof=0)
    upper = mid + std_mul * std
    lower = mid - std_mul * std
    return upper, mid, lower


# ─────────────────────────────────────────────
# ATR ratio : ATR actuel / moyenne glissante (régime volatilité)
# ─────────────────────────────────────────────
def atr_ratio(atr_series: pd.Series, window: int = 20) -> pd.Series:
    avg = atr_series.rolling(window).mean()
    return atr_series / avg.replace(0, 1e-9)


# ─────────────────────────────────────────────
# Bollinger squeeze : largeur BB / moyenne largeur BB
# ─────────────────────────────────────────────
def bb_squeeze(upper: pd.Series, lower: pd.Series,
               window: int = 20) -> pd.Series:
    width     = upper - lower
    width_avg = width.rolling(window).mean()
    return width / width_avg.replace(0, 1e-9)


# ─────────────────────────────────────────────
# Détection PinBar M15 (identique MQL5)
# ─────────────────────────────────────────────
def pinbar_bull(open_: pd.Series, high: pd.Series,
                low: pd.Series, close: pd.Series,
                atr_ref: pd.Series) -> pd.Series:
    body       = (close - open_).abs()
    lower_wick = np.minimum(open_.values, close.values) - low.values
    upper_wick = high.values - np.maximum(open_.values, close.values)
    body_nonzero = body.replace(0, 1e-9)
    valid = (
        (lower_wick >= 2.0 * body_nonzero) &
        (upper_wick <= 0.5 * body_nonzero) &
        (lower_wick > atr_ref * 0.15)
    )
    return pd.Series(valid.astype(int), index=open_.index)


def pinbar_bear(open_: pd.Series, high: pd.Series,
                low: pd.Series, close: pd.Series,
                atr_ref: pd.Series) -> pd.Series:
    body       = (close - open_).abs()
    lower_wick = np.minimum(open_.values, close.values) - low.values
    upper_wick = high.values - np.maximum(open_.values, close.values)
    body_nonzero = body.replace(0, 1e-9)
    valid = (
        (upper_wick >= 2.0 * body_nonzero) &
        (lower_wick <= 0.5 * body_nonzero) &
        (upper_wick > atr_ref * 0.15)
    )
    return pd.Series(valid.astype(int), index=open_.index)


# ─────────────────────────────────────────────
# Détection Engulfing M15 (identique MQL5)
# ─────────────────────────────────────────────
def engulfing_bull(open_: pd.Series, close: pd.Series) -> pd.Series:
    o1, c1 = open_, close
    o2, c2 = open_.shift(1), close.shift(1)
    valid = (c1 > o1) & (c2 < o2) & (o1 <= c2) & (c1 >= o2)
    return valid.astype(int)


def engulfing_bear(open_: pd.Series, close: pd.Series) -> pd.Series:
    o1, c1 = open_, close
    o2, c2 = open_.shift(1), close.shift(1)
    valid = (c1 < o1) & (c2 > o2) & (o1 >= c2) & (c1 <= o2)
    return valid.astype(int)


# ─────────────────────────────────────────────
# Break of Structure H1 (identique MQL5)
# BOS haussier : close H1 > max des 15 hauts précédents + body >= ATR×0.2
# ─────────────────────────────────────────────
def bos_bull(high: pd.Series, open_: pd.Series,
             close: pd.Series, atr_ref: pd.Series,
             lookback: int = 15) -> pd.Series:
    prev_high = high.shift(1).rolling(lookback).max()
    body      = (close - open_).abs()
    valid     = (close > prev_high) & (body >= atr_ref * 0.2)
    return valid.fillna(False).astype(int)


def bos_bear(low: pd.Series, open_: pd.Series,
             close: pd.Series, atr_ref: pd.Series,
             lookback: int = 15) -> pd.Series:
    prev_low = low.shift(1).rolling(lookback).min()
    body     = (close - open_).abs()
    valid    = (close < prev_low) & (body >= atr_ref * 0.2)
    return valid.fillna(False).astype(int)


# ─────────────────────────────────────────────
# Near support / resistance H1
# Support : local low dans les 40 barres H1 précédentes, distance <= ATR×1.5
# ─────────────────────────────────────────────
def near_support(low: pd.Series, close: pd.Series,
                 atr_ref: pd.Series, lookback: int = 40) -> pd.Series:
    """
    Détecte si le prix est proche d'un support H1 récent.
    Version vectorisée : rolling min des lows dans la fenêtre.
    Un support valide = low local (min rolling) à distance <= ATR×1.5 du close.
    """
    # Approche vectorisée : low rolling min sur `lookback` barres précédentes
    roll_min = low.shift(1).rolling(lookback).min()
    dist     = (close - roll_min).abs()
    near     = (dist <= atr_ref * 1.5) & (roll_min > 0)
    return near.fillna(False).astype(int)


def near_resistance(high: pd.Series, close: pd.Series,
                    atr_ref: pd.Series, lookback: int = 40) -> pd.Series:
    """
    Détecte si le prix est proche d'une résistance H1 récente.
    Version vectorisée.
    """
    roll_max = high.shift(1).rolling(lookback).max()
    dist     = (close - roll_max).abs()
    near     = (dist <= atr_ref * 1.5) & (roll_max > 0)
    return near.fillna(False).astype(int)


# ─────────────────────────────────────────────
# Context Score pré-calibré (identique MQL5 v5.6)
# Source : 32 mois XAU + 949 trades simulés v5.5
# ─────────────────────────────────────────────
SCORE_HEURES = [
    1.000, 1.000, 0.949, 1.000, 1.000, 1.000,   # 0h-5h
    0.960, 0.924, 1.074, 1.000, 1.077, 1.001,   # 6h-11h
    1.143, 1.000, 1.000, 1.000, 1.000, 1.429,   # 12h-17h
    1.000, 1.000, 1.000, 1.000, 1.000, 1.000,   # 18h-23h
]

SCORE_JOURS = [
    1.190,  # Lundi
    1.066,  # Mardi
    0.893,  # Mercredi
    0.943,  # Jeudi
    0.922,  # Vendredi
    1.000,  # Samedi
    1.000,  # Dimanche
]


def context_score(index: pd.DatetimeIndex) -> pd.Series:
    """
    Retourne scoreHeure × scoreJour pour chaque timestamp.
    dow MQL5 : 0=Dimanche → Python weekday() : 0=Lundi, 6=Dimanche
    On convertit : dayIdx = (dow - 1) % 7 avec dow MQL5 0=Dim → index 6
    """
    hours  = index.hour
    # pandas weekday: 0=Mon..6=Sun → convert to MQL5 convention then to our table
    # Table SCORE_JOURS: 0=Lun..6=Dim (identique Python weekday)
    days   = index.weekday  # 0=Mon..6=Sun
    sh = np.array([SCORE_HEURES[h] for h in hours])
    sd = np.array([SCORE_JOURS[d]  for d in days])
    return pd.Series(sh * sd, index=index)

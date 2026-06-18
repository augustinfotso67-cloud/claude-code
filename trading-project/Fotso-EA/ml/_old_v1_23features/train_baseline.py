"""
Train ML baselines on the trade dataset.
Strategy:
  1. Chronological train/test split (80/20)
  2. Train LogisticRegression + RandomForest + GradientBoosting on training set
  3. Predict P(win) on test set
  4. Simulate: what if we'd only taken trades with P(win) >= threshold?
  5. Compare net PnL: raw EA vs ML-filtered, on the TEST set only
"""
import os
import sys
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import roc_auc_score, brier_score_loss, log_loss
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.pipeline import Pipeline

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'trades.csv')

CAT_FEATURES = ['signal_class', 'adn', 'miroir', 'psy', 'session', 'direction']
NUM_FEATURES = [
    'hour', 'dow', 'month',
    'sl_dist_pct', 'tp_dist_pct', 'rr_target',
    'lots', 'entry',
    'raison_sl_explosion', 'raison_sl_compression',
    'raison_sl_tendance', 'raison_sl_pullback', 'raison_sl_inst',
    # ── ML features from enriched log (only present in 4-year run) ──
    'atr_h1', 'atr_h4', 'adx_h4', 'ema200_d1_pct', 'spread_pts',
    'score_buy', 'score_sell', 'context_score', 'risk_mul', 'risk_used_pct',
    'psy_peur', 'psy_cupidite', 'psy_epuise_vend', 'psy_epuise_ach',
    'adn_force_explo', 'mi_cible_inst',
    'dg_buy_susp', 'dg_sell_ovr',
]


def make_preprocessor():
    return ColumnTransformer([
        ('num', StandardScaler(), NUM_FEATURES),
        ('cat', OneHotEncoder(handle_unknown='ignore'), CAT_FEATURES),
    ])


def main():
    df = pd.read_csv(DATA, parse_dates=['open_ts'])
    df = df.sort_values('open_ts').reset_index(drop=True)
    df = df.dropna(subset=NUM_FEATURES + ['win']).reset_index(drop=True)

    print(f'Total trades: {len(df)}')
    print(f'Date range: {df["open_ts"].min()} → {df["open_ts"].max()}')
    print(f'Overall WR: {df["win"].mean()*100:.1f}%')
    print(f'Sum profit: {df["profit"].sum():.2f}')

    # Chronological split
    split = int(len(df) * 0.8)
    train, test = df.iloc[:split], df.iloc[split:]
    print(f'\n=== SPLIT ===')
    print(f'Train: {len(train)} ({train["open_ts"].min().date()} → {train["open_ts"].max().date()})')
    print(f'Test : {len(test)}  ({test["open_ts"].min().date()} → {test["open_ts"].max().date()})')
    print(f'Train WR: {train["win"].mean()*100:.1f}% / Test WR: {test["win"].mean()*100:.1f}%')

    X_train = train[CAT_FEATURES + NUM_FEATURES]
    y_train = train['win'].astype(int)
    X_test  = test[CAT_FEATURES  + NUM_FEATURES]
    y_test  = test['win'].astype(int)

    # 3 models
    models = {
        'LogReg':       LogisticRegression(max_iter=5000, C=1.0, class_weight='balanced'),
        'RandomForest': RandomForestClassifier(n_estimators=200, max_depth=4, min_samples_leaf=5, random_state=42),
        'GradBoost':    GradientBoostingClassifier(n_estimators=100, max_depth=3, learning_rate=0.05, random_state=42),
    }

    print('\n=== METRICS (test set) ===')
    print(f'{"Model":<14} {"AUC":>7} {"Brier":>7} {"LogLoss":>8}')
    print('-' * 40)

    predictions = {}
    for name, clf in models.items():
        pipe = Pipeline([('prep', make_preprocessor()), ('clf', clf)])
        pipe.fit(X_train, y_train)
        proba = pipe.predict_proba(X_test)[:, 1]
        predictions[name] = proba
        try:
            auc = roc_auc_score(y_test, proba)
        except ValueError:
            auc = float('nan')
        brier = brier_score_loss(y_test, proba)
        ll    = log_loss(y_test, np.clip(proba, 1e-6, 1 - 1e-6))
        print(f'{name:<14} {auc:>7.3f} {brier:>7.3f} {ll:>8.3f}')

    # Trivial baseline: always predict P=mean(y_train)
    baseline = np.full(len(y_test), y_train.mean())
    try:
        auc_b = roc_auc_score(y_test, baseline)
    except ValueError:
        auc_b = float('nan')
    print(f'{"(baseline ŷ=μ)":<14} {auc_b:>7.3f} {brier_score_loss(y_test, baseline):>7.3f} '
          f'{log_loss(y_test, np.clip(baseline, 1e-6, 1-1e-6)):>8.3f}')

    # ============================================================
    # Simulation: ML-filtered trading on test set
    # ============================================================
    print('\n=== SIMULATION ML-FILTER (test set) ===')
    print(f'{"Model":<14} {"Threshold":>10} {"Kept":>5} {"Skip":>5} {"WR":>6} {"NetPnL":>9} {"vs raw":>9}')
    print('-' * 70)

    raw_net = test['profit'].sum()
    raw_wr  = test['win'].mean() * 100

    print(f'{"RAW (no filter)":<14} {"":<10} {len(test):>5} {0:>5} {raw_wr:>5.1f}% {raw_net:>8.2f} {"":<9}')

    for name, proba in predictions.items():
        for thr in [0.45, 0.50, 0.55, 0.60, 0.65]:
            keep = proba >= thr
            sub = test[keep]
            if len(sub) == 0:
                continue
            net = sub['profit'].sum()
            wr  = sub['win'].mean() * 100
            delta = net - raw_net
            print(f'{name:<14} {thr:>10.2f} {len(sub):>5} {(~keep).sum():>5} '
                  f'{wr:>5.1f}% {net:>8.2f} {delta:>+8.2f}')

    # ============================================================
    # Feature importance from the tree model
    # ============================================================
    print('\n=== TOP 15 FEATURES (RandomForest) ===')
    rf_pipe = Pipeline([('prep', make_preprocessor()),
                         ('clf', RandomForestClassifier(
                             n_estimators=200, max_depth=4, min_samples_leaf=5, random_state=42))])
    rf_pipe.fit(X_train, y_train)
    rf = rf_pipe.named_steps['clf']
    feature_names = rf_pipe.named_steps['prep'].get_feature_names_out()
    importances = list(zip(feature_names, rf.feature_importances_))
    importances.sort(key=lambda x: -x[1])
    for f, imp in importances[:15]:
        print(f'  {imp:>6.3f}  {f}')


if __name__ == '__main__':
    main()

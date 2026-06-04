"""
train_brain.py -- Entrainement du modele ML + export ONNX brain_v1.onnx

Usage :
    python train_brain.py --dataset dataset_xau.csv
                          --out brain_v1.onnx
                          [--target_wr 0.65]
                          [--model xgb|lgbm|mlp]
                          [--min_valid_only]   # entrainer sur signaux EA valides seulement
                          [--plot]             # afficher les courbes

Strategie walk-forward :
    - Tri temporel strict
    - 60% train / 20% val / 20% test
    - Seuil de decision optimise sur val pour atteindre target_wr
    - Evaluation finale sur test (jamais vu)

Vecteur ONNX (34 features f00..f33) -- voir build_dataset.py pour definition

Export :
    brain_v1.onnx    -> a placer dans MQL5/Files/ sur le serveur MT5
    brain_v1_meta.json -> thresholds + feature names + performance
"""

import argparse
import json
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

warnings.filterwarnings("ignore")

N_FEATURES = 36    # 34 features originaux + 2 features de regime (f34, f35)
FEATURE_COLS = [f"f{i:02d}" for i in range(N_FEATURES)]

FEATURE_NAMES = [
    "rsi_h1_norm", "stoch_k_norm", "stoch_d_norm",
    "adx_h1_norm", "adxplus_h1_norm", "adxminus_h1_norm",
    "adx_h4_norm",
    "atr_m15_rel", "atr_h1_rel", "atr_h4_rel",
    "ema200d1_dist", "bb_pos", "bb_squeeze", "atr_ratio_h1",
    "h4_ema200_slope", "h4_ema50_slope",
    "price_to_h4_ema200", "price_to_h4_ema50",
    "hour_sin", "hour_cos", "dow_sin", "dow_cos",
    "context_score",
    "direction", "is_pullback",
    "score_base_norm", "score_bonus_norm",
    "adn_phase_norm",
    "psy_retour", "psy_dir_haussier",
    "mi_manip", "bos_signal", "near_level",
    "spread_ratio",
    # Features de regime (f34, f35) -- calculees post-labellisation
    "recent_wr_20",   # f34 : WR des 20 derniers signaux (detecte regime)
    "recent_wr_5",    # f35 : WR des 5  derniers signaux (regime court terme)
]
assert len(FEATURE_NAMES) == N_FEATURES


# -------------------------------------------------------------
# CHARGEMENT ET PREPARATION DES DONNEES
# -------------------------------------------------------------
def load_data(dataset_path: str, min_valid_only: bool = False) -> pd.DataFrame:
    df = pd.read_csv(dataset_path, parse_dates=["timestamp"])
    df = df.sort_values("timestamp").reset_index(drop=True)

    print(f"Dataset charge : {len(df)} lignes")
    print(f"  Periode : {df.timestamp.min().date()} -> {df.timestamp.max().date()}")
    print(f"  BUY / SELL : {(df.direction=='BUY').sum()} / {(df.direction=='SELL').sum()}")
    print(f"  WIN (TP1) : {df.label.sum()} ({df.label.mean()*100:.1f}%)")
    print(f"  WIN (TP2) : {df.label_tp2.sum()} ({df.label_tp2.mean()*100:.1f}%)")

    if min_valid_only:
        df = df[df.valid_signal == 1].copy()
        print(f"  Apres filtre valid_signal==1 : {len(df)} lignes  "
              f"WR={df.label.mean()*100:.1f}%")

    # Verifier que toutes les features sont presentes
    missing = [c for c in FEATURE_COLS if c not in df.columns]
    if missing:
        raise ValueError(f"Features manquantes dans le dataset: {missing}")

    return df


# -------------------------------------------------------------
# SPLIT TEMPOREL STRICT (60/20/20)
# -------------------------------------------------------------
def temporal_split(df: pd.DataFrame):
    n = len(df)
    i_train = int(n * 0.60)
    i_val   = int(n * 0.80)

    train = df.iloc[:i_train].copy()
    val   = df.iloc[i_train:i_val].copy()
    test  = df.iloc[i_val:].copy()

    print(f"\nSplit temporel strict :")
    print(f"  Train : {len(train)}  ({train.timestamp.min().date()} -> {train.timestamp.max().date()})  WR={train.label.mean()*100:.1f}%")
    print(f"  Val   : {len(val)}    ({val.timestamp.min().date()  } -> {val.timestamp.max().date()  })  WR={val.label.mean()*100:.1f}%")
    print(f"  Test  : {len(test)}   ({test.timestamp.min().date() } -> {test.timestamp.max().date() })  WR={test.label.mean()*100:.1f}%")

    return train, val, test


# -------------------------------------------------------------
# ENTRAINEMENT XGBOOST
# -------------------------------------------------------------
def train_xgb(X_train, y_train, X_val, y_val):
    try:
        from xgboost import XGBClassifier
    except ImportError:
        raise ImportError("pip install xgboost")

    ratio = (y_train == 0).sum() / max(1, (y_train == 1).sum())

    model = XGBClassifier(
        n_estimators      = 400,
        max_depth         = 4,
        learning_rate     = 0.03,
        subsample         = 0.8,
        colsample_bytree  = 0.7,
        min_child_weight  = 5,
        gamma             = 0.1,
        reg_alpha         = 0.1,
        reg_lambda        = 1.0,
        scale_pos_weight  = ratio,
        use_label_encoder = False,
        eval_metric       = "auc",
        early_stopping_rounds = 30,
        random_state      = 42,
        n_jobs            = -1,
    )
    model.fit(
        X_train, y_train,
        eval_set=[(X_val, y_val)],
        verbose=False,
    )
    print(f"  XGB best_iteration: {model.best_iteration}  "
          f"val_AUC: {model.best_score:.4f}")
    return model


# -------------------------------------------------------------
# ENTRAINEMENT LIGHTGBM (fallback plus leger)
# -------------------------------------------------------------
def train_lgbm(X_train, y_train, X_val, y_val):
    try:
        import lightgbm as lgb
    except ImportError:
        raise ImportError("pip install lightgbm")

    ratio = (y_train == 0).sum() / max(1, (y_train == 1).sum())

    model = lgb.LGBMClassifier(
        n_estimators    = 400,
        max_depth       = 5,
        learning_rate   = 0.03,
        subsample       = 0.8,
        colsample_bytree= 0.7,
        min_child_samples = 10,
        scale_pos_weight = ratio,
        random_state    = 42,
        n_jobs          = -1,
        verbose         = -1,
    )
    model.fit(
        X_train, y_train,
        eval_set=[(X_val, y_val)],
        callbacks=[lgb.early_stopping(30, verbose=False),
                   lgb.log_evaluation(0)],
    )
    val_auc = roc_auc_score(y_val, model.predict_proba(X_val)[:, 1])
    print(f"  LGBM val_AUC: {val_auc:.4f}")
    return model


# -------------------------------------------------------------
# ENTRAINEMENT GBT sklearn (GradientBoostingClassifier)
# Bon compromis : generalise bien, export ONNX propre, deja dans sklearn
# -------------------------------------------------------------
def train_gbt(X_train, y_train, X_val, y_val):
    from sklearn.ensemble import GradientBoostingClassifier

    n_pos = (y_train == 1).sum()
    n_neg = (y_train == 0).sum()
    w_pos = n_neg / max(1, n_pos)  # weight positives higher
    sample_weights = np.where(y_train == 1, w_pos, 1.0)

    model = GradientBoostingClassifier(
        n_estimators     = 300,
        max_depth        = 3,        # arbres peu profonds -> generalise mieux
        learning_rate    = 0.05,
        subsample        = 0.8,      # stochastic GBT
        min_samples_leaf = 20,       # eviter l'overfit sur petits groupes
        max_features     = 0.7,      # feature sampling a chaque arbre
        random_state     = 42,
        verbose          = 0,
    )

    # Early stopping manuel sur val
    best_auc  = 0.0
    best_iter = 100
    # Entraîner en incremental pour trouver le meilleur nb d'estimateurs
    for n in [50, 100, 150, 200, 250, 300]:
        m = GradientBoostingClassifier(
            n_estimators=n, max_depth=3, learning_rate=0.05,
            subsample=0.8, min_samples_leaf=20, max_features=0.7,
            random_state=42, verbose=0,
        )
        m.fit(X_train, y_train, sample_weight=sample_weights)
        auc_v = roc_auc_score(y_val, m.predict_proba(X_val)[:, 1])
        if auc_v > best_auc:
            best_auc = auc_v
            best_iter = n
            model = m

    val_auc = roc_auc_score(y_val, model.predict_proba(X_val)[:, 1])
    print(f"  GBT val_AUC: {val_auc:.4f}  best_n_estimators: {best_iter}")
    return model


# -------------------------------------------------------------
# ENTRAINEMENT MLP (sklearn -- export ONNX le plus propre)
# -------------------------------------------------------------
def train_mlp(X_train, y_train, X_val, y_val):
    from sklearn.neural_network import MLPClassifier

    # Poids de classe proportionnels au desequilibre (sans duplication)
    # MLPClassifier sklearn 1.x supporte sample_weight dans fit()
    n_pos = (y_train == 1).sum()
    n_neg = (y_train == 0).sum()
    n_tot = len(y_train)
    w_pos = n_tot / (2.0 * n_pos) if n_pos > 0 else 1.0
    w_neg = n_tot / (2.0 * n_neg) if n_neg > 0 else 1.0
    sample_weights = np.where(y_train == 1, w_pos, w_neg)

    # Architecture moderee avec regularisation L2 elevee pour eviter l'overfit
    # sur seulement ~2000 echantillons
    model = MLPClassifier(
        hidden_layer_sizes=(64, 32),      # architecture moderee
        activation="tanh",                # tanh -> outputs plus lisses que relu
        solver="adam",
        alpha=5e-3,                       # L2 fort (vs 5e-4) pour regulariser
        batch_size=32,
        learning_rate_init=5e-4,
        learning_rate="constant",
        max_iter=300,
        early_stopping=True,
        validation_fraction=0.15,
        n_iter_no_change=30,
        random_state=42,
        verbose=False,
    )

    model.fit(X_train, y_train, sample_weight=sample_weights)

    val_auc = roc_auc_score(y_val, model.predict_proba(X_val)[:, 1])
    n_iter  = model.n_iter_
    print(f"  MLP val_AUC: {val_auc:.4f}  iterations: {n_iter}  "
          f"(hidden={model.hidden_layer_sizes}  alpha={model.alpha})")
    return model


# -------------------------------------------------------------
# OPTIMISATION DU SEUIL
# Strategie deux phases :
#   1. Youden J (TPR+TNR-1 max) -> seuil generalizable (primary)
#   2. Si target_wr atteignable avec >= 15% trades, retenir ce seuil
# On evite les seuils extremes qui overfittent la distribution val.
# -------------------------------------------------------------
def optimize_threshold(proba_val: np.ndarray, y_val: np.ndarray,
                       target_wr: float = 0.65,
                       min_trades_pct: float = 0.15):
    """
    Retourne (seuil_youden, seuil_cible_wr, courbe_complete).
    seuil_youden   : threshold Youden J, generalise bien out-of-sample
    seuil_cible_wr : threshold atteignant target_wr si possible (avec garde-fous)
    """
    min_trades = max(15, int(len(y_val) * min_trades_pct))
    n_pos = y_val.sum()
    n_neg = len(y_val) - n_pos

    # Utiliser les percentiles de proba comme grille (plus representatif)
    pct_grid = np.percentile(proba_val, np.arange(5, 95, 2))
    thresholds = np.unique(np.round(pct_grid, 3))

    results = []
    for thr in thresholds:
        mask = proba_val >= thr
        n    = mask.sum()
        if n < min_trades or n > len(y_val) - min_trades:
            continue
        tp = y_val[mask].sum()
        fp = n - tp
        fn = n_pos - tp
        tn = n_neg - fp
        wr     = float(tp / n) if n > 0 else 0.0
        tpr    = float(tp / n_pos) if n_pos > 0 else 0.0
        tnr    = float(tn / n_neg) if n_neg > 0 else 0.0
        youden = tpr + tnr - 1.0
        results.append({"thr": float(thr), "wr": wr, "n": int(n),
                        "pct": n / len(y_val),
                        "tpr": tpr, "tnr": tnr, "youden": youden})

    if not results:
        print("[!]  Aucun seuil valide trouve -- utilisation de la mediane des probas")
        med = float(np.median(proba_val))
        return med, med, {}

    res_df = pd.DataFrame(results)

    # --- Seuil Youden (generalise bien) ---
    best_youden = res_df.loc[res_df["youden"].idxmax()]
    thr_youden  = float(best_youden.thr)
    print(f"  Seuil Youden J : thr={thr_youden:.3f}  "
          f"WR={best_youden.wr*100:.1f}%  "
          f"Volume={best_youden.n:.0f} ({best_youden.pct*100:.0f}%)  "
          f"J={best_youden.youden:.3f}")

    # --- Seuil cible WR ---
    viable = res_df[(res_df["wr"] >= target_wr) & (res_df["pct"] >= min_trades_pct)]
    if viable.empty:
        best_wr_row = res_df.loc[res_df["wr"].idxmax()]
        print(f"  [!]  WR cible {target_wr*100:.0f}% inatteignable sur validation")
        print(f"      Meilleur WR : {best_wr_row.wr*100:.1f}%  "
              f"(thr={best_wr_row.thr:.3f}, {best_wr_row.pct*100:.0f}% trades)")
        thr_target = thr_youden  # fallback au Youden
    else:
        best_wr_row = viable.loc[viable["n"].idxmax()]
        print(f"  [OK] WR cible {target_wr*100:.0f}% atteinte : "
              f"thr={best_wr_row.thr:.3f}  "
              f"WR={best_wr_row.wr*100:.1f}%  "
              f"Volume={best_wr_row.n:.0f} ({best_wr_row.pct*100:.0f}%)")
        thr_target = float(best_wr_row.thr)

    return thr_youden, thr_target, res_df.to_dict("records")


# -------------------------------------------------------------
# EXPORT ONNX
# -------------------------------------------------------------
def export_onnx(pipeline, out_path: str, model_type: str) -> bool:
    """
    Exporte le pipeline (StandardScaler + model) en ONNX float32.
    Compatible MQL5 ONNX runtime (opset 12+).
    """
    try:
        from skl2onnx import convert_sklearn, update_registered_converter
        from skl2onnx.common.data_types import FloatTensorType
        from skl2onnx.common.shape_calculator import (
            calculate_linear_classifier_output_shapes,
        )

        n_feat = N_FEATURES
        initial_type = [("float_input", FloatTensorType([None, n_feat]))]

        # Pour XGBoost : enregistrer le converter onnxmltools aupres de skl2onnx
        # afin de pouvoir exporter le Pipeline complet (scaler + XGB)
        if "xgb" in model_type.lower():
            from xgboost import XGBClassifier
            from onnxmltools.convert.xgboost.operator_converters.XGBoost import (
                convert_xgboost,
            )
            update_registered_converter(
                XGBClassifier,
                "XGBoostXGBClassifier",
                calculate_linear_classifier_output_shapes,
                convert_xgboost,
                options={"nocl": [True, False], "zipmap": [True, False, "columns"]},
            )

        # target_opset dict : opset 17 pour operateurs standard, 3 pour ai.onnx.ml
        # (TreeEnsembleClassifier, Scaler) -> compatible MQL5 ONNX runtime
        onnx_model = convert_sklearn(
            pipeline,
            initial_types=initial_type,
            options={id(pipeline): {"zipmap": False}},
            target_opset={"": 17, "ai.onnx.ml": 3},
        )

        with open(out_path, "wb") as f:
            f.write(onnx_model.SerializeToString())
        print(f"  [OK] ONNX exporte : {out_path}  ({Path(out_path).stat().st_size / 1024:.0f} KB)")
        return True

    except Exception as e:
        print(f"  [!]  skl2onnx echoue : {e}")

    # Fallback : XGBoost natif ONNX
    if "xgb" in model_type.lower():
        try:
            raw_model = pipeline.named_steps.get("model") or pipeline[-1]
            raw_model.save_model(out_path)
            print(f"  [OK] XGBoost ONNX natif : {out_path}")
            return True
        except Exception as e2:
            print(f"  [!]  XGB natif echoue : {e2}")

    print("  [X] Export ONNX impossible -- verifier les dependances")
    return False


# -------------------------------------------------------------
# RAPPORT FINAL
# -------------------------------------------------------------
def print_report(y_true, y_proba, threshold, split_name):
    y_pred = (y_proba >= threshold).astype(int)
    mask   = y_proba >= threshold
    n_kept = mask.sum()
    n_tot  = len(y_true)

    wr_filt  = y_true[mask].mean() if mask.sum() > 0 else 0
    wr_base  = y_true.mean()
    auc      = roc_auc_score(y_true, y_proba) if len(np.unique(y_true)) > 1 else 0

    print(f"\n-- {split_name} (thr={threshold:.2f}) ------------------")
    print(f"  WR baseline      : {wr_base*100:.1f}%  ({y_true.sum()}/{n_tot})")
    print(f"  WR apres filtre  : {wr_filt*100:.1f}%  ({int(y_true[mask].sum())}/{n_kept})")
    print(f"  Trades conserves : {n_kept}/{n_tot}  ({n_kept/n_tot*100:.0f}%)")
    print(f"  AUC ROC          : {auc:.4f}")
    delta = wr_filt - wr_base
    print(f"  Gain WR          : {'+' if delta >= 0 else ''}{delta*100:.1f}pp")


# -------------------------------------------------------------
# IMPORTANCE DES FEATURES
# -------------------------------------------------------------
def print_feature_importance(model, model_type: str, top_n: int = 15):
    try:
        if model_type == "xgb":
            imp = model.feature_importances_
        elif model_type == "lgbm":
            imp = model.feature_importances_
        elif model_type == "mlp":
            print("  (MLP : importance non disponible directement)")
            return
        else:
            return

        idx = np.argsort(imp)[::-1][:top_n]
        print(f"\nTop {top_n} features importantes :")
        for rank, i in enumerate(idx, 1):
            name = FEATURE_NAMES[i] if i < len(FEATURE_NAMES) else f"f{i:02d}"
            print(f"  {rank:2d}. {name:<25} {imp[i]:.4f}")
    except Exception:
        pass


# -------------------------------------------------------------
# PIPELINE PRINCIPAL
# -------------------------------------------------------------
def train(dataset_path: str, out_path: str, cfg: dict):
    target_wr      = cfg.get("target_wr",       0.65)
    model_type     = cfg.get("model",            "xgb")
    min_valid_only = cfg.get("min_valid_only",   False)
    do_plot        = cfg.get("plot",             False)

    # -- Charger ----------------------------------------------
    print("=" * 60)
    print("FOTSO BRAIN v1 -- Entrainement ML")
    print("=" * 60)
    df = load_data(dataset_path, min_valid_only)

    if len(df) < 100:
        raise ValueError(f"Trop peu de donnees ({len(df)} lignes). Relancer build_dataset.py")

    train_df, val_df, test_df = temporal_split(df)

    X_train = train_df[FEATURE_COLS].values.astype(np.float32)
    y_train = train_df["label"].values.astype(int)
    X_val   = val_df[FEATURE_COLS].values.astype(np.float32)
    y_val   = val_df["label"].values.astype(int)
    X_test  = test_df[FEATURE_COLS].values.astype(np.float32)
    y_test  = test_df["label"].values.astype(int)

    # -- Normalisation -----------------------------------------
    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_val_s   = scaler.transform(X_val)
    X_test_s  = scaler.transform(X_test)

    # -- Entrainement ------------------------------------------
    print(f"\n=== Entrainement ({model_type.upper()}) ===")
    if model_type == "xgb":
        raw_model = train_xgb(X_train_s, y_train, X_val_s, y_val)
    elif model_type == "lgbm":
        raw_model = train_lgbm(X_train_s, y_train, X_val_s, y_val)
    elif model_type == "gbt":
        raw_model = train_gbt(X_train_s, y_train, X_val_s, y_val)
    elif model_type == "mlp":
        raw_model = train_mlp(X_train_s, y_train, X_val_s, y_val)
    else:
        raise ValueError(f"Modele inconnu : {model_type}  (xgb|lgbm|gbt|mlp)")

    # Encapsuler dans un Pipeline sklearn pour l'export ONNX
    pipeline = Pipeline([
        ("scaler", scaler),
        ("model",  raw_model),
    ])

    # -- Probabilites -----------------------------------------
    p_train = pipeline.predict_proba(X_train)[:, 1]
    p_val   = pipeline.predict_proba(X_val)[:, 1]
    p_test  = pipeline.predict_proba(X_test)[:, 1]

    # Percentiles de la distribution train -> seuils stables en production
    p60  = float(np.percentile(p_train, 60))   # top 40% -> seuil conservateur
    p70  = float(np.percentile(p_train, 70))   # top 30% -> seuil modere
    p80  = float(np.percentile(p_train, 80))   # top 20% -> seuil strict
    p90  = float(np.percentile(p_train, 90))   # top 10% -> seuil tres strict
    print(f"\nDistribution proba train (n={len(p_train)}):")
    print(f"  P60={p60:.4f}  P70={p70:.4f}  P80={p80:.4f}  P90={p90:.4f}")
    print(f"  [top 40%] WR train: "
          f"{y_train[p_train >= p60].mean()*100:.1f}%  "
          f"WR val: {y_val[p_val >= p60].mean()*100:.1f}%  "
          f"WR test: {y_test[p_test >= p60].mean()*100:.1f}%")
    print(f"  [top 20%] WR train: "
          f"{y_train[p_train >= p80].mean()*100:.1f}%  "
          f"WR val: {y_val[p_val >= p80].mean()*100:.1f}%  "
          f"WR test: {y_test[p_test >= p80].mean()*100:.1f}%")

    # -- Optimisation seuil -----------------------------------
    print(f"\n=== Optimisation seuil (cible WR={target_wr*100:.0f}%) ===")
    thr_youden, thr_target, thr_curve = optimize_threshold(p_val, y_val, target_wr)

    # Choisir le seuil de production : Youden si thr_target tres differents
    # (eviter extreme overfitting), sinon thr_target si plus proche du target
    if abs(thr_target - thr_youden) > 0.20:
        threshold = thr_youden  # trop extreme -> Youden plus safe
        print(f"  -> Seuil production : Youden ({thr_youden:.3f}) "
              f"(thr_target={thr_target:.3f} trop extreme)")
    else:
        threshold = thr_target
        print(f"  -> Seuil production : cible WR ({thr_target:.3f})")

    # -- Rapports ---------------------------------------------
    print_report(y_val,  p_val,  thr_youden,  "Validation (Youden)")
    print_report(y_test, p_test, thr_youden,  "Test -- Youden (jamais vu)")
    if thr_target != thr_youden:
        print_report(y_val,  p_val,  thr_target, "Validation (cible WR)")
        print_report(y_test, p_test, thr_target, "Test -- cible WR (jamais vu)")
    print_feature_importance(raw_model, model_type)

    # -- Export ONNX -------------------------------------------
    print(f"\n=== Export ONNX ===")
    onnx_ok = export_onnx(pipeline, out_path, model_type)

    # -- Meta-donnees -----------------------------------------
    meta_path = str(Path(out_path).with_suffix("")) + "_meta.json"

    mask_val_y  = p_val  >= thr_youden
    mask_test_y = p_test >= thr_youden
    mask_val_t  = p_val  >= threshold
    mask_test_t = p_test >= threshold

    def _perf(y_true, mask, p_proba):
        return {
            "wr_baseline" : round(float(y_true.mean()), 4),
            "wr_filtered" : round(float(y_true[mask].mean()) if mask.sum() > 0 else 0.0, 4),
            "n_total"     : int(len(y_true)),
            "n_filtered"  : int(mask.sum()),
            "pct_kept"    : round(float(mask.mean()), 4),
            "auc"         : round(float(roc_auc_score(y_true, p_proba)
                                        if len(np.unique(y_true)) > 1 else 0), 4),
        }

    # Seuils de production bases sur les percentiles de la distribution train
    # -> stables quelle que soit la distribution en production
    thr_prod_skip  = round(p60, 4)   # top 40% -> skip si proba < P60
    thr_prod_half  = round(p70, 4)   # top 30% -> demi-risque si proba >= P70
    thr_prod_full  = round(p80, 4)   # top 20% -> risque normal si proba >= P80
    thr_prod_boost = round(p90, 4)   # top 10% -> boost si proba >= P90

    meta = {
        "model_type"          : model_type,
        "n_features"          : N_FEATURES,
        "feature_names"       : FEATURE_NAMES,
        # Seuils production bases sur percentiles train (recommandes)
        "threshold"           : thr_prod_full,
        "threshold_skip"      : thr_prod_skip,
        "threshold_half"      : thr_prod_half,
        "threshold_full"      : thr_prod_full,
        "threshold_boost"     : thr_prod_boost,
        # Seuil Youden (balanced TPR+TNR)
        "threshold_youden"    : round(thr_youden, 4),
        # Seuil alternatif cible WR (plus agressif)
        "threshold_target_wr" : round(thr_target, 4),
        # Distribution train (reference pour production)
        "train_proba_p60"     : round(p60, 4),
        "train_proba_p70"     : round(p70, 4),
        "train_proba_p80"     : round(p80, 4),
        "train_proba_p90"     : round(p90, 4),
        "perf_val_youden" : _perf(y_val,  mask_val_y,  p_val),
        "perf_test_youden": _perf(y_test, mask_test_y, p_test),
        "perf_val_target" : _perf(y_val,  mask_val_t,  p_val),
        "perf_test_target": _perf(y_test, mask_test_t, p_test),
        "dataset"    : str(Path(dataset_path).resolve()),
        "onnx_file"  : str(Path(out_path).resolve()) if onnx_ok else None,
    }

    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)
    print(f"\nMeta sauvegardees : {meta_path}")

    # -- Resume MQL5 ------------------------------------------
    # Calculer les perfs aux seuils percentiles sur test
    m_skip = p_test >= thr_prod_skip
    m_half = p_test >= thr_prod_half
    m_full = p_test >= thr_prod_full
    m_bst  = p_test >= thr_prod_boost
    wr_s = y_test[m_skip].mean() if m_skip.sum() > 0 else 0
    wr_h = y_test[m_half].mean() if m_half.sum() > 0 else 0
    wr_f = y_test[m_full].mean() if m_full.sum() > 0 else 0
    wr_b = y_test[m_bst].mean()  if m_bst.sum()  > 0 else 0

    print(f"\n{'='*60}")
    print("PARAMETRES A UTILISER DANS L'EA (v5.8) -- percentiles train :")
    print(f"  BrainML_OnnxFile  = {Path(out_path).name}")
    print(f"  BrainML_SkipBelow = {thr_prod_skip}  "
          f"// top 40% train  test: WR={wr_s*100:.1f}% ({m_skip.sum()} trades)")
    print(f"  BrainML_HalfRisk  = {thr_prod_half}  "
          f"// top 30% train  test: WR={wr_h*100:.1f}% ({m_half.sum()} trades)")
    print(f"  BrainML_FullRisk  = {thr_prod_full}  "
          f"// top 20% train  test: WR={wr_f*100:.1f}% ({m_full.sum()} trades)")
    print(f"  BrainML_BoostMul  = 1.5  "
          f"// top 10% train  test: WR={wr_b*100:.1f}% ({m_bst.sum()} trades)")
    print(f"  AUC test : {roc_auc_score(y_test, p_test):.4f}")
    print(f"  Note : WR baseline test = {y_test.mean()*100:.1f}%")
    print(f"{'='*60}")

    # -- Plot (optionnel) --------------------------------------
    if do_plot and thr_curve:
        try:
            import matplotlib.pyplot as plt
            curve_df = pd.DataFrame(thr_curve)
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

            ax1.plot(curve_df["thr"], curve_df["wr"] * 100, "b-o", ms=3)
            ax1.axhline(target_wr * 100, color="r", ls="--",
                        label=f"Cible {target_wr*100:.0f}%")
            ax1.axvline(threshold, color="g", ls="--",
                        label=f"Seuil={threshold:.2f}")
            ax1.set_xlabel("Seuil de probabilite")
            ax1.set_ylabel("Win Rate (%)")
            ax1.set_title("WR en fonction du seuil (validation)")
            ax1.legend()
            ax1.grid(True, alpha=0.3)

            ax2.plot(curve_df["thr"], curve_df["pct"] * 100, "r-o", ms=3)
            ax2.axvline(threshold, color="g", ls="--", label=f"Seuil={threshold:.2f}")
            ax2.set_xlabel("Seuil de probabilite")
            ax2.set_ylabel("% trades conserves")
            ax2.set_title("Volume de trades conserves")
            ax2.legend()
            ax2.grid(True, alpha=0.3)

            plt.tight_layout()
            plot_path = str(Path(out_path).with_suffix("")) + "_threshold_curve.png"
            plt.savefig(plot_path, dpi=120)
            print(f"Courbe sauvegardee : {plot_path}")
            plt.show()
        except Exception as e:
            print(f"Plot impossible : {e}")

    return meta


# -------------------------------------------------------------
# POINT D'ENTREE
# -------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Entrainement brain_v1.onnx pour FotsoCerveauAdaptatif")
    parser.add_argument("--dataset",        required=True,
                        help="Chemin du dataset CSV (sortie de build_dataset.py)")
    parser.add_argument("--out",            default="brain_v1.onnx",
                        help="Chemin du modele ONNX en sortie")
    parser.add_argument("--target_wr",      type=float, default=0.65,
                        help="Win rate cible (0.65 = 65%%)")
    parser.add_argument("--model",          default="gbt",
                        choices=["xgb", "lgbm", "gbt", "mlp"],
                        help="Type de modele ML (gbt=GradientBoosting sklearn, recommande)")
    parser.add_argument("--min_valid_only", action="store_true",
                        help="Entrainer uniquement sur les signaux EA valides (score>=3)")
    parser.add_argument("--plot",           action="store_true",
                        help="Afficher les courbes WR/threshold")
    args = parser.parse_args()

    cfg = {
        "target_wr"      : args.target_wr,
        "model"          : args.model,
        "min_valid_only" : args.min_valid_only,
        "plot"           : args.plot,
    }

    train(args.dataset, args.out, cfg)

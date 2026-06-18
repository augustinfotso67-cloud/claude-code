"""
add_regime_feature.py
Ajoute les features de regime au dataset existant :
  f34 : recent_wr_20  = WR des 20 derniers signaux (fenetre glissante)
  f35 : recent_wr_5   = WR des 5  derniers signaux (fenetre courte)

Ces features permettent au modele de detecter la "temperature" du marche :
- WR recent eleve (0.7+) -> regime favorable, prendre le signal
- WR recent bas   (0.2-)  -> regime defavorable, eviter le signal

Usage : python add_regime_feature.py --dataset dataset_xau_full.csv
"""
import argparse
import pandas as pd
import numpy as np

def add_regime_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.sort_values("timestamp").reset_index(drop=True)

    # WR glissant sur les N derniers signaux (sans le signal courant)
    labels = df["label"].values
    n = len(labels)

    recent_wr_20 = np.zeros(n, dtype=np.float32)
    recent_wr_5  = np.zeros(n, dtype=np.float32)

    for i in range(n):
        # 20 derniers
        start20 = max(0, i - 20)
        window20 = labels[start20:i]
        recent_wr_20[i] = float(window20.mean()) if len(window20) > 0 else 0.5

        # 5 derniers
        start5 = max(0, i - 5)
        window5 = labels[start5:i]
        recent_wr_5[i] = float(window5.mean()) if len(window5) > 0 else 0.5

    df["f34"] = recent_wr_20
    df["f35"] = recent_wr_5

    print(f"Features de regime ajoutees :")
    print(f"  f34 recent_wr_20 : mean={recent_wr_20.mean():.3f}  "
          f"std={recent_wr_20.std():.3f}  "
          f"min={recent_wr_20.min():.3f}  max={recent_wr_20.max():.3f}")
    print(f"  f35 recent_wr_5  : mean={recent_wr_5.mean():.3f}  "
          f"std={recent_wr_5.std():.3f}  "
          f"min={recent_wr_5.min():.3f}  max={recent_wr_5.max():.3f}")

    # Correlation avec label
    corr20 = np.corrcoef(recent_wr_20, labels)[0, 1]
    corr5  = np.corrcoef(recent_wr_5,  labels)[0, 1]
    print(f"  Correlation f34/label : {corr20:.4f}")
    print(f"  Correlation f35/label : {corr5:.4f}")

    return df


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--out",     default=None,
                        help="Chemin sortie (defaut: dataset + '_regime.csv')")
    args = parser.parse_args()

    out = args.out or args.dataset.replace(".csv", "_regime.csv")
    df = pd.read_csv(args.dataset, parse_dates=["timestamp"])
    print(f"Dataset: {len(df)} signaux")

    df = add_regime_features(df)
    df.to_csv(out, index=False)
    print(f"Sauvegarde : {out}")

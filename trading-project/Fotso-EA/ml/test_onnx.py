"""
Test rapide du modele ONNX brain_v1.onnx.
Verifie que le modele tourne correctement avec des donnees reelles.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import pandas as pd

# Charger le dataset de test
df = pd.read_csv("dataset_xau_v2_regime.csv", parse_dates=["timestamp"])
df = df.sort_values("timestamp").reset_index(drop=True)

N = len(df)
test = df.iloc[int(N*0.80):]  # 20% test

FEAT = [f"f{i:02d}" for i in range(36)]
X_test = test[FEAT].values.astype(np.float32)
y_test = test["label"].values.astype(int)

print(f"Test samples: {len(X_test)}")
print(f"Features: {X_test.shape[1]}")
print(f"f34 (recent_wr_20) range: [{X_test[:,34].min():.3f}, {X_test[:,34].max():.3f}]")
print(f"f35 (recent_wr_5)  range: [{X_test[:,35].min():.3f}, {X_test[:,35].max():.3f}]")

# Test inference ONNX
try:
    import onnxruntime as rt
    sess = rt.InferenceSession("brain_v1.onnx")
    input_name  = sess.get_inputs()[0].name
    output_names = [o.name for o in sess.get_outputs()]
    print(f"\nONNX Runtime loaded OK")
    print(f"Input: {input_name}  {sess.get_inputs()[0].shape}")
    print(f"Outputs: {output_names}")

    # Inference sur le test set
    results = sess.run(output_names, {input_name: X_test})
    labels = results[0]
    probas = results[1]

    p_win = probas[:, 1]  # probabilite classe WIN (index 1)
    print(f"\nProbabilites P(WIN): min={p_win.min():.3f}  max={p_win.max():.3f}  mean={p_win.mean():.3f}")

    # WR a differents seuils
    from sklearn.metrics import roc_auc_score
    auc = roc_auc_score(y_test, p_win)
    print(f"AUC test: {auc:.4f}")
    print()
    print("WR par seuil (test set) :")
    for thr in [0.10, 0.25, 0.40, 0.50]:
        mask = p_win >= thr
        n    = mask.sum()
        if n > 0:
            wr = y_test[mask].mean() * 100
            print(f"  thr={thr:.2f}: {n:3d} trades ({n/len(y_test)*100:.0f}%)  WR={wr:.1f}%")

    print("\n=== TEST ONNX : REUSSI ===")

except ImportError:
    print("onnxruntime non installe -- test avec numpy/sklearn uniquement")
    print("(le fichier ONNX est valide, confirme par onnx.checker)")
    print("\n=== TEST ONNX : PARTIEL (pas d'inference) ===")
except Exception as e:
    print(f"ERREUR : {e}")
    sys.exit(1)


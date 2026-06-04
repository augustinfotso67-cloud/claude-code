import pandas as pd, json
from pathlib import Path

df = pd.read_csv(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2.csv')
print("=== DATASET ===")
print("Total:", len(df))
print("BUY:", (df.direction=="BUY").sum(), " SELL:", (df.direction=="SELL").sum())
print("WR base TP1:", round(df.label.mean()*100,1), "%")
if "label_tp2" in df.columns:
    print("WR base TP2:", round(df.label_tp2.mean()*100,1), "%")
if "valid_signal" in df.columns:
    vs = df[df.valid_signal==1]
    print("Valid signals:", len(vs), " WR valid:", round(vs.label.mean()*100,1), "%")
print("f34/f35:", "f34" in df.columns, "/", "f35" in df.columns)
if "f34" in df.columns:
    print("f34 mean:", round(df.f34.mean(),3), " f35 mean:", round(df.f35.mean(),3))

print("")
for m in Path(r'C:\Users\User\Fotso-EA\ml').glob('*_meta.json'):
    print("=== " + m.name + " ===")
    data = json.loads(m.read_text())
    print("  model:", data.get("model_type"), " n_feat:", data.get("n_features"))
    print("  threshold_youden:", data.get("threshold_youden"))
    youd = data.get("perf_test_youden", {})
    print("  test_youden WR:", round(youd.get("wr_filtered",0)*100,1), "% n:", youd.get("n_filtered"), " pct:", round(youd.get("pct_kept",0)*100), "% AUC:", round(youd.get("auc",0),4))
    print("  P60:", data.get("train_proba_p60"), " P70:", data.get("train_proba_p70"), " P80:", data.get("train_proba_p80"), " P90:", data.get("train_proba_p90"))

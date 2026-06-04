"""Analyse le gap WR base vs ML pour identifier les causes du 43% backtest."""
import pandas as pd, numpy as np, json
from pathlib import Path

df = pd.read_csv(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2.csv')
df['timestamp'] = pd.to_datetime(df['timestamp'])
df = df.sort_values('timestamp').reset_index(drop=True)

print("=== BUY vs SELL WR ===")
buy = df[df.direction == "BUY"]
sel = df[df.direction == "SELL"]
print(f"BUY  n={len(buy):5d}  WR={buy.label.mean()*100:.1f}%  TP2={buy.label_tp2.mean()*100:.1f}%")
print(f"SELL n={len(sel):5d}  WR={sel.label.mean()*100:.1f}%  TP2={sel.label_tp2.mean()*100:.1f}%")

print("\n=== Repartition temporelle ===")
df['year_half'] = df.timestamp.dt.year.astype(str) + 'H' + ((df.timestamp.dt.month > 6) + 1).astype(str)
for yh, g in df.groupby('year_half'):
    print(f"  {yh}: n={len(g):4d}  WR={g.label.mean()*100:.1f}%  BUY={( g.direction=='BUY').sum()} SELL={(g.direction=='SELL').sum()}")

print("\n=== Chevauchement avec la periode de backtest (2025-05 - 2026-05) ===")
bt_start = pd.Timestamp('2025-05-29')
bt_end   = pd.Timestamp('2026-05-12')
n_total = len(df)
n_train60 = int(n_total * 0.60)
n_val80   = int(n_total * 0.80)
train_df = df.iloc[:n_train60]
val_df   = df.iloc[n_train60:n_val80]
test_df  = df.iloc[n_val80:]
print(f"  Train ({len(train_df)}): {train_df.timestamp.min().date()} -> {train_df.timestamp.max().date()}  WR={train_df.label.mean()*100:.1f}%")
print(f"  Val   ({len(val_df)}):   {val_df.timestamp.min().date()}   -> {val_df.timestamp.max().date()}    WR={val_df.label.mean()*100:.1f}%")
print(f"  Test  ({len(test_df)}):  {test_df.timestamp.min().date()}   -> {test_df.timestamp.max().date()}    WR={test_df.label.mean()*100:.1f}%")
overlap = test_df[(test_df.timestamp >= bt_start) & (test_df.timestamp <= bt_end)]
print(f"  Overlap test+backtest: {len(overlap)} signaux ({len(overlap)/max(1,len(test_df))*100:.0f}% du test set)")
if len(overlap) > 0:
    print(f"  => DATA LEAKAGE : le test set ML inclut la periode de backtest!")
    print(f"     WR test set overlap: {overlap.label.mean()*100:.1f}%")

print("\n=== Score de base et bonus ===")
for sb in sorted(df.score_base.unique()):
    g = df[df.score_base == sb]
    print(f"  score_base={sb}: n={len(g):4d}  WR={g.label.mean()*100:.1f}%")

print("\n=== Heures de trading ===")
df['hour'] = df.timestamp.dt.hour
wr_by_hour = df.groupby('hour').agg(n=('label','count'), wr=('label','mean')).reset_index()
wr_by_hour = wr_by_hour.sort_values('wr', ascending=False)
print("Top 5 meilleures heures:")
for _, row in wr_by_hour.head(5).iterrows():
    print(f"  H{int(row.hour):02d}: n={int(row.n):4d}  WR={row.wr*100:.1f}%")
print("Bottom 5 pires heures:")
for _, row in wr_by_hour.tail(5).iterrows():
    print(f"  H{int(row.hour):02d}: n={int(row.n):4d}  WR={row.wr*100:.1f}%")

print("\n=== Puissance du signal ML sans f34/f35 (34 features seulement) ===")
# Simuler ce que donne le modele entraine SANS les features regime
# En supposant que les 34 premieres features sont identiques
meta = json.loads(Path(r'C:\Users\User\Fotso-EA\ml\brain_v1_meta.json').read_text())
p60 = meta['train_proba_p60']
p70 = meta['train_proba_p70']
p80 = meta['train_proba_p80']
p90 = meta['train_proba_p90']
print(f"  Seuils model: P60={p60} P70={p70} P80={p80} P90={p90}")
print(f"  Youden: {meta['threshold_youden']}")
print(f"  Test WR@Youden: {meta['perf_test_youden']['wr_filtered']*100:.1f}% n={meta['perf_test_youden']['n_filtered']}")
print(f"  ATTENTION: le modele a ete entraine AVEC f34/f35 mais le dataset n'a pas ces colonnes.")
print(f"  => Le modele a probablement ete entraine sur dataset_xau_v2_regime.csv")

regime_path = Path(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2_regime.csv')
if regime_path.exists():
    dr = pd.read_csv(regime_path)
    print(f"\n=== dataset_xau_v2_regime.csv ===")
    print(f"  n={len(dr)}  f34={dr.f34.mean():.3f}  f35={dr.f35.mean():.3f}")
    print(f"  WR base: {dr.label.mean()*100:.1f}%")
else:
    print(f"\n  MANQUANT: dataset_xau_v2_regime.csv n'existe pas!")

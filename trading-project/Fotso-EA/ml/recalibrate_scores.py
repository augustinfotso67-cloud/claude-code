"""
Recalibration des scoreHeuresPreCal et scoreJoursPreCal depuis les donnees reelles.
Produit les nouvelles valeurs a coller dans FotsoCerveauAdaptatif.mq5.
"""
import pandas as pd
import numpy as np

df = pd.read_csv(r'C:\Users\User\Fotso-EA\ml\dataset_xau_v2.csv')
df['timestamp'] = pd.to_datetime(df['timestamp'])
df['hour'] = df.timestamp.dt.hour
df['dow']  = df.timestamp.dt.weekday  # 0=Lun..6=Dim

avg_wr = df.label.mean()
print(f"WR global: {avg_wr*100:.2f}%  (n={len(df)})")

# ── Heures ────────────────────────────────────────────────────────
print("\n=== WR par heure (GMT) ===")
hr = df.groupby('hour').agg(n=('label','count'), wr=('label','mean')).reset_index()
hr['ratio'] = hr.wr / avg_wr
hr['cap_ratio'] = hr.ratio.clip(0.70, 1.45)  # cap conservateur

scores_h = [1.0] * 24
for _, row in hr.iterrows():
    h = int(row.hour)
    # Lissage : poids selon le volume de trades
    weight = min(1.0, row.n / 200.0)  # 200 trades = pleine confiance
    raw = row.ratio
    # Arrondi a 3 decimales
    scores_h[h] = round(1.0 * (1 - weight) + raw * weight, 3)

print("  H  | n    | WR%   | ratio | score")
print("  ---+------+-------+-------+------")
for _, row in hr.iterrows():
    h = int(row.hour)
    skip_flag = " << SKIP" if scores_h[h] < 0.85 else ""
    boost_flag = " ^ BOOST" if scores_h[h] >= 1.10 else ""
    print(f"  {h:02d} | {int(row.n):4d} | {row.wr*100:5.1f}% | {row.ratio:.3f} | {scores_h[h]:.3f}{skip_flag}{boost_flag}")

# ── Jours ─────────────────────────────────────────────────────────
print("\n=== WR par jour (0=Lun..6=Dim) ===")
dow_names = ["Lun","Mar","Mer","Jeu","Ven","Sam","Dim"]
dy = df.groupby('dow').agg(n=('label','count'), wr=('label','mean')).reset_index()
dy['ratio'] = dy.wr / avg_wr

scores_d = [1.0] * 7
for _, row in dy.iterrows():
    d = int(row.dow)
    weight = min(1.0, row.n / 400.0)
    raw = row.ratio
    scores_d[d] = round(1.0 * (1 - weight) + raw * weight, 3)

print("  Jour | n    | WR%   | ratio | score")
print("  -----+------+-------+-------+------")
for _, row in dy.iterrows():
    d = int(row.dow)
    print(f"  {dow_names[d]:3s}  | {int(row.n):4d} | {row.wr*100:5.1f}% | {row.ratio:.3f} | {scores_d[d]:.3f}")

# ── Sortie MQL5 ───────────────────────────────────────────────────
print("\n=== CODE MQL5 A COPIER DANS FotsoCerveauAdaptatif.mq5 ===")
print()
print("double scoreHeuresPreCal[24] = {")
line = ""
for i, s in enumerate(scores_h):
    line += f"   {s:.3f},"
    if (i+1) % 6 == 0:
        comments = {0:"//  0h- 5h", 6:"//  6h-11h", 12:"// 12h-17h", 18:"// 18h-23h"}
        c = comments.get(i-5, "")
        print(f"{line}  {c}")
        line = ""
print("};")
print()
print("double scoreJoursPreCal[7] = {")
for i, (s, n) in enumerate(zip(scores_d, dow_names)):
    comma = "," if i < 6 else ""
    print(f"   {s:.3f}{comma}  // {n}")
print("};")

# ── Impact estime ─────────────────────────────────────────────────
print("\n=== IMPACT ESTIME ===")
# Simuler le filtre avec les nouveaux scores
df['cs_new'] = df.apply(lambda r: scores_h[r.hour] * scores_d[r.dow], axis=1)
filtered_new = df[df.cs_new >= 0.85]
print(f"Avant filtre : n={len(df)}  WR={df.label.mean()*100:.1f}%")
print(f"Apres filtre (cs>=0.85) : n={len(filtered_new)}  WR={filtered_new.label.mean()*100:.1f}%")
print(f"Trades conserves : {len(filtered_new)/len(df)*100:.0f}%")
print(f"Gain WR : +{(filtered_new.label.mean()-df.label.mean())*100:.1f}pp")

# Par heure filtre
removed = df[df.cs_new < 0.85]
if len(removed) > 0:
    print(f"\nHeures skippees (cs < 0.85):")
    for _, row in hr.iterrows():
        h = int(row.hour)
        if scores_h[h] < 0.85:
            n_skip = len(df[df.hour == h])
            print(f"  H{h:02d}: {n_skip} trades  WR={row.wr*100:.1f}%")

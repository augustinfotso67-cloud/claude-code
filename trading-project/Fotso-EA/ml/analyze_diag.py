import pandas as pd, numpy as np, re

p = r"C:\Users\User\Desktop\Nouveau dossier (3)\Fotso_diag_pwin.csv"
df = pd.read_csv(p, encoding="cp1252", engine="python", on_bad_lines="skip")
df.columns = [c.strip() for c in df.columns]

op = df[df["Type"] == "FERMETURE"].copy() if "Type" in df.columns else None
# Type column may hold 'FERMETURE' or trade type; detect via 'Profit' numeric on close rows
df["is_close"] = df["Profit"].astype(str).str.contains(r"-?\d", regex=True) & (df["Profit"].astype(str) != "OUVERT")
opens = df[df["Profit"].astype(str) == "OUVERT"]
closes = df[df["Profit"].astype(str) != "OUVERT"].copy()
closes["pnl"] = pd.to_numeric(closes["Profit"], errors="coerce")
closes = closes.dropna(subset=["pnl"])

print(f"Periode: {df['Date'].iloc[0]} -> {df['Date'].iloc[-1]}")
print(f"Ouvertures: {len(opens)} | Fermetures avec PnL: {len(closes)}")
print(f"PnL total (diag): {closes['pnl'].sum():.2f}")
w = closes[closes.pnl > 0]; l = closes[closes.pnl < 0]; be = closes[closes.pnl == 0]
print(f"Gagnants: {len(w)} | Perdants: {len(l)} | BE(=0): {len(be)}  => WR={len(w)/len(closes)*100:.1f}%")
print(f"Gain moy: {w.pnl.mean():.2f}  Perte moy: {l.pnl.mean():.2f}")
print(f"PF = {w.pnl.sum() / abs(l.pnl.sum()):.2f}")
print()

# Categoriser la RAISON de fermeture (colonne RaisonSL contient le texte)
def reason(row):
    t = str(row.get("RaisonSL", "")) + " " + str(row.get("Signal", ""))
    t = t.lower()
    if "tp_atteint" in t or "objectif" in t: return "TP atteint"
    if "sl_touche" in t and "march" in t:    return "SL (marche contre)"
    if "overlap" in t or "session" in t:     return "Filtre session/overlap"
    if "miroir" in t or "manipulation" in t: return "Miroir Institutionnel"
    if "apprentissage" in t or "wr bas" in t:return "Apprentissage WR bas"
    if "adn inconnue" in t or "phase" in t:  return "ADN phase change"
    if "skip ml" in t:                       return "Skip ML"
    return "autre"

closes["raison"] = closes.apply(reason, axis=1)
print("=== Raison de fermeture x PnL ===")
g = closes.groupby("raison")["pnl"].agg(["count", "sum", "mean"]).sort_values("count", ascending=False)
print(g.to_string())
print()
# Quel % des gains sont des micro-gains (<5$) = fermetures precoces non-TP
micro = w[w.pnl < 5]
print(f"Gains < 5$ (micro / sorties precoces): {len(micro)}/{len(w)} = {len(micro)/len(w)*100:.0f}% des trades gagnants")
print(f"  -> ils pesent {micro.pnl.sum():.2f}$ sur {w.pnl.sum():.2f}$ de gains bruts")
print()
# brain_p distribution sur les ouvertures
bp = pd.to_numeric(opens["brain_p"], errors="coerce").dropna()
print(f"brain_p (ouvertures): n={len(bp)} min={bp.min():.3f} max={bp.max():.3f} mean={bp.mean():.3f} median={bp.median():.3f}")
print(f"  part >= 0.50 : {(bp>=0.50).mean()*100:.0f}%   >= 0.693 : {(bp>=0.693).mean()*100:.0f}%")

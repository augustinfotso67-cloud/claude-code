import pandas as pd, numpy as np
df = pd.read_csv(r"C:\Users\User\Fotso-EA\ml\dataset_live.csv")
ctx = df.f22                 # = CLIP(ContextScore(), 0.5, 1.5)
adx = df.f06*100             # adx_h4
print("=== f22 (context_score, deja clippe 0.5-1.5) ===")
print(f"  min={ctx.min():.3f} max={ctx.max():.3f} mediane={ctx.median():.3f}")
print(f"  quantiles: q33={ctx.quantile(1/3):.3f}  q50={ctx.median():.3f}  q67(SEUIL F6)={ctx.quantile(2/3):.3f}")
print(f"  % >=0.75 (filtre actuel CS_SkipThreshold) : {(ctx>=0.75).mean()*100:.0f}%")
print("\n=== adx_h4 ===")
print(f"  min={adx.min():.1f} max={adx.max():.1f} mediane={adx.median():.1f}")
print(f"  quantiles: q33(SEUIL F6)={adx.quantile(1/3):.1f}  q50={adx.median():.1f}  q67={adx.quantile(2/3):.1f}")
print(f"\nFILTRE F6 = (context_score >= {ctx.quantile(2/3):.3f})  ET  (adx_h4 <= {adx.quantile(1/3):.1f})")
n=((ctx>=ctx.quantile(2/3))&(adx<=adx.quantile(1/3))).sum()
print(f"  -> {n}/{len(df)} trades gardes ({n/len(df)*100:.0f}%)")

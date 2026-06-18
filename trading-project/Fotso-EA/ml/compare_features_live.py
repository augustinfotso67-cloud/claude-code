import pandas as pd, numpy as np, sys
from pathlib import Path
sys.path.insert(0, r"C:\Users\User\Fotso-EA\ml")
import indicators as ind

DATA = Path(r"C:\Users\User\Desktop\Nouveau dossier (3)\xauusd")

def load(suffix):
    f = [x for x in DATA.iterdir() if suffix.lower() in x.name.lower() and x.suffix==".csv"][0]
    cols=["datetime","open","high","low","close","volume","x"]
    try: df=pd.read_csv(f,header=0,names=cols,encoding="utf-16")
    except Exception: df=pd.read_csv(f,header=0,names=cols,encoding="utf-8")
    s=str(df["datetime"].iloc[0])
    fmt="%Y.%m.%d %H:%M" if ":" in s else "%Y.%m.%d"
    df["datetime"]=pd.to_datetime(df["datetime"],format=fmt)
    df=df.set_index("datetime").sort_index()
    df=df[~df.index.duplicated(keep="first")]
    return df

m15=load("M15"); h1=load("H1"); h4=load("H4")
d1=h4.resample("D").agg({"open":"first","high":"max","low":"min","close":"last","volume":"sum"}).dropna()
for df in (m15,h1,h4,d1):
    df["atr14"]=ind.atr(df["high"],df["low"],df["close"],14)
h4["adx14"],_,_=ind.adx(h4["high"],h4["low"],h4["close"],14)
d1["ema200"]=ind.ema(d1["close"],200)

def prev_idx(ts,index):
    return max(0,index.searchsorted(ts,side="left")-1)

diag=pd.read_csv(r"C:\Users\User\Desktop\Nouveau dossier (3)\Fotso_diag_pwin.csv",encoding="cp1252",engine="python",on_bad_lines="skip")
diag.columns=[c.strip() for c in diag.columns]
opens=diag[diag["Profit"].astype(str)=="OUVERT"].copy()
opens["ts"]=pd.to_datetime(opens["Date"].str.strip()+" "+opens["Heure"].str.strip(),format="%Y.%m.%d %H:%M",errors="coerce")
opens=opens.dropna(subset=["ts"])

rows=[]
for _,r in opens.iterrows():
    ts=r["ts"]
    ih1=prev_idx(ts,h1.index); ih4=prev_idx(ts,h4.index); id1=prev_idx(ts,d1.index)
    # barre M15 exacte (contenant ts)
    exact_m15=max(0,m15.index.searchsorted(ts,side="right")-1)
    close=m15["close"].iloc[exact_m15]
    e200=d1["ema200"].iloc[id1]
    rows.append(dict(
        ts=r["ts"],
        atr_m15_log=float(r["atr_m15"]), atr_m15_py=m15["atr14"].iloc[exact_m15],
        atr_h1_log=float(r["atr_h1"]),  atr_h1_py=h1["atr14"].iloc[ih1],
        atr_h4_log=float(r["atr_h4"]),  atr_h4_py=h4["atr14"].iloc[ih4],
        adx_h4_log=float(r["adx_h4"]),  adx_h4_py=h4["adx14"].iloc[ih4],
        d1d_log=float(r["ema200_d1_dist_pct"]),
        d1d_py=(close-e200)/e200*100 if e200>0 else np.nan,
    ))
c=pd.DataFrame(rows)
def pe(a,b): return (abs(a-b)/(abs(b)+1e-9)*100)
print(f"Comparaison sur {len(c)} ouvertures (live log vs Python pipeline)\n")
for col in ["atr_m15","atr_h1","atr_h4","adx_h4"]:
    err=pe(c[f"{col}_log"],c[f"{col}_py"])
    print(f"{col:8s}: erreur median={err.median():5.1f}%  moy={err.mean():6.1f}%  max={err.max():6.1f}%")
errd=(c["d1d_log"]-c["d1d_py"]).abs()
print(f"d1_dist : ecart absolu median={errd.median():.2f} pts  moy={errd.mean():.2f}  (valeurs ~10-15)")
print("\n--- 12 premieres lignes ---")
pd.set_option("display.width",200,"display.max_columns",30)
print(c.head(12).round(3).to_string(index=False))

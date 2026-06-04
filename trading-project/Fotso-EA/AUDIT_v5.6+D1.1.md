# Audit — Cerveau Adaptatif v5.6+D1.1 HOTFIX

**Date :** 2026-05-09
**Fichier :** `FotsoCerveauAdaptatif.mq5` (97 KB / 2453 lignes)
**Auditeur :** Claude (3 passes)

---

## 🟢 Ce qui est OK (validé)

- **HOTFIX D1.1 cohérent** : les **4 filtres** mentionnés dans le commentaire sont **tous** correctement bypassés via `DG_AllowSellAgainstD1()` :
  - `d1UltraHaussier` (EvaluerCerveau l.1512) ✅
  - `_d1Bull` signal SELL (OnTick l.649) ✅
  - `_d1Bull` pullback SELL (OnTick l.658) ✅
  - `dirSell` H4 EMA (EvaluerCerveau l.1546) ✅
- **DualGuard A/B/C** architecturalement propre : modules indépendants, override en lecture seule sur l'état suspendu.
- **Apprentissage borné** : `riskDynamique ∈ [0.2, 1.5]`, `scoreMiniDynamique ∈ [3, 5]` — pas de runaway.
- **`lossesConsecutifs` reset à 0** sur un win (pas de drift).
- **Init mémoire** avec priors raisonnables (boost Londres/NY heures 8-10 et 14-16, jours mardi-jeudi).
- **Conversion MQL5→Python dow** proprement faite dans `ContextScore()` (l.366-371).
- **Pas de fuite de handle** indicator dans `DG_DetectH4Reversal` — release fait dans tous les chemins.

---

## 🔴 BUGS RÉELS — à fixer

### Bug #1 — `OnTradeTransaction` compte les non-SL comme cascade SL
**Fichier :** l.1717-1729
```mq5
if(UseDualGuard && profit < 0)
  {
   long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(dealType == DEAL_TYPE_SELL)
     {
      DG_RegisterBuySL(TimeCurrent());   // ⚠️ TOUTE perte BUY, pas seulement SL
     }
  }
```

**Impact :** sont comptés comme "SL BUY" dans le buffer cascade :
- Fermetures par `GererFermetureForce` (timeout 48h)
- Fermetures `FermerVendredi` à 20h
- Break-even qui clôture légèrement négatif
- Toute fermeture manuelle perdante

**Conséquence concrète :** 3 vendredis 20h en perte → cascade-1 déclenchée → BUY suspendu 24h le lundi sans raison. C'est probablement déjà arrivé en backtest.

**Fix :**
```mq5
ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
if(dealType == DEAL_TYPE_SELL && reason == DEAL_REASON_SL)
  {
   DG_RegisterBuySL(TimeCurrent());
  }
```

---

### Bug #2 — Apprentissage temporel biaisé (heure fermeture vs ouverture)
**Fichier :** l.773-778, `MettreAJourCerveau()`
```mq5
MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);   // ⚠️ heure de FERMETURE
cerveau[idx].scoreHeures[dt.hour] =
   cerveau[idx].scoreHeures[dt.hour] * 0.9 + facteur * 0.1;
```

**Impact :** si un trade ouvre à 9h et ferme à 14h, c'est **14h** qui prend le bonus/malus, alors que la décision d'entrée a été prise à 9h. Sur D1/H4, les trades durent souvent 4-12h → biais systémique.

**Fix :** stocker l'heure d'ouverture dans `tradeLogEntries[]` (déjà existe), retrouver via ticket/deal-in :
```mq5
// Récupérer l'heure d'OUVERTURE depuis le log interne
ulong posIn = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
datetime tOpen = ... // à retrouver via le log existant ou history deal IN
TimeToStruct(tOpen, dt);
```

---

### Bug #3 — Persistance binaire sans versioning
**Fichier :** l.701-742, `ChargerMemoireCerveau()`
```mq5
FileReadArray(h, cerveau);   // ⚠️ lit aveuglément, pas de check de taille
```

**Impact :** si la struct `ClaudeMemoire` change (nouveau champ), le fichier de prod est lu **silencieusement comme corrompu**. Les anciens scores apparaissent comme du bruit dans les nouveaux champs. Aucun warning.

**Fix minimal :**
```mq5
ulong fileSize = FileSize(h);
ulong expectedSize = sizeof(ClaudeMemoire) * 6;
if(fileSize != expectedSize)
  {
   Print("Claude-Core : taille fichier incompatible (", fileSize,
         " vs attendu ", expectedSize, ") — réinitialisation");
   FileClose(h);
   // → tomber dans le `else` d'init vierge
  }
```

**Mieux :** ajouter un magic number + version au début du fichier.

---

## 🟠 Fragilités / dette technique

### #4 — Cast `int(datetime)` dans buffer DualGuard (Y2038 latent)
**Fichier :** l.402, 410, 422
```mq5
int dgRecentBuySL[20] = {0};                        // ⚠️ int = 32 bits
dgRecentBuySL[0] = (int)when;                       // tronque silencieusement
if((datetime)dgRecentBuySL[i] >= cutoff) count++;   // overflow Y2038
```

**Fix :** `long dgRecentBuySL[20]` ou `datetime dgRecentBuySL[20]`.

### #5 — Création/release handles indicateurs à chaque tick
**Fichier :** `DG_DetectH4Reversal()` (l.428), aussi `EvaluerCerveau()` autour l.1529.
```mq5
int handleEma = iMA(...);   // créé
...
IndicatorRelease(handleEma); // détruit
```

Appelé à chaque OnTick (via `DG_ShouldBlockBuy`). MQL5 met les indicateurs en cache, donc le coût n'est pas explosif, mais c'est anti-idiomatique. Stocker en globaux init dans `OnInit()`.

### #6 — Asymétrie seuils EMA200 D1
- `OnTick` : `_d1Bull = px > ema200D1[0] * 1.003` (0.3%)
- `EvaluerCerveau` : `d1UltraHaussier = prix > ema200D1[0] * 1.005` (0.5%)

Pourquoi deux seuils différents pour des conditions sémantiquement proches ? À documenter ou unifier.

### #7 — `OnTradeTransaction` filtre par `DEAL_TYPE_SELL` au lieu de `DEAL_ENTRY_OUT`
Marche par chance grâce au filtre `profit == 0 → return` au début. Mais pour un deal de retournement (`DEAL_ENTRY_INOUT`), le comportement est ambigu. Bonne pratique :
```mq5
ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
if(entry != DEAL_ENTRY_OUT) return;
```

---

## 🟡 Architecture / clarté

### #8 — Découplage caché : adaptatif ↔ pré-calibré
- `MettreAJourCerveau` met à jour `cerveau[idx].scoreHeures[]` (apprentissage runtime)
- `ContextScore()` lit `scoreHeuresPreCal[24]` (pré-calibré 32 mois)
- **Aucun pont entre les deux.** L'apprentissage ne nourrit pas le filtre v5.6.

C'est peut-être un choix — pré-calibré = "vérité historique stable", adaptatif = "ajustement local". Mais à documenter explicitement, sinon c'est trompeur (le user pense que le robot apprend en continu et améliore le filtre, ce qui est faux).

### #9 — Monolithe 2453 lignes
Refactor recommandé en modules `.mqh` :
- `Brain.mqh` (Claude-Core memory, ContextScore)
- `DualGuard.mqh` (les 6 fonctions DG)
- `Signals.mqh` (BOS, Pinbar, Engulfing, Pullback, EvaluerCerveau)
- `Analyse.mqh` (ADN, Empreinte Psy, Miroir Institutionnel)
- `Risk.mqh` (CalculerSLDynamique, CalculerLots)
- `Trade.mqh` (OuvrirTrade, BE, Trailing, FermetureForce)
- `Filters.mqh` (sessions, news, spread, range)
- `Logging.mqh` (logs, notifications, dashboard)
- `FotsoCerveauAdaptatif.mq5` (~200 lignes : OnInit, OnTick, OnTradeTransaction)

Ça rend chaque évolution future trivialement testable et review-able.

### #10 — `#property strict` (l.45)
Legacy MQL4. Sans effet en MQL5 (le strict est implicite). À supprimer pour clarté.

---

## 📋 Plan d'action recommandé (par priorité)

| # | Action | Effort | Impact |
|---|---|---|---|
| 1 | Fix Bug #1 (DEAL_REASON_SL) | 5 min | Élimine fausses cascades |
| 2 | Fix Bug #3 (versioning persistance) | 15 min | Évite corruption silencieuse |
| 3 | Fix Bug #2 (heure ouverture vs fermeture) | 30 min | Apprentissage correct |
| 4 | Fix Fragilités #4, #5, #7 | 30 min | Robustesse |
| 5 | Documentation #6, #8 | 10 min | Clarté |
| 6 | Refactor #9 en modules .mqh | 2-3h | Maintenabilité |

---

## ❓ Questions avant de toucher au code

1. **Backtests** : tu en envoies — c'est sur quelle période et quel symbole ? (XAUUSDm M15 supposé)
2. Le découplage adaptatif/pré-calibré est-il **intentionnel** ?
3. Le compteur cascade DG enregistre actuellement TOUTE perte BUY — as-tu déjà vu en backtest des suspensions BUY déclenchées par des fermetures non-SL (vendredi 20h) ?
4. Tu veux qu'on attaque dans quel ordre : fix les 3 bugs réels d'abord, ou refactor d'abord ?

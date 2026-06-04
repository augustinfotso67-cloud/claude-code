# Synthèse marché XAUUSD — fondations pour l'EA

**Données analysées** : XAUUSDm M15 / M30 / H1 / H4, re-téléchargées (Exness MT5).
**Couverture** : 2020-01-05 → 2026-05-28 (H1/H4/M30 ~1 989 jours, M15 depuis 2022-03).
**Rappel objectifs EA** : WR ≥ 60 %, WR SELL ≥ 50 %, Profit Factor ≥ 1.8, Max DD ≤ 10 %, Profit net ≥ +20 %.

> ⚠️ **Qualité données** : H1/H4/M30 sont **journaliers (1 barre/jour à 00:00) de 2020-01 à 2021-07-16**, puis vrai intraday. M15 est intraday partout (depuis 2022-03). Le profil horaire/sessions n'est fiable que sur la partie intraday — le M15 fait référence.

---

## 1. Régime annuel — l'or n'a quasiment fait que monter

| Année | Régime | Rendement | DD intra-an | Range moy/jour | |move| moy/jour | % jours UP |
|---|---|---:|---:|---:|---:|---:|
| 2020 | **BULL** | +20.7 % | -14.0 % | $26.5 | 0.75 % | 57.9 % |
| 2021 | RANGE | -4.5 % | -13.6 % | $20.6 | 0.53 % | 50.6 % |
| 2022 | RANGE | -0.3 % | **-20.4 %** | $22.1 | 0.62 % | 51.9 % |
| 2023 | **BULL** | +12.8 % | -11.2 % | $20.7 | 0.52 % | 48.2 % |
| 2024 | **BULL** | +27.2 % | -8.0 % | $28.5 | 0.61 % | 55.3 % |
| 2025 | **BULL** | **+64.6 %** | -9.9 % | $52.8 | 0.75 % | 58.0 % |
| 2026* | RANGE | +1.9 % | **-20.1 %** | **$128.2** | **1.37 %** | 50.8 % |

\* 2026 = 126 jours seulement.

**Lecture critique :**
- **5 années sur 6 sont haussières.** Le biais BUY de l'EA (98 % des trades) a été *récompensé par l'histoire*, mais c'est de la chance de survie : **aucune année franchement baissière n'existe dans ce dataset.** Le plus proche d'un marché vendeur = les *creux intra-annuels* de 2021 (-13.6 %), **2022 (-20.4 %)** et **2026 (-20.1 %)**.
- → **La branche SELL n'a toujours pas de vrai terrain de validation.** Pour la stress-tester il faut backtester précisément ces fenêtres : **2022 entier**, **drawdown 2021**, et **2026 (forte volatilité bidirectionnelle)**.

---

## 2. ⚡ Le changement le plus important : explosion de la volatilité

| | 2020-2024 | 2025 | 2026 |
|---|---:|---:|---:|
| Range moyen / jour | $20–28 | $52 | **$128** |
| Mouvement \|open→close\| moyen | 0.5–0.75 % | 0.75 % | **1.37 %** |
| Range max sur 1 jour | ~$127 | $291 | **$768** |

**Implication directe pour l'EA :** tout SL/TP/trailing calibré sur l'ancienne volatilité ($20–30/jour) est **obsolète en 2026**. Un stop "fixe en $" ou un multiple ATR figé sera soit balayé en permanence, soit ridiculement serré face à des journées à $768 de range. **Le sizing et les stops DOIVENT être proportionnels à l'ATR courant** — c'est la condition n°1 pour tenir le Max DD ≤ 10 % et viser un PF ≥ 1.8 dans le régime actuel.

---

## 3. Équilibre haussier / baissier

- Jours **UP : 53.5 %**  | jours **DOWN : 46.5 %** (open→close, 1 989 jours).
- Léger edge long, mais **46.5 % de jours baissiers = l'opportunité SELL existe largement** ; l'EA ne la prend simplement pas. Activer une vraie branche SELL (validée) est le levier le plus crédible pour l'objectif WR SELL ≥ 50 %.

---

## 4. Profil par jour de semaine (M15, intraday réel)

| Jour | move moy | % UP | Range moy | Verdict |
|---|---:|---:|---:|---|
| Lundi | +0.050 % | 53.8 % | $45 | correct |
| **Mardi** | **+0.114 %** | **57.0 %** | $46 | ✅ meilleur |
| **Mercredi** | **+0.125 %** | 55.4 % | $44 | ✅ meilleur |
| Jeudi | +0.050 % | 50.0 % | $47 | ⚖️ le plus faible / 50-50 |
| Vendredi | +0.079 % | 53.7 % | $48 | correct (mais clôture WE) |
| Dimanche | -0.012 % | 47.5 % | **$13** | 🚫 bruit, range minuscule |

**À retenir :** **Mardi/Mercredi** = meilleur biais haussier (favoriser BUY). **Jeudi** = quasi 50/50, le plus risqué directionnellement. **Dimanche** = à ne pas trader (range $13, gaps/bruit). *(Note : l'ancien diagnostic disait "Mardi = pertes" — les nouvelles données disent l'inverse, Mardi est désormais le meilleur jour.)*

---

## 5. Saisonnalité mensuelle

Mois **favorables** (BUY) : Janvier, Mars, Avril, Juillet, Octobre, Décembre (souvent 65–83 % positifs).
Mois **à risque** : **Juin** (-1.38 %, seulement 33 % positifs — pire mois), **Mai** et **Septembre** mitigés (sur 2022+ : Mai -1.27 %, Juin -0.85 %).

**À retenir :** effet "sell in May" présent sur l'or. **En mai-juin : réduire le risque BUY, autoriser/favoriser SELL.** Décembre et le Q1 (jan-avr) sont les périodes les plus porteuses en long.

---

## 6. Profil horaire / sessions (M15 — référence)

| Session (heure broker) | Volatilité (std) | Range moy | % UP | Verdict |
|---|---:|---:|---:|---|
| Asie (0-6) | 0.102 | $3.87 | 50.3 % | calme, peu de mouvement |
| Londres (7-12) | 0.115 | $4.25 | 50.7 % | montée en régime |
| **Overlap LDN/NY (13-16)** | **0.159** | **$6.22** | 51.3 % | ✅ fenêtre de mouvement principale |
| New York (17-21) | 0.097 | $3.57 | 50.8 % | se calme |
| Tardif (22-23) | 0.098 | $3.25 | **52.0 %** | petit biais haussier |

**Détails horaires marquants :**
- **Heures mortes : 3h–5h** (range $2.7–3.7, h4 std 0.06) → éviter les entrées breakout, faux signaux.
- **Heures de retournement/whipsaw : 13h et 15h** (rendement moyen **négatif** malgré gros range) → l'overlap bouge mais part souvent dans les deux sens ; entrer sur confirmation, pas sur la 1ère bougie. *(13h déjà flaggé dans l'ancien diagnostic.)*
- **23h** : léger biais haussier récurrent (53 % UP).
- **Conclusion** : la fenêtre 13h–16h porte l'essentiel du mouvement exploitable ; viser les entrées tendance là, filtrer le bruit d'Asie.

---

## 7. Ce qui est BON / MAUVAIS pour atteindre les objectifs

### ✅ Favorable
- Le marché **tend** beaucoup (5/6 ans bull) → une stratégie trend-following BUY a un terrain naturel.
- Mardi/Mercredi + Q1/Q4 + overlap 13-16h = contextes à privilégier pour le long.
- 46.5 % de jours DOWN = matière première suffisante pour une branche SELL rentable.

### ⚠️ À corriger en priorité
1. **Sizing/stops non adaptatifs à l'ATR** → incompatibles avec le régime 2026 ($128/jour). **Priorité n°1.**
2. **Branche SELL jamais validée** → backtester 2022 (bear -20 % DD), creux 2021, et 2026 avant tout réel. Tant que `PF_SELL > 1.5` n'est pas démontré, l'objectif WR SELL ≥ 50 % est théorique.
3. **Dimanche** : exclure du trading (range $13, bruit).
4. **Mai-Juin** : réduire l'exposition BUY (saisonnalité négative).
5. **Heures 3h-5h et bougies 13h/15h** : filtrer (faux signaux / whipsaw).

### 🎯 Verdict objectifs
- **WR ≥ 60 % / PF ≥ 1.8 / +20 %** : atteignables côté BUY dans un marché haussier, à condition de **stops ATR-adaptatifs** (sinon le régime 2026 casse le PF).
- **WR SELL ≥ 50 %** : **non démontrable sur ce dataset sans backtest ciblé** des fenêtres baissières — c'est le chantier de validation prioritaire.
- **Max DD ≤ 10 %** : tenable historiquement (DD intra-an max -20 % en 2022/2026 sur le sous-jacent, l'EA doit rester bien en-dessous via sizing ATR + DailyStopLoss).

---

## Fichiers produits
- `analysis/{M15,M30,H1,H4}_report.md` — profils détaillés par TF.
- `analysis/{M15,M30,H1,H4}_daily.csv` — **enregistrement jour par jour** (open/high/low/close, rendement, range, true range, direction, volume) — 1 ligne = 1 jour.
- `ml/analyze_market.py` — script reproductible (relançable sur BTC/US30/USTEC).

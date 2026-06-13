# FOTSO AI Analyst — Spec produit (Phase 3 SaaS)

**Statut** : Idéation
**Origine** : 13 juin 2026 — inspiration par le produit "Code Ton Trade" (TikTok @codetontrade)
**Cible déploiement** : Post-D1 (septembre 2026 au plus tôt)
**Owner** : Augustin Fotso (DG)

---

## Vision du produit

Un **assistant d'analyse de marché** activé depuis TradingView, qui ne donne **PAS** de signaux "BUY/SELL" binaires, mais une **analyse de régime + scénario conditionnel + invalideurs + garde-fous** — version automatisée de la méthodologie FOTSO COMPANY.

Différenciation radicale vs concurrents (CodeTonTrade et autres) :
- 🟢 **Pas de signal binaire**. Toujours un scénario *si X alors Y, sinon Z*.
- 🟢 **Toujours un invalideur explicite** ("si prix franchit Z, la lecture est morte")
- 🟢 **Garde-fous macro** intégrés (NFP, CPI, FOMC dans les 4h → mode prudence forcé)
- 🟢 **Pas de Take Profit imaginaire** — uniquement zones de prise de profit basées sur structure
- 🟢 **Transparence** : on dit explicitement quand on n'est pas sûr

---

## Architecture technique (réaliste, faisable en 1-2 mois solo)

```
Utilisateur (TradingView ou WhatsApp)
       ↓
    Bot WhatsApp / Extension Chrome (frontend)
       ↓ HTTP POST {symbol, timeframe, screenshot ou OHLC}
    Backend Node/Python (sur VPS Hetzner 5€/mois)
       ↓ enrichissement (calendrier news, régime XAU, etc.)
       ↓ API Claude (claude-haiku-4-5 pour rapide+pas cher)
    Retour formaté JSON {régime, scénario, invalideur, garde-fous}
       ↓
    Affichage utilisateur (overlay ou message)
```

### Choix techniques par défaut
- **Modèle** : Claude Haiku (latence ~3 sec, coût ~0.01-0.05 USD/analyse) avec fallback Sonnet pour analyses complexes
- **Backend** : Node.js / Express ou Python FastAPI sur VPS Hetzner CX22 (5 €/mois)
- **Frontend MVP** : Bot WhatsApp via Twilio (le plus rapide à déployer)
- **Frontend V2** : Extension Chrome qui overlay sur TradingView
- **Paiement** : Stripe + Wise pour comptes Cameroun

### Format de réponse type (à figer comme contrat API)
```json
{
  "symbol": "XAUUSD",
  "timeframe": "M15",
  "timestamp": "2026-06-13T13:15:29Z",
  "regime": {
    "type": "TRENDING_BULL",
    "confidence": 0.74,
    "comment": "Trend haussier H4 confirmé, ADX 32"
  },
  "scenario": {
    "direction": "LONG",
    "trigger": "Pullback vers 4 425-4 435 + bougie de rejet",
    "invalidation": "Cassure H1 < 4 410 = setup mort",
    "tp_zones": ["4 480 (résistance immédiate)", "4 510 (swing high)"],
    "rr_estimate": "1:1.5 à 1:2.3"
  },
  "guards": {
    "news_within_4h": ["NFP US 14:30 UTC"],
    "session": "London active",
    "recommendation": "WAIT post-NFP avant entrée"
  },
  "honesty": {
    "confidence_overall": "Moderate",
    "warning": "Vendredi NFP : risque de fake breakout"
  }
}
```

---

## Économie cible

### Coûts mensuels (estimation pour 300 utilisateurs)

| Poste | Coût |
|---|---|
| Claude Haiku API (300 × 30 analyses) | ~30-80 USD |
| VPS Hetzner CX22 | 5 USD |
| Twilio WhatsApp (300 utilisateurs) | 20-40 USD |
| Domaine + email | 2 USD |
| Stripe (% des revenus) | 3-5% |
| **Total fixe** | **~60-130 USD/mois** |

### Pricing FOTSO (différencié anti-gourou)

| Tier | Prix | Analyses incluses |
|---|---|---|
| Free | 0 USD | 5 analyses/mois (acquisition) |
| **Pro** | **9 USD/mois** | 50 analyses |
| Premium | 19 USD/mois | Illimitées + WhatsApp direct avec orchestrateur humain (toi) |

### Break-even et trajectoire

- 10 abonnés Pro = 90 USD/mois → couvre coûts + 30 USD
- 50 abonnés Pro = 450 USD/mois → couvre coûts + 350 USD (= 7× la cible D1)
- 100 abonnés Pro = 900 USD/mois → c'est le SaaS qui fait vivre FOTSO COMPANY

**Hypothèse marketing** : conversion 2-5% des audiences atteintes (canal Telegram, futurs canaux). Avec 1000 visiteurs/mois sur le site → 20-50 abonnés Pro.

---

## Pré-requis avant lancement

1. ✅ D1 atteinte (50 USD/mois minimum générés par services + Strategy Provider)
2. ✅ Méthodologie FOTSO d'analyse de marché documentée et reproductible
3. ✅ 5+ audits techniques publiés comme preuve d'expertise (audit GoldPipMiner = #1)
4. ✅ Strategy Provider XM lancé (preuve qu'on trade ce qu'on analyse)
5. ⬜ Prototype interne testé pendant 4 semaines (toi seul utilisateur)
6. ⬜ Validation juridique : disclaimer "advice ≠ recommendation", conformité brokers tiers

---

## Roadmap idéale

```
Aoû 2026  — D1 atteinte (50 USD/mois) → on dégage du temps pour Phase 3
Sep 2026  — Build MVP WhatsApp bot (4-6 semaines solo dev)
Oct 2026  — Beta privée avec 10 utilisateurs (canal Telegram fidèles)
Nov 2026  — Launch public Pro à 9 USD/mois
Déc 2026  — Itérations sur feedback, ajout extension Chrome
Q1 2027   — Si 50+ abonnés stables → embauche première personne (front-end ?)
```

---

## Risques identifiés (réels)

1. **API Claude coûts** : si analyse complexe → 0.30 USD chacune. À 300 utilisateurs × 30 analyses = 2 700 USD/mois si Sonnet partout. **Mitigation** : Haiku par défaut, Sonnet uniquement si user Premium.
2. **TradingView TOS** : extension Chrome qui lit le DOM peut être un risque (TradingView peut casser à chaque update). **Mitigation** : MVP en WhatsApp bot, pas d'extension dans un premier temps.
3. **Risque légal** : "conseil en investissement" est régulé. Le disclaimer "outil d'aide à la décision, pas conseil" doit être omniprésent. **Mitigation** : positionnement éducatif, pas conseil.
4. **Concurrence** : Code Ton Trade existe déjà. Mais marché énorme, segmentation possible. **Mitigation** : positionnement anti-gourou très net.
5. **Risque psychologique pour toi** : se laisser distraire de D1 par cette idée plus excitante. **Mitigation** : NE PAS toucher avant D1.

---

## Décision actée le 13 juin 2026

**Cette idée est notée et conservée en l'état. Aucun travail dessus avant D1 atteinte.**

Lisa a explicitement nommé ce risque : *"une idée plus excitante est le meilleur moyen de tuer la roadmap actuelle"*.

Pour le moment :
- ✅ Spec figée dans le repo
- ✅ Référence vers concurrent "Code Ton Trade" notée
- ⏸️ Aucune ligne de code, aucun setup, aucune réflexion supplémentaire avant septembre
- ⏸️ On revient sur le sujet en bilan mensuel juin (30 juin) seulement pour confirmer qu'on attend

---

— Document vivant, à enrichir lors des bilans mensuels FOTSO COMPANY

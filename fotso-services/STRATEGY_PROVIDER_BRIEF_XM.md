# Brief Strategy Provider XM — Préparation inscription

**Auteur** : Cabrel, broker-execution-specialist
**Date** : 12 juin 2026
**Statut** : Préparation pré-activation (le président activera quand v6.0 sera satisfaisante en live)

---

## Synthèse opérationnelle

### XM Copy Trading — la voie principale

| Élément | Valeur |
|---|---|
| Type de compte | Ultra Low Standard MT5 (USD) |
| Capital source minimum | **500-1000 USD** (500 = crédibilité min) |
| Track record avant promo | 30-60 jours live silencieux |
| Commission perf | **20%** (recommandé, plafond XM 50%) |
| Modèle | High Water Mark (HWM) |
| XM prend sur ta commission | **0%** (XM se rémunère sur le spread) |
| Min investment copieur | 100 USD |
| Méthode dépôt/retrait Cameroun | Skrill principal / Wise backup / Payoneer C |

### Bonus — XM Partners cumulable
- Inscription parallèle à XM Partners (rev share sur clients référés)
- Double monétisation : commission perf + revenu par copieur qui devient client XM via lien
- Zéro conflit, à activer ensemble

---

## Checklist du Jour J (9 étapes)

1. Login compte XM existant → Member Area → Open Additional Account → **Ultra Low Standard, USD, MT5**
2. Déposer **500-1000 USD** via Skrill
3. Installer v6.0 sur ce compte MT5, params validés v6.0
4. Laisser tourner **30 jours minimum** en silencieux AVANT soumission Strategy Manager
5. XM App → "Copy Trading" → "Become a Strategy Manager" → formulaire :
   - Nom : "FOTSO Gold Adaptive v6"
   - Description (voir pitch ci-dessous)
   - Performance fee : **20%**
   - Min investment copieur : **100 USD**
   - Risk level : "Moderate"
6. KYC additionnel possible (preuve de résidence < 3 mois + selfie)
7. Configurer compte source :
   - Risque par trade identique aux backtests
   - Pas de trades manuels parasites
   - Magic number unique
8. S'inscrire à **XM Partners** en parallèle
9. Monitoring hebdo : nb copieurs / AUM copiée / slippage source↔copieur (cible < 2 pips XAU)

---

## Pitch description Strategy Manager (modèle prêt)

> "Système automatisé sur XAU/USD, timeframe M15. Approche mean-reversion adaptative avec filtres horaires et directionnels. Objectif : Sharpe > 0.8, drawdown max 8%. Conçu pour stabilité, pas pour explosivité. Pas de martingale, pas de grid, pas de news trading. Risque fixe 1% par trade.
>
> Pas un système qui double le compte en 3 mois. Capital recommandé 500 USD minimum pour absorber le drawdown. Horizon évaluation : 6 mois minimum.
>
> Drawdown contrôlé = capital préservé."

→ Positionnement assumé : **sérieux, transparent, anti-gourou**. Cible copieurs éduqués, pas chasseurs de jackpot.

---

## Timeline réaliste

| Étape | Délai |
|---|---|
| Ouverture compte + dépôt | J+0 à J+3 |
| Track record live silencieux | J+3 à J+33 |
| Activation Strategy Manager + KYC | J+33 à J+45 |
| Premiers 1-3 copieurs organiques | J+45 à J+75 |
| Premier HWM franchi → commission | J+75 à J+120 |
| Premier retrait cash Cameroun | J+120 à J+135 |

**Taille copieurs à 4 mois** : réaliste **3-8 copieurs**, AUM 500-2 500 USD, commission perf **5-25 USD/mois**.

**Pour atteindre 50 USD/mois D1** : nécessite **~10-20 copieurs actifs, AUM ~5 000 USD copiée**. Réaliste à **6-9 mois** sans promo externe, **3-4 mois** avec stack XM Copy + XM Partners + MQL5 Signals + services techniques.

→ **Strategy Provider seul ne fait PAS les 50 USD/mois D1 d'ici fin août.** Les services techniques restent le vecteur principal d'atteinte de D1. Strategy Provider = capital long terme.

---

## Alternatives en backup

| Plateforme | Friction | Quand l'activer |
|---|---|---|
| **MQL5 Signals** | 6/10 (paiement Cameroun via Wise/Payoneer) | Dès 12 semaines track record live atteint |
| **ZuluTrade** | 5/10 | Phase 2 si besoin diversifier |
| **cTrader Copy** (Pepperstone/IC Markets) | 7/10 (nouveau KYC) | Phase 2 |

---

## 5 pièges à anticiper

1. **Slippage source vs copieurs** : tester d'abord avec 1 sous-compte XM perso comme premier "copieur"
2. **Délais KYC additionnels** : possible 5-10 jours ouvrés, anticiper docs
3. **Frais cachés conversion XAF/USD** : jusqu'à 3% spread bancaire
4. **Risque réputation** : si v6.0 démarre par DD 8% live, copieurs partent + reviews négatives → **commencer silencieusement 30-60j AVANT promo**
5. **Risque psychologique président** : si voit -3% live, tentation modifier l'EA → **hands-off 60 jours minimum**

---

*Sources consultées : XM Copy Trading docs officielles, MQL5 Signals rules, TradersUnion review 2026, daytrading.com ZuluTrade.*

— Cabrel

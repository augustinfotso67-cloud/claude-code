# Réunion de brainstorming — Pivot d'actif sous-jacent

**Date** : Lundi 15 juin 2026, 08h00 Cameroun (UTC+1)
**Format** : Brainstorming 8 voix (5 principales + 3 consultatives)
**Convoquée par** : Augustin Fotso (DG)
**Statut** : Document préparatoire — la décision sera prise par le DG après la réunion

---

## 🎯 PHASE 1 — Brouillon de la perspective du président (à valider/modifier demain matin)

> Brouillon basé sur tes messages des 12-14 juin. **Tu le modifies à ta guise demain matin avant le lancement.** Il doit rester TA voix, pas la mienne.

```
Équipe,

Le XAU/USD a été mon école pendant 4 mois. J'y ai construit toute notre 
méthodologie (v5.6 → v5.99 → v5.91 → v6.0), tous nos verdicts statistiques, 
toute notre infrastructure de test. Je ne regrette pas une heure.

Mais en faisant le bilan honnête de ce vendredi :
- v6.0 est validé sur XAU mais à ~3-4%/an avec DD 3-5%. C'est bien 
  techniquement, mais ce n'est pas assez pour mon contexte personnel à 
  court terme.
- v5.91 archivé : machine à beta XAU 2025.
- L'or est extrêmement volatile en 2026 (range journalier passé de $20 à $128). 
  J'ai eu beaucoup de DD émotionnels en chemin.

Après une nuit de réflexion, je propose une exploration :

DIRECTION : pivoter vers un actif moins volatile historiquement, avec un 
cours plus prévisible, moins d'évènements inattendus.

CANDIDATS : EUR/USD, US30, NAS100
- Le Cerveau Adaptatif est déjà multi-paires (6 supportées nativement)
- Ces 3 actifs sont déjà dans le code
- J'ai les données historiques sur ma machine, prêtes à backtester

CONTRAINTE : budget initial 50 USD (démo ou réel, à clarifier avec Fabiany).

ENJEU : D1 INCHANGÉE — 50 USD/mois de revenu généré par FOTSO d'ici 
fin août 2026.

Je veux votre avis honnête. Est-ce une bonne idée ou une fuite en avant ? 
Si oui, quel actif prioriser ? Quelle méthodologie de test ? Quel ordre 
tactique ?

Augustin
```

---

## 📋 CONTEXTE COMMUN À TOUS LES AGENTS

Avant chaque invocation, ce contexte sera transmis tel quel :

```
Contexte FOTSO COMPANY au 14 juin 2026 :

- v6.0 sur XAU/USD validé par Auréole : Sharpe OOS 0.88, DD 3-5%, 
  PF 1.16, profil Strategy Provider. Gelé production-ready.
- v5.91 + Regime Gate archivé : architecture inadaptée 
  (Cerveau Adaptatif non-filtrable).
- v5.99 brut sur 4.25 ans : PF 0.96, DD 17% (catastrophique).
- Pôle services lancé le 10 juin : audit GoldPipMiner publié 
  sur canal Telegram (780 membres), 0 lead à ce stade.
- Brief Strategy Provider XM préparé par Cabrel le 12 juin : 
  rail prêt, pas encore activé.
- D1 cible non-négociable : 50 USD/mois de revenu généré par 
  FOTSO d'ici 31 août 2026.
- Cadence Lisa : 5/2, max 1 décision majeure par semaine, 
  pas de modif EA en cours de live.
- Le président propose un PIVOT D'ACTIF : XAU → EUR/USD ou US30 
  ou NAS100, budget 50 USD initial.
- Le Cerveau Adaptatif est multi-paires (6 supportées nativement), 
  les données historiques sont dispo localement.

Cette réunion est CONSULTATIVE. La décision sera prise par le DG 
après synthèse orchestrateur.
```

---

## 🧠 PHASE 2 — Cercle principal (tour de table intégral)

### Louis — quant-strategist
**Question** : Sur quel actif (EUR/USD, US30, NAS100) l'edge a-t-il le plus de chances de transposer ? Quelles sont les microstructures spécifiques ? Les filtres v6.0 (heures gagnantes XAU calibrées sur fixings Shanghai/London) sont-ils transposables ou faut-il tout recalibrer ? Lequel correspond le mieux au critère "moins volatile et prévisible" du président ? Verdict honnête : est-ce un pivot stratégique sain ou une fuite ?

### Fabiany — risk-manager
**Question** : Sur 50 USD démo vs 50 USD réel — quelle reco ? Sizing minimum viable par actif (lot min EUR/USD vs US30 vs NAS100, contraintes broker Exness) ? Combien faut-il vraiment pour démarrer un compte réel viable (50, 200, 500, 1000) sans pulvériser le risque 1% par trade ? Risk policy si on bascule de XAU à ces actifs : quels kill switches recalibrer ?

### Cabrel — broker-execution-specialist
**Question** : Strategy Provider XM sur EUR/USD ou indices vs XAU — quel marché copy trading est le plus actif et le mieux rémunéré ? Spreads/commissions Exness pour ces 3 actifs (notamment Exness Standard vs Ultra Low) ? Restrictions techniques (lot min, contrats, swap weekends pour indices) ? Disponibilité des données historiques tick-level chez Exness pour ces actifs ?

### Mahamat — mql5-developer
**Question** : Le Cerveau v5.99 (FotsoCerveauAdaptatif.mq5) est-il VRAIMENT multi-paires opérationnel ou y a-t-il des paramètres XAU-hardcodés ? Quelles sont les 6 paires natives mentionnées dans le code ? Quelles adaptations code requises pour tester proprement EUR/USD vs indices (spread, contract size, point value, news feed) ? Y a-t-il un risque que le `brain_v4.onnx` embarqué soit XAU-spécifique ?

### Lisa — discipline-coach
**Question** : Cette décision de pivot d'actif est-elle RATIONNELLE ou ÉMOTIONNELLE ? Pattern à surveiller : "fuite en avant" après un verdict modeste sur v6.0 vs "exploration légitime exploitant les assets" ? Garde-fous à imposer AVANT le pivot pour éviter le cycle v5.6 → v5.99 → v5.91 répété sur EUR/USD ? Le président est-il en train de fuir le DD émotionnel XAU ou d'optimiser objectivement ?

---

## 📊 PHASE 3 — Cercle consultatif (1 paragraphe chacun)

### Auréole — backtest-auditor
**Question** : Avant de lancer un cycle de dev sur un nouvel actif, quels critères statistiques objectifs définir AVANT pour valider/rejeter chaque actif ? Combien de backtests minimum (sample size par actif) ? Définition opérationnelle de "succès" sur EUR/USD/indices (remplaçant le "je le saurai quand je le verrai" du 12 juin) ?

### Berios "Docta" — data-scientist
**Question** : Profils statistiques historiques comparés des 3 actifs candidats (volatilité, autocorrélation rendements, régimes structurels). Qualité requise des données du président (M15 ticks vs barres, dates couvertes, gaps) pour un test crédible. Quels biais data sont à anticiper sur EUR/USD ou indices vs XAU ?

### Aziz — forward-test-watchman
**Question** : Indicateurs spécifiques à monitorer en démo paper trading selon l'actif (différences EUR/USD vs indices vs XAU). Drift live vs backtest typique par actif (spreads variables, gaps weekends pour indices, etc.). Temps minimum forward test avant inscription Strategy Provider sur ces actifs : 30 jours suffisant ou plus ?

---

## 🎯 PHASE 4 — Synthèse orchestrateur (mon rôle)

Après que les 8 agents auront rendu, je produis :

1. **Carte des positions** : consensus / divergences / abstentions
2. **3 scénarios actionables** :
   - 🅰️ Pivot complet vers actif X
   - 🅱️ Test multi-actif parallèle
   - 🅲️ Pas de pivot, focus services
3. **Risques majeurs** identifiés par l'équipe
4. **Recommandation orchestrateur** (avec biais explicite)

## 🎯 PHASE 5 — Décision du président

Le président tranche. Sa décision est commitée comme `DECISION_PIVOT_15JUIN.md` dans le repo. Si la décision est "pivot acté", on planifie S3-revised + S4.

---

## 📅 Timeline opérationnelle de demain matin

```
08h00 — Le président valide/modifie le brouillon Phase 1
08h05 — Orchestrateur lance les 8 agents EN PARALLÈLE 
        (en mode background, durée ~3-5 min chacun)
08h25 — Tous les agents ont rendu
08h30 — Orchestrateur livre la synthèse Phase 4
08h45 — Le président lit, réfléchit
09h00 — Décision actée Phase 5
09h15 — Doc commité, plan S3-revised si pivot
09h30 — Fin de réunion, président reprend sa journée
```

**Charge réelle pour le président** : ~30-45 min de présence active. Le reste tourne en arrière-plan.

---

*Document préparé le 14 juin 2026 à 20h22 par l'orchestrateur, en vue de la réunion du 15 juin 2026 08h00.*

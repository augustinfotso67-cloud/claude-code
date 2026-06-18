# Verdict — Regime Gate sur Fotso_Cerveau_v591

**Date** : 12 juin 2026
**Équipe** : Louis (spec), Mahamat (code), Auréole (audit), orchestrateur (consolidation)
**Statut** : 🗄️ **v5.91 ARCHIVÉ — hypothèse de régime réfutée sur cet EA**

---

## Hypothèse testée

Le président pensait que v5.91 atteignait ses objectifs combinés (WR 60%, PF 1.5, gros rendement) en 2025, et qu'un **interrupteur de régime** (gate A∧B) permettrait de ne le laisser tourner que dans son régime viable, capturant 2025 tout en coupant 2022 (bear) et 2026 (chop haut niveau).

Spec Louis : gate = Filtre A (Close D1 > EMA200 D1 + pente positive) **ET** Filtre B (ADX D1 ≥ seuil). Discriminant clé : ADX D1 sépare le bull directionnel 2025 (ADX > 30) du chop haut-niveau 2026 (ADX < 25).

## Backtests — 4 runs (2022.01 → 2026.06, Risk 2%, Every tick)

| Run | Gate | ADX min | Trades | PF | DD | Sharpe | Net |
|---|---|---|---|---|---|---|---|
| REF | OFF | — | 700 | 0.92 | 11.0% | -0.38 | **-463 $** |
| RG-22 | ON | 22 | 419 | 1.08 | 4.9% | +0.43 | **+275 $** |
| RG-25 | ON | 25 | 355 | 0.83 | 10.0% | -0.70 | **-630 $** |
| RG-28 | ON | 28 | 303 | 1.02 | 5.2% | +0.11 | **+56 $** |

## Pourquoi c'est REJETÉ

### 1. Résultat non-monotone (garde-fou anti-curve-fit de Louis)
ADX 22 → +275 / ADX 25 → **-630** / ADX 28 → +56.
Le verdict bascule entre les seuils ronds adjacents, et NON-monotonement. Louis l'avait posé comme critère éliminatoire : *« Si le verdict bascule entre 22 et 28, le filtre est fragile → INUTILISABLE. »* Un vrai régime se lit sur une plage de seuils. Ici, non.

### 2. Aucun seuil ne passe les 4 critères de victoire
| Critère | RG-22 | RG-25 | RG-28 |
|---|---|---|---|
| ≥ 70% gain 2025 | ✅ | ✅ | ❌ |
| Réduit pertes 2022+2026 ≥ 50% | ✅ | ❌ | ✅ |
| Net > 0 ET **PF > 1.3** | PF 1.08 ❌ | ❌❌ | PF 1.02 ❌ |
| ≥ 100 trades | ✅ | ✅ | ✅ |

Le critère #3 (PF > 1.3) tombe partout.

### 3. La cause profonde — apprentissage adaptatif inséparable
v5.91 = "Cerveau Adaptatif" : sa mémoire interne (`riskDynamique`, `scoreMiniDynamique`, `scoreHeures`) évolue avec la séquence des trades.

**Découverte clé** : v5.91 fait +9 605 $ sur 2025 en **standalone** (compte démarré frais en jan 2025), mais seulement **+875 $** sur 2025 en **continu** (après avoir digéré 2022-2024). Le "+7 077 $ stable" que le président jugeait prometteur était un **artefact de mémoire vierge**.

→ On ne peut pas filtrer proprement en amont un EA dont l'apprentissage dépend de la séquence : le filtre change la mémoire en aval, produisant les résultats non-monotones observés. C'est structurel, pas un problème de réglage.

## Conclusion

L'intuition du président — *« il y a des régimes où ça marche et des régimes où rien ne survit »* — **est juste pour le marché**. Mais **cet EA-ci n'a pas l'architecture pour l'exploiter** : son adaptation interne le rend non-filtrable proprement.

En conditions réelles (tournant en continu), v5.91 fait **-463 $ sur 4,4 ans**. C'est une machine à beta XAU 2025, inséparable de son régime et de son état de mémoire.

**Décision : v5.91 archivé. Pas de troisième patch (règle Louis respectée).**

## Ce qui survit
- **v6.0** reste l'EA de référence (validé, Sharpe OOS 0.88, DD 3-5%, profil Strategy Provider).
- La méthodologie a fonctionné : hypothèse posée, critères figés AVANT, verdict accepté sur les faits.

— Équipe FOTSO COMPANY

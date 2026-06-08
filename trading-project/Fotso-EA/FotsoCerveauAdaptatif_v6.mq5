//+------------------------------------------------------------------+
//|         LE CERVEAU ADAPTATIF DE FOTSO                           |
//|         Expert Advisor Unique au Monde                          |
//|                                                                  |
//|   "Ce robot ne trade pas les indicateurs.                       |
//|    Il trade la psychologie, l'ADN et l'empreinte                |
//|    institutionnelle des marchés financiers."                    |
//|                                                                  |
//|   Création exclusive : Augustin Fotso & Claude                  |
//|   Technologie : Claude-Core Intelligence Adaptative             |
//|   Version : 5.6+D1.1 — DUAL ENRICHISSEMENT + FIX SELL          |
//|                                                                  |
//|   BASE : v5.5 (architecture intacte, 5 modules + Claude-Core)  |
//|                                                                  |
//|   ─── HOTFIX v5.6+D1.1 (3 mai 2026) ────────────────────────  |
//|   Bug détecté en backtest réel : "SELL BLOQUÉ v5.3 — D1        |
//|   haussier" affiché en permanence en uptrend. Cause : 3        |
//|   filtres durs bloquaient les SELL avant que DualGuard         |
//|   override puisse s'exécuter. CORRIGÉ :                         |
//|   - EvaluerCerveau() : filtre v5.3 d1UltraHaussier             |
//|   - EvaluerSignaux() : filtre _d1Bull pour signal SELL         |
//|   - EvaluerSignaux() : filtre _d1Bull pour pullback SELL       |
//|   - EvaluerCerveau() : filtre dirSell basé sur H4 EMA          |
//|   Tous ces filtres sont maintenant bypassés UNIQUEMENT quand   |
//|   DualGuard est en mode suspension active (DG_AllowSellAgainstD1)|
//|                                                                  |
//|   ENRICHISSEMENTS v5.6+D1 (2 changements ISOLABLES via inputs):|
//|                                                                  |
//|   ─── CHANGEMENT 1 : FILTRE CONTEXTUEL (UseContextFilter) ───   |
//|   Source : 32 mois XAU + 949 trades simulés v5.5               |
//|   scoreHeuresPreCal[24] + scoreJoursPreCal[7]                  |
//|   Hybride : skip<0.85 | risk×cs sinon | boost cap 1.05         |
//|                                                                  |
//|   ─── CHANGEMENT 2 : DUALGUARD ANTI-CASCADE (UseDualGuard) ──   |
//|   Source : 41 corrections D1>1.5% + 81 séries ≥3SL identifiées |
//|   Module A : détection H4 rapide (2 bougies bear sous EMA50)   |
//|              → suspend BUY 8h                                   |
//|   Module B : coupe-circuit cascade (3SL/12h, 5SL/48h)         |
//|              → suspend BUY 24h ou 72h                          |
//|   Module C : OVERRIDE — débloque les SELL pendant suspension   |
//|              (corrige le bug du filtre v5.3)                   |
//+------------------------------------------------------------------+
#property copyright "Augustin Fotso & Claude — Le Cerveau Adaptatif"
#property version   "6.00"
#property strict
//
// ===================================================================
// CHANGELOG v6.0 (2026-06-08) — FILTRES DATA-DRIVEN (Louis quant) :
//   Source : analyse du backtest 4.25 ans de v5.99 (1967 trades).
//   v5.99 brute  : PF 0.98 / Net -293$ (perte legere).
//   v5.99 filtree: PF 1.30 / Net +1851$ / DD -3.8% sur le meme dataset.
//
//   HYPOTHESE ECONOMIQUE (Louis) :
//     - Heures GAGNANTES = pre-fixing asiatique tardif + pre-London open
//       (broker GMT+3 : 2,3,4,6,8,9).
//     - Heures PERDANTES = fixing London AM/PM + news US (drainage de
//       liquidite, faux mouvements).
//     - Jeudi PERDANT = drainage de liquidite pre-NFP/CPI.
//
//   3 FILTRES AJOUTES (tous parametrables, master switch InpUseV6Filters):
//     1. FILTRE HORAIRE : trade autorise seulement sur InpAllowedHours.
//     2. FILTRE JEUDI   : skip jeudi si InpSkipThursday.
//     3. FILTRE ADX DIRECTIONNEL (ADX H4) :
//          BUY  autorise si ADX_H4 > InpADX_BuyMin (default 30).
//          SELL autorise si InpADX_SellMin < ADX_H4 < InpADX_SellMax (20..30).
//     (+ filtre volatilite ATR H4 OFF par defaut, gain marginal.)
//
//   IMPLEMENTATION : point d'insertion UNIQUE dans OuvrirTrade() — couvre
//   les 5 chemins d'ouverture (BUY/SELL tendance, pullback, override DG).
//   ADX H4 reutilise le handle existant hADX_H4_brain (cree en
//   InitIndicateurs, libere en OnDeinit). Aucun nouveau handle.
//
//   v5.99 RESTE LA BASELINE GELEE. Ce fichier est une COPIE enrichie.
// ===================================================================
//
// CHANGELOG v5.9 (2026-05-27) — RECALIBRATION MAJEURE :
//   - BRAIN ML v3 (brain_v2_clean.onnx) : retrain sans data leakage.
//     Train 2022-2025.05 / Test OOS 2025.05-2026.05 -> AUC=0.9422.
//     WR test @P60: 89.1% (36% trades) vs base 40.2%. Plus de faux 88%.
//   - CONTEXT SCORES recalibrés sur 5490 signaux dataset réels :
//     Jeudi SKIP (WR 32.5%) / Vendredi BOOST (WR 45.4% vs ancienne pénalité)
//     H06/H07 SKIP (WR 33%) / H22 SKIP (WR 30%) / H16-H17 BOOST (WR 46-47%)
//     Impact : WR 40.6% -> 43.1% par filtrage seul (+2.6pp, 80% trades conservés)
//   - ComputeRecentWR default 0.5 -> 0.40 (aligne sur WR réel training XAU)
//   - ML thresholds alignés sur percentiles train v3 (P60/P70/P80/P90)
//
// CHANGELOG v5.7 (2026-05-12) :
//   - BUG #1 FIX : DG cascade compte seulement les vrais SL (DEAL_REASON_SL)
//   - BUG #2 FIX : scoreHeures utilise l'heure d'OUVERTURE du trade (DEAL_TIME entry)
//   - BUG #3 FIX : ClaudeCore_Fotso.dat versionné (magic + version, anti-corruption)
//   - FIX atr   : lecture shift 1 (bougie clôturée) + fallback shift 0
//   - ML LOG    : log enrichi avec 19 features (ATR M15/H1/H4, ADX, EMA200 D1 dist,
//                 scores, ContextScore, peur/cupidite/épuisements, force_explo, DG flags)
//   - BRAIN ML  : modulateur de risque par ONNX RandomForest entraîné sur 549 trades.
//                 P(win) < 0.40 → skip / < 0.50 → x0.5 / < 0.60 → x1.0 / ≥ 0.60 → x1.5
//   - TREND TF  : filtre directionnel sur EMA200 TF configurable (default H4 au lieu de D1).
//                 Problème résolu : avant 0 SELL/mois en uptrend D1 long. Maintenant H4
//                 se retourne plus vite et permet de capter les corrections.

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// v5.7 : le modèle ONNX est embarqué comme ressource dans l'EX5.
// Cela évite les problèmes de sandbox du Strategy Tester (qui isole MQL5\Files\).
// Au compile time, MetaEditor lit MQL5\Files\brain_v1.onnx et l'incorpore au binaire.
// → après compilation, l'EA est autonome, le fichier .onnx n'est plus requis sur disque.
#resource "\\Files\\brain_v4.onnx" as uchar BrainMLModelData[]  // v6.2 : label realiste + contre-tendance

CTrade        trade;
CPositionInfo posInfo;

//+------------------------------------------------------------------+
//|                   PARAMÈTRES                                     |
//+------------------------------------------------------------------+
input double RiskPercent        = 1.0;
input double DailyStopLoss      = 20.0;
input double TP1_RR             = 1.5;
input double TP2_RR             = 2.5;
input double ATR_Multiplier     = 2.5;    // v5.1 : réduit de 2.5 → 2.0 (SL moins large)
input int    MaxTradesJour      = 5;      // v6.1 : 5 trades/jour (plafond relevé pour volume)
input int    MaxHeuresTrade     = 48;
input int    LondonStart        = 2;
input int    LondonEnd          = 13;
input int    NYStart            = 14;
input int    NYEnd              = 23;
input bool   FiltrerNews        = true;
input int    NFP_Avant          = 60;  input int NFP_Apres = 60;
input int    CPI_Avant          = 60;  input int CPI_Apres = 30;
input int    FED_Avant          = 120; input int FED_Apres = 60;
input string FF_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json";
input bool   UseForexFactory    = true;
input bool   UseBreakEven       = true;
input double BE_ATR_Multi       = 2.0;    // v5.2 : BE à 2.0x ATR (1.5x trop proche)
input bool   UseTrailing        = true;
input double Trail_ATR_Multi    = 2.5;
input bool   ShowDashboard      = true;
input bool   EnableLogs         = true;
input string LogFile            = "Fotso_Cerveau_log_v58.csv";
// ── Protection Capital ──────────────────────────────────────────
input double HWM_AlertPct      = 10.0;
input double HWM_StopPct       = 20.0;
input double WeeklyMaxLoss     = 6.0;
input bool   FermerVendredi    = true;
input int    VendrediHeure     = 20;
input int    MaxLossesJour     = 3;

// ── Notifications Claude-Core ──────────────────────────────────────
input bool   NotifMT5Push      = true;
input bool   NotifMT5Alerte    = true;
input bool   NotifEmail        = false;
input string EmailDestinataire = "";
input bool   NotifOuverture    = true;
input bool   NotifFermeture    = true;
input bool   NotifBE           = true;
input bool   NotifSignalFaible = false;
input bool   NotifRegime       = true;
input bool   NotifDailyStop    = true;
input bool   NotifCerveau      = true;

// ── v5.6 : ENRICHISSEMENT DATA-DRIVEN — Filtre contextuel ─────────
input bool   UseContextFilter   = true;   // Active la pré-calibration data-driven
input double CS_SkipThreshold   = 0.75;   // v6.1 : 0.80->0.75, ML protège contre les mauvaises heures
input double CS_BoostCap        = 1.05;   // Cap du boost de risque (prudent)
input bool   ShowContextScore   = true;   // Afficher CS dans le dashboard
input bool   LogContextScore    = true;   // Logger CS dans le CSV trades

// ── v5.7 : FILTRE DIRECTIONNEL — TF de tendance configurable ─────
// AVANT : tous les filtres SELL/BUY contre-tendance utilisaient EMA200 D1, ce qui
//         bloquait quasi tous les SELL pendant un long uptrend D1 (problème vécu :
//         1 mois sur Or/BTC/US30/USTEC = 0 SELL, 100% BUY).
// MAINTENANT : on utilise EMA200 sur le TF choisi (default H4) qui se retourne
//         beaucoup plus vite et permet à l'EA de SELL pendant les corrections H4.
input ENUM_TIMEFRAMES TrendFilterTF = PERIOD_H1;   // v6.1 : H4->H1, tendance sur les 40 dernières bougies H1
input int             TrendFilterPeriod = 40;      // v6.1 : EMA40 H1 (~1.7 jour, très réactif)

// ── v6.1 : BRAIN ML v3 H1EMA40 — 36 features, XGBoost H1 EMA40, AUC OOS=0.9309 ──
// 4372 train (2022-2025.05) / 1118 test OOS (2025.05-2026.05), WR base=40.2%
// Test OOS @P60: WR=89.1% (36% trades) | @Youden(0.501): WR=83.5% (44% trades)
// Modele: brain_v2_clean.onnx — plus de data leakage vs brain_v1.
input bool   UseBrainML        = false;   // v6.3 : OFF par defaut (brain sans edge + coupe le trading hors distribution)
input string BrainML_OnnxFile  = "brain_v4.onnx";  // v6.2 : label realiste + contre-tendance (GBT, AUC OOS=0.774)
// Seuils v6.2 brain_v4 — labels honnetes (SL prioritaire), test OOS 2025-09->2026-05 :
//   gate 0.40 -> WR=63.9% @43% | 0.45 -> 65.4% @41% | 0.693 -> 69.1% @26% | 0.726 -> 70.2% @15%
//   SELL desormais valide et > BUY (gate 0.40 : WR_BUY=60.6% WR_SELL=66.8%)
input double BrainML_SkipBelow = 0.40;     // v6.2 : volume d'abord -> WR~64% @ ~43% trades
input double BrainML_HalfRisk  = 0.50;     // v6.2 : [0.40,0.50[ demi-risque
input double BrainML_FullRisk  = 0.693;    // v6.2 : P70 train -> WR~69%
input double BrainML_BoostThreshold = 0.726; // v6.2 : P80 train -> WR~70%
input double BrainML_BoostMul  = 1.5;     // Multiplicateur boost
input bool   BrainML_LogProba  = true;    // Log de P(win) dans le journal Print
input bool   BrainML_CollectFeatures = false; // COLLECTE : logue les 36 features reelles MT5 -> Fotso_ml_features.csv (pour reentrainer le brain aligne live)

// ── v5.6+D1 : DUALGUARD ANTI-CASCADE ──────────────────────────────
input bool   UseDualGuard           = true;   // Active la protection anti-cascade
// Module A : détection rapide H4
input bool   UseDualGuardH4         = true;   // 2 bougies H4 bear sous EMA50
input int    DualGuardH4_BearCount  = 3;      // v6.1 : 2->3 bougies H4 bear (moins sensible marché haussier)
input double DualGuardH4_BodyMin    = 0.5;    // Corps min (× ATR H4) pour valider
input int    DualGuardH4_SuspendH   = 4;      // v6.1 : 8->4h de suspension BUY
// Module B : coupe-circuit cascade
input bool   UseDualGuardCascade    = false;  // v6.1 : OFF (cascade rare avec ML WR=83%, freine inutilement)
input int    DG_Casc1_NbSL          = 3;      // Nb SL pour 1er niveau
input int    DG_Casc1_WindowH       = 12;     // Fenêtre temporelle 1er niveau (h)
input int    DG_Casc1_SuspendH      = 24;     // Suspension après 1er niveau
input int    DG_Casc2_NbSL          = 5;      // Nb SL pour 2e niveau
input int    DG_Casc2_WindowH       = 48;     // Fenêtre 2e niveau (h)
input int    DG_Casc2_SuspendH      = 72;     // Suspension après 2e niveau
// Module C : override D1 (SELL autorisé pendant suspension BUY)
input bool   UseDualGuardOverride   = true;   // SELL contre D1 autorisé en suspension

// ── v6.0 : FILTRES DATA-DRIVEN (specs Louis, backtest 1967 trades) ──
// Tout est OFF si InpUseV6Filters = false (retour au comportement v5.99).
input bool   InpUseV6Filters = true;             // Master switch des filtres v6.0
input string InpAllowedHours = "2,3,4,6,8,9";    // Heures broker (GMT+3) autorisees
input bool   InpSkipThursday = true;             // Skip jeudi (drainage pre-NFP/CPI)
input int    InpADX_Period   = 14;               // Periode ADX H4 (info/coherence handle)
input double InpADX_BuyMin   = 30.0;             // BUY autorise si ADX_H4 > 30
input double InpADX_SellMin  = 20.0;             // SELL autorise si 20 < ADX_H4 ...
input double InpADX_SellMax  = 30.0;             // ... < ADX_H4 < 30
input bool   InpUseVolFilter = false;            // Filtre volatilite ATR H4 (OFF, gain marginal)
input double InpATR_H4_Max   = 19.0;             // Si InpUseVolFilter : skip si ATR_H4 > seuil

//+------------------------------------------------------------------+
//|     v5.9 — TABLES DE PRÉ-CALIBRATION (recalibrées 5490 signaux) |
//|     Source : dataset ML 2022-2026 XAU (4450 BUY / 1040 SELL)    |
//|     Impact filtrage : WR 40.6% -> 43.1% (+2.6pp, 80% trades)    |
//+------------------------------------------------------------------+
// Multiplicateurs par heure (0h-23h, GMT broker)
// H06/H07 (London pré-ouverture) et H22 (fin NY) = SKIP (<0.85)
double scoreHeuresPreCal[24] = {
   1.000, 1.000, 1.000, 1.018, 1.003, 0.967,  //  0h- 5h
   0.814, 0.840, 0.963, 0.899, 1.032, 0.986,  //  6h-11h : 6h/7h SKIP
   0.947, 1.000, 1.061, 1.035, 1.122, 1.152,  // 12h-17h : 16h/17h BOOST
   1.093, 0.973, 0.909, 1.048, 0.755, 1.000   // 18h-23h : 22h SKIP
};

// Multiplicateurs par jour (Lun=0, Mar=1, ..., Dim=6)
// ATTENTION : Jeudi (0.801) = SKIP sur toutes heures normales
// Vendredi = BOOST (correction vs ancienne calibration 0.922)
double scoreJoursPreCal[7] = {
   1.178,  // Lundi    ★ meilleur jour (WR 47.8%)
   0.956,  // Mardi    ↓ légère pénalité (WR 38.8%)
   0.997,  // Mercredi   neutre (WR 40.4%)
   0.801,  // Jeudi    ✗ SKIP — WR 32.5% (pire jour)
   1.118,  // Vendredi ★ très bon (WR 45.4%) — recalibration majeure
   1.000,  // Samedi   neutre (rare)
   1.000   // Dimanche neutre (peu de trades)
};

//+------------------------------------------------------------------+
//|          CLAUDE-CORE — MÉMOIRE ADAPTATIVE                       |
//+------------------------------------------------------------------+
struct ClaudeMemoire {
   char   paire[20];
   double winRate;
   int    totalWinsPaire;
   int    totalLossesPaire;
   double profitNetPaire;
   double scoreHeures[24];
   double scoreJours[7];
   double riskDynamique;
   double atrMultDynamique;
   int    scoreMiniDynamique;
   double atrMoyenne;
   double adxMoyenne;
   int    totalTrades;
   datetime derniereMAJ;
   int    lossesConsecutifs;
   double slMultiDynamique;
};

ClaudeMemoire cerveau[6];
string ClaudeCoreFile = "ClaudeCore_Fotso.dat";

int GetPaireIndex()
  {
   string sym = Symbol();
   if(StringFind(sym,"XAU")>=0||StringFind(sym,"GOLD")>=0) return 0;
   if(StringFind(sym,"BTC")>=0)                             return 1;
   if(StringFind(sym,"EUR")>=0)                             return 2;
   if(StringFind(sym,"GBP")>=0)                             return 3;
   if(StringFind(sym,"NAS")>=0)                             return 4;
   if(StringFind(sym,"US30")>=0||StringFind(sym,"DJ")>=0)   return 5;
   return 2;
  }

//+------------------------------------------------------------------+
//|          IDÉE 3 — L'ADN DU MOUVEMENT (4 phases)                 |
//+------------------------------------------------------------------+
enum PhaseADN { ADN_INCONNUE=0, ADN_ACCUMULATION=1,
                ADN_COMPRESSION=2, ADN_DECLENCHEUR=3, ADN_EXPLOSION=4 };

struct ADNMouvement {
   PhaseADN phase;
   bool     haussier;
   double   niveauDeclencheur;
   double   forceExplosion;
};

struct EmpreintePsy {
   double   indexPeur;
   double   indexCupidite;
   double   epuisementVendeurs;
   double   epuisementAcheteurs;
   bool     retournementIminent;
   bool     directionHaussiere;
};

struct MiroirInstitutionnel {
   double   niveauLiquiditeHaut;
   double   niveauLiquiditeBas;
   bool     manipulationDetectee;
   bool     piegeTendance;
   double   cibleInstitutionnelle;
   bool     confirmationEntree;
};

//+------------------------------------------------------------------+
//|   STRUCTURE LOG TRADE v5.1 — Pour log OUVERTURE avec raison    |
//+------------------------------------------------------------------+
struct TradeLogEntry {
   ulong    ticket;
   string   signal;
   string   adn;
   string   direction;
   double   entry;
   double   sl;
   double   tp;
   string   raisonSL;   // Raison du SL (pourquoi ce niveau)
   string   raisonTP;   // Raison du TP (pourquoi ce niveau)
   bool     isPullback;
   datetime timeOuvert;
};

TradeLogEntry tradeLogEntries[500];
int tradeLogCount = 0;

//+------------------------------------------------------------------+
//|                    VARIABLES GLOBALES                            |
//+------------------------------------------------------------------+
double   startOfDayBalance  = 0;
int      tradesToday        = 0;
datetime lastDayChecked     = 0;
bool     robotActif         = true;
double   dailyPnL           = 0;
int      totalWins          = 0;
int      totalLosses        = 0;
string   lastSignal         = "Cerveau en veille...";
string   etatCerveau        = "Initialisation...";
string   lastRegimeNotif    = "";

double   highWaterMark      = 0;
double   weeklyStartBalance = 0;
datetime lastWeekChecked    = 0;
int      lossesAujourdhui   = 0;
datetime lastBarTime        = 0;
int      tradesCeBarre      = 0;

struct NewsEvent {
   datetime time; string name; int avant; int apres; string source;
};
NewsEvent newsEvents[];
int       newsCount = 0;

int hEMA200_D1, hRSI, hStoch, hADX, hATR, hBollinger;
double ema200D1[], rsiVal[], stochMain[], stochSignal[];
// v5.7 : EMA200 sur le TF directionnel (H4 par defaut) — utilisee par les filtres
int    hEMA200_TREND = INVALID_HANDLE;
double ema200Trend[];
double adxMain[], adxPlus[], adxMinus[], atrVal[];
double bbUpper[], bbMiddle[], bbLower[];
// v5.8 : handles supplementaires pour BrainML 36 features
int hATR_M15_brain   = INVALID_HANDLE;  // ATR M15/14
int hATR_H4_brain    = INVALID_HANDLE;  // ATR H4/14
int hADX_H4_brain    = INVALID_HANDLE;  // ADX H4/14
int hEMA200_H4_brain = INVALID_HANDLE;  // EMA200 H4
int hEMA50_H4_brain  = INVALID_HANDLE;  // EMA50 H4

//+------------------------------------------------------------------+
//|                         OnInit                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   startOfDayBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
   highWaterMark      = AccountInfoDouble(ACCOUNT_BALANCE);
   weeklyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lastWeekChecked    = TimeCurrent();
   lastDayChecked     = TimeCurrent();
   lossesAujourdhui   = 0;

   if(!InitIndicateurs()) return INIT_FAILED;

   ChargerMemoireCerveau();

   LoadNewsFromMT5();
   if(UseForexFactory && !MQLInfoInteger(MQL_TESTER))
      LoadNewsFromForexFactory();

   if(EnableLogs) InitLogFile();
   BrainML_InitCollectFile();
   EventSetTimer(3600);

   int idx = GetPaireIndex();
   Print("╔══════════════════════════════════════════════════╗");
   Print("║  LE CERVEAU ADAPTATIF DE FOTSO v5.6+D1          ║");
   Print("║  Augustin Fotso & Claude — Mai 2026             ║");
   Print("╠══════════════════════════════════════════════════╣");
   Print("║ Paire      : ", Symbol());
   Print("║ WR mémorisé: ", DoubleToString(cerveau[idx].winRate, 1), "%");
   Print("║ Trades hist: ", cerveau[idx].totalTrades);
   Print("║ Risk dynami: ", DoubleToString(cerveau[idx].riskDynamique, 2), "%");
   Print("║ Score mini : ", cerveau[idx].scoreMiniDynamique, "/6");
   Print("╠══════════════════════════════════════════════════╣");
   Print("║ CHANGEMENT 1 : FILTRE CONTEXTUEL [", UseContextFilter?"ON":"OFF","]");
   Print("║   - 32 mois XAU + 949 trades simulés v5.5      ║");
   Print("║   - cs<0.85=SKIP | cs<1.10=risk×cs | sinon×",DoubleToString(CS_BoostCap,2),"║");
   Print("║   - WR 38.1→58.1% / PF 1.07→2.48 (TEST 2026)  ║");
   Print("╠══════════════════════════════════════════════════╣");
   Print("║ CHANGEMENT 2 : DUALGUARD ANTI-CASCADE [", UseDualGuard?"ON":"OFF","]");
   Print("║   - Module H4 [",   UseDualGuardH4?"ON":"OFF",
         "] : ",DualGuardH4_BearCount," bougies bear → ",DualGuardH4_SuspendH,"h");
   Print("║   - Module Casc [", UseDualGuardCascade?"ON":"OFF","] : ",
                          DG_Casc1_NbSL,"SL/",DG_Casc1_WindowH,"h → ",DG_Casc1_SuspendH,"h");
   Print("║                            ", DG_Casc2_NbSL,"SL/",DG_Casc2_WindowH,"h → ",DG_Casc2_SuspendH,"h");
   Print("║   - Override SELL [",UseDualGuardOverride?"ON":"OFF","]");
   Print("║   - Source : 41 corrections + 81 séries SL    ║");
   Print("╠══════════════════════════════════════════════════╣");
   Print("║ ContextScore actuel : ", DoubleToString(ContextScore(),3));
   Print("║ DualGuard SL 12h/48h : ", DG_CountBuySLInWindow(DG_Casc1_WindowH),
                                  " / ", DG_CountBuySLInWindow(DG_Casc2_WindowH));
   Print("╚══════════════════════════════════════════════════╝");

   // ── BrainML : chargement du modèle ONNX ──
   if(UseBrainML)
     {
      BrainML_Init();   // erreurs gérées en interne : mode dégradé si KO
     }

   // v5.7.1 : en visualisation tester, MT5 attache parfois automatiquement les indicateurs
   // créés par l'EA dans des sous-fenêtres du chart M15, masquant le dashboard.
   // On tente de les retirer (no-op si pas présents).
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
     {
      // On essaie tous les noms courts possibles selon les params
      ChartIndicatorDelete(0, 1, "Stochastic(5,3,3)");
      ChartIndicatorDelete(0, 1, "Stochastic");
      ChartIndicatorDelete(0, 2, "ATR(14)");
      ChartIndicatorDelete(0, 2, "ATR");
      ChartIndicatorDelete(0, 1, "ATR(14)");
      ChartIndicatorDelete(0, 1, "ATR");
     }

   etatCerveau = "Actif v5.9 — BrainML v3 AUC=0.9422 OOS | CS recalibré | DualGuard";
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   SauvegarderMemoireCerveau();
   BrainML_Deinit();
   EventKillTimer();
   NettoyerDashboard();
   IndicatorRelease(hEMA200_D1); IndicatorRelease(hEMA200_TREND);
   IndicatorRelease(hRSI);
   IndicatorRelease(hStoch);     IndicatorRelease(hADX);
   IndicatorRelease(hATR);       IndicatorRelease(hBollinger);
   // v5.8 : liberation handles BrainML supplementaires
   if(hATR_M15_brain   != INVALID_HANDLE) IndicatorRelease(hATR_M15_brain);
   if(hATR_H4_brain    != INVALID_HANDLE) IndicatorRelease(hATR_H4_brain);
   if(hADX_H4_brain    != INVALID_HANDLE) IndicatorRelease(hADX_H4_brain);
   if(hEMA200_H4_brain != INVALID_HANDLE) IndicatorRelease(hEMA200_H4_brain);
   if(hEMA50_H4_brain  != INVALID_HANDLE) IndicatorRelease(hEMA50_H4_brain);
   ArrayFree(newsEvents);
   Print("Cerveau sauvegardé. W:", totalWins, " L:", totalLosses);
  }

void OnTimer()
  {
   ResetQuotidien();
   LoadNewsFromMT5();
   if(UseForexFactory && !MQLInfoInteger(MQL_TESTER))
      LoadNewsFromForexFactory();
  }

//+------------------------------------------------------------------+
//|     v5.6 — ContextScore() : multiplicateur data-driven         |
//|     Retourne scoreHeure × scoreJour pour le moment courant      |
//|     Source : 6 périodes de 6 mois validées forward 2026         |
//+------------------------------------------------------------------+
double ContextScore()
  {
   // Si XAUUSDm uniquement — applicable seulement aux paires gold
   // Pour les autres paires, neutre (1.0) jusqu'à analyse dédiée
   string sym = Symbol();
   bool isXAU = (StringFind(sym,"XAU")>=0 || StringFind(sym,"GOLD")>=0);
   if(!isXAU) return 1.0;

   if(!UseContextFilter) return 1.0;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   int dow  = dt.day_of_week;  // 0=Sun, 1=Mon, ..., 6=Sat (MQL5 convention)

   // Conversion MQL5 (0=Dim) vers convention Python (0=Lun)
   int dayIdx;
   if(dow == 0)      dayIdx = 6;  // Dimanche
   else              dayIdx = dow - 1;  // Lun=0, Mar=1, ..., Sam=5

   if(hour < 0 || hour > 23)  return 1.0;
   if(dayIdx < 0 || dayIdx > 6) return 1.0;

   double sH = scoreHeuresPreCal[hour];
   double sJ = scoreJoursPreCal[dayIdx];
   return sH * sJ;
  }

//+------------------------------------------------------------------+
//|     v5.6 — RiskMultiplierFromCS() : modulation hybride          |
//|     Mode HYBRIDE choisi : skip si cs < 0.85, risk × cs sinon    |
//|     Boost capé à CS_BoostCap (×1.05 prudent)                   |
//+------------------------------------------------------------------+
double RiskMultiplierFromCS(double cs)
  {
   if(!UseContextFilter)      return 1.0;
   if(cs < CS_SkipThreshold)  return 0.0;        // signal SKIP
   if(cs >= 1.10)             return CS_BoostCap; // boost capé
   return cs;                                     // modulation continue
  }

//+------------------------------------------------------------------+
//|     v5.6+D1 — DUALGUARD ANTI-CASCADE                            |
//|     Détecte et coupe les cascades de SL en BUY contre-tendance |
//|     Source : 81 séries ≥3SL identifiées sur 32 mois XAU        |
//+------------------------------------------------------------------+
// Variables d'état DualGuard (persistantes entre ticks)
datetime dgBuySuspendUntil  = 0;          // Timestamp jusqu'auquel BUY est suspendu
string   dgSuspendReason    = "";         // Raison lisible pour log/dashboard
int      dgRecentBuySL[20]  = {0};        // Buffer rolling des timestamps de SL BUY
int      dgRecentBuySL_count = 0;         // Nombre d'entrées dans le buffer

// ── ML LOG : snapshots des features au moment de la décision/ouverture ────
// Set par OnTick juste avant OuvrirTrade(), lu par LogOuverture()
int    g_lastSignalBuy   = 0;
int    g_lastSignalSell  = 0;
// Set par OuvrirTrade() avant LogOuverture()
double g_lastCS          = 1.0;
double g_lastRiskMul     = 1.0;
double g_lastRiskUsed    = 0.0;
double g_lastSlDistPts   = 0.0;

// ── ML BRAIN v5.8 : handle ONNX + derniere prediction + historique regime ──
long   g_onnxBrainHandle = INVALID_HANDLE;
double g_lastPwin        = -1.0;   // derniere P(win) calculee (-1 = inconnu)
double g_lastMlMult      = 1.0;    // dernier multiplicateur ML applique
const int BRAINML_NFEATURES = 36;  // brain_v1.onnx : 36 features (v5.8)
float  g_lastFeatures[36];         // COLLECTE : cache du dernier vecteur envoye au modele
const string BrainML_CollectFile = "Fotso_ml_features.csv"; // sortie collecte features

// Historique circulaire des 25 derniers resultats (pour f34/f35 recent_wr)
struct BrainTradeResult { bool win; };
BrainTradeResult g_brainHistory[25];
int g_brainHistoryCount = 0;  // nombre de resultats enregistres (0..25)
int g_brainHistoryHead  = 0;  // index de la prochaine ecriture (circulaire)

// Score du dernier signal evalue (set par EvaluerCerveau avant return)
int g_lastScoreBase  = 3;   // score_base (0-6), default mid
int g_lastScoreBonus = 3;   // score_bonus (0-7), default mid

// Enregistrer un nouveau SL BUY dans le buffer (appelé depuis OnTradeTransaction)
void DG_RegisterBuySL(datetime when)
  {
   // Décaler le buffer : nouvelle entrée à l'index 0
   for(int i = 19; i > 0; i--) dgRecentBuySL[i] = dgRecentBuySL[i-1];
   dgRecentBuySL[0] = (int)when;
   if(dgRecentBuySL_count < 20) dgRecentBuySL_count++;
  }

// Compter les SL BUY dans une fenêtre de N heures
int DG_CountBuySLInWindow(int windowHours)
  {
   datetime now = TimeCurrent();
   datetime cutoff = now - windowHours * 3600;
   int count = 0;
   for(int i = 0; i < dgRecentBuySL_count; i++)
     {
      if((datetime)dgRecentBuySL[i] >= cutoff) count++;
     }
   return count;
  }

// Module A : détection rapide H4
bool DG_DetectH4Reversal()
  {
   if(!UseDualGuardH4) return false;

   // Charger 5 bougies H4 récentes
   double closeH4[], openH4[], highH4[], lowH4[];
   ArraySetAsSeries(closeH4,true); ArraySetAsSeries(openH4,true);
   ArraySetAsSeries(highH4,true);  ArraySetAsSeries(lowH4,true);
   if(CopyClose(Symbol(),PERIOD_H4,1,5,closeH4) < 5) return false;
   if(CopyOpen (Symbol(),PERIOD_H4,1,5,openH4)  < 5) return false;
   if(CopyHigh (Symbol(),PERIOD_H4,1,5,highH4)  < 5) return false;
   if(CopyLow  (Symbol(),PERIOD_H4,1,5,lowH4)   < 5) return false;

   // Calculer EMA50 H4
   int handleEma = iMA(Symbol(),PERIOD_H4,50,0,MODE_EMA,PRICE_CLOSE);
   if(handleEma == INVALID_HANDLE) return false;
   double ema50H4[]; ArraySetAsSeries(ema50H4,true);
   if(CopyBuffer(handleEma,0,1,5,ema50H4) < 5)
     { IndicatorRelease(handleEma); return false; }
   IndicatorRelease(handleEma);

   // Calculer ATR H4 pour valider la taille des corps
   int handleAtr = iATR(Symbol(),PERIOD_H4,14);
   if(handleAtr == INVALID_HANDLE) return false;
   double atrH4[]; ArraySetAsSeries(atrH4,true);
   if(CopyBuffer(handleAtr,0,1,3,atrH4) < 3)
     { IndicatorRelease(handleAtr); return false; }
   IndicatorRelease(handleAtr);

   // Compter les bougies H4 bear consécutives sous EMA50 avec corps significatif
   int nBear = 0;
   double atrRef = atrH4[0];
   for(int i = 0; i < DualGuardH4_BearCount && i < 5; i++)
     {
      bool isBear = closeH4[i] < openH4[i];
      bool sousEma = closeH4[i] < ema50H4[i];
      double body = MathAbs(closeH4[i] - openH4[i]);
      bool bodyOk = (body >= DualGuardH4_BodyMin * atrRef);
      if(isBear && sousEma && bodyOk) nBear++;
      else break;  // doivent être consécutives
     }

   return (nBear >= DualGuardH4_BearCount);
  }

// Fonction principale : appelée à chaque OnTick avant ouverture de position
// Retourne true si un trade BUY doit être skippé maintenant
bool DG_ShouldBlockBuy()
  {
   if(!UseDualGuard) return false;

   datetime now = TimeCurrent();

   // 1. Si une suspension est encore active, on bloque
   if(dgBuySuspendUntil > now)
     {
      // Suspension toujours active
      return true;
     }

   // 2. Module A : retournement H4 détecté ?
   if(DG_DetectH4Reversal())
     {
      dgBuySuspendUntil = now + DualGuardH4_SuspendH * 3600;
      dgSuspendReason = StringFormat("H4-REVERSAL (suspend %dh)", DualGuardH4_SuspendH);
      Print("DualGuard A : ", dgSuspendReason, " jusqu'à ",
            TimeToString(dgBuySuspendUntil));
      if(NotifMT5Push) SendNotification("DualGuard A : Retournement H4 détecté → BUY suspendu " +
                                         IntegerToString(DualGuardH4_SuspendH) + "h");
      return true;
     }

   // 3. Module B : cascade de SL ?
   if(UseDualGuardCascade)
     {
      int slCasc2 = DG_CountBuySLInWindow(DG_Casc2_WindowH);
      if(slCasc2 >= DG_Casc2_NbSL)
        {
         dgBuySuspendUntil = now + DG_Casc2_SuspendH * 3600;
         dgSuspendReason = StringFormat("CASCADE-2 (%d SL/%dh, suspend %dh)",
                                         slCasc2, DG_Casc2_WindowH, DG_Casc2_SuspendH);
         Print("DualGuard B2 : ", dgSuspendReason);
         if(NotifMT5Push) SendNotification("DualGuard B2 : " +
                                            IntegerToString(slCasc2) + " SL en " +
                                            IntegerToString(DG_Casc2_WindowH) +
                                            "h → BUY suspendu " +
                                            IntegerToString(DG_Casc2_SuspendH) + "h");
         return true;
        }

      int slCasc1 = DG_CountBuySLInWindow(DG_Casc1_WindowH);
      if(slCasc1 >= DG_Casc1_NbSL)
        {
         dgBuySuspendUntil = now + DG_Casc1_SuspendH * 3600;
         dgSuspendReason = StringFormat("CASCADE-1 (%d SL/%dh, suspend %dh)",
                                         slCasc1, DG_Casc1_WindowH, DG_Casc1_SuspendH);
         Print("DualGuard B1 : ", dgSuspendReason);
         if(NotifMT5Push) SendNotification("DualGuard B1 : " +
                                            IntegerToString(slCasc1) + " SL en " +
                                            IntegerToString(DG_Casc1_WindowH) +
                                            "h → BUY suspendu " +
                                            IntegerToString(DG_Casc1_SuspendH) + "h");
         return true;
        }
     }

   return false;
  }

// État DualGuard pour dashboard / override SELL
bool DG_IsBuySuspended()
  {
   return (UseDualGuard && dgBuySuspendUntil > TimeCurrent());
  }

// Override D1 : autoriser SELL contre tendance D1 si BUY est suspendu
bool DG_AllowSellAgainstD1()
  {
   return (UseDualGuard && UseDualGuardOverride && DG_IsBuySuspended());
  }

//+------------------------------------------------------------------+
//|  BRAIN-ML : Modulateur de risque par P(win) (Random Forest ONNX) |
//|                                                                  |
//|  Le modèle est entraîné en Python (ml/export_onnx.py) sur les   |
//|  549 trades du backtest XAU 2022-04→2026-04. À chaque ouverture |
//|  candidate, on construit le vecteur de 23 features dans l'ordre  |
//|  EXACT de FEATURE_ORDER (Python) et on appelle OnnxRun().        |
//|  La P(win) sortie module le risk% effectivement utilisé :        |
//|    < SkipBelow  → trade annulé                                   |
//|    < HalfRisk   → risk × 0.5                                     |
//|    < FullRisk   → risk × 1.0                                     |
//|    ≥ FullRisk   → risk × BoostMul                                |
//+------------------------------------------------------------------+
bool BrainML_Init()
  {
   if(!UseBrainML) return true;

   // v5.7 : on charge depuis la ressource embarquée (#resource au top du fichier).
   // Plus de souci de path/sandbox — le modèle est dans le .ex5.
   g_onnxBrainHandle = OnnxCreateFromBuffer(BrainMLModelData, ONNX_DEFAULT);
   if(g_onnxBrainHandle == INVALID_HANDLE)
     {
      Print("BrainML : OnnxCreateFromBuffer a échoué (err=", GetLastError(),
            "). Tentative fallback fichier...");
      // Fallback : essayer de charger depuis fichier (anciens utilisateurs)
      g_onnxBrainHandle = OnnxCreate(BrainML_OnnxFile, ONNX_DEFAULT);
      if(g_onnxBrainHandle == INVALID_HANDLE)
        {
         Print("BrainML : fallback fichier KO aussi (err=", GetLastError(),
               "). → mode dégradé : pas de modulation ML");
         return false;
        }
      Print("BrainML : chargé depuis fichier (fallback).");
     }
   else
     {
      Print("BrainML : chargé depuis ressource embarquée (taille=",
            ArraySize(BrainMLModelData), " bytes)");
     }

   // Input : float[1,36]  (brain_v1.onnx v5.8)
   const long inputShape[]  = {1, BRAINML_NFEATURES};
   if(!OnnxSetInputShape(g_onnxBrainHandle, 0, inputShape))
     {
      Print("BrainML : OnnxSetInputShape failed, err=", GetLastError());
      OnnxRelease(g_onnxBrainHandle);
      g_onnxBrainHandle = INVALID_HANDLE;
      return false;
     }

   // Outputs : output 0 = label int64[1], output 1 = proba float[1,2]
   const long out0Shape[]   = {1};
   const long out1Shape[]   = {1, 2};
   if(!OnnxSetOutputShape(g_onnxBrainHandle, 0, out0Shape))
     { Print("BrainML : OnnxSetOutputShape(0) failed, err=", GetLastError()); }
   if(!OnnxSetOutputShape(g_onnxBrainHandle, 1, out1Shape))
     { Print("BrainML : OnnxSetOutputShape(1) failed, err=", GetLastError()); }

   Print("BrainML v6.2 : brain_v4.onnx charge. 36 features GBT (AUC OOS=0.774, label realiste, contre-tendance ON)");
   // Test rapide : OnnxRun avec un vecteur nul pour verifier que le modele repond
   {
    matrixf testInp(1, BRAINML_NFEATURES);  testInp.Fill(0.0f);
    long    testLbl[1];
    matrixf testProb(1, 2);
    if(!OnnxRun(g_onnxBrainHandle, ONNX_NO_CONVERSION, testInp, testLbl, testProb))
      {
       Print("WARN BrainML : OnnxRun test KO (err=", GetLastError(),
             ") — verifier opset ONNX (MT5 supporte max opset ~15).");
       Print("  brain_v3_h1ema40.onnx probablement compile avec opset trop eleve.");
       Print("  Relancer retrain_h1ema40.py (opset 12) puis recompiler l'EA.");
      }
    else
      {
       Print("BrainML : OnnxRun test OK — P(class=1)=", DoubleToString((double)testProb[0,1], 4));
      }
   }
   return true;
  }

void BrainML_Deinit()
  {
   if(g_onnxBrainHandle != INVALID_HANDLE)
     {
      OnnxRelease(g_onnxBrainHandle);
      g_onnxBrainHandle = INVALID_HANDLE;
     }
  }

// Lit l'ATR shift 1 sur le TF donné, fallback shift 0 si échec
double _ReadATR(ENUM_TIMEFRAMES tf, int period = 14)
  {
   int h = iATR(Symbol(), tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double b[]; ArraySetAsSeries(b, true);
   double v = 0.0;
   if(CopyBuffer(h, 0, 1, 1, b) > 0 && b[0] > 0) v = b[0];
   else if(CopyBuffer(h, 0, 0, 1, b) > 0)        v = b[0];
   IndicatorRelease(h);
   return v;
  }

double _ReadADX(ENUM_TIMEFRAMES tf, int period = 14)
  {
   int h = iADX(Symbol(), tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double b[]; ArraySetAsSeries(b, true);
   double v = 0.0;
   if(CopyBuffer(h, 0, 1, 1, b) > 0 && b[0] > 0) v = b[0];
   else if(CopyBuffer(h, 0, 0, 1, b) > 0)        v = b[0];
   IndicatorRelease(h);
   return v;
  }

// Retourne le WR des n derniers trades fermes (pour f34/f35)
// Defaut 0.40 si pas d'historique (WR historique XAU = 40.6% en training)
double ComputeRecentWR(int n)
  {
   int count = 0, wins = 0;
   // Parcourir le buffer circulaire du plus recent (head-1) au plus ancien
   for(int k = 0; k < 25 && count < n; k++)
     {
      int idx = (g_brainHistoryHead - 1 - k + 25) % 25;
      if(count >= g_brainHistoryCount) break;  // pas assez d'historique
      wins  += g_brainHistory[idx].win ? 1 : 0;
      count++;
     }
   // 0.40 = WR baseline dataset training (aligne sur la distribution d'entrainement)
   return (count > 0) ? (double)wins / count : 0.40;
  }

// Construit le vecteur de 36 features pour brain_v1.onnx (v5.8)
// Ordre IDENTIQUE a FEATURE_ORDER dans build_dataset.py
void BrainML_BuildFeatures(bool isBuy, bool isPullback,
                            double entry,
                            const ADNMouvement &adn, const MiroirInstitutionnel &mi,
                            const EmpreintePsy &psy,
                            float &features[])
  {
   ArrayResize(features, BRAINML_NFEATURES);

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   double close = entry;
   double eps   = 1e-9;

   // ── Lire indicateurs H1 (deja en global : shift 1 = barre fermee) ──
   double rsi_h1   = (ArraySize(rsiVal)    > 1) ? rsiVal[1]    : rsiVal[0];
   double stoch_k  = (ArraySize(stochMain) > 1) ? stochMain[1] : stochMain[0];
   double stoch_d  = (ArraySize(stochSignal)>1) ? stochSignal[1]:stochSignal[0];
   double adx_h1   = (ArraySize(adxMain)   > 1) ? adxMain[1]   : adxMain[0];
   double adxp_h1  = (ArraySize(adxPlus)   > 1) ? adxPlus[1]   : adxPlus[0];
   double adxm_h1  = (ArraySize(adxMinus)  > 1) ? adxMinus[1]  : adxMinus[0];
   double atr_h1   = (ArraySize(atrVal)    > 1) ? atrVal[1]    : atrVal[0];
   double bb_up    = (ArraySize(bbUpper)   > 1) ? bbUpper[1]   : bbUpper[0];
   double bb_mid   = (ArraySize(bbMiddle)  > 1) ? bbMiddle[1]  : bbMiddle[0];
   double bb_lo    = (ArraySize(bbLower)   > 1) ? bbLower[1]   : bbLower[0];

   // ── Lire ATR M15 ──
   double atr_m15 = 0.0;
   if(hATR_M15_brain != INVALID_HANDLE)
     {
      double buf[]; ArraySetAsSeries(buf, true);
      if(CopyBuffer(hATR_M15_brain, 0, 1, 1, buf) > 0) atr_m15 = buf[0];
     }

   // ── Lire ADX H4 ──
   double adx_h4 = 0.0;
   if(hADX_H4_brain != INVALID_HANDLE)
     {
      double buf[]; ArraySetAsSeries(buf, true);
      if(CopyBuffer(hADX_H4_brain, 0, 1, 1, buf) > 0) adx_h4 = buf[0];
     }

   // ── Lire ATR H4 ──
   double atr_h4 = 0.0;
   if(hATR_H4_brain != INVALID_HANDLE)
     {
      double buf[]; ArraySetAsSeries(buf, true);
      if(CopyBuffer(hATR_H4_brain, 0, 1, 1, buf) > 0) atr_h4 = buf[0];
     }

   // ── Lire EMA200 H4 et EMA50 H4 (7 barres pour slope) ──
   double ema200h4 = 0.0, ema200h4_5 = 0.0;
   double ema50h4  = 0.0, ema50h4_5  = 0.0;
   if(hEMA200_H4_brain != INVALID_HANDLE)
     {
      double buf[]; ArraySetAsSeries(buf, true);
      if(CopyBuffer(hEMA200_H4_brain, 0, 1, 7, buf) >= 7)
        { ema200h4 = buf[0]; ema200h4_5 = buf[5]; }
     }
   if(hEMA50_H4_brain != INVALID_HANDLE)
     {
      double buf[]; ArraySetAsSeries(buf, true);
      if(CopyBuffer(hEMA50_H4_brain, 0, 1, 7, buf) >= 7)
        { ema50h4 = buf[0]; ema50h4_5 = buf[5]; }
     }

   // ── Calculer bb_squeeze (BB_width / BB_width_avg20) ──
   double bb_squeeze = 1.0;
   if(hBollinger != INVALID_HANDLE)
     {
      double bup[], blo[]; ArraySetAsSeries(bup, true); ArraySetAsSeries(blo, true);
      if(CopyBuffer(hBollinger, 0, 1, 21, bup) >= 21 &&
         CopyBuffer(hBollinger, 2, 1, 21, blo) >= 21)
        {
         double wNow = bup[0] - blo[0];
         double wAvg = 0.0;
         for(int k = 0; k < 20; k++) wAvg += (bup[k] - blo[k]);
         wAvg /= 20.0;
         if(wAvg > eps) bb_squeeze = wNow / wAvg;
        }
     }

   // ── Calculer atr_ratio_h1 (ATR_H1 / ATR_H1_avg20) ──
   double atr_ratio = 1.0;
   if(hATR != INVALID_HANDLE)
     {
      double abuf[]; ArraySetAsSeries(abuf, true);
      if(CopyBuffer(hATR, 0, 1, 21, abuf) >= 21)
        {
         double aAvg = 0.0;
         for(int k = 0; k < 20; k++) aAvg += abuf[k];
         aAvg /= 20.0;
         if(aAvg > eps) atr_ratio = abuf[0] / aAvg;
        }
     }

   // ── EMA200 D1 distance ──
   double d1_dist = 0.0;
   if(ArraySize(ema200D1) > 0 && ema200D1[0] > 0)
      d1_dist = (close - ema200D1[0]) / ema200D1[0] * 100.0;

   // ── Temporel ──
   int hour = dt.hour;
   int dow  = dt.day_of_week;
   double h_sin = MathSin(2.0 * M_PI * hour / 24.0);
   double h_cos = MathCos(2.0 * M_PI * hour / 24.0);
   double d_sin = MathSin(2.0 * M_PI * dow  / 7.0);
   double d_cos = MathCos(2.0 * M_PI * dow  / 7.0);

   // ── Signaux BOS et niveaux ──
   double bos_sig  = (isBuy ? BOS_Haussier() : BOS_Baissier()) ? 1.0 : 0.0;
   double near_lvl = (isBuy ? PrixProcheSupport() : PrixProcheResistance()) ? 1.0 : 0.0;

   // ── Clip helper (inline) ──
   #define CLIP(v, lo, hi) (MathMax((lo), MathMin((hi), (v))))

   // ── Construire le vecteur (ordre identique a build_dataset.py) ──
   features[ 0] = (float)(rsi_h1  / 100.0);                               // rsi_h1_norm
   features[ 1] = (float)(stoch_k / 100.0);                               // stoch_k_norm
   features[ 2] = (float)(stoch_d / 100.0);                               // stoch_d_norm
   features[ 3] = (float)(adx_h1  / 100.0);                               // adx_h1_norm
   features[ 4] = (float)(adxp_h1 / 100.0);                               // adxplus_h1_norm
   features[ 5] = (float)(adxm_h1 / 100.0);                               // adxminus_h1_norm
   features[ 6] = (float)(adx_h4  / 100.0);                               // adx_h4_norm
   features[ 7] = (float)(atr_m15 / (close + eps));                       // atr_m15_rel
   features[ 8] = (float)(atr_h1  / (close + eps));                       // atr_h1_rel
   features[ 9] = (float)(atr_h4  / (close + eps));                       // atr_h4_rel
   features[10] = (float)CLIP(d1_dist, -20.0, 20.0);                      // ema200d1_dist
   features[11] = (float)CLIP((close - bb_mid) / (bb_up - bb_lo + eps), -2.0, 2.0); // bb_pos
   features[12] = (float)CLIP(bb_squeeze, 0.0, 3.0);                      // bb_squeeze
   features[13] = (float)CLIP(atr_ratio,  0.0, 5.0);                      // atr_ratio_h1
   features[14] = (float)CLIP((ema200h4 - ema200h4_5) / (atr_h4 + eps), -5.0, 5.0); // h4_ema200_slope
   features[15] = (float)CLIP((ema50h4  - ema50h4_5)  / (atr_h4 + eps), -5.0, 5.0); // h4_ema50_slope
   features[16] = (float)CLIP((close - ema200h4) / (atr_h4 + eps), -10.0, 10.0);    // price_to_h4_ema200
   features[17] = (float)CLIP((close - ema50h4)  / (atr_h4 + eps), -10.0, 10.0);    // price_to_h4_ema50
   features[18] = (float)h_sin;                                            // hour_sin
   features[19] = (float)h_cos;                                            // hour_cos
   features[20] = (float)d_sin;                                            // dow_sin
   features[21] = (float)d_cos;                                            // dow_cos
   features[22] = (float)CLIP(ContextScore(), 0.5, 1.5);                  // context_score
   features[23] = (float)(isBuy ? 1.0 : 0.0);                             // direction
   features[24] = (float)(isPullback ? 1.0 : 0.0);                        // is_pullback
   features[25] = (float)(g_lastScoreBase  / 6.0);                        // score_base_norm
   features[26] = (float)(g_lastScoreBonus / 7.0);                        // score_bonus_norm
   features[27] = (float)((double)adn.phase / 4.0);                       // adn_phase_norm
   features[28] = (float)(psy.retournementIminent  ? 1.0 : 0.0);          // psy_retour
   features[29] = (float)(psy.directionHaussiere   ? 1.0 : 0.0);          // psy_dir_haussier
   features[30] = (float)(mi.manipulationDetectee  ? 1.0 : 0.0);          // mi_manip
   features[31] = (float)bos_sig;                                          // bos_signal
   features[32] = (float)near_lvl;                                         // near_level
   features[33] = (float)CLIP(atr_m15 / (atr_h1 + eps), 0.0, 2.0);       // spread_ratio (atr_m15/atr_h1)
   features[34] = (float)ComputeRecentWR(20);                              // recent_wr_20
   features[35] = (float)ComputeRecentWR(5);                               // recent_wr_5
   #undef CLIP
  }

// Retourne P(win) in [0,1] ou -1 si erreur / desactive
// isPullback : true si signal pullback (f24 du modele)
double BrainML_PredictWinProba(bool isBuy, bool isPullback, double entry,
                                const ADNMouvement &adn,
                                const MiroirInstitutionnel &mi,
                                const EmpreintePsy &psy)
  {
   if(!UseBrainML || g_onnxBrainHandle == INVALID_HANDLE) return -1.0;

   float input_features[];
   BrainML_BuildFeatures(isBuy, isPullback, entry, adn, mi, psy, input_features);

   // Reorganiser en matrixf [1, 36]
   matrixf inp(1, BRAINML_NFEATURES);
   for(int i = 0; i < BRAINML_NFEATURES; i++)
     {
      inp[0, i] = input_features[i];
      g_lastFeatures[i] = input_features[i];   // COLLECTE : cache vecteur exact MT5
     }

   // Outputs : label (long[1] = int64) + probabilities (matrix float[1,2])
   // BUG FIX v5.8.2 : le ONNX XGBoost exporte label en int64. Utiliser vectorf
   // ici cause un mismatch type avec ONNX_NO_CONVERSION -> OnnxRun echoue
   // silencieusement et renvoie -1 (= brain ML inactif). Tableau static long[1]
   // = type exact int64 attendu par OnnxRun.
   long      labelOut[1];
   matrixf   probOut(1, 2);

   if(!OnnxRun(g_onnxBrainHandle, ONNX_NO_CONVERSION, inp, labelOut, probOut))
     {
      Print("BrainML : OnnxRun a échoué (err=", GetLastError(), ")");
      return -1.0;
     }

   // Note : skl2onnx exporte probOut[0] = (probOut[1] - 1) bizarrement.
   // La vraie P(class=1) = probOut[0,1] (testé vs sklearn, match exact).
   double pWin = (double)probOut[0, 1];
   if(pWin < 0.0) pWin = 0.0;
   if(pWin > 1.0) pWin = 1.0;
   return pWin;
  }

//+------------------------------------------------------------------+
//| COLLECTE — (re)cree le CSV des features et ecrit l'entete        |
//| Appele en OnInit() : tronque a chaque run de backtest.           |
//+------------------------------------------------------------------+
void BrainML_InitCollectFile()
  {
   if(!BrainML_CollectFeatures) return;
   int h = FileOpen(BrainML_CollectFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
     {
      Print("COLLECTE : impossible d'ouvrir ", BrainML_CollectFile, " (err=", GetLastError(), ")");
      return;
     }
   string hdr = "timestamp,symbol,direction,entry,sl,tp1,tp2,pwin_live";
   for(int i = 0; i < BRAINML_NFEATURES; i++) hdr += StringFormat(",f%02d", i);
   FileWrite(h, hdr);
   FileClose(h);
   Print("COLLECTE ACTIVE : features ecrites dans ", BrainML_CollectFile);
  }

//+------------------------------------------------------------------+
//| COLLECTE — ajoute une ligne (vecteur exact MT5 + entry/sl/tp).   |
//| g_lastFeatures doit etre a jour (rempli par PredictWinProba).    |
//+------------------------------------------------------------------+
void BrainML_CollectFeatureRow(bool isBuy, double entry, double sl, double tp1, double tp2, double pWin)
  {
   if(!BrainML_CollectFeatures) return;
   int h = FileOpen(BrainML_CollectFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   string ts = TimeToString(iTime(_Symbol, PERIOD_M15, 0), TIME_DATE|TIME_MINUTES);
   string row = ts + "," + _Symbol + "," + (isBuy ? "BUY" : "SELL") + "," +
                DoubleToString(entry, _Digits) + "," + DoubleToString(sl, _Digits) + "," +
                DoubleToString(tp1, _Digits) + "," + DoubleToString(tp2, _Digits) + "," +
                DoubleToString(pWin, 6);
   for(int i = 0; i < BRAINML_NFEATURES; i++)
      row += "," + DoubleToString((double)g_lastFeatures[i], 8);
   FileWrite(h, row);
   FileClose(h);
  }

// Multiplicateur de risque depuis P(win). Retourne 0.0 si trade doit etre skipped.
// Seuils v6.2 (GBT brain_v4) : Skip<0.40 | Half[0.40,0.50[ | Full[0.50,0.693[ | Boost>=0.726
double BrainML_RiskMultiplier(double pWin)
  {
   if(pWin < 0.0)                        return 0.0;           // ONNX KO -> bloquer (brain_p=-1 = diagnostic)
   if(pWin < BrainML_SkipBelow)          return 0.0;           // SKIP (gate Youden)
   if(pWin < BrainML_HalfRisk)           return 0.5;           // demi-risque
   if(pWin < BrainML_FullRisk)           return 1.0;           // risque normal
   if(pWin >= BrainML_BoostThreshold)    return BrainML_BoostMul; // BOOST (P90 train, WR 95.7%)
   return 1.0;                                                  // [FullRisk, BoostThreshold[ -> risque normal
  }

void OnTick()
  {
   ResetQuotidien();
   if(!robotActif)             return;
   if(StopJournalierAtteint()) return;
   if(!SpreadAcceptable())     return;
   if(!HeureAutoriseePourPaire()) return;

   if(LireIndicateurs())
     {
      GererBreakEven();
      GererTrailing();
     }
   GererFermetureForce();
   AfficherDashboard();

   if(!EstDansSessionOptimale())          return;
   if(FiltrerNews && EstProcheNews())     return;
   if(tradesToday >= MaxTradesJour)       return;
   // v5.5 : Stop si 3 losses dans la journée (total, pas consécutifs)
   // v5.4 : 2 consécutifs était trop agressif → coupait les récupérations
   // v5.5 : 3 total/jour → protection douce, laisse la chance de récupérer sur 1-2 trades
   if(lossesAujourdhui >= 3)
     {
      etatCerveau = "STOP JOUR : 3 losses atteints — Protection journalière v5.5";
      return;
     }
   if(!AucunePositionOuverte())           return;
   if(!FiltreQualiteBTCXAU(true) && !FiltreQualiteBTCXAU(false)) return;

   // ── v5.6 : FILTRE CONTEXTUEL HYBRIDE (data-driven 32 mois XAU) ──
   // Skip uniquement si contexte vraiment défavorable (cs < 0.85)
   // Le risk dynamique sera appliqué dans OuvrirTrade()
   double csNow = ContextScore();
   if(UseContextFilter && csNow < CS_SkipThreshold)
     {
      etatCerveau = StringFormat("SKIP v5.6 : ContextScore %.3f < %.2f (heure/jour défavorable)",
                                  csNow, CS_SkipThreshold);
      return;
     }

   // ── v5.6+D1 : DUALGUARD ANTI-CASCADE ────────────────────────
   // Met à jour l'état des suspensions BUY (modules A+B+C)
   // Note : DG_ShouldBlockBuy modifie l'état si nouvelle suspension détectée.
   // On l'appelle ici pour que les modules A et B s'évaluent à chaque tick,
   // même si on n'a pas encore de signal — la suspension sera consommée
   // dans EvaluerSignaux pour bloquer les BUY.
   if(UseDualGuard) DG_ShouldBlockBuy();

   // ── v5.1 : FILTRE RANGE GLOBAL — Suspendre si ADX faible sur H4 ──
   if(EstMarcheEnRange()) {
      etatCerveau = "RANGE détecté — Trading suspendu (ADX < 18 H4)";
      return;
   }

   datetime bar = iTime(Symbol(), PERIOD_M15, 0);
   if(bar == lastBarTime) return;
   lastBarTime   = bar;
   tradesCeBarre = 0;

   // DEBUG v5.8.4 : signaler si LireIndicateurs échoue sur une nouvelle barre
   if(!LireIndicateurs()) {
      static datetime _dbgLireBar = 0;
      if(bar != _dbgLireBar) { _dbgLireBar = bar; Print("DBG: LireIndicateurs FAIL barre=", TimeToString(bar)); }
      return;
   }
   if(tradesCeBarre >= 1) return;

   EmpreintePsy     psy  = AnalyserEmpreintePsy();
   ADNMouvement     adn  = AnalyserADNMouvement();
   MiroirInstitutionnel mi = AnalyserMiroirInstitutionnel();

   int signalBuy  = EvaluerCerveau(true,  psy, adn, mi);
   int signalSell = EvaluerCerveau(false, psy, adn, mi);
   // ML LOG : snapshot pour usage par LogOuverture() si un trade s'ouvre ce tick
   g_lastSignalBuy  = signalBuy;
   g_lastSignalSell = signalSell;

   double _px5   = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   // v5.7 : filtre directionnel basé sur EMA200 TF configurable (default H4) au lieu de D1
   //        → permet aux SELL de passer pendant les corrections H4 (problème avant : 0 SELL/mois)
   bool   _trendBull = (ArraySize(ema200Trend)>0 && _px5 > ema200Trend[0] * 1.003);
   bool   _trendBear = (ArraySize(ema200Trend)>0 && _px5 < ema200Trend[0] * 0.997);

   // ── v5.6+D1 : DualGuard — état de suspension ────────────────
   bool dgBuyBlocked = DG_IsBuySuspended();
   bool dgSellOK     = DG_AllowSellAgainstD1();  // SELL contre D1 si BUY suspendu

   if(dgBuyBlocked)
     {
      lastSignal = "BUY bloqué par DualGuard : " + dgSuspendReason;
      etatCerveau = lastSignal;
      // Si override actif et signal SELL existant, on autorise SELL
      // même si D1 est haussier (override D1)
      if(dgSellOK && signalSell > 0)
        {
         lastSignal = "SELL OVERRIDE D1 [DualGuard] " + dgSuspendReason;
         OuvrirTrade(false, adn, mi, psy, false);
         return;
        }
      // Sinon : pas de BUY pendant suspension, on regarde quand même les SELL normaux
     }

   if(!dgBuyBlocked && signalBuy > 0 && signalBuy >= signalSell)
     {
      lastSignal = "BUY TENDANCE [Cerveau v5]";
      OuvrirTrade(true, adn, mi, psy, false);
      return;
     }
   // SELL TENDANCE : autorisé si D1 baissier OU si DualGuard override actif
   if(signalSell > 0 && (!_trendBull || dgSellOK))
     {
      lastSignal = dgSellOK ? "SELL TENDANCE [DualGuard OVERRIDE]"
                            : "SELL TENDANCE [Cerveau v5]";
      OuvrirTrade(false, adn, mi, psy, false);
      return;
     }

   // PULLBACK SELL : autorisé si D1 baissier OU si DualGuard override actif
   bool pbSell = (!_trendBull || dgSellOK) && EstPullbackContreTendance(false, psy, mi);
   bool pbBuy  = (!dgBuyBlocked) && (!_trendBear) && EstPullbackContreTendance(true, psy, mi);

   if(pbSell)
     {
      lastSignal = dgSellOK ? "SELL PULLBACK [DualGuard OVERRIDE]"
                            : "SELL PULLBACK contre-H4 [Cerveau v5]";
      OuvrirTrade(false, adn, mi, psy, true);
     }
   else if(pbBuy)
     {
      lastSignal = "BUY PULLBACK contre-H4 [Cerveau v5]";
      OuvrirTrade(true, adn, mi, psy, true);
     }
   else
      lastSignal = "Cerveau en analyse...";
  }

//+------------------------------------------------------------------+
//|   v5.1 — FILTRE RANGE : ADX H4 faible sur 3 barres consécutives|
//+------------------------------------------------------------------+
bool EstMarcheEnRange()
  {
   int hADX_H4 = iADX(Symbol(), PERIOD_H4, 14);
   if(hADX_H4 == INVALID_HANDLE) return false;

   double adxH4[]; ArraySetAsSeries(adxH4, true);
   bool enRange = false;
   if(CopyBuffer(hADX_H4, 0, 0, 4, adxH4) >= 3)
     {
      // v5.3 : Range si ADX H4 < 18 sur les 3 dernières barres
      // v5.5 : seuil relevé à 20 — détecte mieux les consolidations type sept-mars 2025
      // NB : on garde 3 barres (v5.4 à 4 barres était trop restrictif)
      // DEBUG v5.8.2 : log ADX H4 à chaque nouvelle bougie M15
      static datetime _lastDebugBar = 0;
      datetime _curBar = iTime(Symbol(), PERIOD_M15, 0);
      if(_curBar != _lastDebugBar) {
         _lastDebugBar = _curBar;
         PrintFormat("DEBUG ADX_H4: [1]=%.2f [2]=%.2f [3]=%.2f → range=%s",
                     adxH4[1], adxH4[2], adxH4[3],
                     (adxH4[1]<20.0 && adxH4[2]<20.0 && adxH4[3]<20.0) ? "OUI" : "non");
      }
      if(adxH4[1] < 20.0 && adxH4[2] < 20.0 && adxH4[3] < 20.0)
         enRange = true;
     }
   IndicatorRelease(hADX_H4);
   return enRange;
  }

//+------------------------------------------------------------------+
//|    CLAUDE-CORE — GESTION MÉMOIRE                                |
//+------------------------------------------------------------------+
// BUG #3 FIX : versioning du fichier de persistance pour éviter corruption silencieuse
//   - Magic 0x46435241 ("FCRA" = Fotso Cerveau adAptatif)
//   - Version 1 = struct ClaudeMemoire actuelle (16 champs)
//   - Si magic OU version OU taille ne matchent pas → on tombe sur init vierge avec warning
const uint CLAUDE_CORE_MAGIC   = 0x46435241;
const uint CLAUDE_CORE_VERSION = 1;

void ChargerMemoireCerveau()
  {
   int h = FileOpen(ClaudeCoreFile, FILE_READ|FILE_BIN);
   bool loaded = false;
   if(h != INVALID_HANDLE)
     {
      ulong sz = FileSize(h);
      uint  expectedExtra = sizeof(uint)*2;  // magic + version
      ulong expectedTotal = expectedExtra + (ulong)sizeof(ClaudeMemoire) * 6;

      if(sz >= expectedExtra)
        {
         uint magic   = FileReadInteger(h, sizeof(uint));
         uint version = FileReadInteger(h, sizeof(uint));
         if(magic == CLAUDE_CORE_MAGIC && version == CLAUDE_CORE_VERSION && sz == expectedTotal)
           {
            FileReadArray(h, cerveau);
            loaded = true;
            Print("Claude-Core : Mémoire chargée (v", version, ", ",
                  cerveau[GetPaireIndex()].totalTrades, " trades historiques)");
           }
         else if(sz == (ulong)sizeof(ClaudeMemoire) * 6)
           {
            // Ancien format sans header → on accepte mais on log et on re-sauvera versionné
            FileSeek(h, 0, SEEK_SET);
            FileReadArray(h, cerveau);
            loaded = true;
            Print("Claude-Core : Mémoire LEGACY chargée (sera convertie au prochain save). ",
                  cerveau[GetPaireIndex()].totalTrades, " trades historiques.");
           }
         else
           {
            Print("Claude-Core WARNING : fichier incompatible (magic=", magic,
                  " version=", version, " size=", sz,
                  " attendu=", expectedTotal, ") → réinitialisation");
           }
        }
      FileClose(h);
     }
   if(loaded) return;
   else
     {
      string paires[6] = {"XAUUSDm","BTCUSDm","EURUSDm","GBPUSDm","NAS100m","US30m"};
      for(int i = 0; i < 6; i++)
        {
         StringToCharArray(paires[i], cerveau[i].paire, 0, 20);
         cerveau[i].winRate          = 50.0;
         cerveau[i].totalWinsPaire   = 0;
         cerveau[i].totalLossesPaire = 0;
         cerveau[i].profitNetPaire   = 0;
         cerveau[i].riskDynamique    = RiskPercent;
         cerveau[i].atrMultDynamique = ATR_Multiplier;
         cerveau[i].scoreMiniDynamique = 2;  // v6.1 : départ 3->2 pour plus de signaux
         cerveau[i].atrMoyenne         = 0;
         cerveau[i].adxMoyenne         = 25;
         cerveau[i].totalTrades        = 0;
         cerveau[i].derniereMAJ        = TimeCurrent();
         cerveau[i].lossesConsecutifs  = 0;
         cerveau[i].slMultiDynamique   = 1.0;

         for(int h2=0; h2<24; h2++) cerveau[i].scoreHeures[h2] = 1.0;
         for(int d=0;  d<7;  d++)   cerveau[i].scoreJours[d]   = 1.0;

         cerveau[i].scoreHeures[8]=1.3;  cerveau[i].scoreHeures[9]=1.4;
         cerveau[i].scoreHeures[10]=1.3; cerveau[i].scoreHeures[14]=1.5;
         cerveau[i].scoreHeures[15]=1.6; cerveau[i].scoreHeures[16]=1.4;
         cerveau[i].scoreJours[2]=1.2;
         cerveau[i].scoreJours[3]=1.3;
         cerveau[i].scoreJours[4]=1.2;
        }
      Print("Claude-Core : Premiere initialisation — memoire vierge");
     }
  }

void SauvegarderMemoireCerveau()
  {
   int h = FileOpen(ClaudeCoreFile, FILE_WRITE|FILE_BIN);
   if(h != INVALID_HANDLE)
     {
      // BUG #3 FIX : header magic + version pour détection de corruption
      FileWriteInteger(h, (int)CLAUDE_CORE_MAGIC,   sizeof(uint));
      FileWriteInteger(h, (int)CLAUDE_CORE_VERSION, sizeof(uint));
      FileWriteArray(h, cerveau);
      FileClose(h);
      Print("Claude-Core : Mémoire sauvegardée");
     }
  }

// BUG #2 FIX : signature étendue pour accepter l'heure d'OUVERTURE du trade.
// Si non fournie (0), retombe sur TimeCurrent() = heure de fermeture (ancien comportement).
// Le bon usage : passer DEAL_TIME du deal d'entrée pour que scoreHeures apprenne
// à quelle HEURE D'ENTRÉE les trades gagnent/perdent, pas l'heure aléatoire de fermeture.
void MettreAJourCerveau(bool isWin, double profit, datetime openTime = 0)
  {
   int idx = GetPaireIndex();

   if(isWin)
     {
      cerveau[idx].totalWinsPaire++;
      cerveau[idx].lossesConsecutifs = 0;
     }
   else
     {
      cerveau[idx].totalLossesPaire++;
      cerveau[idx].lossesConsecutifs++;
     }
   cerveau[idx].totalTrades++;
   cerveau[idx].profitNetPaire += profit;

   int total = cerveau[idx].totalWinsPaire + cerveau[idx].totalLossesPaire;
   if(total > 0)
      cerveau[idx].winRate = (double)cerveau[idx].totalWinsPaire / total * 100.0;

   // BUG #2 FIX : utilise l'heure d'OUVERTURE pour mettre à jour scoreHeures/scoreJours
   datetime tForScore = (openTime > 0) ? openTime : TimeCurrent();
   MqlDateTime dt; TimeToStruct(tForScore, dt);
   double facteur = isWin ? 1.05 : 0.95;
   cerveau[idx].scoreHeures[dt.hour] =
      cerveau[idx].scoreHeures[dt.hour] * 0.9 + facteur * 0.1;
   cerveau[idx].scoreJours[dt.day_of_week] =
      cerveau[idx].scoreJours[dt.day_of_week] * 0.9 + facteur * 0.1;

   if(ArraySize(atrVal) > 0)
      cerveau[idx].atrMoyenne =
         cerveau[idx].atrMoyenne * 0.95 + atrVal[0] * 0.05;

   if(total >= 10)
     {
      // v6.1 : seuil abaissé 52%->42% — ML (WR=83%) ne doit pas déclencher le frein
      // scoreMini: plancher 2 (était 3), plafond 4 (était 5) — moins agressif
      if(cerveau[idx].winRate < 42.0)
        {
         cerveau[idx].riskDynamique     = MathMax(0.3, cerveau[idx].riskDynamique * 0.92);
         cerveau[idx].scoreMiniDynamique = MathMin(4,   cerveau[idx].scoreMiniDynamique + 1);
         etatCerveau = "Apprentissage : Reduction risque (WR bas)";
        }
      else if(cerveau[idx].winRate > 65.0)
        {
         cerveau[idx].riskDynamique     = MathMin(1.5, cerveau[idx].riskDynamique * 1.1);
         cerveau[idx].scoreMiniDynamique = MathMax(2,   cerveau[idx].scoreMiniDynamique - 1);
         etatCerveau = "Apprentissage : Augmentation confiance (WR haut)";
        }
      else
         etatCerveau = "Apprentissage : Paramètres stables";
     }

   cerveau[idx].derniereMAJ = TimeCurrent();
   SauvegarderMemoireCerveau();
  }

//+------------------------------------------------------------------+
//|    IDÉE 2 — EMPREINTE TEMPORELLE                                |
//+------------------------------------------------------------------+
bool EstDansSessionOptimale()
  {
   if(StringFind(Symbol(),"BTC") >= 0) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;

   int h   = dt.hour;
   int idx = GetPaireIndex();

   bool sessionStandard = ((h>=LondonStart && h<LondonEnd) ||
                           (h>=NYStart     && h<NYEnd));
   if(!sessionStandard) return false;

   if(cerveau[idx].totalTrades >= 20)
     {
      double scoreH = cerveau[idx].scoreHeures[h];
      double scoreD = cerveau[idx].scoreJours[dt.day_of_week];

      if(scoreH * scoreD < 0.7)
        {
         etatCerveau = "Empreinte temporelle : Heure défavorable mémorisée";
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//|    IDÉE 1 — EMPREINTE PSYCHOLOGIQUE                             |
//+------------------------------------------------------------------+
EmpreintePsy AnalyserEmpreintePsy()
  {
   EmpreintePsy psy;
   psy.indexPeur         = 0;
   psy.indexCupidite     = 0;
   psy.epuisementVendeurs = 0;
   psy.epuisementAcheteurs = 0;
   psy.retournementIminent = false;
   psy.directionHaussiere  = false;

   if(ArraySize(atrVal) == 0 || ArraySize(rsiVal) == 0) return psy;

   double mechesBasses = 0, mechesHautes = 0;
   double corpsHaussiers = 0, corpsBarssiers = 0;

   for(int i = 1; i <= 5; i++)
     {
      double o = iOpen(Symbol(), PERIOD_H1, i);
      double c = iClose(Symbol(), PERIOD_H1, i);
      double h = iHigh(Symbol(), PERIOD_H1, i);
      double l = iLow(Symbol(),  PERIOD_H1, i);
      double mBasse = MathMin(o,c) - l;
      double mHaute = h - MathMax(o,c);

      mechesBasses += mBasse;
      mechesHautes += mHaute;
      if(c > o) corpsHaussiers++; else corpsBarssiers++;
     }

   double totalMeches = mechesBasses + mechesHautes;
   if(totalMeches > 0)
     {
      psy.epuisementVendeurs  = (mechesBasses / totalMeches) * 100;
      psy.epuisementAcheteurs = (mechesHautes / totalMeches) * 100;
     }

   psy.indexCupidite = rsiVal[0];
   psy.indexPeur     = 100 - rsiVal[0];

   // v5.2 : RETOURNEMENT IMMINENT — EXIGE 2 BOUGIES CONFIRMÉES (pas 1)
   // Avant: 1 bougie suffisait → faux signaux fréquents
   // Maintenant: la bougie actuelle ET la précédente doivent confirmer

   double mBasse1 = MathMin(iOpen(Symbol(),PERIOD_H1,1),iClose(Symbol(),PERIOD_H1,1))
                    - iLow(Symbol(),PERIOD_H1,1);
   double mBasse2 = MathMin(iOpen(Symbol(),PERIOD_H1,2),iClose(Symbol(),PERIOD_H1,2))
                    - iLow(Symbol(),PERIOD_H1,2);
   double mBasse3 = MathMin(iOpen(Symbol(),PERIOD_H1,3),iClose(Symbol(),PERIOD_H1,3))
                    - iLow(Symbol(),PERIOD_H1,3);

   // v5.2 : croissance sur 2 bougies consécutives (mBasse1 > mBasse2 ET mBasse2 > mBasse3)
   bool mechesBassessCroissantes = (mBasse1 > mBasse2 && mBasse2 > mBasse3 &&
                                    mBasse1 > atrVal[0]*0.20);

   double mHaute1 = iHigh(Symbol(),PERIOD_H1,1)
                    - MathMax(iOpen(Symbol(),PERIOD_H1,1),iClose(Symbol(),PERIOD_H1,1));
   double mHaute2 = iHigh(Symbol(),PERIOD_H1,2)
                    - MathMax(iOpen(Symbol(),PERIOD_H1,2),iClose(Symbol(),PERIOD_H1,2));
   double mHaute3 = iHigh(Symbol(),PERIOD_H1,3)
                    - MathMax(iOpen(Symbol(),PERIOD_H1,3),iClose(Symbol(),PERIOD_H1,3));

   // v5.2 : idem pour les mèches hautes
   bool mechesHautesCroissantes = (mHaute1 > mHaute2 && mHaute2 > mHaute3 &&
                                   mHaute1 > atrVal[0]*0.20);

   if(mechesBassessCroissantes && rsiVal[0] < 45)
     {
      psy.retournementIminent  = true;
      psy.directionHaussiere   = true;
     }
   else if(mechesHautesCroissantes && rsiVal[0] > 55)
     {
      psy.retournementIminent  = true;
      psy.directionHaussiere   = false;
     }

   return psy;
  }

//+------------------------------------------------------------------+
//|    IDÉE 3 — ADN DU MOUVEMENT                                    |
//+------------------------------------------------------------------+
ADNMouvement AnalyserADNMouvement()
  {
   ADNMouvement adn;
   adn.phase              = ADN_INCONNUE;
   adn.haussier           = false;
   adn.niveauDeclencheur  = 0;
   adn.forceExplosion     = 0;

   if(ArraySize(atrVal)==0 || ArraySize(bbUpper)==0 || ArraySize(adxMain)==0)
      return adn;

   double atrMoy = 0; int cnt = 0;
   double atrBuf[]; ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(hATR, 0, 0, 25, atrBuf) >= 20)
     {
      for(int i = 1; i <= 20; i++) { atrMoy += atrBuf[i]; cnt++; }
      if(cnt > 0) atrMoy /= cnt;
     }
   else atrMoy = atrVal[0];

   double atrRatio    = atrMoy > 0 ? atrVal[0] / atrMoy : 1.0;
   double bbWidth     = bbUpper[0] - bbLower[0];
   double bbWidthMoy  = 0;

   double bbH[],bbL[]; ArraySetAsSeries(bbH,true); ArraySetAsSeries(bbL,true);
   if(CopyBuffer(hBollinger,0,0,21,bbH)>=20 && CopyBuffer(hBollinger,2,0,21,bbL)>=20)
     {
      for(int i=1;i<=20;i++) bbWidthMoy += (bbH[i]-bbL[i]);
      bbWidthMoy /= 20;
     }
   double bbCompression = bbWidthMoy > 0 ? bbWidth / bbWidthMoy : 1.0;

   if(adxMain[0] < 18 && atrRatio < 0.8 && bbCompression < 0.7)
     {
      adn.phase = ADN_ACCUMULATION;
      etatCerveau = "ADN Phase 1 : Accumulation silencieuse détectée";
     }
   else if(adxMain[0] < 22 && bbCompression < 0.5 && atrRatio < 0.7)
     {
      adn.phase = ADN_COMPRESSION;
      adn.niveauDeclencheur = bbUpper[0];
      etatCerveau = "ADN Phase 2 : Compression extreme — Explosion imminente !";
     }
   else if(adxMain[0] >= 22 && adxMain[0] < 30 && atrRatio >= 0.9 &&
           bbCompression >= 0.7)
     {
      adn.phase    = ADN_DECLENCHEUR;
      adn.haussier = (adxPlus[0] > adxMinus[0]);
      etatCerveau  = "ADN Phase 3 : Déclencheur — Direction identifiée";
     }
   else if(adxMain[0] >= 28 && atrRatio >= 1.2 && bbCompression >= 0.9)
     {
      adn.phase         = ADN_EXPLOSION;
      adn.haussier      = (adxPlus[0] > adxMinus[0]);
      adn.forceExplosion = MathMin(100, (adxMain[0] - 28) * 3 + atrRatio * 20);
      etatCerveau = "ADN Phase 4 : EXPLOSION " +
                   (adn.haussier ? "HAUSSIERE" : "BAISSIERE") +
                   " Force:" + DoubleToString(adn.forceExplosion,0) + "%";
     }

   // v5.91 FIX : catch-all restreint — seul ADX≥25 donne ADN_DECLENCHEUR.
   // v5.9 assignait ADN_COMPRESSION/ACCUMULATION aux conditions ADX<25, ce qui faisait
   // chuter le WR à ~30% en autorisant le trading dans les marchés faibles/flat.
   // v5.91 laisse ADX<25 comme ADN_INCONNUE (bloqué) : seules les tendances fortes passent.
   if(adn.phase == ADN_INCONNUE && adxMain[0] >= 25)
     {
      adn.phase    = ADN_DECLENCHEUR;
      adn.haussier = (ArraySize(adxPlus)>0 && ArraySize(adxMinus)>0 && adxPlus[0] > adxMinus[0]);
      etatCerveau  = "ADN Phase 3 (catch-all v5.91) : tendance confirmée ADX>25";
     }

   return adn;
  }

//+------------------------------------------------------------------+
//|    IDÉE 4 — MIROIR INSTITUTIONNEL                               |
//+------------------------------------------------------------------+
MiroirInstitutionnel AnalyserMiroirInstitutionnel()
  {
   MiroirInstitutionnel mi;
   mi.manipulationDetectee  = false;
   mi.piegeTendance         = false;
   mi.niveauLiquiditeHaut   = 0;
   mi.niveauLiquiditeBas    = 0;
   mi.cibleInstitutionnelle = 0;
   mi.confirmationEntree    = false;

   if(ArraySize(atrVal) == 0) return mi;

   double prix = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double atr  = atrVal[0];

   int touchesHaut = 0, touchesBas = 0;
   double refHaut = iHigh(Symbol(), PERIOD_H1, 1);
   double refBas  = iLow(Symbol(),  PERIOD_H1, 1);

   for(int i = 2; i <= 30; i++)
     {
      double h = iHigh(Symbol(), PERIOD_H1, i);
      double l = iLow(Symbol(),  PERIOD_H1, i);
      if(MathAbs(h - refHaut) <= atr * 0.5) touchesHaut++;
      if(MathAbs(l - refBas)  <= atr * 0.5) touchesBas++;
     }

   if(touchesHaut >= 2) mi.niveauLiquiditeHaut = refHaut;
   if(touchesBas  >= 2) mi.niveauLiquiditeBas  = refBas;

   double prevHigh = -DBL_MAX;
   double prevLow  =  DBL_MAX;
   for(int k=2; k<=5; k++)
     {
      double hk = iHigh(Symbol(),PERIOD_H1,k);
      double lk = iLow(Symbol(), PERIOD_H1,k);
      if(hk > prevHigh) prevHigh = hk;
      if(lk < prevLow)  prevLow  = lk;
     }
   double closeH1  = iClose(Symbol(), PERIOD_H1, 1);
   double highH1   = iHigh(Symbol(),  PERIOD_H1, 1);
   double lowH1    = iLow(Symbol(),   PERIOD_H1, 1);

   bool fauxBullBreak = (highH1 > prevHigh * 1.0005 &&
                         closeH1 < prevHigh * 1.002);
   bool fauxBearBreak = (lowH1 < prevLow * 0.9995 &&
                         closeH1 > prevLow * 0.998);

   if(fauxBullBreak || fauxBearBreak)
     {
      mi.manipulationDetectee = true;
      mi.piegeTendance        = fauxBullBreak;
      mi.confirmationEntree = true;

      if(fauxBullBreak)
         mi.cibleInstitutionnelle = prevHigh - atr * 2;
      else
         mi.cibleInstitutionnelle = prevLow  + atr * 2;

      etatCerveau = "Miroir Inst. : MANIPULATION détectée — Piège " +
                   (fauxBullBreak ? "HAUSSIER" : "BAISSIER");
     }

   return mi;
  }

//+------------------------------------------------------------------+
//|    HELPERS DE STRUCTURE                                         |
//+------------------------------------------------------------------+
bool BOS_Haussier()
  {
   double ph=-DBL_MAX;
   for(int i=2;i<=15;i++){double h=iHigh(Symbol(),PERIOD_H1,i);if(h>ph)ph=h;}
   if(ph==-DBL_MAX) return false;
   double dc=iClose(Symbol(),PERIOD_H1,1);
   double body=MathAbs(iClose(Symbol(),PERIOD_H1,1)-iOpen(Symbol(),PERIOD_H1,1));
   return(dc>ph&&body>=atrVal[0]*0.2);
  }

bool BOS_Baissier()
  {
   double pl=DBL_MAX;
   for(int i=2;i<=15;i++){double l=iLow(Symbol(),PERIOD_H1,i);if(l<pl)pl=l;}
   if(pl==DBL_MAX) return false;
   double dc=iClose(Symbol(),PERIOD_H1,1);
   double body=MathAbs(iClose(Symbol(),PERIOD_H1,1)-iOpen(Symbol(),PERIOD_H1,1));
   return(dc<pl&&body>=atrVal[0]*0.2);
  }

bool PrixProcheSupport()
  {
   double px=SymbolInfoDouble(Symbol(),SYMBOL_BID),atr=atrVal[0];
   for(int i=3;i<=40;i++){double l=iLow(Symbol(),PERIOD_H1,i);
      if(l<iLow(Symbol(),PERIOD_H1,i+1)&&l<iLow(Symbol(),PERIOD_H1,i-1))
         if(MathAbs(px-l)<=atr*1.5) return true;} return false;
  }

bool PrixProcheResistance()
  {
   double px=SymbolInfoDouble(Symbol(),SYMBOL_ASK),atr=atrVal[0];
   for(int i=3;i<=40;i++){double h=iHigh(Symbol(),PERIOD_H1,i);
      if(h>iHigh(Symbol(),PERIOD_H1,i+1)&&h>iHigh(Symbol(),PERIOD_H1,i-1))
         if(MathAbs(px-h)<=atr*1.5) return true;} return false;
  }

bool EngulfingHaussier()
  {
   double o1=iOpen(Symbol(),PERIOD_M15,1),c1=iClose(Symbol(),PERIOD_M15,1);
   double o2=iOpen(Symbol(),PERIOD_M15,2),c2=iClose(Symbol(),PERIOD_M15,2);
   return(c1>o1&&c2<o2&&o1<=c2&&c1>=o2);
  }

bool PinBarHaussier()
  {
   double o=iOpen(Symbol(),PERIOD_M15,1),c=iClose(Symbol(),PERIOD_M15,1);
   double h=iHigh(Symbol(),PERIOD_M15,1),l=iLow(Symbol(),PERIOD_M15,1);
   double body=MathAbs(c-o); if(body==0) return false;
   return(MathMin(o,c)-l>=body*2.0&&h-MathMax(o,c)<=body*0.5);
  }

bool EngulfingBaissier()
  {
   double o1=iOpen(Symbol(),PERIOD_M15,1),c1=iClose(Symbol(),PERIOD_M15,1);
   double o2=iOpen(Symbol(),PERIOD_M15,2),c2=iClose(Symbol(),PERIOD_M15,2);
   return(c1<o1&&c2>o2&&o1>=c2&&c1<=o2);
  }

bool PinBarBaissier()
  {
   double o=iOpen(Symbol(),PERIOD_M15,1),c=iClose(Symbol(),PERIOD_M15,1);
   double h=iHigh(Symbol(),PERIOD_M15,1),l=iLow(Symbol(),PERIOD_M15,1);
   double body=MathAbs(c-o); if(body==0) return false;
   return(h-MathMax(o,c)>=body*2.0&&MathMin(o,c)-l<=body*0.5);
  }

bool PullbackZoneH4(bool pourBuy)
  {
   double prix = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double atr  = ArraySize(atrVal)>0 ? atrVal[0] : 0;
   if(atr <= 0) return false;

   double ema200H4 = 0;
   int h200 = iMA(Symbol(), PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(h200 != INVALID_HANDLE)
     {
      double b200[]; ArraySetAsSeries(b200, true);
      if(CopyBuffer(h200, 0, 0, 3, b200) >= 1) ema200H4 = b200[0];
      IndicatorRelease(h200);
     }

   double ema50H4 = 0;
   int h50 = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(h50 != INVALID_HANDLE)
     {
      double b50[]; ArraySetAsSeries(b50, true);
      if(CopyBuffer(h50, 0, 0, 3, b50) >= 1) ema50H4 = b50[0];
      IndicatorRelease(h50);
     }

   bool nearEMA200 = (ema200H4 > 0 && MathAbs(prix - ema200H4) <= atr * 1.5);
   bool nearEMA50  = (ema50H4  > 0 && MathAbs(prix - ema50H4)  <= atr * 1.2);

   if(pourBuy)
      return (nearEMA200 || nearEMA50) && prix > ema200H4 * 0.99;
   else
      return (nearEMA200 || nearEMA50) && prix < ema200H4 * 1.01;
  }

bool FiltreQualiteBTCXAU(bool pourBuy)
  {
   bool isBTC = (StringFind(Symbol(),"BTC") >= 0);
   bool isXAU = (StringFind(Symbol(),"XAU")>=0 || StringFind(Symbol(),"GOLD")>=0);
   if(!isBTC && !isXAU) return true;

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);

   if(isBTC && dt.day_of_week == 0 && dt.hour >= 18) return false;
   if(isBTC && dt.day_of_week == 1 && dt.hour <= 2)  return false;

   if(isXAU && dt.hour == 15 && dt.min >= 0 && dt.min <= 45)  return false;
   if(isXAU && dt.hour == 16 && dt.min >= 0 && dt.min <= 15)  return false;

   if(dt.day_of_week == 5 && dt.hour >= 18) return false;

   return true;
  }

//+------------------------------------------------------------------+
//|   v5.1 — PULLBACK CONTRE-TENDANCE : 3/4 critères minimum       |
//+------------------------------------------------------------------+
bool EstPullbackContreTendance(bool pourBuy, EmpreintePsy &psy, MiroirInstitutionnel &mi)
  {
   if(ArraySize(atrVal)==0 || ArraySize(rsiVal)==0) return false;

   double emaH4_0=0, emaH4_5=0;
   int hH4 = iMA(Symbol(), PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(hH4 != INVALID_HANDLE)
     {
      double bH4[]; ArraySetAsSeries(bH4, true);
      if(CopyBuffer(hH4, 0, 0, 8, bH4) >= 6)
        { emaH4_0 = bH4[0]; emaH4_5 = bH4[5]; }
      IndicatorRelease(hH4);
     }
   bool h4Haussier = (emaH4_0 > emaH4_5 && emaH4_0 > 0);
   bool h4Baissier = (emaH4_0 < emaH4_5 && emaH4_0 > 0);

   if(pourBuy  && !h4Baissier) return false;
   if(!pourBuy && !h4Haussier) return false;

   double prix = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double atr  = atrVal[0];

   bool rsiOK = pourBuy ?
        (rsiVal[0] <= 38) :   // v5.1 : seuil plus strict (38 au lieu de 40)
        (rsiVal[0] >= 62);    // v5.1 : seuil plus strict (62 au lieu de 60)

   bool stochOK = pourBuy ?
        (stochMain[0] >= stochSignal[0] && stochMain[1] < stochSignal[1] && stochMain[1] <= 35) :
        (stochMain[0] <= stochSignal[0] && stochMain[1] > stochSignal[1] && stochMain[1] >= 65);

   bool chandOK = pourBuy ? (EngulfingHaussier() || PinBarHaussier())
                           : (EngulfingBaissier() || PinBarBaissier());

   bool niveauOK = pourBuy ?
        (PrixProcheSupport() || prix <= bbLower[0] * 1.003) :
        (PrixProcheResistance() || prix >= bbUpper[0] * 0.997);

   bool tenuH4 = pourBuy ?
        (emaH4_0 > 0 && prix > emaH4_0 * 0.992) :
        (emaH4_0 > 0 && prix < emaH4_0 * 1.008);

   if(!tenuH4) return false;

   int pbScore = 0;
   if(rsiOK)    pbScore++;
   if(stochOK)  pbScore++;
   if(chandOK)  pbScore++;
   if(niveauOK) pbScore++;

   // v5.1 : 3/4 minimum au lieu de 2/4 — filtre les faux signaux
   bool valide = (pbScore >= 3);
   if(valide)
      Print("PULLBACK CT (",pourBuy?"BUY":"SELL",")",
            " H4:", h4Haussier?"HAUSSIER":"BAISSIER",
            " RSI:", DoubleToString(rsiVal[0],1),
            " Stoch:", stochOK, " Chand:", chandOK,
            " Niveau:", niveauOK, " Score:", pbScore, "/4");
   return valide;
  }

//+------------------------------------------------------------------+
//|    SL DYNAMIQUE — v5.1 : borne max réduite à 3.0               |
//+------------------------------------------------------------------+
double CalculerSLDynamique(ADNMouvement &adn, MiroirInstitutionnel &mi,
                            EmpreintePsy &psy)
  {
   int    idx   = GetPaireIndex();
   bool   isBTC = (StringFind(Symbol(),"BTC") >= 0);
   bool   isXAU = (StringFind(Symbol(),"XAU")>=0||StringFind(Symbol(),"GOLD")>=0);

   double atrMul = ATR_Multiplier;
   if(isBTC) atrMul *= 1.5;
   if(isXAU) atrMul *= 1.1;

   atrMul *= cerveau[idx].slMultiDynamique;

   if(adn.phase == ADN_ACCUMULATION)
      atrMul *= 1.3;
   else if(adn.phase == ADN_COMPRESSION)
      atrMul *= 1.15;
   else if(adn.phase == ADN_DECLENCHEUR)
      atrMul *= 1.0;
   else if(adn.phase == ADN_EXPLOSION)
     {
      if(adn.forceExplosion > 80)
         atrMul *= 0.85;
      else
         atrMul *= 1.0;
     }
   else
      atrMul *= 1.1;

   if(psy.retournementIminent)
     {
      if(psy.epuisementVendeurs > 70 || psy.epuisementAcheteurs > 70)
         atrMul *= 0.9;
     }
   else
      atrMul *= 1.05;

   if(mi.manipulationDetectee && mi.confirmationEntree)
      atrMul *= 0.85;

   if(cerveau[idx].lossesConsecutifs >= 4)
      atrMul *= 1.3;
   else if(cerveau[idx].lossesConsecutifs == 3)
      atrMul *= 1.2;
   else if(cerveau[idx].lossesConsecutifs == 2)
      atrMul *= 1.1;

   if(ArraySize(atrVal) > 0)
     {
      if(cerveau[idx].atrMoyenne <= 0)
         cerveau[idx].atrMoyenne = atrVal[0];

      double atrRatio = atrVal[0] / cerveau[idx].atrMoyenne;

      if(atrRatio > 3.0)      atrMul *= 1.5;
      else if(atrRatio > 2.0) atrMul *= 1.3;
      else if(atrRatio > 1.5) atrMul *= 1.15;
      else if(atrRatio < 0.6) atrMul *= 0.9;
     }

   // v5.1 : borne max réduite à 3.0 (au lieu de 4.0) — SL moins large
   // v5.2 : Plafond SL absolu si volatilité > 2x moyenne — protège contre gros losses jan-fev 2026
   if(ArraySize(atrVal) > 0 && cerveau[idx].atrMoyenne > 0)
     {
      double atrRatioFinal = atrVal[0] / cerveau[idx].atrMoyenne;
      if(atrRatioFinal > 2.0) atrMul = MathMin(atrMul, 2.0); // Plafond dur en haute volatilité
     }
   atrMul = MathMax(1.5, MathMin(3.0, atrMul));

   Print("SL v5.2 : ATRmul=", DoubleToString(atrMul, 2),
         " | ADN=", EnumToString(adn.phase),
         " | Losses=", cerveau[idx].lossesConsecutifs,
         " | WR=", DoubleToString(cerveau[idx].winRate, 1), "%");

   return atrMul;
  }

//+------------------------------------------------------------------+
//|   OUVRIR TRADE + LOG OUVERTURE AVEC RAISON TP/SL               |
//+------------------------------------------------------------------+
void OuvrirTrade(bool isBuy, ADNMouvement &adn, MiroirInstitutionnel &mi,
                  EmpreintePsy &psy, bool isPullback=false)
  {
   int    idx    = GetPaireIndex();
   bool   isBTC  = (StringFind(Symbol(),"BTC") >= 0);
   bool   isXAU  = (StringFind(Symbol(),"XAU")>=0||StringFind(Symbol(),"GOLD")>=0);

   double atrMul = CalculerSLDynamique(adn, mi, psy);

   double atr    = atrVal[0];
   int    digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double prix   = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                         : SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double atrMulFinal = atrMul;
   if(isXAU) atrMulFinal = MathMin(atrMul, 1.8);
   if(isBTC) atrMulFinal = MathMin(atrMul, 2.0);

   if(isPullback)
     {
      atrMulFinal = MathMin(atrMulFinal, 1.5);          // v5.3 : 1.5x au lieu de 1.2x — moins de stops chassés
      if(isXAU) atrMulFinal = MathMin(atrMulFinal, 1.5); // v5.3 : XAU 1.5x (au lieu de 1.0x — trop serré sur GOLD)
      if(isBTC) atrMulFinal = MathMin(atrMulFinal, 1.5);
     }

   double slDist = atr * atrMulFinal;

   // ── RAISON SL — Explicite pour le log ─────────────────────────
   string raisonSL = "";
   if(isPullback)
      raisonSL = "SL_PULLBACK_" + DoubleToString(atrMulFinal,2) + "xATR";
   else if(adn.phase == ADN_EXPLOSION)
      raisonSL = "SL_EXPLOSION_ADN_" + DoubleToString(atrMulFinal,2) + "xATR";
   else if(mi.manipulationDetectee)
      raisonSL = "SL_APRES_MANIPULATION_" + DoubleToString(atrMulFinal,2) + "xATR";
   else if(psy.retournementIminent)
      raisonSL = "SL_RETOURNEMENT_PSY_" + DoubleToString(atrMulFinal,2) + "xATR";
   else
      raisonSL = "SL_TENDANCE_H4_" + DoubleToString(atrMulFinal,2) + "xATR";

   double tp1Multi, tp2Multi;
   string raisonTP = "";
   if(isPullback)
     {
      // v5.5 : PULLBACK CT TP relevé à RR1.5-2.0 (au lieu de 1.0-1.3)
      // Meilleure compensation sans modifier le split TP1/TP2 qui fonctionne bien
      tp1Multi = 1.5;
      tp2Multi = 2.0;
      raisonTP = "TP_PULLBACK_CT_RR1.5-2.0";
     }
   else
     {
      tp1Multi = TP1_RR;
      tp2Multi = TP2_RR;
      raisonTP = "TP_TENDANCE_RR" + DoubleToString(tp1Multi,1) + "-" + DoubleToString(tp2Multi,1);

      if(adn.phase == ADN_EXPLOSION && adn.forceExplosion > 80)
        {
         tp1Multi *= 1.2; tp2Multi *= 1.3;
         raisonTP = "TP_EXPLOSION_FORCE_RR" + DoubleToString(tp1Multi,1) + "-" + DoubleToString(tp2Multi,1);
        }
      if(mi.manipulationDetectee && mi.cibleInstitutionnelle > 0)
        {
         double distCible = MathAbs(mi.cibleInstitutionnelle - prix);
         if(distCible > slDist * 1.5)
           {
            tp2Multi = MathMax(tp2Multi, distCible / slDist);
            raisonTP = "TP_CIBLE_INSTIT_RR" + DoubleToString(tp2Multi,1);
           }
        }
     }

   double sl, tp1, tp2;
   if(isBuy)
     {
      sl  = NormalizeDouble(prix - slDist,            digits);
      tp1 = NormalizeDouble(prix + slDist * tp1Multi, digits);
      tp2 = NormalizeDouble(prix + slDist * tp2Multi, digits);
     }
   else
     {
      sl  = NormalizeDouble(prix + slDist,            digits);
      tp1 = NormalizeDouble(prix - slDist * tp1Multi, digits);
      tp2 = NormalizeDouble(prix - slDist * tp2Multi, digits);
     }

   double riskUsed = isPullback ?
                     MathMin(cerveau[idx].riskDynamique * 0.5, 0.5) :
                     cerveau[idx].riskDynamique;

   // ── v5.6 : MODULATION RISQUE PAR CONTEXTE (mode HYBRIDE) ──
   // ContextScore [0.85 → 1.10+] module riskUsed
   //   cs ≥ 1.10  → risk × CS_BoostCap (×1.05 prudent capé)
   //   0.85 ≤ cs < 1.10 → risk × cs (modulation continue)
   //   cs < 0.85 → trade déjà skippé en OnTick(), n'arrive jamais ici
   double cs = ContextScore();
   double riskMul = RiskMultiplierFromCS(cs);
   if(riskMul <= 0.0)
     {
      // Garde-fou défensif : ne devrait jamais arriver (déjà filtré OnTick)
      Print("v5.6 : RiskMul = 0 → trade annulé (cs=", DoubleToString(cs,3), ")");
      return;
     }
   double riskAvant = riskUsed;
   riskUsed *= riskMul;
   // ML LOG : snapshot pour LogOuverture()
   g_lastCS       = cs;
   g_lastRiskMul  = riskMul;

   // ── BRAIN-ML : modulation du risque par P(win) ────────────────
   // Estime la probabilité de gain avec le modèle ONNX entraîné sur les 549 trades 4y.
   //   - Si < BrainML_SkipBelow  → trade ANNULÉ
   //   - Sinon modulation du risque selon les seuils
   // v5.8 : nouvelle signature avec isPullback (f24 du vecteur brain_v1)
   double pWin   = BrainML_PredictWinProba(isBuy, isPullback, prix, adn, mi, psy);
   // v6.3 : brain ML sans edge (AUC~0.50) ET nuisible (gate -> pWin<0.3 hors distribution
   // de prix d'entrainement -> coupe tout le trading apres 2022). UseBrainML=false => mlMult=1.0.
   double mlMult = UseBrainML ? BrainML_RiskMultiplier(pWin) : 1.0;
   g_lastPwin    = pWin;
   g_lastMlMult  = mlMult;

   // COLLECTE : logue le signal AVANT le gate ML (capture toute la distribution,
   // y compris les signaux que le gate rejette) -> dataset non biaise pour reentrainer.
   if(BrainML_CollectFeatures && pWin >= 0.0)
      BrainML_CollectFeatureRow(isBuy, prix, sl, tp1, tp2, pWin);

   if(BrainML_LogProba && pWin >= 0.0)
      Print("BrainML : P(win)=", DoubleToString(pWin, 3),
            " → mult=", DoubleToString(mlMult, 2),
            " (", isBuy ? "BUY" : "SELL", ")");

   if(mlMult <= 0.0)
     {
      Print("BrainML : trade ANNULÉ — P(win)=", DoubleToString(pWin, 3),
            " < seuil ", DoubleToString(BrainML_SkipBelow, 2));
      etatCerveau = "Skip ML — P(win)=" + DoubleToString(pWin, 3);
      return;
     }
   riskUsed *= mlMult;

   g_lastRiskUsed = riskUsed;
   // Cap absolu à 2.5% du capital quoi qu'il arrive (sécurité)
   riskUsed = MathMin(riskUsed, 2.5);

   double lots = CalculerLots(slDist, riskUsed);
   if(lots <= 0) { Print("Lots invalides !"); return; }

   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double minL = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double half = MathFloor(lots/2.0/step)*step;
   double l1, l2;
   if(half < minL) { l1=0; l2=lots; }
   else            { l1=half; l2=half; }

   string typeTag = isPullback ? "_PB" : "";
   string comm1 = isBuy ? "Fotso_BUY_TP1"+typeTag : "Fotso_SELL_TP1"+typeTag;
   string comm2 = isBuy ? "Fotso_BUY_TP2"+typeTag : "Fotso_SELL_TP2"+typeTag;

   if(l1 > 0)
      isBuy ? trade.Buy(l1,Symbol(),prix,sl,tp1,comm1)
            : trade.Sell(l1,Symbol(),prix,sl,tp1,comm1);

   bool ok = isBuy ? trade.Buy(l2,Symbol(),prix,sl,tp2,comm2)
                   : trade.Sell(l2,Symbol(),prix,sl,tp2,comm2);

   if(ok)
     {
      tradesToday++;
      tradesCeBarre++;

      // ── LOG OUVERTURE IMMÉDIATE v5.1 ──────────────────────────
      if(EnableLogs)
         LogOuverture(isBuy, prix, sl, tp2, lots, raisonSL, raisonTP,
                      isPullback, adn, mi, psy);

      Print(isBuy?"BUY":"SELL", isPullback?" [PB]":" [TENDANCE]",
            " Lots:", DoubleToString(lots,2),
            " Risk:", DoubleToString(riskUsed,2), "%",
            " (CS:", DoubleToString(cs,3),
            " mul:", DoubleToString(riskMul,2), ")",
            " SL:", DoubleToString(sl,digits),
            " TP1:", DoubleToString(tp1,digits),
            " TP2:", DoubleToString(tp2,digits),
            " ATRmul:", DoubleToString(atrMulFinal,2),
            " RaisonSL:", raisonSL,
            " RaisonTP:", raisonTP);

      NotifierOuverture(isBuy, prix, sl, tp1, tp2, lots,
                        0, 0, (isPullback?"PB-CTH4 ":"TREND ") +
                        EnumToString(adn.phase) +
                        " SLx" + DoubleToString(atrMulFinal,2) +
                        " " + raisonSL);
     }
   else
      Print("Erreur ouverture:", GetLastError());
  }

//+------------------------------------------------------------------+
//|    ÉVALUER CERVEAU — v5.1 : Bonus D1 séparé fort/faible        |
//+------------------------------------------------------------------+
int EvaluerCerveau(bool pourBuy,
                   EmpreintePsy &psy,
                   ADNMouvement &adn,
                   MiroirInstitutionnel &mi)
  {
   double prix  = SymbolInfoDouble(Symbol(), pourBuy ? SYMBOL_BID : SYMBOL_ASK);
   // v5.7 : Filtres directionnels basés sur EMA200 TF configurable (default H4) au lieu de D1.
   // Raison : sur Or/BTC/US30/USTEC en uptrend D1 long, l'EA ne shortait jamais (0 SELL/mois).
   // L'EMA H4 se retourne plus vite et permet de capter les corrections.
   // Les variables gardent leur nom historique pour minimiser les diffs, mais elles sont
   // maintenant calculées sur le TF configuré (TrendFilterTF).
   bool   d1Bull= (ArraySize(ema200Trend)>0 && prix > ema200Trend[0]);
   bool   d1Bear= (ArraySize(ema200Trend)>0 && prix < ema200Trend[0]);
   bool   d1BullFort = (ArraySize(ema200Trend)>0 && prix > ema200Trend[0] * 1.003); // v6.1 : 1.5%->0.3% adapté H1 EMA40
   bool   d1BearFort = (ArraySize(ema200Trend)>0 && prix < ema200Trend[0] * 0.997); // v6.1 : 1.5%->0.3% adapté H1 EMA40
   // SELL bloqué si trend > EMA * 1.010 — v6.1 : 0.5%->1.0% (H1 EMA40 bouge vite, 0.5% était du bruit)
   bool   d1UltraHaussier = (ArraySize(ema200Trend)>0 && prix > ema200Trend[0] * 1.010);

   // ── v5.6+D1 FIX : Override du blocage SELL si DualGuard est en mode suspension ──
   // Le filtre v5.3 bloquait TOUS les SELL en uptrend D1, ce qui empêchait
   // l'EA de profiter des corrections (cause des cascades de SL en BUY).
   // Maintenant, quand DualGuard a suspendu les BUY (correction détectée),
   // on autorise les SELL contre-tendance D1 — c'est précisément le but
   // du module Override de DualGuard.
   bool dualGuardOverrideActif = DG_AllowSellAgainstD1();

   // v6.2 : blocage d1UltraHaussier RETIRE — la contre-tendance (SELL en uptrend) est
   // desormais autorisee et filtree par le gate ML (brain_v4 a appris des SELL contre-tendance,
   // WR_SELL OOS ~67% > WR_BUY). C'est le seuil BrainML_SkipBelow qui protege la qualite.

   bool   isBTC = (StringFind(Symbol(),"BTC")>=0);
   bool   isXAU = (StringFind(Symbol(),"XAU")>=0||StringFind(Symbol(),"GOLD")>=0);
   int    idx   = GetPaireIndex();

   // v5.8.4 FIX : utiliser le handle global hEMA200_TREND (déjà initialisé en OnInit)
   // au lieu de créer un handle local (risque : handle créé/relâché en boucle chaque tick)
   double emaH4_0=0, emaH4_5=0, emaH4_10=0;
   if(hEMA200_TREND != INVALID_HANDLE)
     {
      double bH4[]; ArraySetAsSeries(bH4,true);
      if(CopyBuffer(hEMA200_TREND,0,0,15,bH4)>=11)
        { emaH4_0=bH4[0]; emaH4_5=bH4[5]; emaH4_10=bH4[10]; }
     }
   bool h4H = (emaH4_0 > emaH4_5 && emaH4_0 > 0);
   bool h4B = (emaH4_0 < emaH4_5 && emaH4_0 > 0);
   bool h4H_fort = (h4H && emaH4_5 > emaH4_10);
   bool h4B_fort = (h4B && emaH4_5 < emaH4_10);

   // DEBUG v5.8.4 : log complet conditions BUY une fois par barre M15
   static datetime _dbgH4Bar = 0;
   datetime _curH4Bar = iTime(Symbol(), PERIOD_M15, 0);
   if(_curH4Bar != _dbgH4Bar && pourBuy) {
      _dbgH4Bar = _curH4Bar;
      PrintFormat("DBG_BUY %s ema0=%.1f ema5=%.1f h4H=%s h4B=%s adx=%.1f rsi=%.1f stoch=%.1f/%.1f trendEMA=%.1f d1UH=%s",
                  TimeToString(_curH4Bar,TIME_DATE|TIME_MINUTES),
                  emaH4_0, emaH4_5,
                  h4H?"Y":"N", h4B?"Y":"N",
                  ArraySize(adxMain)>0?adxMain[0]:0.0,
                  ArraySize(rsiVal)>0?rsiVal[0]:0.0,
                  ArraySize(stochMain)>0?stochMain[0]:0.0,
                  ArraySize(stochSignal)>0?stochSignal[0]:0.0,
                  ArraySize(ema200Trend)>0?ema200Trend[0]:0.0,
                  d1UltraHaussier?"Y":"N");
   }

   bool dirBuy  = h4H;
   bool dirSell = h4B;
   // v6.2 : porte de direction H1 EMA40 RETIREE comme veto — BUY et SELL sont tous deux
   // evalues et c'est le ML (brain_v4, entraine sans veto de direction) qui tranche le sens.
   // La pente reste un composant de score (c1 ci-dessous), pas un blocage dur.
   // -> aligne le live sur le dataset v4 (sinon live != backtest).
   // v5.3 : ADN_INCONNUE toujours bloqué — mais ADN_ACCUMULATION autorisé si PSY confirmé
   // v5.2 bloquait ADN_INCONNUE + ADN_ACCUMULATION → trop restrictif
   if(adn.phase == ADN_INCONNUE)
     {
      etatCerveau = "ADN INCONNUE — Attente phase identifiée (v5.3)";
      return 0;
     }

   // v5.3 : ADN_ACCUMULATION autorisé UNIQUEMENT si PSY retournement confirmé dans la bonne direction
   if(adn.phase == ADN_ACCUMULATION)
     {
      bool psyConfirme = pourBuy ? (psy.retournementIminent && psy.directionHaussiere)
                                  : (psy.retournementIminent && !psy.directionHaussiere);
      if(!psyConfirme)
        {
         etatCerveau = "ADN ACCUMULATION — PSY non confirmé, signal refusé";
         return 0;
        }
     }

   bool adnOK  = (adn.phase == ADN_ACCUMULATION ||
                  adn.phase == ADN_COMPRESSION ||
                  adn.phase == ADN_DECLENCHEUR  ||
                  adn.phase == ADN_EXPLOSION);
   bool adnDir = pourBuy ? adn.haussier : !adn.haussier;

   bool c1 = pourBuy ? h4H : h4B;

   bool c2 = pourBuy ?
             (rsiVal[0] >= 38 && rsiVal[0] <= 72) :
             (rsiVal[0] >= 28 && rsiVal[0] <= 62);

   bool c3_classique = pourBuy ?
             (stochMain[1]<stochSignal[1] && stochMain[0]>=stochSignal[0] && stochMain[1]<30) :
             (stochMain[1]>stochSignal[1] && stochMain[0]<=stochSignal[0] && stochMain[1]>70);
   bool c3_pullback = pourBuy ?
             (stochMain[1]<stochSignal[1] && stochMain[0]>=stochSignal[0] &&
              stochMain[1]>=20 && stochMain[1]<=55) :
             (stochMain[1]>stochSignal[1] && stochMain[0]<=stochSignal[0] &&
              stochMain[1]>=45 && stochMain[1]<=80);
   bool c3 = c3_classique || c3_pullback;

   bool c4 = pourBuy ? (BOS_Haussier() || PrixProcheSupport())
                     : (BOS_Baissier() || PrixProcheResistance());

   // v5.1 : seuil ADX relevé à 22 minimum pour GOLD (évite le range)
   double adxMin = (isBTC||isXAU) ? 22.0 : 22.0;
   bool c5 = pourBuy ?
             (ArraySize(adxMain)>0 && adxMain[0]>=adxMin && adxPlus[0]>adxMinus[0]) :
             (ArraySize(adxMain)>0 && adxMain[0]>=adxMin && adxMinus[0]>adxPlus[0]);

   bool c6 = pourBuy ? (EngulfingHaussier() || PinBarHaussier())
                     : (EngulfingBaissier() || PinBarBaissier());

   int score = 0;
   if(c1)score++;if(c2)score++;if(c3)score++;
   if(c4)score++;if(c5)score++;if(c6)score++;

   if(!c1) return 0;
   // v5.3 : ADX non bloquant si H4 FORT + ADN confirmé dans bonne direction
   // v5.2 : ADX obligatoire → coupe les entrées en début de tendance (ADX < 22 au déclenchement)
   // Nouvelle logique : si H4 très fort ET ADN identifié ET direction confirmée → autoriser sans ADX
   bool h4EtAdnForts = (h4H_fort || h4B_fort) && adnOK && adnDir;
   if(!c5 && !h4EtAdnForts) return 0;

   int bonusScore = 0;

   // v5.1 : Bonus D1 FORT uniquement (>1.5% au-dessus EMA200 D1)
   // Évite le cas où D1 est "juste au-dessus" et donne un faux bonus
   bool bonusD1 = pourBuy ? d1BullFort : d1BearFort;
   if(bonusD1) bonusScore++;

   bool bonusPsy = pourBuy ?
                   (psy.retournementIminent && psy.directionHaussiere) :
                   (psy.retournementIminent && !psy.directionHaussiere);
   if(bonusPsy) bonusScore++;

   bool bonusADN = (adnOK && adnDir);
   if(bonusADN) bonusScore++;

   bool bonusMiroir = false;
   if(mi.manipulationDetectee && mi.confirmationEntree)
     {
      bool miOK = pourBuy ? mi.piegeTendance==false : mi.piegeTendance==true;
      if(miOK) { bonusMiroir = true; bonusScore += 2; }
     }

   bool bonusTemp = false;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
     {
      double scoreTemp = cerveau[idx].scoreHeures[dt.hour] *
                         cerveau[idx].scoreJours[dt.day_of_week];
      if(scoreTemp >= 1.2) { bonusTemp = true; bonusScore++; }
     }

   bool bonusH4fort = pourBuy ? h4H_fort : h4B_fort;
   if(bonusH4fort) bonusScore++;

   bool bonusPBZone = PullbackZoneH4(pourBuy);
   if(bonusPBZone) bonusScore++;

   bool isPullback = pourBuy ?
        (rsiVal[0] <= 48 && c3_pullback && (PrixProcheSupport() || bbLower[0]>0)) :
        (rsiVal[0] >= 52 && c3_pullback && (PrixProcheResistance() || bbUpper[0]>0));
   if(bonusPBZone) isPullback = true;

   int scoreTotal = score + bonusScore;
   int scoreMin   = cerveau[idx].scoreMiniDynamique;

   bool seuilBase  = (score >= 3);
   bool seuilBonus = (bonusScore >= 2); // v6.1 : 3->2, ML filtre les signaux faibles (score_bonus_norm feature)
   bool seuilTotal = (scoreTotal >= scoreMin);

   // DEBUG v5.8.4 : log score final une fois par barre pour BUY
   static datetime _dbgScoreBar = 0;
   datetime _curScoreBar = iTime(Symbol(), PERIOD_M15, 0);
   if(_curScoreBar != _dbgScoreBar && pourBuy) {
      _dbgScoreBar = _curScoreBar;
      PrintFormat("DBG_SCORE %s base=%d/6 bonus=%d/7 total=%d min=%d | c1=%s c2=%s c3=%s c4=%s c5=%s c6=%s | ADN=%d dir=%s",
                  TimeToString(_curScoreBar,TIME_DATE|TIME_MINUTES),
                  score, bonusScore, scoreTotal, scoreMin,
                  c1?"Y":"N", c2?"Y":"N", c3?"Y":"N", c4?"Y":"N", c5?"Y":"N", c6?"Y":"N",
                  (int)adn.phase, adn.haussier?"H":"B");
   }

   if(seuilBase && seuilBonus && seuilTotal)
     {
      string typeSignal = isPullback ? "PULLBACK" : "BREAKOUT";
      Print(pourBuy?"BUY":"SELL",
            " [Cerveau v5.5] Base:", score, "/6",
            " Bonus:", bonusScore, "/7",
            " Total:", scoreTotal, "/13",
            " Type:", typeSignal,
            " | D1fort:", bonusD1,
            " H4fort:", bonusH4fort,
            " PBzone:", bonusPBZone,
            " Psy:", bonusPsy,
            " ADN:", bonusADN,
            " Miroir:", bonusMiroir,
            " Temp:", bonusTemp,
            " ADX:", DoubleToString(adxMain[0],1));
      // v5.8 : capturer les scores pour le vecteur BrainML
      g_lastScoreBase  = score;
      g_lastScoreBonus = bonusScore;
      return isPullback ? 2 : 1;
     }

   if(score >= 2 && bonusScore >= 2 && scoreTotal >= scoreMin - 1)
     {
      Print("Signal proche v5.2 — Base:", score, "/6",
            " Bonus:", bonusScore, "/6 (min:3)",
            " Total:", scoreTotal, " (min:", scoreMin, ")",
            " ADX:", DoubleToString(adxMain[0],1));
      NotifierSignalFaible(pourBuy, score, bonusScore);
     }

   return 0;
  }

//+------------------------------------------------------------------+
//|    OnTradeTransaction                                            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal))           return;
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   if(profit == 0) return;

   dailyPnL += profit;
   if(profit > 0) totalWins++;
   else         { totalLosses++; lossesAujourdhui++; }
   double balAp=AccountInfoDouble(ACCOUNT_BALANCE);
   if(balAp>highWaterMark) highWaterMark=balAp;

   // BUG #2 FIX : retrouver l'heure d'OUVERTURE du trade fermé pour que scoreHeures
   // apprenne sur la bonne heure (entrée), pas sur l'heure aléatoire de sortie.
   datetime tOpen = 0;
   ulong    posId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(posId > 0)
     {
      // Charger toute l'historique (les anciennes positions y sont)
      HistorySelect(0, TimeCurrent());
      int nDeals = HistoryDealsTotal();
      for(int i = 0; i < nDeals; i++)
        {
         ulong dTicket = HistoryDealGetTicket(i);
         if(dTicket == 0) continue;
         if(HistoryDealGetInteger(dTicket, DEAL_POSITION_ID) != (long)posId) continue;
         if(HistoryDealGetInteger(dTicket, DEAL_ENTRY) != DEAL_ENTRY_IN)     continue;
         tOpen = (datetime)HistoryDealGetInteger(dTicket, DEAL_TIME);
         break;
        }
     }
   MettreAJourCerveau(profit > 0, profit, tOpen);

   // ── v5.8 : Enregistrer le resultat dans l'historique BrainML (f34/f35) ──
   // Seuls les vrais trades Fotso comptent (pas les trades manuels)
   if(UseBrainML)
     {
      g_brainHistory[g_brainHistoryHead].win = (profit > 0);
      g_brainHistoryHead = (g_brainHistoryHead + 1) % 25;
      if(g_brainHistoryCount < 25) g_brainHistoryCount++;
     }

   // ── v5.6+D1 : Enregistrer SL BUY pour DualGuard cascade ──
   // BUG #1 FIX (audit 2026-05-09) : on enregistrait toute fermeture BUY perdante
   // (timeout MaxHeuresTrade=48h, FermerVendredi 20h, BE négatif, close manuel)
   // comme un SL → cascade DG injustifiée → suspensions BUY artificielles le lundi.
   // Maintenant on filtre strictement sur DEAL_REASON_SL (vrai stop-loss touché).
   if(UseDualGuard && profit < 0)
     {
      long dealType   = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      long dealEntry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      long dealReason = HistoryDealGetInteger(trans.deal, DEAL_REASON);

      // Conditions strictes :
      //   - DEAL_TYPE_SELL = ce deal vend (donc clôture d'un BUY OU ouverture SELL)
      //   - DEAL_ENTRY_OUT = c'est bien une SORTIE (pas une ouverture/retournement)
      //   - DEAL_REASON_SL = la sortie a été déclenchée par le stop-loss
      if(dealType   == DEAL_TYPE_SELL  &&
         dealEntry  == DEAL_ENTRY_OUT  &&
         dealReason == DEAL_REASON_SL)
        {
         DG_RegisterBuySL(TimeCurrent());
         Print("DualGuard : SL BUY enregistré (total fenêtre 12h: ",
               DG_CountBuySLInWindow(DG_Casc1_WindowH), ", 48h: ",
               DG_CountBuySLInWindow(DG_Casc2_WindowH), ")");
        }
      // Log informatif si on filtre une fermeture perdante non-SL (utile pour debug)
      else if(dealType == DEAL_TYPE_SELL && dealEntry == DEAL_ENTRY_OUT)
        {
         string raisonNonSL = "AUTRE";
         if(dealReason == DEAL_REASON_TP)       raisonNonSL = "TP (rare en perte)";
         else if(dealReason == DEAL_REASON_SO)  raisonNonSL = "STOP_OUT";
         else if(dealReason == DEAL_REASON_EXPERT) raisonNonSL = "EXPERT (timeout/vendredi/BE/manuel)";
         else if(dealReason == DEAL_REASON_CLIENT) raisonNonSL = "CLIENT (close manuel)";
         Print("DualGuard : fermeture BUY perdante ignorée (raison=", raisonNonSL,
               ") — pas comptée dans cascade");
        }
     }

   string raison;
   // Détecter si c'est un TP ou SL selon le profit et la position
   if(profit > 0)
      raison = "TP_ATTEINT — Objectif prix atteint";
   else
     {
      // Identifier la raison du SL depuis le log d'ouverture
      raison = TrouverRaisonSL(trans.deal);
      if(raison == "") raison = "SL_TOUCHE — Prix contre la position";
     }

   NotifierFermeture(profit, AccountInfoDouble(ACCOUNT_BALANCE), raison);

   if(EnableLogs) LogFermeture(trans.deal, profit, raison);
  }

//+------------------------------------------------------------------+
//|   v5.1 — RETROUVER RAISON SL DEPUIS LOG INTERNE                |
//+------------------------------------------------------------------+
string TrouverRaisonSL(ulong ticket)
  {
   for(int i = 0; i < tradeLogCount; i++)
     {
      if(tradeLogEntries[i].ticket == ticket)
         return "SL=" + tradeLogEntries[i].raisonSL;
     }
   return "SL_TOUCHE";
  }

//+------------------------------------------------------------------+
//|   v5.1 — LOG OUVERTURE : Signal + Raison SL/TP                 |
//+------------------------------------------------------------------+
void LogOuverture(bool isBuy, double prix, double sl, double tp, double lots,
                   string raisonSL, string raisonTP, bool isPullback,
                   ADNMouvement &adn, MiroirInstitutionnel &mi, EmpreintePsy &psy)
  {
   int h = FileOpen(LogFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);

   datetime t    = TimeCurrent();
   double   wr   = (totalWins+totalLosses)>0 ?
                   (double)totalWins/(totalWins+totalLosses)*100 : 0;
   string   dir  = isBuy ? "BUY" : "SELL";
   string   typeT = isPullback ? "PULLBACK_CT" : "TENDANCE_H4";
   string   adnStr = EnumToString(adn.phase);
   string   miroirStr = mi.manipulationDetectee ? "MANIPULATION_"+( mi.piegeTendance?"HAUSSIER":"BAISSIER") : "OK";
   string   psyStr = psy.retournementIminent ? "RETOUR_"+(psy.directionHaussiere?"HAUSSIER":"BAISSIER") : "NEUTRE";

   // ── ML LOG v5.6+D1.1+ML : capture des features marché ──────────────
   // Indicateurs multi-TF calculés à l'instant de l'ouverture.
   // Tous échecs → on log la sentinelle "" (parseur Python ignorera ces lignes).
   double atrM15 = 0.0, atrH1 = 0.0, atrH4 = 0.0, adxH4 = 0.0;
   double ema200_d1_pct = 0.0;
   long   spreadPts = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);

   // FIX atr_m15=0 : on lit le SHIFT 1 (dernière bougie clôturée) au lieu du shift 0
   // (bougie en cours), garanti d'avoir une valeur ATR calculée. On essaie d'abord shift 1,
   // puis on retombe sur shift 0 si shift 1 échoue (1er tick du backtest).
   int hATRm15 = iATR(Symbol(), PERIOD_M15, 14);
   if(hATRm15 != INVALID_HANDLE)
     {
      double b[]; ArraySetAsSeries(b, true);
      if(CopyBuffer(hATRm15, 0, 1, 1, b) > 0 && b[0] > 0) atrM15 = b[0];
      else if(CopyBuffer(hATRm15, 0, 0, 1, b) > 0)        atrM15 = b[0];
      IndicatorRelease(hATRm15);
     }
   int hATRh1 = iATR(Symbol(), PERIOD_H1, 14);
   if(hATRh1 != INVALID_HANDLE)
     {
      double b[]; ArraySetAsSeries(b, true);
      if(CopyBuffer(hATRh1, 0, 1, 1, b) > 0 && b[0] > 0) atrH1 = b[0];
      else if(CopyBuffer(hATRh1, 0, 0, 1, b) > 0)        atrH1 = b[0];
      IndicatorRelease(hATRh1);
     }
   int hATRh4 = iATR(Symbol(), PERIOD_H4, 14);
   if(hATRh4 != INVALID_HANDLE)
     {
      double b[]; ArraySetAsSeries(b, true);
      if(CopyBuffer(hATRh4, 0, 1, 1, b) > 0 && b[0] > 0) atrH4 = b[0];
      else if(CopyBuffer(hATRh4, 0, 0, 1, b) > 0)        atrH4 = b[0];
      IndicatorRelease(hATRh4);
     }
   int hADXh4 = iADX(Symbol(), PERIOD_H4, 14);
   if(hADXh4 != INVALID_HANDLE)
     {
      double b[]; ArraySetAsSeries(b, true);
      if(CopyBuffer(hADXh4, 0, 1, 1, b) > 0 && b[0] > 0) adxH4 = b[0];
      else if(CopyBuffer(hADXh4, 0, 0, 1, b) > 0)        adxH4 = b[0];
      IndicatorRelease(hADXh4);
     }
   // Distance prix → EMA200 D1 (positive = au-dessus, négative = en-dessous), en %
   if(ArraySize(ema200D1) > 0 && ema200D1[0] > 0)
      ema200_d1_pct = (prix - ema200D1[0]) / ema200D1[0] * 100.0;

   // v5.1 : log complet avec raisons TP et SL + ML features
   FileWrite(h,
      TimeToString(t, TIME_DATE),
      TimeToString(t, TIME_MINUTES),
      lastSignal + "_OUVERTURE",
      adnStr + "|" + miroirStr + "|" + psyStr,
      typeT,
      Symbol(),
      dir,
      DoubleToString(prix, 2),
      "OUVERT",
      DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
      DoubleToString(wr, 1) + "%",
      raisonSL,
      raisonTP,
      "SL=" + DoubleToString(sl, 2),
      "TP=" + DoubleToString(tp, 2),
      "Lots=" + DoubleToString(lots, 2),
      // ── ML features (17 colonnes) ──
      DoubleToString(atrM15, 5),
      DoubleToString(atrH1,  5),
      DoubleToString(atrH4,  5),
      DoubleToString(adxH4,  2),
      DoubleToString(ema200_d1_pct, 4),
      IntegerToString((int)spreadPts),
      IntegerToString(g_lastSignalBuy),
      IntegerToString(g_lastSignalSell),
      DoubleToString(g_lastCS,       4),
      DoubleToString(g_lastRiskMul,  4),
      DoubleToString(g_lastRiskUsed, 3),
      DoubleToString(psy.indexPeur,         4),
      DoubleToString(psy.indexCupidite,     4),
      DoubleToString(psy.epuisementVendeurs,4),
      DoubleToString(psy.epuisementAcheteurs,4),
      DoubleToString(adn.forceExplosion,    4),
      DoubleToString(mi.cibleInstitutionnelle, 2),
      (DG_IsBuySuspended()       ? "1" : "0"),
      (DG_AllowSellAgainstD1()   ? "1" : "0"),
      // ── v5.8.1 : ML brain prediction (Axe A diagnostic) ──
      DoubleToString(g_lastPwin,    4),
      DoubleToString(g_lastMlMult,  3));
   FileClose(h);
  }

//+------------------------------------------------------------------+
//|   v5.1 — LOG FERMETURE : Raison détaillée TP ou SL             |
//+------------------------------------------------------------------+
void LogFermeture(ulong ticket, double profit, string raison)
  {
   int h = FileOpen(LogFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);

   datetime t    = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   double entry  = HistoryDealGetDouble(ticket, DEAL_PRICE);
   string sym    = HistoryDealGetString(ticket, DEAL_SYMBOL);
   long   type   = HistoryDealGetInteger(ticket, DEAL_TYPE);
   long   entry_t= HistoryDealGetInteger(ticket, DEAL_ENTRY);
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double wr     = (totalWins+totalLosses)>0 ?
                   (double)totalWins/(totalWins+totalLosses)*100 : 0;

   string direction;
   if(entry_t == DEAL_ENTRY_OUT || entry_t == DEAL_ENTRY_INOUT)
      direction = (type == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   else
      direction = (type == DEAL_TYPE_BUY) ? "BUY" : "SELL";

   // Raison détaillée TP ou SL
   string raisonDetail = "";
   string resultStr = "";
   if(profit > 0)
     {
      raisonDetail = "TP_ATTEINT — Prix a touché l'objectif fixé (RR favorable)";
      resultStr    = "WIN +" + DoubleToString(profit, 2) + "$";
     }
   else
     {
      // Raison SL contextuelle
      raisonDetail = raison;
      if(StringFind(raison, "PULLBACK") >= 0)
         raisonDetail += " — Retournement CT invalide, tendance H4 a repris";
      else if(StringFind(raison, "EXPLOSION") >= 0)
         raisonDetail += " — Explosion non confirmée ou épuisée";
      else if(StringFind(raison, "MANIPULATION") >= 0)
         raisonDetail += " — Signal institutionnel invalidé";
      else if(StringFind(raison, "TENDANCE") >= 0)
         raisonDetail += " — Tendance H4 contrariée par mouvement adverse";
      else
         raisonDetail += " — Marché contre la position";
      resultStr = "LOSS " + DoubleToString(profit, 2) + "$";
     }

   // ML LOG : 17 colonnes vides supplémentaires pour rester aligné avec l'en-tête
   FileWrite(h,
      TimeToString(t, TIME_DATE),
      TimeToString(t, TIME_MINUTES),
      lastSignal,
      etatCerveau,
      "FERMETURE",
      sym,
      direction,
      DoubleToString(entry, 2),
      DoubleToString(profit, 2),
      DoubleToString(bal, 2),
      DoubleToString(wr, 1) + "%",
      raisonDetail,
      resultStr,
      "", "", "",
      "", "", "", "", "", "",  // atr_m15..spread_pts
      "", "", "", "", "",      // scores + risk
      "", "", "", "",          // psy continus
      "", "",                  // adn/mi continus
      "", "",                  // dg flags
      "", "");                 // v5.8.1 : brain_p, brain_mult (vides à la fermeture)
   FileClose(h);
  }

//+------------------------------------------------------------------+
//|    BE + TRAILING                                                 |
//+------------------------------------------------------------------+
void GererBreakEven()
  {
   if(!UseBreakEven) return;
   double atr=atrVal[0];
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol()!=Symbol()) continue;
      ulong tk=posInfo.Ticket(); double en=posInfo.PriceOpen();
      double sl=posInfo.StopLoss();
      int dg=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
      double pt=SymbolInfoDouble(Symbol(),SYMBOL_POINT);
      if(posInfo.PositionType()==POSITION_TYPE_BUY)
        {
         if(SymbolInfoDouble(Symbol(),SYMBOL_BID)>=en+atr*BE_ATR_Multi&&sl<en)
           { double nsl=NormalizeDouble(en+pt,dg);
             if(trade.PositionModify(tk,nsl,posInfo.TakeProfit()))
               { Print("BE BUY ",tk," SL->",DoubleToString(nsl,dg));
                 if(NotifBE) NotifierBreakEven("BUY", nsl, tk); } }
        }
      else if(posInfo.PositionType()==POSITION_TYPE_SELL)
        {
         if(SymbolInfoDouble(Symbol(),SYMBOL_ASK)<=en-atr*BE_ATR_Multi&&(sl>en||sl==0))
           { double nsl=NormalizeDouble(en-pt,dg);
             if(trade.PositionModify(tk,nsl,posInfo.TakeProfit()))
               { Print("BE SELL ",tk," SL->",DoubleToString(nsl,dg));
                 if(NotifBE) NotifierBreakEven("SELL", nsl, tk); } }
        }
     }
  }

void GererTrailing()
  {
   if(!UseTrailing) return;
   double atr=atrVal[0];
   int dg=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol()!=Symbol()) continue;
      if(StringFind(posInfo.Comment(),"TP2")<0) continue;
      ulong  tk=posInfo.Ticket();
      double sl=posInfo.StopLoss();
      double en=posInfo.PriceOpen();
      double tp=posInfo.TakeProfit();
      if(posInfo.PositionType()==POSITION_TYPE_BUY)
        {
         double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
         double gain=bid-en;
         if(sl<en) continue;
         double distTP=(tp>en)?(tp-en):1;
         double pctTP=gain/distTP;
         if(pctTP<0.50) continue;
         double trailDist=(pctTP>=0.80)?atr*1.5:atr*Trail_ATR_Multi;
         double nsl=NormalizeDouble(bid-trailDist,dg);
         if(nsl>sl&&nsl>en)
            if(trade.PositionModify(tk,nsl,tp))
               Print("Trail BUY #",tk," ",DoubleToString(pctTP*100,0),"% SL->",DoubleToString(nsl,dg));
        }
      else if(posInfo.PositionType()==POSITION_TYPE_SELL)
        {
         double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
         double gain=en-ask;
         if(sl>en&&sl!=0) continue;
         double distTP=(en>tp)?(en-tp):1;
         double pctTP=gain/distTP;
         if(pctTP<0.50) continue;
         double trailDist=(pctTP>=0.80)?atr*1.5:atr*Trail_ATR_Multi;
         double nsl=NormalizeDouble(ask+trailDist,dg);
         if((nsl<sl||sl==0)&&nsl<en)
            if(trade.PositionModify(tk,nsl,tp))
               Print("Trail SELL #",tk," ",DoubleToString(pctTP*100,0),"% SL->",DoubleToString(nsl,dg));
        }
     }
  }

void GererFermetureForce()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   bool weekend=(FermerVendredi&&dt.day_of_week==5&&dt.hour>=VendrediHeure);
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol()!=Symbol()) continue;
      long h=(long)(TimeCurrent()-posInfo.Time())/3600;
      if(h>=MaxHeuresTrade)
        { trade.PositionClose(posInfo.Ticket());
          Print("Fermeture forcée durée ",posInfo.Ticket()," ",h,"h"); }
      else if(weekend)
        { trade.PositionClose(posInfo.Ticket());
          Print("Fermeture weekend ",posInfo.Ticket()); }
     }
  }

//+------------------------------------------------------------------+
//|    UTILITAIRES                                                   |
//+------------------------------------------------------------------+
double CalculerLots(double slPoints, double riskPct)
  {
   if(slPoints<=0) return 0;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double risk=bal*riskPct/100.0;
   double tv=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);
   double step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   double minL=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double maxL=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(tv<=0||ts<=0) return minL;
   double lots=risk/(slPoints/ts*tv);
   long lev=AccountInfoInteger(ACCOUNT_LEVERAGE);
   double px=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double cs=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_CONTRACT_SIZE);
   double mReq=lev>0?(px*cs*lots)/lev:0;
   double mFre=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(mReq>0&&mReq>mFre*0.8) lots=(mFre*0.8*lev)/(px*cs);
   lots=MathFloor(lots/step)*step;
   return MathMax(minL,MathMin(maxL,lots));
  }

bool AucunePositionOuverte()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Symbol()==Symbol()) return false;
   return true;
  }

bool StopJournalierAtteint()
  {
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double pct=((startOfDayBalance-bal)/startOfDayBalance)*100;
   if(pct>=DailyStopLoss)
     { if(robotActif){Alert("Stop journalier !"); NotifierStopJournalier(pct,bal); robotActif=false;} return true; }
   return false;
  }

// v5.7.1 : limites de spread configurables via inputs (tune sans recompile)
int       MaxSpread_XAU  = 400;   // v6.3 FORCE (non-input) : spread broker XAU ~280 en backtest, 250 bloquait TOUT
input int MaxSpread_BTC  = 1000;
input int MaxSpread_EUR  = 50;
input int MaxSpread_GBP  = 50;
input int MaxSpread_NAS  = 200;   // v5.7.1 : 150 → 200 (USTEC souvent au-dessus)
input int MaxSpread_US30 = 250;   // v5.7.1 : 200 → 250
input int MaxSpread_OTHER = 250;

double GetMaxSpread()
  {
   string sym=Symbol();
   if(StringFind(sym,"BTC")>=0) return (double)MaxSpread_BTC;
   if(StringFind(sym,"XAU")>=0||StringFind(sym,"GOLD")>=0) return (double)MaxSpread_XAU;
   if(StringFind(sym,"EUR")>=0) return (double)MaxSpread_EUR;
   if(StringFind(sym,"GBP")>=0) return (double)MaxSpread_GBP;
   if(StringFind(sym,"NAS")>=0) return (double)MaxSpread_NAS;
   if(StringFind(sym,"US30")>=0) return (double)MaxSpread_US30;
   return (double)MaxSpread_OTHER;
  }

bool SpreadAcceptable()
  {
   double sp=(double)SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);
   if(sp>GetMaxSpread()){Print("Spread élevé:",sp); return false;}
   return true;
  }

bool HeureAutoriseePourPaire()
  {
   bool isXAU=(StringFind(Symbol(),"XAU")>=0||StringFind(Symbol(),"GOLD")>=0);
   bool isBTC=(StringFind(Symbol(),"BTC")>=0);
   if(!isXAU&&!isBTC) return true;

   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int h=dt.hour; int m=dt.min;

   if(isXAU)
     {
      bool interdit=(h==15)||(h==16&&m<=30)||(h==14&&m>=30);
      if(interdit)
        {
         etatCerveau="XAU : Overlap 14h30-16h30 — Attente session propre";
         return false;
        }
     }

   if(isBTC)
     {
      bool nuit=(h>=22||h<6);
      if(nuit)
        {
         etatCerveau="BTC : Session nuit 22h-06h — En attente";
         return false;
        }
     }
   return true;
  }

bool EstProcheNews()
  {
   if(StringFind(Symbol(),"BTC")>=0) return false;
   if(newsCount==0) return false;
   datetime now=TimeCurrent();
   for(int i=0;i<newsCount;i++)
     {
      long d=((long)newsEvents[i].time-(long)now)/60;
      if(d>0&&d<=newsEvents[i].avant) return true;
      if(d<=0&&MathAbs(d)<=newsEvents[i].apres) return true;
     }
   return false;
  }

void ResetQuotidien()
  {
   MqlDateTime now,last;
   TimeToStruct(TimeCurrent(),now); TimeToStruct(lastDayChecked,last);
   if(now.day!=last.day)
     {
      startOfDayBalance=AccountInfoDouble(ACCOUNT_BALANCE);
      tradesToday=0; dailyPnL=0; robotActif=true;
      lossesAujourdhui=0;
      lastDayChecked=TimeCurrent();
      cerveau[GetPaireIndex()].lossesConsecutifs=0;
      MqlDateTime dt_r; TimeToStruct(TimeCurrent(),dt_r);
      if(dt_r.day_of_week==1){weeklyStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);}
      double bal_r=AccountInfoDouble(ACCOUNT_BALANCE);
      if(bal_r>highWaterMark) highWaterMark=bal_r;
      cerveau[GetPaireIndex()].lossesConsecutifs = 0;
      LoadNewsFromMT5();
      if(UseForexFactory&&!MQLInfoInteger(MQL_TESTER)) LoadNewsFromForexFactory();
      if(tradesToday > 0) NotifierResumeDuJour();
      Print("Reset quotidien $",DoubleToString(startOfDayBalance,2));
     }
  }

//+------------------------------------------------------------------+
//|    NEWS                                                         |
//+------------------------------------------------------------------+
void LoadNewsFromMT5()
  {
   datetime from=iTime(Symbol(),PERIOD_D1,0);
   datetime to=from+86400*7;
   MqlCalendarValue values[];
   int total=CalendarValueHistory(values,from,to,"US");
   for(int i=0;i<total;i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id,ev)) continue;
      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
      bool existe=false;
      for(int j=0;j<newsCount;j++)
         if(newsEvents[j].time==values[i].time&&newsEvents[j].name==ev.name)
           {existe=true;break;}
      if(existe) continue;
      NewsEvent ne; ne.time=values[i].time; ne.name=ev.name; ne.source="MT5";
      AssignerBlocNews(ne);
      ArrayResize(newsEvents,newsCount+1);
      newsEvents[newsCount]=ne; newsCount++;
     }
  }

void LoadNewsFromForexFactory()
  {
   char result[]; string headers="Content-Type: application/json\r\n";
   string respH; char postData[];
   int res=WebRequest("GET",FF_URL,headers,5000,postData,result,respH);
   if(res!=200){Print("[FF] code:",res); return;}
   ParseForexFactoryJSON(CharArrayToString(result));
  }

void ParseForexFactoryJSON(string json)
  {
   int pos=0;
   while(true)
     {
      int s=StringFind(json,"{",pos); if(s<0) break;
      int e=StringFind(json,"}",s);   if(e<0) break;
      string obj=StringSubstr(json,s,e-s+1); pos=e+1;
      if(ExtractJSONField(obj,"country")!="USD") continue;
      if(ExtractJSONField(obj,"impact")!="High") continue;
      string title=ExtractJSONField(obj,"title");
      datetime t=StringToTime(ExtractJSONField(obj,"date")+" "+ExtractJSONField(obj,"time"));
      if(t==0) continue;
      bool existe=false;
      for(int j=0;j<newsCount;j++)
         if(StringFind(newsEvents[j].name,title)>=0){existe=true;break;}
      if(existe) continue;
      NewsEvent ne; ne.time=t; ne.name=title; ne.source="FF";
      AssignerBlocNews(ne);
      ArrayResize(newsEvents,newsCount+1);
      newsEvents[newsCount]=ne; newsCount++;
     }
  }

string ExtractJSONField(string json,string key)
  {
   string s="\""+key+"\":\""; int i=StringFind(json,s);
   if(i<0) return "";
   i+=StringLen(s); int e=StringFind(json,"\"",i);
   if(e<0) return "";
   return StringSubstr(json,i,e-i);
  }

void AssignerBlocNews(NewsEvent &ne)
  {
   if(StringFind(ne.name,"NFP")>=0||StringFind(ne.name,"Non-Farm")>=0)
     {ne.avant=NFP_Avant;ne.apres=NFP_Apres;}
   else if(StringFind(ne.name,"CPI")>=0)
     {ne.avant=CPI_Avant;ne.apres=CPI_Apres;}
   else if(StringFind(ne.name,"Fed")>=0||StringFind(ne.name,"FOMC")>=0)
     {ne.avant=FED_Avant;ne.apres=FED_Apres;}
   else {ne.avant=30;ne.apres=30;}
  }

//+------------------------------------------------------------------+
//|    LOG — v5.1 : Header enrichi avec colonnes Raison SL/TP      |
//+------------------------------------------------------------------+
void InitLogFile()
  {
   int h=FileOpen(LogFile,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE) return;
   // v5.1 : colonnes enrichies avec RaisonSL, RaisonTP, NiveauSL, NiveauTP, Lots
   // v5.6+D1.1+ML : 19 nouvelles colonnes pour pipeline machine learning (35 cols total)
   //   - Indicateurs marché : ATR M15/H1/H4, ADX H4, distance EMA200 D1, spread
   //   - Scores décision    : score_buy, score_sell, context_score, risk_mul, risk_used
   //   - Psy continus       : peur, cupidite, epuisement vendeurs/acheteurs
   //   - ADN/Miroir continus: force_explosion, cible_inst
   //   - État DualGuard     : buy_suspended, sell_override
   FileWrite(h,"Date","Heure","Signal","ADN_Miroir_Psy","Type","Paire",
               "Direction","Entry","Profit","Balance","WinRate",
               "RaisonSL","RaisonTP","NiveauSL","NiveauTP","Lots",
               // ── ML features (toujours présentes à l'ouverture, vides à la fermeture) ──
               "atr_m15","atr_h1","atr_h4","adx_h4","ema200_d1_dist_pct","spread_pts",
               "score_buy","score_sell","context_score","risk_mul","risk_used_pct",
               "psy_peur","psy_cupidite","psy_epuise_vend","psy_epuise_ach",
               "adn_force_explo","mi_cible_inst",
               "dg_buy_susp","dg_sell_ovr",
               // ── v5.8.1 : ML brain prediction (Axe A diagnostic) ──
               "brain_p","brain_mult");
   FileClose(h);
  }

//+------------------------------------------------------------------+
//|    NOTIFICATIONS                                                 |
//+------------------------------------------------------------------+
void EnvoyerNotification(string titre, string message, bool urgent=false)
  {
   string msg = "[CERVEAU FOTSO] " + titre + " | " + message;
   if(NotifMT5Alerte && urgent) Alert(msg);
   if(NotifMT5Push)
      if(!SendNotification(msg))
         Print("Push echec — MT5 Tools>Options>Notifications");
   if(NotifEmail && EmailDestinataire != "")
      if(!SendMail("[Cerveau Fotso] " + titre + " " + Symbol(), message))
         Print("Email echec — MT5 Tools>Options>Email");
   Print(msg);
  }

void NotifierOuverture(bool isBuy, double prix, double sl, double tp1,
                        double tp2, double lots, int sBase, int sCerveau,
                        string adnPhase)
  {
   if(!NotifOuverture) return;
   int    dg  = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   string dir = isBuy ? "BUY ACHAT" : "SELL VENTE";
   string titre = dir + " — " + Symbol();
   string msg = "Entree:" + DoubleToString(prix,dg) +
                " | SL:" + DoubleToString(sl,dg) +
                " | TP1:" + DoubleToString(tp1,dg) +
                " | TP2:" + DoubleToString(tp2,dg) +
                " | Lots:" + DoubleToString(lots,2) +
                " | ADN:" + adnPhase +
                " | Risk:" + DoubleToString(cerveau[GetPaireIndex()].riskDynamique,2) + "%";
   EnvoyerNotification(titre, msg, true);
  }

void NotifierFermeture(double profit, double balance, string raison)
  {
   if(!NotifFermeture) return;
   string res   = profit >= 0 ? "WIN +" : "LOSS ";
   string titre = res + DoubleToString(profit,2) + "$ — " + Symbol();
   double wr    = (totalWins+totalLosses)>0 ?
                  (double)totalWins/(totalWins+totalLosses)*100 : 0;
   string msg = "Resultat:" + DoubleToString(profit,2) + "$" +
                " | Balance:" + DoubleToString(balance,2) + "$" +
                " | PnL jour:" + DoubleToString(dailyPnL,2) + "$" +
                " | WR:" + DoubleToString(wr,1) + "%" +
                " | Raison:" + raison +
                " | WR paire:" + DoubleToString(cerveau[GetPaireIndex()].winRate,1) + "%";
   EnvoyerNotification(titre, msg, profit < 0);
  }

void NotifierBreakEven(string direction, double newSL, ulong ticket)
  {
   if(!NotifBE) return;
   int dg = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   string titre = "PROTECTION BE — " + Symbol() + " " + direction;
   string msg = "Break-Even activé ! SL->" + DoubleToString(newSL,dg) +
                " | Ticket#" + IntegerToString((int)ticket) +
                " | Trade sécurisé à zéro risque";
   EnvoyerNotification(titre, msg, false);
  }

void NotifierSignalFaible(bool pourBuy, int sBase, int sCerveau)
  {
   if(!NotifSignalFaible) return;
   string dir = pourBuy ? "BUY" : "SELL";
   string titre = "SIGNAL PROCHE v5.2 — " + Symbol() + " " + dir;
   string msg = "Signal détecté mais seuil non atteint." +
                " Base:" + IntegerToString(sBase) + "/6 (min 3)" +
                " | Cerveau:" + IntegerToString(sCerveau) + "/5 (min 3)";
   EnvoyerNotification(titre, msg, false);
  }

void NotifierChangementRegime(string nouveauRegime)
  {
   if(!NotifRegime) return;
   if(nouveauRegime == lastRegimeNotif) return;
   lastRegimeNotif = nouveauRegime;
   string titre = "REGIME MARCHE : " + nouveauRegime + " — " + Symbol();
   string msg = ""; bool urgent = false;
   if(nouveauRegime == "RANGE")
     { msg = "Marché en range — Trading suspendu automatiquement."; }
   else if(nouveauRegime == "VOLATIL")
     { msg = "VOLATILITE EXTREME — Trading suspendu. Risque de gaps!"; urgent=true; }
   else if(nouveauRegime == "TENDANCE")
     { msg = "Tendance forte — Conditions optimales. Cerveau en alerte."; }
   else
     { msg = "Régime neutre — Trading avec prudence."; }
   EnvoyerNotification(titre, msg, urgent);
  }

void NotifierStopJournalier(double pct, double balance)
  {
   if(!NotifDailyStop) return;
   string titre = "STOP JOURNALIER — " + Symbol();
   string msg = "Drawdown " + DoubleToString(pct,2) + "% atteint!" +
                " | Balance:" + DoubleToString(balance,2) + "$" +
                " | Robot désactivé jusqu'à demain." +
                " | PnL jour:" + DoubleToString(dailyPnL,2) + "$";
   EnvoyerNotification(titre, msg, true);
  }

void NotifierDecisionCerveau(string decision)
  {
   if(!NotifCerveau) return;
   EnvoyerNotification("CERVEAU ADAPTATIF — " + Symbol(), decision, false);
  }

void NotifierResumeDuJour()
  {
   int    idx = GetPaireIndex();
   double wr  = (totalWins+totalLosses)>0 ?
                (double)totalWins/(totalWins+totalLosses)*100 : 0;
   string titre = "RÉSUMÉ JOURNÉE — " + Symbol();
   string msg = "Trades:" + IntegerToString(tradesToday) +
                " | PnL:" + DoubleToString(dailyPnL,2) + "$" +
                " | WR:" + DoubleToString(wr,1) + "%" +
                " | WR paire:" + DoubleToString(cerveau[idx].winRate,1) + "%" +
                " | Risk:" + DoubleToString(cerveau[idx].riskDynamique,2) + "%" +
                " | Etat:" + etatCerveau;
   EnvoyerNotification(titre, msg, false);
  }

//+------------------------------------------------------------------+
//|    INIT & LECTURE INDICATEURS                                   |
//+------------------------------------------------------------------+
bool InitIndicateurs()
  {
   hEMA200_D1=iMA(Symbol(),PERIOD_D1,200,0,MODE_EMA,PRICE_CLOSE);
   // v5.7 : EMA200 sur le TF directionnel choisi (default H4)
   hEMA200_TREND=iMA(Symbol(),TrendFilterTF,TrendFilterPeriod,0,MODE_EMA,PRICE_CLOSE);
   hRSI      =iRSI(Symbol(),PERIOD_H1,14,PRICE_CLOSE);
   hStoch    =iStochastic(Symbol(),PERIOD_M15,5,3,3,MODE_SMA,STO_LOWHIGH);
   hADX      =iADX(Symbol(),PERIOD_H1,14);
   hATR      =iATR(Symbol(),PERIOD_H1,14);
   hBollinger=iBands(Symbol(),PERIOD_H1,20,0,2.0,PRICE_CLOSE);
   // v5.8 : handles supplementaires pour BrainML 36 features
   hATR_M15_brain   = iATR(Symbol(), PERIOD_M15, 14);
   hATR_H4_brain    = iATR(Symbol(), PERIOD_H4,  14);
   hADX_H4_brain    = iADX(Symbol(), PERIOD_H4,  14);
   hEMA200_H4_brain = iMA(Symbol(),  PERIOD_H4,  200, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50_H4_brain  = iMA(Symbol(),  PERIOD_H4,  50,  0, MODE_EMA, PRICE_CLOSE);

   if(hEMA200_D1==INVALID_HANDLE||hEMA200_TREND==INVALID_HANDLE||hRSI==INVALID_HANDLE||
      hStoch==INVALID_HANDLE||hADX==INVALID_HANDLE||
      hATR==INVALID_HANDLE||hBollinger==INVALID_HANDLE||
      hATR_M15_brain==INVALID_HANDLE||hATR_H4_brain==INVALID_HANDLE||
      hADX_H4_brain==INVALID_HANDLE||hEMA200_H4_brain==INVALID_HANDLE||
      hEMA50_H4_brain==INVALID_HANDLE)
     { Alert("Erreur indicateurs — verifier historique !"); return false; }

   ArraySetAsSeries(ema200D1,true); ArraySetAsSeries(ema200Trend,true);
   ArraySetAsSeries(rsiVal,true);
   ArraySetAsSeries(stochMain,true); ArraySetAsSeries(stochSignal,true);
   ArraySetAsSeries(adxMain,true); ArraySetAsSeries(adxPlus,true);
   ArraySetAsSeries(adxMinus,true); ArraySetAsSeries(atrVal,true);
   ArraySetAsSeries(bbUpper,true); ArraySetAsSeries(bbMiddle,true);
   ArraySetAsSeries(bbLower,true);

   // v5.93 warmup : uniquement hors testeur pour ne pas contaminer le contexte
   // de simulation. En testeur, l'appel CopyBuffer en OnInit avec des données
   // historiques pré-test provoque err=4807 (ERR_INDICATOR_DATA_NOT_FOUND)
   // sur toutes les barres simulées — le testeur doit initialiser l'indicateur
   // lui-même à partir de la date de début du test.
   if(!MQL5InfoInteger(MQL5_TESTER))
     {
      double _warmup[]; ArraySetAsSeries(_warmup, true);
      int _cnt  = CopyBuffer(hEMA200_TREND,    0, 0, TrendFilterPeriod+10, _warmup);
      int _cntD1= CopyBuffer(hEMA200_D1,       0, 0, 210,                  _warmup);
      int _cntH4= CopyBuffer(hEMA200_H4_brain, 0, 0, TrendFilterPeriod+10, _warmup);
      PrintFormat("v5.93 warmup (live): TREND=%d D1=%d H4brain=%d (handle=%d)",
                  _cnt, _cntD1, _cntH4, hEMA200_TREND);
     }
   else
     {
      // v5.96 : warmup tester en 2 etapes.
      //   1. iTime() force la synchronisation des series TF (D1/H4/H1).
      //   2. CopyBuffer(count=1) DECLENCHE le calcul lazy des indicateurs.
      //      Sans cet appel, BarsCalculated reste -1 et tous les CopyBuffer
      //      suivants echouent (catch-22 du v5.95). count=1 evite err 4807.
      iTime(Symbol(), PERIOD_D1, 0);
      iTime(Symbol(), PERIOD_H4, 0);
      iTime(Symbol(), PERIOD_H1, 0);
      iTime(Symbol(), PERIOD_M15, 0);

      double _trigger[];
      CopyBuffer(hEMA200_D1,    0, 0, 1, _trigger);
      CopyBuffer(hEMA200_TREND, 0, 0, 1, _trigger);
      CopyBuffer(hRSI,          0, 0, 1, _trigger);
      CopyBuffer(hStoch,        0, 0, 1, _trigger);
      CopyBuffer(hStoch,        1, 0, 1, _trigger);
      CopyBuffer(hADX,          0, 0, 1, _trigger);
      CopyBuffer(hADX,          1, 0, 1, _trigger);
      CopyBuffer(hADX,          2, 0, 1, _trigger);
      CopyBuffer(hATR,          0, 0, 1, _trigger);
      CopyBuffer(hBollinger,    0, 0, 1, _trigger);
      CopyBuffer(hBollinger,    1, 0, 1, _trigger);
      CopyBuffer(hBollinger,    2, 0, 1, _trigger);

      PrintFormat("v5.96 tester warmup — TFs: D1_bars=%d H4_bars=%d H1_bars=%d | calc: EMA_D1=%d EMA_TREND=%d RSI=%d ATR=%d",
                  Bars(Symbol(), PERIOD_D1),
                  Bars(Symbol(), PERIOD_H4),
                  Bars(Symbol(), PERIOD_H1),
                  BarsCalculated(hEMA200_D1),
                  BarsCalculated(hEMA200_TREND),
                  BarsCalculated(hRSI),
                  BarsCalculated(hATR));
     }

   Print("v5.7 : Filtre directionnel = EMA", TrendFilterPeriod,
         " sur ", EnumToString(TrendFilterTF));
   return true;
  }

// v5.94 helper : CopyBuffer robuste en tester.
// Essaie shift=0, sinon shift=1 (la barre courante peut etre indisponible si
// l'indicateur n'a pas encore calcule la derniere bougie). Retourne le nombre
// de barres copiees (0 ou < count signifie echec).
int _SafeCopyBuffer(int handle, int buffer, int count, double &dst[])
  {
   int n = CopyBuffer(handle, buffer, 0, count, dst);
   if(n < count) n = CopyBuffer(handle, buffer, 1, count, dst);
   return n;
  }

// v5.95 : verifie qu'un handle indicateur est pret (calcule par MT5).
// BarsCalculated retourne -1 si l'indicateur n'est pas pret, sinon le nombre
// de barres calculees. < min_bars = indicateur en cours de chargement -> skip.
bool _IsHandleReady(int handle, int min_bars = 3)
  {
   if(handle == INVALID_HANDLE) return false;
   int calc = BarsCalculated(handle);
   return calc >= min_bars;
  }

bool LireIndicateurs()
  {
   // === v5.96 FIX : on supprime le BarsCalculated guard qui creait un catch-22.
   // CopyBuffer est l'evenement qui DECLENCHE le calcul lazy de l'indicateur.
   // Si on skip avant CopyBuffer, l'indicateur ne demarre jamais.
   // L'init InitIndicateurs() fait deja un CopyBuffer(count=1) pour amorcer.
   // Ici on appelle directement _SafeCopyBuffer (shift 0/1 fallback).

   // STEP 1 : force load des series multi-TF a chaque tick (no-op si OK)
   iTime(Symbol(), PERIOD_D1, 0);
   iTime(Symbol(), PERIOD_H4, 0);
   iTime(Symbol(), PERIOD_H1, 0);

   // STEP 2 : copie effective avec fallback shift=1
   bool ok=true;
   int r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11;
   r0 = _SafeCopyBuffer(hEMA200_D1,    0, 3, ema200D1);    if(r0<3)ok=false;
   r1 = _SafeCopyBuffer(hEMA200_TREND, 0, 3, ema200Trend); if(r1<3)ok=false;
   r2 = _SafeCopyBuffer(hRSI,          0, 3, rsiVal);      if(r2<3)ok=false;
   r3 = _SafeCopyBuffer(hStoch,        0, 3, stochMain);   if(r3<3)ok=false;
   r4 = _SafeCopyBuffer(hStoch,        1, 3, stochSignal); if(r4<3)ok=false;
   r5 = _SafeCopyBuffer(hADX,          0, 3, adxMain);     if(r5<3)ok=false;
   r6 = _SafeCopyBuffer(hADX,          1, 3, adxPlus);     if(r6<3)ok=false;
   r7 = _SafeCopyBuffer(hADX,          2, 3, adxMinus);    if(r7<3)ok=false;
   r8 = _SafeCopyBuffer(hATR,          0, 3, atrVal);      if(r8<3)ok=false;
   r9 = _SafeCopyBuffer(hBollinger,    0, 3, bbUpper);     if(r9<3)ok=false;
   r10= _SafeCopyBuffer(hBollinger,    1, 3, bbMiddle);    if(r10<3)ok=false;
   r11= _SafeCopyBuffer(hBollinger,    2, 3, bbLower);     if(r11<3)ok=false;

   // LOG diagnostic uniquement si echec persiste apres warmup (>500 barres)
   if(!ok) {
      static int _failCount = 0; _failCount++;
      // Skip les 500 premieres failures (warmup naturel des indicateurs)
      if(_failCount > 500) {
         static datetime _dbgLireBar2 = 0;
         datetime _cb = iTime(Symbol(), PERIOD_M15, 0);
         if(_cb != _dbgLireBar2) {
            _dbgLireBar2 = _cb;
            PrintFormat("LIRE_FAIL_PERSIST %s D1=%d TREND=%d RSI=%d StM=%d StS=%d ADXm=%d ADX+=%d ADX-=%d ATR=%d bbU=%d bbM=%d bbL=%d",
               TimeToString(_cb,TIME_DATE|TIME_MINUTES),
               r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11);
         }
      }
   }
   return ok;
  }

//+------------------------------------------------------------------+
//|    DASHBOARD                                                     |
//+------------------------------------------------------------------+
void AfficherDashboard()
  {
   if(!ShowDashboard) return;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double eq =AccountInfoDouble(ACCOUNT_EQUITY);
   double dd =startOfDayBalance>0?(startOfDayBalance-bal)/startOfDayBalance*100:0;
   double wr =(totalWins+totalLosses)>0?
              (double)totalWins/(totalWins+totalLosses)*100:0;
   int idx=GetPaireIndex();

   CreerLabel("FOT_h1","LE CERVEAU ADAPTATIF DE FOTSO v5.6+D1",          10,18,0xFFD700,12,true);
   CreerLabel("FOT_h2","Filtre Contextuel + DualGuard | "+Symbol(),       10,36,0x8B949E, 8,false);
   CreerLabel("FOT_s0","-----------------------------------",             10,50,0x30363D, 8,false);
   CreerLabel("FOT_b1","Balance  : $"+DoubleToString(bal,2),              10,64,0xFFFFFF, 9,false);
   CreerLabel("FOT_e1","Equity   : $"+DoubleToString(eq,2),               10,80,0xFFFFFF, 9,false);
   CreerLabel("FOT_p1","PnL Jour : "+(dailyPnL>=0?"+":"")+"$"+DoubleToString(dailyPnL,2),
                                                                         10,96,dailyPnL>=0?0x56D364:0xF85149,9,false);
   CreerLabel("FOT_dd","Drawdown : -"+DoubleToString(dd,1)+"%",          10,112,dd>DailyStopLoss*0.7?0xE3B341:0xFFFFFF,9,false);
   CreerLabel("FOT_s1","-----------------------------------",             10,126,0x30363D, 8,false);
   CreerLabel("FOT_wr","WinRate  : "+DoubleToString(wr,1)+"% W:"+IntegerToString(totalWins)+" L:"+IntegerToString(totalLosses),
                                                                         10,140,wr>=55?0x56D364:0xE3B341,9,false);
   CreerLabel("FOT_cr","WR Paire : "+DoubleToString(cerveau[idx].winRate,1)+"% ("+IntegerToString(cerveau[idx].totalTrades)+" trades)",
                                                                         10,156,0x79C0FF,9,false);
   CreerLabel("FOT_rk","Risk Dyn : "+DoubleToString(cerveau[idx].riskDynamique,2)+"%",
                                                                         10,172,0x79C0FF,9,false);
   CreerLabel("FOT_sl","SL Core  : x"+DoubleToString(cerveau[idx].slMultiDynamique,2)+" | Losses: "+IntegerToString(cerveau[idx].lossesConsecutifs),
                                                                         10,188,cerveau[idx].lossesConsecutifs>=3?0xF85149:0xFFFFFF, 9,false);
   // ── v5.6 : Affichage du ContextScore (data-driven) ──
   if(ShowContextScore)
     {
      double csDash = ContextScore();
      string csTxt;
      color csCol;
      if(csDash >= 1.10)        { csTxt = "★★ TOP";    csCol = 0x56D364; }
      else if(csDash >= 1.00)   { csTxt = "★ Bon";     csCol = 0x79C0FF; }
      else if(csDash >= 0.95)   { csTxt = "Neutre";    csCol = 0xFFFFFF; }
      else if(csDash >= CS_SkipThreshold) { csTxt = "↓ Faible"; csCol = 0xE3B341; }
      else                      { csTxt = "⚠ SKIP";   csCol = 0xF85149; }
      CreerLabel("FOT_cs","Context  : "+DoubleToString(csDash,3)+" — "+csTxt,
                 10,200,csCol,9,false);
     }
   // ── v5.6+D1 : Affichage état DualGuard ──
   if(UseDualGuard)
     {
      string dgTxt;
      color dgCol;
      if(DG_IsBuySuspended())
        {
         long secLeft = (long)dgBuySuspendUntil - (long)TimeCurrent();
         long hLeft = secLeft / 3600;
         dgTxt = "⛔ BUY suspendu " + IntegerToString((int)hLeft) + "h — " + dgSuspendReason;
         dgCol = 0xF85149;
        }
      else
        {
         int sl12 = DG_CountBuySLInWindow(DG_Casc1_WindowH);
         int sl48 = DG_CountBuySLInWindow(DG_Casc2_WindowH);
         dgTxt = "✓ Actif | SL 12h:" + IntegerToString(sl12) +
                 " 48h:" + IntegerToString(sl48);
         dgCol = (sl12 >= DG_Casc1_NbSL-1 || sl48 >= DG_Casc2_NbSL-1) ?
                  0xE3B341 : 0x79C0FF;
        }
      CreerLabel("FOT_dg","DualGrd  : " + dgTxt, 10,216,dgCol,9,false);
     }
   CreerLabel("FOT_s2","-----------------------------------",             10,232,0x30363D, 8,false);
   CreerLabel("FOT_sg","Signal   : "+lastSignal,                         10,246,StringFind(lastSignal,"BUY")>=0?0x56D364:StringFind(lastSignal,"SELL")>=0?0xF85149:0x8B949E,9,false);
   CreerLabel("FOT_et","Cerveau  : "+etatCerveau,                        10,262,0xE3B341, 8,false);
   CreerLabel("FOT_se","Session  : "+(EstDansSessionOptimale()?"Optimale":"Inactive"),
                                                                         10,278,0xFFFFFF, 9,false);
   CreerLabel("FOT_ro","Robot    : "+(robotActif?"ACTIF v5.6+D1":"ARRÊTÉ"), 10,294,robotActif?0x56D364:0xF85149,9,false);
   if(ArraySize(adxMain)>0)
      CreerLabel("FOT_ax","ADX      : "+DoubleToString(adxMain[0],1)+(adxMain[0]<22?" [RANGE!]":""),
                 10,310,adxMain[0]>=22?0x56D364:0xF85149,9,false);
   if(ArraySize(rsiVal)>0)
      CreerLabel("FOT_rs","RSI      : "+DoubleToString(rsiVal[0],1),     10,326,rsiVal[0]>=70?0xF85149:rsiVal[0]<=30?0x56D364:0xFFFFFF,9,false);
   ChartRedraw(0);
  }

void CreerLabel(string name,string text,int x,int y,color clr,int fs,bool bold)
  {
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
     }
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fs);
   ObjectSetString(0,name,OBJPROP_FONT,bold?"Arial Bold":"Arial");
  }

void NettoyerDashboard()
  {
   string lb[]={"FOT_h1","FOT_h2","FOT_s0","FOT_b1","FOT_e1","FOT_p1",
                "FOT_dd","FOT_s1","FOT_wr","FOT_cr","FOT_rk","FOT_s2",
                "FOT_sl","FOT_cs","FOT_dg","FOT_sg","FOT_et","FOT_se","FOT_ro","FOT_ax","FOT_rs"};
   for(int i=0;i<ArraySize(lb);i++) ObjectDelete(0,lb[i]);
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
//|   "Notre empreinte indélébile sur les marchés financiers"       |
//|    Augustin Fotso & Claude — Mai 2026 — v5.6+D1                |
//+------------------------------------------------------------------+

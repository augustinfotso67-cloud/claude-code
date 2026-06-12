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
//|   Version : 5.91 — Pullback H1 BUY+SELL — 3 situations       |
//|                                                                  |
//|   BASE : v5.3 (meilleure version : 54% WR / 153 trades / +57%)|
//|   RÉGRESSIONS v5.4 IDENTIFIÉES ET CORRIGÉES :                  |
//|   ✗ Position unique TP2 : pertes doublées (-60$ vs -15$)        |
//|   ✗ Stop 2 losses/jour : trop agressif, coupe le volume         |
//|   ✗ WR<58% anticyclique : risk réduit trop tôt, rate la hausse |
//|   ✗ ADX<22 sur 4 barres : filtre range trop restrictif          |
//|                                                                  |
//|   CORRECTIONS v5.5 (sur base v5.3, chirurgicales) :             |
//|   1) PULLBACK CT TP : RR1.5-2.0 (au lieu de 1.0-1.3)           |
//|      → meilleure compensation sans changer le split TP1/TP2     |
//|   2) Filtre range H4 : ADX<20 sur 3 barres (au lieu de 18)     |
//|      → détecte mieux les consolidations sans sur-filtrer        |
//|   3) Stop journalier : 3 losses total/jour (pas consécutifs)    |
//|      → protection douce sans couper les récupérations           |
//|   4) Apprentissage : seuil baisse à WR<52% (au lieu de 45%)    |
//|      → réagit plus tôt sans sur-réduire le risk                 |
//+------------------------------------------------------------------+
#property copyright "Augustin Fotso & Claude — Le Cerveau Adaptatif"
#property version   "5.91"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;

//+------------------------------------------------------------------+
//|                   PARAMÈTRES                                     |
//+------------------------------------------------------------------+
input double RiskPercent        = 2.0;
input double DailyStopLoss      = 20.0;
input double TP1_RR             = 1.5;
input double TP2_RR             = 2.5;
input double ATR_Multiplier     = 2.0;    // v5.1 : réduit de 2.5 → 2.0 (SL moins large)
input int    MaxTradesJour      = 2;      // v5.3 : 2 trades/jour — volume x2 pour atteindre 200 trades/an
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
input string LogFile            = "Fotso_Cerveau_log_v55.csv";
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
double adxMain[], adxPlus[], adxMinus[], atrVal[];
double bbUpper[], bbMiddle[], bbLower[];

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
   EventSetTimer(3600);

   int idx = GetPaireIndex();
   Print("╔══════════════════════════════════════════════════╗");
   Print("║     LE CERVEAU ADAPTATIF DE FOTSO v5.5          ║");
   Print("║     Augustin Fotso & Claude — Avril 2026        ║");
   Print("╠══════════════════════════════════════════════════╣");
   Print("║ Paire      : ", Symbol());
   Print("║ WR mémorisé: ", DoubleToString(cerveau[idx].winRate, 1), "%");
   Print("║ Trades hist: ", cerveau[idx].totalTrades);
   Print("║ Risk dynami: ", DoubleToString(cerveau[idx].riskDynamique, 2), "%");
   Print("║ Score mini : ", cerveau[idx].scoreMiniDynamique, "/6");
   Print("╠══════════════════════════════════════════════════╣");
   Print("║ BASE v5.3 + CORRECTIONS CHIRURGICALES v5.5 :   ║");
   Print("║ - PULLBACK CT TP : RR1.5-2.0 (was 1.0-1.3)    ║");
   Print("║ - Filtre range : ADX H4 < 20 / 3 barres        ║");
   Print("║ - Stop jour : 3 losses total (pas consécutifs) ║");
   Print("║ - Apprentissage : baisse si WR < 52%           ║");
   Print("╚══════════════════════════════════════════════════╝");

   etatCerveau = "Actif v5.5 — Base v5.3 + corrections ciblées";
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   SauvegarderMemoireCerveau();
   EventKillTimer();
   NettoyerDashboard();
   IndicatorRelease(hEMA200_D1); IndicatorRelease(hRSI);
   IndicatorRelease(hStoch);     IndicatorRelease(hADX);
   IndicatorRelease(hATR);       IndicatorRelease(hBollinger);
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

   // ── v5.1 : FILTRE RANGE GLOBAL — Suspendre si ADX faible sur H4 ──
   if(EstMarcheEnRange()) {
      etatCerveau = "RANGE détecté — Trading suspendu (ADX < 18 H4)";
      return;
   }

   datetime bar = iTime(Symbol(), PERIOD_M15, 0);
   if(bar == lastBarTime) return;
   lastBarTime   = bar;
   tradesCeBarre = 0;

   if(!LireIndicateurs()) return;
   if(tradesCeBarre >= 1) return;

   EmpreintePsy     psy  = AnalyserEmpreintePsy();
   ADNMouvement     adn  = AnalyserADNMouvement();
   MiroirInstitutionnel mi = AnalyserMiroirInstitutionnel();

   int signalBuy  = EvaluerCerveau(true,  psy, adn, mi);
   int signalSell = EvaluerCerveau(false, psy, adn, mi);

   double _px5   = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   bool   _d1Bull = (ArraySize(ema200D1)>0 && _px5 > ema200D1[0] * 1.003);
   bool   _d1Bear = (ArraySize(ema200D1)>0 && _px5 < ema200D1[0] * 0.997);

   if(signalBuy > 0 && signalBuy >= signalSell)
     {
      lastSignal = "BUY TENDANCE [Cerveau v5]";
      OuvrirTrade(true, adn, mi, psy, false);
      return;
     }
   if(signalSell > 0 && !_d1Bull)
     {
      lastSignal = "SELL TENDANCE [Cerveau v5]";
      OuvrirTrade(false, adn, mi, psy, false);
      return;
     }

   bool pbSell = (!_d1Bull) && EstPullbackContreTendance(false, psy, mi);
   bool pbBuy  = (!_d1Bear) && EstPullbackContreTendance(true,  psy, mi);

   if(pbSell)
     {
      lastSignal = "SELL PULLBACK contre-H4 [Cerveau v5]";
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
      if(adxH4[1] < 20.0 && adxH4[2] < 20.0 && adxH4[3] < 20.0)
         enRange = true;
     }
   IndicatorRelease(hADX_H4);
   return enRange;
  }

//+------------------------------------------------------------------+
//|    CLAUDE-CORE — GESTION MÉMOIRE                                |
//+------------------------------------------------------------------+
void ChargerMemoireCerveau()
  {
   int h = FileOpen(ClaudeCoreFile, FILE_READ|FILE_BIN);
   if(h != INVALID_HANDLE)
     {
      FileReadArray(h, cerveau);
      FileClose(h);
      Print("Claude-Core : Mémoire chargée (", cerveau[GetPaireIndex()].totalTrades, " trades historiques)");
     }
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
         cerveau[i].scoreMiniDynamique = 3;
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
     { FileWriteArray(h, cerveau); FileClose(h);
       Print("Claude-Core : Mémoire sauvegardée"); }
  }

void MettreAJourCerveau(bool isWin, double profit)
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

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
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
      // v5.5 : seuil de baisse relevé à 52% (au lieu de 45%)
      // → réagit plus tôt aux séries de losses sans sur-réduire
      // v5.4 à 58% était trop agressif : réduisait en pleine tendance haussière
      if(cerveau[idx].winRate < 52.0)
        {
         cerveau[idx].riskDynamique     = MathMax(0.2, cerveau[idx].riskDynamique * 0.9);
         cerveau[idx].scoreMiniDynamique = MathMin(5,   cerveau[idx].scoreMiniDynamique + 1);
         etatCerveau = "Apprentissage : Reduction risque (WR bas)";
        }
      else if(cerveau[idx].winRate > 60.0)
        {
         cerveau[idx].riskDynamique     = MathMin(1.5, cerveau[idx].riskDynamique * 1.1);
         cerveau[idx].scoreMiniDynamique = MathMax(3,   cerveau[idx].scoreMiniDynamique - 1);
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

   // v5.5+ : Filtre heure défavorable mémorisée DÉSACTIVÉ sur XAU/GOLD
   // → Supprimé car trop restrictif sur l'or : bloque des heures profitables
   //   mémorisées comme mauvaises à cause d'événements isolés (NFP, CPI, etc.)
   //   Les sessions London/NY suffisent pour le filtrage temporel sur GOLD
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

//+------------------------------------------------------------------+
//|   ENTRÉE APRÈS PULLBACK H1 — "Ne jamais entrer en correction"   |
//+------------------------------------------------------------------+
// ════════════════════════════════════════════════════════════
//   GESTION PULLBACK H1 — 3 SITUATIONS
//   1. Tendance pure      : H1 aligne tendance → entrer directement
//   2. Correction courte  : H1 contre tendance (1-2 bougies) → attendre
//   3. Pullback setup     : H1 a fait une correction + retournement → IDEAL
// ════════════════════════════════════════════════════════════

// Detecte si le H1 est en pleine correction (ne pas entrer maintenant)
bool H1EnCorrection(bool pourBuy)
  {
   if(ArraySize(atrVal)==0) return false;
   double atr=atrVal[0];

   // Pour BUY : chercher des bougies H1 baissières consecutives
   // Pour SELL : chercher des bougies H1 haussieres consecutives
   int bougiesContre=0;
   for(int i=1;i<=3;i++)
     {
      double o=iOpen(Symbol(),PERIOD_H1,i);
      double c=iClose(Symbol(),PERIOD_H1,i);
      double corps=MathAbs(c-o);
      if(corps<atr*0.15) break; // Bougie trop petite = pas significative

      bool contreDir=pourBuy?(c<o):(c>o);
      if(contreDir) bougiesContre++;
      else break; // Des que ca s arrete, plus de correction
     }

   // 2+ bougies contre la tendance = correction active
   if(bougiesContre>=2)
     {
      etatCerveau="H1"+" en correction "+(pourBuy?"baissiere":"haussiere")+" — Attente fin";
      return true;
     }
   return false;
  }

// Confirme que le pullback est TERMINE et que c est le bon moment d entrer
// Gere a la fois :
// - Fin d une simple correction (1-2 bougies)
// - Fin d un vrai pullback (plus grand, plus net)
// Dans les deux cas : chercher un signal de retournement H1
bool H1PullbackConfirme(bool pourBuy)
  {
   if(ArraySize(atrVal)==0) return true;
   double atr=atrVal[0];

   double c0=iClose(Symbol(),PERIOD_H1,1), o0=iOpen(Symbol(),PERIOD_H1,1);
   double h0=iHigh(Symbol(),PERIOD_H1,1),  l0=iLow(Symbol(),PERIOD_H1,1);
   double c1=iClose(Symbol(),PERIOD_H1,2), o1=iOpen(Symbol(),PERIOD_H1,2);
   double c2=iClose(Symbol(),PERIOD_H1,3), o2=iOpen(Symbol(),PERIOD_H1,3);

   // Verifier qu il y a EU une correction avant (sinon pas de pullback)
   bool correctionEue=false;
   for(int i=2;i<=5;i++)
     {
      double o=iOpen(Symbol(),PERIOD_H1,i);
      double c=iClose(Symbol(),PERIOD_H1,i);
      if(pourBuy&&c<o&&(o-c)>atr*0.15){correctionEue=true;break;}
      if(!pourBuy&&c>o&&(c-o)>atr*0.15){correctionEue=true;break;}
     }

   if(pourBuy)
     {
      // Signal 1 : Bougie H1 haussiere de bonne taille
      bool bougieH=(c0>o0)&&((c0-o0)>=atr*0.2);

      // Signal 2 : Pin Bar bas = rejet de zone basse (support)
      double mecheBase=MathMin(c0,o0)-l0;
      bool pinBar=(mecheBase>MathAbs(c0-o0)*1.5)&&(mecheBase>atr*0.2);

      // Signal 3 : Engulfing haussier = avale la bougie baissiere precedente
      bool engulf=(c0>o0)&&(c1<o1)&&(c0>o1)&&(o0<=c1);

      // Signal 4 : Deux bougies haussieres consecutives apres correction
      bool deuxHaussiers=(c0>o0)&&(c1>o1)&&correctionEue;

      if(bougieH||pinBar||engulf||deuxHaussiers)
        {
         string signal=bougieH?"Bougie H":pinBar?"Pin Bar":engulf?"Engulfing":"2 bougies";
         etatCerveau="Pullback "+"H1"+" BUY confirme ["+signal+"] — Entree";
         return true;
        }
      etatCerveau="Attente retournement H1 BUY apres pullback...";
      return false;
     }
   else
     {
      // Meme logique pour SELL
      bool bougieB=(c0<o0)&&((o0-c0)>=atr*0.2);
      double mecheHaute=h0-MathMax(c0,o0);
      bool pinBar=(mecheHaute>MathAbs(c0-o0)*1.5)&&(mecheHaute>atr*0.2);
      bool engulf=(c0<o0)&&(c1>o1)&&(c0<o1)&&(o0>=c1);
      bool deuxBaissiers=(c0<o0)&&(c1<o1)&&correctionEue;

      if(bougieB||pinBar||engulf||deuxBaissiers)
        {
         string signal=bougieB?"Bougie B":pinBar?"Pin Bar":engulf?"Engulfing":"2 bougies";
         etatCerveau="Pullback "+"H1"+" SELL confirme ["+signal+"] — Entree";
         return true;
        }
      etatCerveau="Attente retournement H1 SELL apres pullback...";
      return false;
     }
  }



int EvaluerCerveau(bool pourBuy,
                   EmpreintePsy &psy,
                   ADNMouvement &adn,
                   MiroirInstitutionnel &mi)
  {
   double prix  = SymbolInfoDouble(Symbol(), pourBuy ? SYMBOL_BID : SYMBOL_ASK);
   bool   d1Bull= (ArraySize(ema200D1)>0 && prix > ema200D1[0]);
   bool   d1Bear= (ArraySize(ema200D1)>0 && prix < ema200D1[0]);
   // v5.1 : D1 FORT = prix > EMA200 D1 de plus de 1.5% (pas juste au-dessus)
   bool   d1BullFort = (ArraySize(ema200D1)>0 && prix > ema200D1[0] * 1.015);
   bool   d1BearFort = (ArraySize(ema200D1)>0 && prix < ema200D1[0] * 0.985);
   // v5.3 : SELL bloqué si D1 > EMA200 * 1.005 — filtre renforcé
   // v5.2 bloquait seulement >+2% mais les SELL en tendance haussière même faible perdent
   bool   d1UltraHaussier = (ArraySize(ema200D1)>0 && prix > ema200D1[0] * 1.005);
   if(!pourBuy && d1UltraHaussier)
     {
      etatCerveau = "SELL BLOQUÉ v5.3 — D1 haussier >+0.5% EMA200 (filtre renforcé)";
      return 0;
     }

   bool   isBTC = (StringFind(Symbol(),"BTC")>=0);
   bool   isXAU = (StringFind(Symbol(),"XAU")>=0||StringFind(Symbol(),"GOLD")>=0);
   int    idx   = GetPaireIndex();

   double emaH4_0=0, emaH4_5=0, emaH4_10=0;
   int hH4tmp=iMA(Symbol(),PERIOD_H4,200,0,MODE_EMA,PRICE_CLOSE);
   if(hH4tmp!=INVALID_HANDLE)
     {
      double bH4[]; ArraySetAsSeries(bH4,true);
      if(CopyBuffer(hH4tmp,0,0,15,bH4)>=11)
        { emaH4_0=bH4[0]; emaH4_5=bH4[5]; emaH4_10=bH4[10]; }
      IndicatorRelease(hH4tmp);
     }
   bool h4H = (emaH4_0 > emaH4_5 && emaH4_0 > 0);
   bool h4B = (emaH4_0 < emaH4_5 && emaH4_0 > 0);
   bool h4H_fort = (h4H && emaH4_5 > emaH4_10);
   bool h4B_fort = (h4B && emaH4_5 < emaH4_10);

   bool dirBuy  = h4H;
   bool dirSell = h4B;
   if(pourBuy  && !dirBuy)  return 0;
   if(!pourBuy && !dirSell) return 0;
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

   // ── GESTION PULLBACK H1 — BUY ET SELL ─────────────────────
   // Si correction active : ne pas entrer (attendre la fin)
   // Si pas encore de signal de retournement : attendre
   // Si pullback confirme : entrer avec precision
   if(H1EnCorrection(pourBuy)) return 0;
   if(!H1PullbackConfirme(pourBuy)) return 0;

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
   bool seuilBonus = (bonusScore >= 3); // v5.3 : bonus minimum 3/7 (v5.2=4 trop restrictif)
   bool seuilTotal = (scoreTotal >= scoreMin);

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

   MettreAJourCerveau(profit > 0, profit);

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

   // v5.1 : log complet avec raisons TP et SL
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
      "Lots=" + DoubleToString(lots, 2));
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
      "",
      "",
      "");
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
      double spread=SymbolInfoDouble(Symbol(),SYMBOL_ASK)-SymbolInfoDouble(Symbol(),SYMBOL_BID);
      double beBuffer=MathMax(spread*1.5,pt*3);
      if(posInfo.PositionType()==POSITION_TYPE_BUY)
        {
         if(SymbolInfoDouble(Symbol(),SYMBOL_BID)>=en+atr*BE_ATR_Multi&&sl<en)
           { double nsl=NormalizeDouble(en+beBuffer,dg);
             if(trade.PositionModify(tk,nsl,posInfo.TakeProfit()))
               { Print("BE BUY ",tk," SL->",DoubleToString(nsl,dg));
                 if(NotifBE) NotifierBreakEven("BUY", nsl, tk); } }
        }
      else if(posInfo.PositionType()==POSITION_TYPE_SELL)
        {
         if(SymbolInfoDouble(Symbol(),SYMBOL_ASK)<=en-atr*BE_ATR_Multi&&(sl>en||sl==0))
           { double nsl=NormalizeDouble(en-beBuffer,dg);
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

double GetMaxSpread()
  {
   string sym=Symbol();
   if(StringFind(sym,"BTC")>=0) return 3000.0;
   if(StringFind(sym,"XAU")>=0||StringFind(sym,"GOLD")>=0) return 500.0;
   if(StringFind(sym,"EUR")>=0) return 50.0;
   if(StringFind(sym,"GBP")>=0) return 50.0;
   if(StringFind(sym,"NAS")>=0) return 150.0;
   if(StringFind(sym,"US30")>=0) return 200.0;
   return 250.0;
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
   FileWrite(h,"Date","Heure","Signal","ADN_Miroir_Psy","Type","Paire",
               "Direction","Entry","Profit","Balance","WinRate",
               "RaisonSL","RaisonTP","NiveauSL","NiveauTP","Lots");
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
   hRSI      =iRSI(Symbol(),PERIOD_H1,14,PRICE_CLOSE);
   hStoch    =iStochastic(Symbol(),PERIOD_M15,5,3,3,MODE_SMA,STO_LOWHIGH);
   hADX      =iADX(Symbol(),PERIOD_H1,14);
   hATR      =iATR(Symbol(),PERIOD_H1,14);
   hBollinger=iBands(Symbol(),PERIOD_H1,20,0,2.0,PRICE_CLOSE);

   if(hEMA200_D1==INVALID_HANDLE||hRSI==INVALID_HANDLE||
      hStoch==INVALID_HANDLE||hADX==INVALID_HANDLE||
      hATR==INVALID_HANDLE||hBollinger==INVALID_HANDLE)
     { Alert("Erreur indicateurs — vérifier historique !"); return false; }

   ArraySetAsSeries(ema200D1,true); ArraySetAsSeries(rsiVal,true);
   ArraySetAsSeries(stochMain,true); ArraySetAsSeries(stochSignal,true);
   ArraySetAsSeries(adxMain,true); ArraySetAsSeries(adxPlus,true);
   ArraySetAsSeries(adxMinus,true); ArraySetAsSeries(atrVal,true);
   ArraySetAsSeries(bbUpper,true); ArraySetAsSeries(bbMiddle,true);
   ArraySetAsSeries(bbLower,true);
   return true;
  }

bool LireIndicateurs()
  {
   bool ok=true;
   if(CopyBuffer(hEMA200_D1,0,0,3,ema200D1)  <3)ok=false;
   if(CopyBuffer(hRSI,      0,0,3,rsiVal)    <3)ok=false;
   if(CopyBuffer(hStoch,    0,0,3,stochMain) <3)ok=false;
   if(CopyBuffer(hStoch,    1,0,3,stochSignal)<3)ok=false;
   if(CopyBuffer(hADX,      0,0,3,adxMain)   <3)ok=false;
   if(CopyBuffer(hADX,      1,0,3,adxPlus)   <3)ok=false;
   if(CopyBuffer(hADX,      2,0,3,adxMinus)  <3)ok=false;
   if(CopyBuffer(hATR,      0,0,3,atrVal)    <3)ok=false;
   if(CopyBuffer(hBollinger,0,0,3,bbUpper)   <3)ok=false;
   if(CopyBuffer(hBollinger,1,0,3,bbMiddle)  <3)ok=false;
   if(CopyBuffer(hBollinger,2,0,3,bbLower)   <3)ok=false;
   return ok;
  }

//+------------------------------------------------------------------+
//|    DASHBOARD                                                     |
//+------------------------------------------------------------------+
void AfficherDashboard()
  {
   if(!ShowDashboard) return;
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd     = startOfDayBalance > 0 ? (startOfDayBalance - bal) / startOfDayBalance * 100.0 : 0;
   double wr     = (totalWins + totalLosses) > 0 ?
                   (double)totalWins / (totalWins + totalLosses) * 100.0 : 0;
   double pnlPct = startOfDayBalance > 0 ? dailyPnL / startOfDayBalance * 100.0 : 0;
   int    idx    = GetPaireIndex();
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   bool   enPos  = false;
   for(int i = 0; i < PositionsTotal(); i++)
      if(posInfo.SelectByIndex(i) && posInfo.Symbol() == Symbol())
        { enPos = true; break; }

   // ─── FOND PRINCIPAL ─────────────────────────────────────────────
   CreerRectangle("FOT_BG_MAIN",  8,   8, 310, 370, (color)0x0D0D1A, true);
   CreerRectangle("FOT_BG_BORD",  8,   8, 310, 370, (color)0x1A1A3A, false);

   // ─── BANDE TITRE ────────────────────────────────────────────────
   CreerRectangle("FOT_BG_TITLE", 8,   8, 310, 42, (color)0x1A1040, true);
   CreerLabel("FOT_h1", "CERVEAU FOTSO  v5.5",                           18, 14, (color)0xFFD700, 10, true);
   CreerLabel("FOT_h2", Symbol() + " | ADN+PSY+MirrorInst", 195, 16, (color)0x6666AA, 8, false);

   // ─── SECTION CAPITAL ────────────────────────────────────────────
   CreerRectangle("FOT_BG_CAP",  10, 52, 306, 108, (color)0x0A0A20, true);
   CreerLabel("FOT_lbl_bal", "BALANCE",  18, 56, (color)0x444466, 7, false);
   CreerLabel("FOT_lbl_eq",  "EQUITY",  120, 56, (color)0x444466, 7, false);
   CreerLabel("FOT_lbl_dd",  "DRAWDOWN",220, 56, (color)0x444466, 7, false);

   color clrBal = (color)(bal >= startOfDayBalance ? 0x00E57A : 0xFF4444);
   color clrDD  = (color)(dd > DailyStopLoss * 0.7 ? 0xFF4444 : dd > DailyStopLoss * 0.4 ? 0xFFAA00 : 0x00E57A);
   color clrEq  = (color)(eq >= bal ? 0x00E57A : 0xFF8800);

   CreerLabel("FOT_b1", "$" + DoubleToString(bal, 2),   18, 70, clrBal, 10, true);
   CreerLabel("FOT_e1", "$" + DoubleToString(eq,  2),  120, 70, clrEq,  10, true);
   CreerLabel("FOT_dd", DoubleToString(dd, 1) + "%",   220, 70, clrDD,  10, true);

   string pnlStr = (dailyPnL >= 0 ? "+" : "") + "$" + DoubleToString(dailyPnL, 2) +
                   "  (" + (pnlPct >= 0 ? "+" : "") + DoubleToString(pnlPct, 1) + "%)";
   color clrPnL = (color)(dailyPnL >= 0 ? 0x00E57A : 0xFF4444);
   CreerLabel("FOT_lbl_pnl", "PNL JOUR",  18,  88, (color)0x444466, 7, false);
   CreerLabel("FOT_p1", pnlStr,            18, 100, clrPnL, 9, true);

   // ─── LOSSES JOUR ────────────────────────────────────────────────
   color clrLJ = (color)(lossesAujourdhui >= 3 ? 0xFF4444 : lossesAujourdhui >= 2 ? 0xFFAA00 : 0x444466);
   CreerLabel("FOT_lbl_lj", "Losses/jour: " + IntegerToString(lossesAujourdhui) + "/3  |  Trades: " +
              IntegerToString(tradesToday) + "/" + IntegerToString(MaxTradesJour),
              18, 118, clrLJ, 7, false);

   // ─── SEPARATEUR ─────────────────────────────────────────────────
   CreerRectangle("FOT_SEP1", 10, 162, 306, 2, (color)0x1E1E3E, true);

   // ─── SECTION PERFORMANCE ────────────────────────────────────────
   CreerRectangle("FOT_BG_PERF", 10, 166, 306, 86, (color)0x0A0A20, true);
   CreerLabel("FOT_lbl_perf", "=== PERFORMANCE =====================", 18, 170, (color)0x2A2A5A, 8, false);

   color clrWR = (color)(wr >= 60 ? 0x00E57A : wr >= 50 ? 0xFFAA00 : 0xFF4444);
   string wrBar = "";
   int barFill = (int)(wr / 10.0);
   for(int b = 0; b < 10; b++) wrBar += (b < barFill ? "█" : "░");

   CreerLabel("FOT_wr",  "WR  " + DoubleToString(wr, 1) + "%  " + wrBar,
              18, 184, clrWR, 9, false);
   CreerLabel("FOT_wrl", "W:" + IntegerToString(totalWins) + "  L:" + IntegerToString(totalLosses),
              18, 200, (color)0x6666AA, 8, false);
   CreerLabel("FOT_cr",  "WR paire : " + DoubleToString(cerveau[idx].winRate, 1) +
              "% (" + IntegerToString(cerveau[idx].totalTrades) + " trades hist.)",
              18, 215, (color)0x7799CC, 8, false);
   CreerLabel("FOT_rk",  "Risk dyn : " + DoubleToString(cerveau[idx].riskDynamique, 2) +
              "%   SLx" + DoubleToString(cerveau[idx].slMultiDynamique, 2),
              18, 230, (color)0x7799CC, 8, false);

   // ─── SEPARATEUR ─────────────────────────────────────────────────
   CreerRectangle("FOT_SEP2", 10, 254, 306, 2, (color)0x1E1E3E, true);

   // ─── SECTION MARCHÉ ─────────────────────────────────────────────
   CreerRectangle("FOT_BG_MKT", 10, 258, 306, 72, (color)0x0A0A20, true);
   CreerLabel("FOT_lbl_mkt", "=== MARCHE ===========================", 18, 262, (color)0x2A2A5A, 8, false);

   double adxNow = ArraySize(adxMain) > 0 ? adxMain[0] : 0;
   double rsiNow = ArraySize(rsiVal)  > 0 ? rsiVal[0]  : 0;
   color clrADX  = (color)(adxNow >= 25 ? 0x00E57A : adxNow >= 22 ? 0xFFAA00 : 0xFF4444);
   color clrRSI  = (color)(rsiNow >= 70 ? 0xFF4444 : rsiNow <= 30 ? 0x00E57A : 0xCCCCCC);

   CreerLabel("FOT_ax", "ADX  " + DoubleToString(adxNow, 1) + (adxNow < 22 ? "  ⚠ RANGE" : "  ✓ TREND"),
              18, 278, clrADX, 9, false);
   CreerLabel("FOT_rs", "RSI  " + DoubleToString(rsiNow, 1) +
              (rsiNow >= 70 ? "  SURACH." : rsiNow <= 30 ? "  SURVND." : "  NEUTRE"),
              18, 294, clrRSI, 9, false);
   CreerLabel("FOT_sp", "Spread: " + DoubleToString(spread * 10000, 0) + " pts",
              180, 278, (color)(spread * 10000 > 150 ? 0xFF4444 : 0x6666AA), 8, false);
   CreerLabel("FOT_se", "Session: " + (EstDansSessionOptimale() ? "✓ Optimale" : "× Inactive"),
              180, 294, (color)(EstDansSessionOptimale() ? 0x00E57A : 0x666688), 8, false);

   // ─── SEPARATEUR ─────────────────────────────────────────────────
   CreerRectangle("FOT_SEP3", 10, 332, 306, 2, (color)0x1E1E3E, true);

   // ─── SECTION ÉTAT ROBOT ─────────────────────────────────────────
   CreerRectangle("FOT_BG_BOT", 10, 336, 306, 42, (color)0x0A0A20, true);

   color clrSig = (color)(StringFind(lastSignal,"BUY")  >= 0 ? 0x00E57A :
                  StringFind(lastSignal,"SELL") >= 0 ? 0xFF4444 : 0x555577);
   CreerLabel("FOT_sg", "► " + lastSignal, 18, 340, clrSig, 8, false);

   color clrLoss = (color)(cerveau[idx].lossesConsecutifs >= 3 ? 0xFF4444 :
                   cerveau[idx].lossesConsecutifs >= 2 ? 0xFFAA00 : 0x555577);
   CreerLabel("FOT_lc", "Losses consec: " + IntegerToString(cerveau[idx].lossesConsecutifs),
              18, 356, clrLoss, 8, false);

   string robotStr = robotActif ? (enPos ? "● EN POSITION" : "● EN ATTENTE") : "■ ARRETE";
   color  clrRob   = (color)(!robotActif ? 0xFF4444 : enPos ? 0xFFAA00 : 0x00E57A);
   CreerLabel("FOT_ro", robotStr, 180, 340, clrRob, 9, true);

   string etat = etatCerveau;
   if(StringLen(etat) > 38) etat = StringSubstr(etat, 0, 35) + "...";
   CreerLabel("FOT_et", etat, 180, 356, (color)0xE3B341, 7, false);

   ChartRedraw(0);
  }

void CreerRectangle(string name, int x, int y, int w, int h, color clr, bool filled)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE,     w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE,     h);
      ObjectSetInteger(0, name, OBJPROP_BACK,      false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
     }
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      filled ? clr : clrNONE);
   ObjectSetInteger(0, name, OBJPROP_COLOR,         clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,   BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,         1);
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
   string lb[]={
      "FOT_BG_MAIN","FOT_BG_BORD","FOT_BG_TITLE","FOT_BG_CAP",
      "FOT_BG_PERF","FOT_BG_MKT","FOT_BG_BOT",
      "FOT_SEP1","FOT_SEP2","FOT_SEP3",
      "FOT_h1","FOT_h2",
      "FOT_lbl_bal","FOT_lbl_eq","FOT_lbl_dd","FOT_lbl_pnl","FOT_lbl_lj",
      "FOT_b1","FOT_e1","FOT_dd","FOT_p1",
      "FOT_lbl_perf","FOT_wr","FOT_wrl","FOT_cr","FOT_rk",
      "FOT_lbl_mkt","FOT_ax","FOT_rs","FOT_sp","FOT_se",
      "FOT_sg","FOT_lc","FOT_ro","FOT_et"
   };
   for(int i = 0; i < ArraySize(lb); i++) ObjectDelete(0, lb[i]);
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
//|   "Notre empreinte indélébile sur les marchés financiers"       |
//|    Augustin Fotso & Claude — Avril 2026 — v5.5+                |
//|    Dashboard visuel | Filtre heure défav. OFF sur XAU          |
//+------------------------------------------------------------------+

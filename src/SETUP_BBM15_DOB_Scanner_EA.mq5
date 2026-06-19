//+------------------------------------------------------------------+
//| SETUP_BBM15 DOB Scanner EA                                       |
//| Scanner MT5 sans trading automatique base sur un indicateur DOB   |
//+------------------------------------------------------------------+
#property copyright "SETUP_BBM15"
#property version   "1.103"
#property strict

input string InpSymbols = "";                         // Actifs a scanner, separes par virgule. Vide = actif du graphique
input int    InpLookbackBars = 300;                   // Nombre de bougies M15 analysees
input bool   InpUseH1BearishTrendFilter = true;       // Filtrer uniquement si la tendance H1 est baissiere
input int    InpH1TrendLookbackBars = 20;             // Nombre de bougies H1 pour definir la tendance
input int    InpMaxOrderBlockCandles = 5;             // Nombre maximum de bougies haussieres dans l'OB bearish
input double InpMinSibiPoints = 0.0;                  // Taille minimale de la SIBI en points
input bool   InpScanBullishDob = false;               // Scanner DOB bullish: desactive pour cette version de test
input bool   InpScanBearishDob = true;                // Scanner DOB bearish: cassure dessus, retour sur le haut
input bool   InpBreakRequiresClose = true;            // Cassure validee par cloture hors zone OB
input bool   InpAlertOnCurrentCandle = true;          // Alerte intrabougie, sinon bougie cloturee
input bool   InpFirstPullbackOnly = true;             // Alerter uniquement le premier retour dans le BB
input bool   InpOneAlertPerBreaker = true;            // Une seule alerte par breaker block
input bool   InpPopupAlert = true;                    // Alerte popup MT5
input bool   InpSoundAlert = true;                    // Alerte sonore
input string InpAlertSound = "alert.wav";             // Fichier son MT5
input bool   InpDrawArrowOnChart = true;              // Dessiner une fleche sur le graphique actif
input bool   InpDrawDobZoneOnChart = true;            // Dessiner la zone DOB liee a chaque alerte
input bool   InpDrawHistoricalArrows = true;          // Afficher les anciennes fleches sur le graphique actif
input int    InpMaxHistoricalArrows = 50;             // Nombre maximum de fleches historiques
input color  InpArrowColor = clrRed;                  // Couleur de la fleche d'alerte
input color  InpBullishDobZoneColor = clrLimeGreen;   // Rectangle DOB bullish
input color  InpBearishDobZoneColor = clrRed;         // Rectangle DOB bearish
input int    InpDobZoneWidth = 2;                     // Epaisseur du rectangle DOB
input int    InpArrowCode = 233;                      // Code Wingdings de la fleche
input int    InpScanEverySeconds = 10;                // Frequence de scan

struct SetupSignal
{
   string   symbol;
   int      direction;
   datetime ob_time;
   double   ob_low;
   double   ob_high;
   datetime break_time;
   datetime alert_time;
   double   alert_price;
};

string g_alerted_keys[];

//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(MathMax(1, InpScanEverySeconds));
   Print("SETUP_BBM15 DOB Scanner EA demarre. Aucun trade automatique n'est execute.");
   DrawHistoricalArrows();
   ScanAllSymbols();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}

//+------------------------------------------------------------------+
void OnTick()
{
   ScanAllSymbols();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   ScanAllSymbols();
}

//+------------------------------------------------------------------+
void ScanAllSymbols()
{
   string symbols[];
   int total = BuildSymbolsList(symbols);

   for(int i = 0; i < total; i++)
   {
      SetupSignal signal;
      if(FindBullishBreakerPullback(symbols[i], signal))
      {
         string key = BuildAlertKey(signal);
         if(!WasAlerted(key))
         {
            RegisterAlert(key);
            DrawAlertArrow(signal, false);
            SendSetupAlert(signal);
         }
      }
   }
}

//+------------------------------------------------------------------+
int BuildSymbolsList(string &symbols[])
{
   ArrayResize(symbols, 0);

   string raw = InpSymbols;
   StringReplace(raw, " ", "");
   StringReplace(raw, "\t", "");

   if(raw == "")
   {
      ArrayResize(symbols, 1);
      symbols[0] = _Symbol;
      return(1);
   }

   string parts[];
   int count = StringSplit(raw, ',', parts);

   for(int i = 0; i < count; i++)
   {
      if(parts[i] == "")
         continue;

      int size = ArraySize(symbols);
      ArrayResize(symbols, size + 1);
      symbols[size] = parts[i];
   }

   return(ArraySize(symbols));
}

//+------------------------------------------------------------------+
bool FindBullishBreakerPullback(const string symbol, SetupSignal &signal)
{
   int alert_index = InpAlertOnCurrentCandle ? 0 : 1;
   return(FindBullishBreakerPullbackAt(symbol, alert_index, signal));
}

//+------------------------------------------------------------------+
bool FindBullishBreakerPullbackAt(const string symbol, const int alert_index, SetupSignal &signal)
{
   if(!SymbolSelect(symbol, true))
      return(false);

   if(!InpScanBearishDob)
      return(false);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_to_copy = MathMax(50, InpLookbackBars);
   int copied = CopyRates(symbol, PERIOD_M15, 0, bars_to_copy, rates);
   if(copied < 20 || alert_index >= copied)
      return(false);

   if(InpUseH1BearishTrendFilter && !IsH1BearishTrend(symbol, rates[alert_index].time))
      return(false);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00001;

   double min_gap = InpMinSibiPoints * point;
   bool has_selected = false;
   SetupSignal selected;

   for(int sibi_index = alert_index + 2; sibi_index < copied - 3; sibi_index++)
   {
      int first_candle = sibi_index + 2;
      int third_candle = sibi_index;

      if(!IsBearishSibi(rates, first_candle, third_candle, min_gap))
         continue;

      if(!IsBullish(rates[first_candle]))
         continue;

      double ob_low = 0.0;
      double ob_high = 0.0;
      int ob_oldest = first_candle;
      int ob_newest = first_candle;
      if(!BuildBearishObZone(rates, copied, first_candle, ob_low, ob_high, ob_oldest, ob_newest))
         continue;

      int break_index = FindBreakIndex(rates, sibi_index - 1, alert_index + 1, -1, ob_low, ob_high);
      if(break_index < 0)
         continue;

      if(alert_index >= break_index)
         continue;

      double alert_level = ob_high;
      if(!TouchesLevel(rates[alert_index], alert_level))
         continue;

      if(InpFirstPullbackOnly && HasEarlierLevelTouch(rates, break_index - 1, alert_index + 1, alert_level))
         continue;

      SetupSignal candidate;
      candidate.symbol = symbol;
      candidate.direction = -1;
      candidate.ob_time = rates[ob_newest].time;
      candidate.ob_low = ob_low;
      candidate.ob_high = ob_high;
      candidate.break_time = rates[break_index].time;
      candidate.alert_time = rates[alert_index].time;
      candidate.alert_price = alert_level;

      if(!has_selected)
      {
         selected = candidate;
         has_selected = true;
         continue;
      }

      if(ZonesOverlap(selected.ob_low, selected.ob_high, candidate.ob_low, candidate.ob_high))
      {
         if(ZoneHeight(candidate.ob_low, candidate.ob_high) > ZoneHeight(selected.ob_low, selected.ob_high))
            selected = candidate;
      }
   }

   if(!has_selected)
      return(false);

   signal = selected;
   return(true);
}

//+------------------------------------------------------------------+
bool IsH1BearishTrend(const string symbol, const datetime when)
{
   int lookback = MathMax(2, InpH1TrendLookbackBars);
   int shift = iBarShift(symbol, PERIOD_H1, when, false);
   if(shift < 0)
      return(false);

   int newest_closed = shift + 1;
   int oldest = newest_closed + lookback - 1;

   if(Bars(symbol, PERIOD_H1) <= oldest)
      return(false);

   double newest_close = iClose(symbol, PERIOD_H1, newest_closed);
   double oldest_close = iClose(symbol, PERIOD_H1, oldest);

   if(newest_close <= 0.0 || oldest_close <= 0.0)
      return(false);

   return(newest_close < oldest_close);
}

//+------------------------------------------------------------------+
bool IsBullish(const MqlRates &bar)
{
   return(bar.close > bar.open);
}

//+------------------------------------------------------------------+
bool IsBearishSibi(const MqlRates &rates[], const int first_candle, const int third_candle, const double min_gap)
{
   return(rates[first_candle].low > rates[third_candle].high + min_gap);
}

//+------------------------------------------------------------------+
bool BuildBearishObZone(const MqlRates &rates[],
                        const int copied,
                        const int first_candle,
                        double &ob_low,
                        double &ob_high,
                        int &ob_oldest,
                        int &ob_newest)
{
   ob_low = DBL_MAX;
   ob_high = -DBL_MAX;
   ob_oldest = first_candle;
   ob_newest = first_candle;

   int count = 0;
   for(int ob_index = first_candle; ob_index < copied && count < InpMaxOrderBlockCandles; ob_index++)
   {
      if(!IsBullish(rates[ob_index]))
         break;

      ob_low = MathMin(ob_low, rates[ob_index].low);
      ob_high = MathMax(ob_high, rates[ob_index].high);
      ob_oldest = ob_index;
      count++;
   }

   return(count > 0 && ob_low != DBL_MAX && ob_high != -DBL_MAX && ob_high > ob_low);
}

//+------------------------------------------------------------------+
bool ZonesOverlap(const double low_a, const double high_a, const double low_b, const double high_b)
{
   return(MathMax(low_a, low_b) <= MathMin(high_a, high_b));
}

//+------------------------------------------------------------------+
double ZoneHeight(const double low_price, const double high_price)
{
   return(MathAbs(high_price - low_price));
}

//+------------------------------------------------------------------+
int FindBreakIndex(const MqlRates &rates[],
                   const int from_index,
                   const int to_index,
                   const int direction,
                   const double ob_low,
                   const double ob_high)
{
   for(int i = from_index; i >= to_index; i--)
   {
      bool broken = false;

      if(direction > 0)
         broken = InpBreakRequiresClose ? (rates[i].close < ob_low) : (rates[i].low < ob_low);
      else if(direction < 0)
         broken = (rates[i].close > ob_high);

      if(broken)
         return(i);
   }

   return(-1);
}

//+------------------------------------------------------------------+
bool TouchesLevel(const MqlRates &bar, const double level)
{
   return(bar.high >= level && bar.low <= level);
}

//+------------------------------------------------------------------+
bool HasEarlierLevelTouch(const MqlRates &rates[], const int from_index, const int to_index, const double level)
{
   for(int i = from_index; i >= to_index; i--)
   {
      if(TouchesLevel(rates[i], level))
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
void DrawHistoricalArrows()
{
   if((!InpDrawArrowOnChart && !InpDrawDobZoneOnChart) || !InpDrawHistoricalArrows)
      return;

   ClearHistoricalArrows();

   int drawn = 0;
   int start_index = InpAlertOnCurrentCandle ? 1 : 2;
   int max_index = MathMax(start_index, InpLookbackBars - 20);

   for(int alert_index = start_index; alert_index <= max_index && drawn < InpMaxHistoricalArrows; alert_index++)
   {
      SetupSignal signal;
      if(FindBullishBreakerPullbackAt(_Symbol, alert_index, signal))
      {
         DrawAlertArrow(signal, true);
         drawn++;
      }
   }

   Print(StringFormat("SETUP_BBM15 DOB Scanner EA: %d fleches historiques dessinees sur %s.", drawn, _Symbol));
}

//+------------------------------------------------------------------+
void ClearHistoricalArrows()
{
   string prefix = "SETUP_BBM15_DOB_HIST_";

   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
string BuildAlertKey(const SetupSignal &signal)
{
   string side = signal.direction > 0 ? "BULLISH_DOB_BB_BOTTOM" : "BEARISH_DOB_BB_TOP";
   string base = signal.symbol + "|" + side + "|" + IntegerToString((long)signal.ob_time) + "|" + IntegerToString((long)signal.break_time);

   if(InpOneAlertPerBreaker)
      return(base);

   return(base + "|" + IntegerToString((long)signal.alert_time));
}

//+------------------------------------------------------------------+
bool WasAlerted(const string key)
{
   for(int i = 0; i < ArraySize(g_alerted_keys); i++)
   {
      if(g_alerted_keys[i] == key)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
void RegisterAlert(const string key)
{
   int size = ArraySize(g_alerted_keys);
   ArrayResize(g_alerted_keys, size + 1);
   g_alerted_keys[size] = key;
}

//+------------------------------------------------------------------+
void SendSetupAlert(const SetupSignal &signal)
{
   string side = signal.direction > 0 ? "DOB bullish casse dessous, pullback sur le bas" : "DOB bearish casse dessus, pullback sur le haut";
   string message = StringFormat(
      "SETUP_BBM15 DOB Scanner | %s | M15 | %s | Prix %.5f",
      signal.symbol,
      side,
      signal.alert_price
   );

   if(InpPopupAlert)
      Alert(message);

   if(InpSoundAlert)
      PlaySound(InpAlertSound);

   Print(message);
}

//+------------------------------------------------------------------+
void DrawAlertArrow(const SetupSignal &signal, const bool historical)
{
   if(signal.symbol != _Symbol)
      return;

   string prefix = historical ? "SETUP_BBM15_DOB_HIST_" : "SETUP_BBM15_DOB_ALERT_";
   DrawDobZone(signal, historical, prefix);

   if(!InpDrawArrowOnChart)
      return;

   string name = prefix + signal.symbol + "_" + IntegerToString((long)signal.alert_time) + "_" + IntegerToString((long)signal.break_time);
   ObjectDelete(0, name);

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, signal.alert_time, signal.alert_price))
      return;

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, InpArrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpArrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);

   string label = name + "_TEXT";
   ObjectDelete(0, label);
   ObjectCreate(0, label, OBJ_TEXT, 0, signal.alert_time, signal.alert_price);
   string side = signal.direction > 0 ? "bull" : "bear";
   ObjectSetString(0, label, OBJPROP_TEXT, historical ? "DOB " + side + " hist" : "DOB " + side + " alert");
   ObjectSetInteger(0, label, OBJPROP_COLOR, InpArrowColor);
   ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

//+------------------------------------------------------------------+
void DrawDobZone(const SetupSignal &signal, const bool historical, const string prefix)
{
   if(!InpDrawDobZoneOnChart)
      return;

   string name = prefix
                 + signal.symbol
                 + "_"
                 + IntegerToString((long)signal.ob_time)
                 + "_"
                 + IntegerToString((long)signal.alert_time)
                 + "_ZONE";
   ObjectDelete(0, name);

   datetime right_time = signal.alert_time;
   if(right_time <= signal.ob_time)
      right_time = signal.ob_time + (datetime)PeriodSeconds(PERIOD_M15);

   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, signal.ob_time, signal.ob_high, right_time, signal.ob_low))
      return;

   color zone_color = signal.direction > 0 ? InpBullishDobZoneColor : InpBearishDobZoneColor;
   ObjectSetInteger(0, name, OBJPROP_COLOR, zone_color);
   ObjectSetInteger(0, name, OBJPROP_FILL, false);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpDobZoneWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

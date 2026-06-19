//+------------------------------------------------------------------+
//| SETUP_BBM15                                                     |
//| Indicateur MT5 - detection de setup ICT                         |
//+------------------------------------------------------------------+
#property copyright "SETUP_BBM15"
#property version   "1.001"
#property indicator_chart_window
#property indicator_plots 0

input string InpSymbols = "";                    // Actifs a scanner, separes par virgule. Vide = actif du graphique
input int    InpLookbackBars = 300;              // Nombre de bougies M15 analysees
input int    InpMaxOrderBlockCandles = 5;        // Nombre maximum de bougies baissieres dans l'OB
input double InpMinFvgPoints = 0.0;              // Taille minimale du BISI en points
input bool   InpUseWicksForObZone = true;        // Zone OB avec meches completes, sinon corps
input bool   InpBreakRequiresClose = true;       // Cassure validee par cloture sous l'OB
input bool   InpAlertOnCurrentCandle = true;     // Alerte intrabougie, sinon bougie cloturee
input bool   InpFirstPullbackOnly = true;        // Alerter uniquement le premier retour dans le BB
input bool   InpOneAlertPerBreaker = true;       // Une seule alerte par breaker block
input bool   InpPopupAlert = true;               // Alerte popup MT5
input bool   InpSoundAlert = true;               // Alerte sonore
input string InpAlertSound = "alert.wav";        // Fichier son MT5
input bool   InpDrawZones = true;                // Dessiner les zones sur le graphique courant
input int    InpScanEverySeconds = 10;           // Frequence de scan

struct SetupSignal
{
   string   symbol;
   datetime ob_start_time;
   datetime ob_end_time;
   double   ob_low;
   double   ob_high;
   datetime fvg_start_time;
   datetime fvg_end_time;
   double   fvg_low;
   double   fvg_high;
   datetime break_time;
   datetime alert_time;
};

string g_alerted_keys[];

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "SETUP_BBM15");
   EventSetTimer(MathMax(1, InpScanEverySeconds));
   ScanAllSymbols();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   ScanAllSymbols();
}

//+------------------------------------------------------------------+
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   ScanAllSymbols();
   return(rates_total);
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
            DrawSignal(signal);
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
   if(!SymbolSelect(symbol, true))
      return(false);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_to_copy = MathMax(50, InpLookbackBars);
   int copied = CopyRates(symbol, PERIOD_M15, 0, bars_to_copy, rates);
   if(copied < 20)
      return(false);

   int alert_index = InpAlertOnCurrentCandle ? 0 : 1;
   if(alert_index >= copied)
      return(false);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00001;

   double min_gap = InpMinFvgPoints * point;

   for(int fvg_index = alert_index + 2; fvg_index < copied - 3; fvg_index++)
   {
      int first_candle = fvg_index + 2;
      int third_candle = fvg_index;

      if(!IsBullishFvg(rates, first_candle, third_candle, min_gap))
         continue;

      if(!IsBearish(rates[first_candle]))
         continue;

      double ob_low = DBL_MAX;
      double ob_high = -DBL_MAX;
      int ob_oldest = first_candle;
      int ob_newest = first_candle;
      int ob_count = 0;

      for(int ob_index = first_candle; ob_index < copied && ob_count < InpMaxOrderBlockCandles; ob_index++)
      {
         if(!IsBearish(rates[ob_index]))
            break;

         double candle_low = InpUseWicksForObZone ? rates[ob_index].low : MathMin(rates[ob_index].open, rates[ob_index].close);
         double candle_high = InpUseWicksForObZone ? rates[ob_index].high : MathMax(rates[ob_index].open, rates[ob_index].close);

         ob_low = MathMin(ob_low, candle_low);
         ob_high = MathMax(ob_high, candle_high);
         ob_oldest = ob_index;
         ob_count++;
      }

      if(ob_count <= 0 || ob_low == DBL_MAX || ob_high == -DBL_MAX)
         continue;

      int break_index = FindBreakIndex(rates, fvg_index - 1, alert_index + 1, ob_low);
      if(break_index < 0)
         continue;

      if(alert_index >= break_index)
         continue;

      if(!TouchesZone(rates[alert_index], ob_low, ob_high))
         continue;

      if(InpFirstPullbackOnly && HasEarlierPullbackTouch(rates, break_index - 1, alert_index + 1, ob_low, ob_high))
         continue;

      signal.symbol = symbol;
      signal.ob_start_time = rates[ob_oldest].time;
      signal.ob_end_time = rates[ob_newest].time;
      signal.ob_low = ob_low;
      signal.ob_high = ob_high;
      signal.fvg_start_time = rates[first_candle].time;
      signal.fvg_end_time = rates[third_candle].time;
      signal.fvg_low = rates[first_candle].high;
      signal.fvg_high = rates[third_candle].low;
      signal.break_time = rates[break_index].time;
      signal.alert_time = rates[alert_index].time;
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool IsBearish(const MqlRates &bar)
{
   return(bar.close < bar.open);
}

//+------------------------------------------------------------------+
bool IsBullishFvg(const MqlRates &rates[], const int first_candle, const int third_candle, const double min_gap)
{
   return(rates[third_candle].low > rates[first_candle].high + min_gap);
}

//+------------------------------------------------------------------+
int FindBreakIndex(const MqlRates &rates[], const int from_index, const int to_index, const double ob_low)
{
   for(int i = from_index; i >= to_index; i--)
   {
      bool broken = InpBreakRequiresClose ? (rates[i].close < ob_low) : (rates[i].low < ob_low);
      if(broken)
         return(i);
   }

   return(-1);
}

//+------------------------------------------------------------------+
bool TouchesZone(const MqlRates &bar, const double zone_low, const double zone_high)
{
   return(bar.high >= zone_low && bar.low <= zone_high);
}

//+------------------------------------------------------------------+
bool HasEarlierPullbackTouch(const MqlRates &rates[], const int from_index, const int to_index, const double zone_low, const double zone_high)
{
   for(int i = from_index; i >= to_index; i--)
   {
      if(TouchesZone(rates[i], zone_low, zone_high))
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
string BuildAlertKey(const SetupSignal &signal)
{
   string base = signal.symbol + "|BULLISH_BB|" + IntegerToString((long)signal.ob_start_time) + "|" + IntegerToString((long)signal.break_time);

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
   string message = StringFormat(
      "SETUP_BBM15 | %s | M15 | Pullback sur Breaker Block bullish | Zone %.5f - %.5f",
      signal.symbol,
      signal.ob_low,
      signal.ob_high
   );

   if(InpPopupAlert)
      Alert(message);

   if(InpSoundAlert)
      PlaySound(InpAlertSound);

   Print(message);
}

//+------------------------------------------------------------------+
void DrawSignal(const SetupSignal &signal)
{
   if(!InpDrawZones)
      return;

   if(signal.symbol != _Symbol)
      return;

   datetime right_time = TimeCurrent() + (datetime)(PeriodSeconds(PERIOD_M15) * 20);
   string prefix = "SETUP_BBM15_" + signal.symbol + "_" + IntegerToString((long)signal.ob_start_time) + "_";

   DrawRectangle(prefix + "BB", signal.ob_start_time, signal.ob_high, right_time, signal.ob_low, clrDodgerBlue, true);
   DrawRectangle(prefix + "FVG", signal.fvg_start_time, signal.fvg_high, signal.fvg_end_time, signal.fvg_low, clrMediumPurple, false);

   string label = prefix + "LABEL";
   ObjectDelete(0, label);
   ObjectCreate(0, label, OBJ_TEXT, 0, signal.alert_time, signal.ob_high);
   ObjectSetString(0, label, OBJPROP_TEXT, "BB pullback alert");
   ObjectSetInteger(0, label, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

//+------------------------------------------------------------------+
void DrawRectangle(const string name, const datetime left_time, const double top_price, const datetime right_time, const double bottom_price, const color rect_color, const bool filled)
{
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, left_time, top_price, right_time, bottom_price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, rect_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, filled);
}

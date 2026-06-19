//+------------------------------------------------------------------+
//| SETUP_BBM15 DOB Scanner EA                                       |
//| Scanner MT5 sans trading automatique base sur un indicateur DOB   |
//+------------------------------------------------------------------+
#property copyright "SETUP_BBM15"
#property version   "1.100"
#property strict

input string InpSymbols = "";                         // Actifs a scanner, separes par virgule. Vide = actif du graphique
input int    InpLookbackBars = 300;                   // Nombre de bougies M15 analysees
input string InpDobIndicatorName = "DisplacementOrderBlock"; // Nom de l'indicateur OB installe dans MQL5/Indicators
input bool   InpDobDebugEnabled = false;              // Logs de l'indicateur DOB
input bool   InpBreakRequiresClose = true;            // Cassure validee par cloture sous le bas de l'OB
input bool   InpAlertOnCurrentCandle = true;          // Alerte intrabougie, sinon bougie cloturee
input bool   InpFirstPullbackOnly = true;             // Alerter uniquement le premier retour dans le BB
input bool   InpOneAlertPerBreaker = true;            // Une seule alerte par breaker block
input bool   InpPopupAlert = true;                    // Alerte popup MT5
input bool   InpSoundAlert = true;                    // Alerte sonore
input string InpAlertSound = "alert.wav";             // Fichier son MT5
input bool   InpDrawArrowOnChart = true;              // Dessiner une fleche sur le graphique actif
input bool   InpDrawHistoricalArrows = true;          // Afficher les anciennes fleches sur le graphique actif
input int    InpMaxHistoricalArrows = 50;             // Nombre maximum de fleches historiques
input color  InpArrowColor = clrRed;                  // Couleur de la fleche d'alerte
input int    InpArrowCode = 233;                      // Code Wingdings de la fleche
input int    InpScanEverySeconds = 10;                // Frequence de scan

struct SetupSignal
{
   string   symbol;
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
   Print("Indicateur DOB attendu dans MQL5/Indicators: ", InpDobIndicatorName);
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

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_to_copy = MathMax(50, InpLookbackBars);
   int copied = CopyRates(symbol, PERIOD_M15, 0, bars_to_copy, rates);
   if(copied < 20 || alert_index >= copied)
      return(false);

   double dob_highs[];
   double dob_lows[];
   double dob_trends[];
   if(!CopyDobBuffers(symbol, copied, dob_highs, dob_lows, dob_trends))
      return(false);

   for(int ob_index = alert_index + 3; ob_index < copied - 3; ob_index++)
   {
      if(dob_trends[ob_index] < 0.5)
         continue;

      double ob_low = 0.0;
      double ob_high = 0.0;
      if(!NormalizeDobZone(dob_highs[ob_index], dob_lows[ob_index], ob_low, ob_high))
         continue;

      int break_index = FindBreakIndex(rates, ob_index - 1, alert_index + 1, ob_low);
      if(break_index < 0)
         continue;

      if(alert_index >= break_index)
         continue;

      if(!TouchesBreakerBottom(rates[alert_index], ob_low))
         continue;

      if(InpFirstPullbackOnly && HasEarlierBottomTouch(rates, break_index - 1, alert_index + 1, ob_low))
         continue;

      signal.symbol = symbol;
      signal.ob_time = rates[ob_index].time;
      signal.ob_low = ob_low;
      signal.ob_high = ob_high;
      signal.break_time = rates[break_index].time;
      signal.alert_time = rates[alert_index].time;
      signal.alert_price = ob_low;
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool CopyDobBuffers(const string symbol,
                    const int bars_count,
                    double &dob_highs[],
                    double &dob_lows[],
                    double &dob_trends[])
{
   ArraySetAsSeries(dob_highs, true);
   ArraySetAsSeries(dob_lows, true);
   ArraySetAsSeries(dob_trends, true);

   int handle = iCustom(symbol,
                        PERIOD_M15,
                        InpDobIndicatorName,
                        InpDobDebugEnabled,
                        false,
                        false,
                        clrLightPink,
                        clrLightGreen,
                        false,
                        STYLE_SOLID,
                        1);

   if(handle == INVALID_HANDLE)
   {
      Print("Impossible de charger l'indicateur DOB: ", InpDobIndicatorName, " pour ", symbol);
      return(false);
   }

   int copied_high = CopyBuffer(handle, 0, 0, bars_count, dob_highs);
   int copied_low = CopyBuffer(handle, 1, 0, bars_count, dob_lows);
   int copied_trend = CopyBuffer(handle, 2, 0, bars_count, dob_trends);
   IndicatorRelease(handle);

   if(copied_high < bars_count || copied_low < bars_count || copied_trend < bars_count)
   {
      Print("Buffers DOB incomplets pour ", symbol, ". Verifie que l'indicateur est installe et compile.");
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
bool NormalizeDobZone(const double buffer_a, const double buffer_b, double &ob_low, double &ob_high)
{
   if(!IsUsablePrice(buffer_a) || !IsUsablePrice(buffer_b))
      return(false);

   ob_low = MathMin(buffer_a, buffer_b);
   ob_high = MathMax(buffer_a, buffer_b);

   return(ob_high > ob_low);
}

//+------------------------------------------------------------------+
bool IsUsablePrice(const double value)
{
   if(value == EMPTY_VALUE || value <= 0.0)
      return(false);

   if(value > DBL_MAX / 4.0)
      return(false);

   return(MathIsValidNumber(value));
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
bool TouchesBreakerBottom(const MqlRates &bar, const double ob_low)
{
   return(bar.high >= ob_low && bar.low <= ob_low);
}

//+------------------------------------------------------------------+
bool HasEarlierBottomTouch(const MqlRates &rates[], const int from_index, const int to_index, const double ob_low)
{
   for(int i = from_index; i >= to_index; i--)
   {
      if(TouchesBreakerBottom(rates[i], ob_low))
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
void DrawHistoricalArrows()
{
   if(!InpDrawArrowOnChart || !InpDrawHistoricalArrows)
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
   string base = signal.symbol + "|DOB_BB_BOTTOM|" + IntegerToString((long)signal.ob_time) + "|" + IntegerToString((long)signal.break_time);

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
      "SETUP_BBM15 DOB Scanner | %s | M15 | Pullback touche le bas du Breaker Block bullish | Prix %.5f",
      signal.symbol,
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
   if(!InpDrawArrowOnChart)
      return;

   if(signal.symbol != _Symbol)
      return;

   string prefix = historical ? "SETUP_BBM15_DOB_HIST_" : "SETUP_BBM15_DOB_ALERT_";
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
   ObjectSetString(0, label, OBJPROP_TEXT, historical ? "DOB BB hist" : "DOB BB alert");
   ObjectSetInteger(0, label, OBJPROP_COLOR, InpArrowColor);
   ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

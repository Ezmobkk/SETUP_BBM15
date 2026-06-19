//+------------------------------------------------------------------+
//| SETUP_BBM15                                                     |
//| Indicateur MT5 - detection de setup ICT                         |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "SETUP_BBM15");
   return(INIT_SUCCEEDED);
}

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
   return(rates_total);
}

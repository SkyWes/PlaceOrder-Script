//+------------------------------------------------------------------+
//|                                                      LotCalc.mq5 |
//+------------------------------------------------------------------+
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Expert\Money\MoneyFixedRisk.mqh>
#include <NewBar.mqh>
//+------------------------------------------------------------------+
class LotCalc
  {
public:
                     LotCalc(void);
                    ~LotCalc(void);

   double            FindLot(double price, double sl);
   int               Init(double pr, double x,ENUM_TIMEFRAMES p);
   double            addSpread() { return spread();   }
   double            GetBuyLot() { return m_buy_lot;  }
   double            GetSellLot() { return m_sell_lot; }
   double            addX()      { return m_x;        }

private:
   CTrade            m_trade;                      // trading object
   CSymbolInfo       m_symbol;                     // symbol info object
   CAccountInfo      m_account;                    // account info wrapper
   CMoneyFixedRisk   m_money;
   double            m_x;
   double            m_buy_lot;
   double            m_sell_lot;
   ENUM_TIMEFRAMES   m_period;
   double            spread() { return(m_symbol.Ask()-m_symbol.Bid()); }
   void              BreakEven(double &entry, const double &sl);

   bool              RefreshRates();
  };

//+------------------------------------------------------------------+
LotCalc::LotCalc(void)
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
LotCalc::~LotCalc(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int LotCalc::Init(double pr, double x, ENUM_TIMEFRAMES p)
  {
   m_x = x;
   m_period = p;
   m_symbol.Name(Symbol());
   m_symbol.Refresh();
   if(!RefreshRates())
     {
      Print("Error RefreshRates. Bid=",DoubleToString(m_symbol.Bid(),Digits()),
            ", Ask=",DoubleToString(m_symbol.Ask(),Digits()));
      return(INIT_FAILED);
     }
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;

//---
   if(!m_money.Init(GetPointer(m_symbol),m_period,m_symbol.Point()*digits_adjust))
      return(INIT_FAILED);
   m_money.Percent(pr);
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LotCalc::FindLot(double price, double sl)
  {
   if(!RefreshRates())
      return -1;
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return -1;


//--- getting lot size for open long position (CMoneyFixedRisk)
   double lot=0.0;
   double profit_check;
   double check_volume_lot;
   string side{};


   if(price - sl > 0)
     {
      BreakEven(price,sl);
      price += spread() + m_x;
      lot=m_money.CheckOpenLong(price,sl);
      profit_check = m_account.OrderProfitCheck(m_symbol.Name(),ORDER_TYPE_BUY,lot,price,sl);
      check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lot,price,ORDER_TYPE_BUY);
      m_buy_lot = lot;
      side = "long position";
     }
   else
     {
      BreakEven(sl,price);
      price -= m_x;
      sl += spread();
      lot = m_money.CheckOpenShort(price,sl);
      profit_check = m_account.OrderProfitCheck(m_symbol.Name(),ORDER_TYPE_SELL,lot,price,sl);
      check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lot,price,ORDER_TYPE_SELL);
      m_sell_lot = lot;
      side = "short position";
     }
   Print(__FUNCTION__," : ",side, ", sl= ",DoubleToString(sl,m_symbol.Digits()),
         ", price= ", DoubleToString(price,m_symbol.Digits()),
         ", Lot: ",DoubleToString(lot,2),
         ", ProfitCheck: ", DoubleToString(profit_check,2),
         ", Balance: ",    DoubleToString(m_account.Balance(),2),
         ", Equity: ",     DoubleToString(m_account.Equity(),2),
         ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
   if(lot==0.0)
      return -1;

//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lot,price,ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         return lot;
        }
      else
         Print("ERROR! FUNCTION: ",__FUNCTION__," not enough money.");
//---
   return -1;


  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LotCalc::RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LotCalc::BreakEven(double &entry, const double &sl)
  {
   string sector = SymbolInfoString(Symbol(),SYMBOL_SECTOR_NAME);
   string crypto = SymbolInfoString("BTCUSD",SYMBOL_SECTOR_NAME);
   double commission;

   sector==crypto ? commission = 0.00075 : commission = 0.000035;
   commission = MathFloor(((entry*commission) + (sl*commission)));
   entry += commission;
  }
//+------------------------------------------------------------------+

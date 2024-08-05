#include <LotCalc.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#property script_show_inputs
input double input_percent_risk = 1; //Enter the percent risk
input double manual_lot = 0; //LotCalc bypass, manual lot
input double input_add_x = 2;  // Enter price buffer

double pr_risk{};
double add_x{};

LotCalc           calc;
CTrade            exp_trade;
CSymbolInfo       s_info;
CAccountInfo      a_info;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---

   string obj_name = ObjectName(0,0,0,OBJ_FIBO);

   if(obj_name=="")
     {
      MessageBox("No fibo object found.");
      return;
     }

   double start;
   double stop;

   if(!ObjectGetDouble(0,obj_name,OBJPROP_PRICE,0,start))
     {
      MessageBox("No fibo start price found.");
     }
   if(!ObjectGetDouble(0,obj_name,OBJPROP_PRICE,1,stop))
     {
      MessageBox("No fibo stop price found.");
     }

   string side = "";
   if(start > stop)
     {
      side = "BuyStop";
     }
   else
     {
      side = "SellStop";
     }



   s_info.Name(Symbol());
   s_info.RefreshRates();
   pr_risk = input_percent_risk;
   Print("input_add_x: ",input_add_x, " s_info.Point(): ",s_info.Point());
   add_x = NormalizeDouble(input_add_x*s_info.Point(),s_info.Digits());
   Print("add_x: ", add_x);
   if(calc.Init(pr_risk,add_x,PERIOD_CURRENT)==INIT_FAILED)
     {
      MessageBox("LotCalc.mqh init failed.");
      return;
     }

   double tp;
   double price;
   double sl;
   double buy_lot;
   double sell_lot;
   double profit;

   if(side=="BuyStop")
     {
      tp = 0.0;
      price = start + calc.addSpread() + calc.addX();
      sl = stop - s_info.Point()*2;
      if(manual_lot==0)
        {
         buy_lot = calc.FindLot(price,sl);
        }
      else
        {
         buy_lot = manual_lot;
         if(OrderCalcProfit(ORDER_TYPE_BUY,Symbol(),buy_lot,price,sl,profit))
           {
            double p = profit/a_info.Balance() * 100;
            Print("Profit: $",profit, " risk: ",DoubleToString(p,2),"%.");
           }
        }

      string msg = "Place pending " + side + " order of "+DoubleToString(buy_lot,2)+" at price: " + DoubleToString(price,_Digits)+ " with stop: "+ DoubleToString(sl,_Digits);
      int msg_box = MessageBox(msg,NULL,MB_OKCANCEL);

      if(msg_box!=1)
        {
         return;
        }

      if(price <= s_info.Ask() || !exp_trade.BuyStop(buy_lot,price,Symbol(),sl,tp,ORDER_TIME_GTC,0))
        {
         Print("failed to place order: ",exp_trade.ResultRetcodeDescription());
        }
     }
   if(side=="SellStop")
     {
      tp = 0.0;
      price = start - calc.addX();
      sl = stop + calc.addSpread() + s_info.Point()*2;
      if(manual_lot==0)
        {
         sell_lot = calc.FindLot(price,sl);
        }
      else
        {
         sell_lot = manual_lot;
         if(OrderCalcProfit(ORDER_TYPE_SELL,Symbol(),sell_lot,price,sl,profit))
           {
            double p = profit / a_info.Balance() * 100;
            Print("Profit: $",profit," risk: ",DoubleToString(p,2),"%.");
           }
        }

      string msg = "Place pending " + side + " order of "+DoubleToString(sell_lot,2)+" at price: " + DoubleToString(price,_Digits)+ " with stop: "+ DoubleToString(sl,_Digits);
      int msg_box = MessageBox(msg,NULL,MB_OKCANCEL);

      if(msg_box!=1)
        {
         return;
        }

      if(price >= s_info.Ask() || !exp_trade.SellStop(sell_lot,price,Symbol(),sl,tp,ORDER_TIME_GTC,0))
        {
         Print("failed to place order: ",exp_trade.ResultRetcodeDescription());
        }
     }


  }
//+------------------------------------------------------------------+

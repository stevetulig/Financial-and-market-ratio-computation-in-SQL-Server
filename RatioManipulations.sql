
--script for calculating various ratios and preparing two output tables:
--outputTable contains financial ratios, with one data point per company per year
--outputTable_MktBased contains market-based ratios, with one data point per company per month
use Zenith

--store important items in temporary tables
--Net Operating Cashflows
select StockID, ReportMonth, ReportYear, ItemValue into #CFO from Financials where Item='Net Operating Cashflows' and ItemValue is not null
--Net Investing Cashflows
select StockID, ReportMonth, ReportYear, ItemValue into #CFI from Financials where Item='Net Investing Cashflows' and ItemValue is not null
--Net Financing Cashflows
select StockID, ReportMonth, ReportYear, ItemValue into #CFF from Financials where Item='Net Financing Cashflows' and ItemValue is not null
--Total Assets
select StockID, ReportMonth, ReportYear, ItemValue into #TA from Financials where Item='Total Assets' and ItemValue is not null
--Total Liabilities
select StockID, ReportMonth, ReportYear, ItemValue into #TL from Financials where Item='Total Liabilities' and ItemValue is not null
--EBITDA
select StockID, ReportMonth, ReportYear, ItemValue into #EBITDA from Financials where Item='EBITDA' and ItemValue is not null
--Total Equity
select StockID, ReportMonth, ReportYear, ItemValue into #TE from Financials where Item='Total Equity' and ItemValue is not null
--Market Cap.
select StockID, ReportMonth, ReportYear, ItemValue into #MC from Financials where Item='Market Cap.' and ItemValue is not null
--Book/Price
select StockID, ReportMonth, ReportYear, 1/ItemValue as ItemValue into #BP from Financials where Item='Price/Book Value' and ItemValue is not null and ItemValue<>0
--Earnings/Price (1/price-earnings ratio)
select StockID, ReportMonth, ReportYear, 1/ItemValue as ItemValue into #EP from Financials where Item='PER' and ItemValue is not null and ItemValue<>0
--Enterprise Value; as assets - equity + market cap
select a.StockID, a.ReportMonth, a.ReportYear, a.ItemValue-e.ItemValue+m.ItemValue as ItemValue
 into #EV
 from (#TA a inner join #TE e on a.StockID=e.STockID and a.ReportMonth=e.ReportMonth and a.ReportYear=e.ReportYear)
 inner join #MC m on a.StockID=m.StockID and a.ReportMonth=m.ReportMonth and a.ReportYear=m.ReportYear

--calculate (otherwise unavailable) ratios
--CFO on assets
select a.StockID, a.ReportMonth, a.ReportYear, a.ItemValue/b.ItemValue as ItemValue into #CFO_A
 from #CFO a inner join #TA b on a.StockID=b.STockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
 where b.ItemValue<>0
update #CFO_A set ItemValue=1 where ItemValue>1
update #CFO_A set ItemValue=-1 where ItemValue<-1
--CFI on assets
select a.StockID, a.ReportMonth, a.ReportYear, a.ItemValue/b.ItemValue as ItemValue into #CFI_A
 from #CFI a inner join #TA b on a.StockID=b.STockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
 where b.ItemValue<>0
update #CFI_A set ItemValue=1 where ItemValue>1
update #CFI_A set ItemValue=-1 where ItemValue<-1
--CFF on assets
select a.StockID, a.ReportMonth, a.ReportYear, a.ItemValue/b.ItemValue as ItemValue into #CFF_A
 from #CFF a inner join #TA b on a.StockID=b.STockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
 where b.ItemValue<>0
update #CFF_A set ItemValue=1 where ItemValue>1
update #CFF_A set ItemValue=-1 where ItemValue<-1
--EBITDA/EV
select a.StockID, a.ReportMonth, a.ReportYear, a.ItemValue/b.ItemValue as ItemValue into #EBITDA_EV
 from #EBITDA a inner join #EV b on a.StockID=b.STockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
 where b.ItemValue<>0
--debt ratio (Total Liabilities / Total Assets)
select a.StockID, a.ReportMonth, a.ReportYear, a.ItemValue/b.ItemValue as ItemValue into #D_A
 from #TL a inner join #TA b on a.StockID=b.STockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
 where b.ItemValue<>0
update #D_A set ItemValue=1 where ItemValue>1

--prepare an output table for financial ratios (datapoints are at financial year-ends)
drop table if exists outputTable
select StockID, ReportMonth, ReportYear, cast(Null as decimal(10,6)) as B_P, cast(Null as decimal(10,6)) as E_P,
	cast(Null as decimal(10,6)) as ROE, cast(Null as decimal(10,6)) as D_A, cast(Null as decimal(10,6)) as CFO_A,
	cast(Null as decimal(10,6)) as CFI_A, cast(Null as decimal(10,6)) as CFF_A, cast(Null as decimal(10,6)) as EBITDA_EV
	into outputTable
	from Financials group by StockID, ReportMonth, ReportYear
create unique index idx1 on outputTable (StockID, ReportMonth, ReportYear)

/*
update ratios in output table
to minimise space we use the stored procedure which runs versions of the following:
update a
set a.<ratio-name>=b.ItemValue
from outputTable a inner join <temporary table name> b
on a.StockID=b.StockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
see the script updateOutputTable_Mkt.sql for the stored procedure
*/
exec updateOutputTable 'B_P', '#BP'
exec updateOutputTable 'E_P', '#EP'
exec updateOutputTable 'ROE', 'ROE' -- this (pre-calculated) data was from another source
exec updateOutputTable 'D_A', '#D_A'
exec updateOutputTable 'CFO_A', '#CFO_A'
exec updateOutputTable 'CFI_A', '#CFI_A'
exec updateOutputTable 'CFF_A', '#CFF_A'
exec updateOutputTable 'EBITDA_EV', '#EBITDA_EV'

--prepare an output table for market-based ratios (datapoints are at every month-end)
drop table if exists outputTable_MktBased
select StockID, monthEnd, cast(Null as decimal(10,6)) as MOM, cast(Null as decimal(10,6)) as LIQ,
	cast(Null as decimal(10,6)) as MCR
	into outputTable_MktBased
	from Companylist, monthEndDates
create unique clustered index idx2 on outputTable_MktBased (StockID, monthEnd)

--update market-based ratios using a similar procedure which joins on "PriceDate"
--see the script updateOutputTable.sql for the stored procedure
exec updateOutputTable_Mkt 'MOM', 'MOM6' -- this is prior 6-month return (precalculated)
exec updateOutputTable_Mkt 'LIQ', 'LIQ' -- this is Liquidity as defined by S&P (precalculated)
exec updateOutputTable_Mkt 'MCR', 'MCR' -- this is ranking by market cap (precaculated)
delete from outputTable_MktBased where MOM is null and LIQ is NULL and MCR is null

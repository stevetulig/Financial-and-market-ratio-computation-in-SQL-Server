/*
Script for calculating various ratios based on market (ASX) data.

One of the ratios (DD, or distance-to-default) is calculated from financial
statement, interest rate and market data. DD is calculated in Python and
then imported back into this databse.

The raw market data are stored in the Daily_prices table in long format,
where each row contains one observation per company per trading day.

Liquidity (LIQ) is calculated based on Standard and Poors' index methodology,
in the script calcLiquidity.sql

The output is stored in the table outputTableMktBased where each row contains
one observation per company per month (as at the end of each month).

As the output data is monthly, no lookup table is required for portfolio
rebalancing during backtesting.
*/

use Zenith

--prepare an output table for market-based ratios (datapoints are at every month-end)
drop table if exists outputTableMktBased
select StockID, PriceDate as monthEnd, cast(Null as float) as MOM6, cast(Null as float) as MOM12,
	cast(Null as float) as LIQ, cast(Null as float) as MCR, cast(Null as float) as DD
	into outputTableMktBased
	from Companylist cross join tradingdays
	where EOM=1
create unique clustered index idx2 on outputTableMktBased (StockID, monthEnd)

-- six-month momentum (i.e. prior six-month return)
-- fastest method of several attempted:
with EOM_data (StockID, PriceDate, AI) as
(
select StockID, PriceDate, AccumIndex 
from stockaccumindex where PriceDate in (select PriceDate from tradingdays where EOM=1)
)
select e1.StockID, e1.PriceDate, e1.AI/e0.AI-1 as MOM6
into #tempMOM6
from EOM_data e1 inner join EOM_data e0
on e1.StockID=e0.StockID and DATEDIFF(m,e0.PriceDate,e1.PriceDate)=6
where e0.AI<>0

update o set o.MOM6=t.MOM6
from outputTableMktBased o inner join #tempMOM6 t
on o.StockID=t.StockID and o.monthEnd=t.PriceDate

drop table #tempMOM6

-- 12-month momentum (i.e. prior 12-month return)
with EOM_data (StockID, PriceDate, AI) as
(
select StockID, PriceDate, AccumIndex 
from stockaccumindex where PriceDate in (select PriceDate from tradingdays where EOM=1)
)
select e1.StockID, e1.PriceDate, e1.AI/e0.AI-1 as MOM12
into #tempMOM12
from EOM_data e1 inner join EOM_data e0
on e1.StockID=e0.StockID and DATEDIFF(m,e0.PriceDate,e1.PriceDate)=12
where e0.AI<>0

update o set o.MOM12=t.MOM12
from outputTableMktBased o inner join #tempMOM12 t
on o.StockID=t.StockID and o.monthEnd=t.PriceDate

drop table #tempMOM12

-- Liquidity, based on Standard & Poors' ASX200 Index Methodology,
-- previously calculated and stored in the table Liquidity; see calcLiquidity.sql
update o set o.LIQ=l.MedianLiquidity
from outputTableMktBased o inner join Liquidity_SP l
on o.StockID=l.StockID and o.monthEnd=l.PriceDate

-- Ranking by market capitalisation, where 1=Largest
with mcr_cte (StockID, PriceDate, MCR) as
(
select StockID, PriceDate, rank() over (partition by PriceDate order by MarketCap desc)
from Daily_prices where MarketCap is not null
and PriceDate in (select PriceDate from tradingdays where EOM=1)
)
update o set o.MCR=m.MCR
from outputTableMktBased o inner join mcr_cte m
on o.StockID=m.StockID and o.monthEnd=m.PriceDate

--Distance to default, previously calculated using Python and stored in the table DD;
--see ...
update o set o.DD=d.DD
from outputTableMktBased o inner join DD d
on o.StockID=d.StockID and year(o.monthEnd)=d.[Year] and month(o.monthEnd)=12

/*
end of script
*/

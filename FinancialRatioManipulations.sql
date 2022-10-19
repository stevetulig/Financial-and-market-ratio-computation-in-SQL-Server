
/*
Script for calculating various ratios based on financial statement data.

The raw data are stored in the Financials table in long format.

The output is stored in the table outputTable where each row contains
one observation per company per year.

To save space, some of the simple ratios of the form numerator/denominator
make use of the stored procedure calcFinancialRatio.

For backtesting purposes, the script also creates a lookup table for
matching portfolio rebalancing (end-of-calendar-year) dates with
appropriate financial-year-ends, for each company and year. Financial
statements are assumed to be unavailable until three months after
financial year end, and rebalance dates are at 31 December every year
from 2000 to 2012. We therefore look for the most recent report date
for each company from 1 October year(t-1) to 30 September year(t).
*/
use Zenith

--prepare an output table for financial ratios (datapoints are at financial year-ends)
drop table if exists outputTable
select StockID, ReportMonth, ReportYear, cast(Null as float) as B_P, cast(Null as float) as E_P,
	cast(Null as float) as ROE, cast(Null as float) as D_A, cast(Null as float) as CFO_A,
	cast(Null as float) as CFI_A, cast(Null as float) as CFF_A,
	cast(Null as float) as ACCRUALS, cast(Null as float) as EBITDA_EV
	into outputTable
	from Financials group by StockID, ReportMonth, ReportYear
create unique index idx1 on outputTable (StockID, ReportMonth, ReportYear)

--Book/Price = 1/price-to-book ratio, which is already stored in the database
update a set B_P=1/b.ItemValue
from outputTable a inner join Financials b
on a.StockID=b.StockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
where Item='Price/Book Value' and ItemValue is not null and ItemValue<>0

--Earnings/Price = 1/price-earnings ratio, which is already stored in the database
update a set E_P=1/b.ItemValue
from outputTable a inner join Financials b
on a.StockID=b.StockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear
where Item='PER' and ItemValue is not null and ItemValue<>0

--Return on Equity
with roe_cte (StockID, ReportMonth, ReportYear, ROE) as
(
select n.StockID, n.ReportMonth, n.ReportYear, (n.ItemValue-isnull(noe.ItemValue,0))/(e.ItemValue-isnull(eoe.ItemValue,0))
from
(Financials n inner join Financials e on n.StockID=e.StockID and n.ReportMonth=e.ReportMonth and n.ReportYear=e.ReportYear
and n.Item='Net Profit after Tax Before Abnormals' and e.Item='Total Equity')
left join Financials noe
on n.StockID=noe.StockID and n.ReportMonth=noe.ReportMonth and n.ReportYear=noe.ReportYear and noe.Item='Outside Equity Interests'
left join Financials eoe
on n.StockID=eoe.StockID and n.ReportMonth=eoe.ReportMonth and n.ReportYear=eoe.ReportYear and eoe.Item='Outside Equity'
where e.ItemValue-isnull(eoe.ItemValue,0)<>0
)
update o set o.ROE=r.ROE
from outputTable o inner join roe_cte r
on o.StockID=r.StockID and o.ReportMonth=r.ReportMonth and o.ReportYear=r.ReportYear
update outputTable set ROE=-1 where ROE<-1
update outputTable set ROE=1 where ROE>1

--simple ratios calculated using the stored procedure calcFInancialRatio

-- Debt/Assets
exec calcFinancialRatio 'D_A', 'Total Liabilities', 'Total Assets'
update outputTable set D_A=1 where D_A>1

-- Cashflow from operations / Assets
exec calcFinancialRatio 'CFO_A', 'Net Operating Cashflows', 'Total Assets'
update outputTable set CFO_A=1 where CFO_A>1
update outputTable set CFO_A=-1 where CFO_A<-1

-- Investing cashflows / Assets
exec calcFinancialRatio 'CFI_A', 'Net Investing Cashflows', 'Total Assets'
update outputTable set CFI_A=1 where CFI_A>1
update outputTable set CFI_A=-1 where CFI_A<-1

-- Financing cashflows / Assets
exec calcFinancialRatio 'CFF_A', 'Net Financing Cashflows', 'Total Assets'
update outputTable set CFF_A=1 where CFF_A>1
update outputTable set CFF_A=-1 where CFF_A<-1

-- Accruals = (NPAT-CFO)/TA
with ACCRUALS_cte (StockID, ReportMonth, ReportYear, ACCRUALS) as
(
select n.StockID, n.ReportMonth, n.ReportYear,
(n.ItemValue-cfo.ItemValue)/ta.ItemValue
from Financials n inner join Financials ta
on n.StockID=ta.StockID and n.ReportMonth=ta.ReportMonth
and n.ReportYear=ta.ReportYear
and n.Item='Net Profit after Tax Before Abnormals' and ta.Item='Total Assets'
inner join Financials cfo
on n.StockID=cfo.StockID and n.ReportMonth=cfo.ReportMonth
and n.ReportYear=cfo.ReportYear and cfo.Item='Net Operating Cashflows'
where ta.ItemValue<>0
)
update o set o.ACCRUALS=a.ACCRUALS
from outputTable o inner join ACCRUALS_cte a
on o.StockID=a.StockID and o.ReportMonth=a.ReportMonth and o.ReportYear=a.ReportYear

--EBITDA / Enterprise Value
with ev_cte (StockID, ReportMonth, ReportYear, EBITDA_EV) as
(
select a.StockID, a.ReportMonth, a.ReportYear, eb.ItemValue/(a.ItemValue-e.ItemValue+m.ItemValue)
from
Financials a inner join Financials e on a.StockID=e.StockID and a.ReportMonth=e.ReportMonth and a.ReportYear=e.ReportYear
inner join Financials m on a.StockID=m.StockID and a.ReportMonth=m.ReportMonth and a.ReportYear=m.ReportYear
inner join Financials eb on a.StockID=eb.StockID and a.ReportMonth=eb.ReportMonth and a.ReportYear=eb.ReportYear
where a.Item='Total Assets' and e.Item='Total Equity' and m.Item='Market Cap.' and eb.Item='EBITDA'
and a.ItemValue-e.ItemValue+m.ItemValue>0
)
update o set o.EBITDA_EV=e.EBITDA_EV
from outputTable o inner join ev_cte e
on o.StockID=e.StockID and o.ReportMonth=e.ReportMonth and o.ReportYear=e.ReportYear

/* For backtesting purposes, we create a table with reference to the date of the most recent financial report
before each rebalance date. We assume reports are unavailable until three months after financial year end
and that rebalance dates are at 31 December every year from 2000 to 2012. We therefore look for the most
recent report date for each company from 1 October year(t-1) to 30 September year(t). */
drop table if exists financialRefDates
create table financialRefDates (StockID int, rebalanceDate datetime, reportDate datetime)
create index idx1 on financialRefDates (StockID, rebalanceDate)
declare @y int
declare @rebalanceDate datetime
set @y=2000
while @y<2013
	begin
		set @rebalanceDate=DATEFROMPARTS(@y,12,31);
		with findates_cte (s, d1) as
		(
		select StockID, max(datefromparts(ReportYear+1900,ReportMonth,1)) from Financials
			where DATEDIFF(m, DATEFROMPARTS(ReportYear+1900,ReportMonth,1), DATEFROMPARTS(@y,12,31)) between 3 and 14
			and AnnInt='A'
			group by StockID
		)
		insert financialRefDates (StockID, rebalanceDate, reportDate)
			select s, @rebalanceDate, DATEADD(d,-1,DATEADD(m,1,d1))
			from findates_cte
		set @y=@y+1
	end

/*
end of script
*/

-- stored procedure to update market-based ratios in outputTable_MktBased
create proc updateOutputTable_Mkt
@ratioName varchar(20),
@srcTable varchar(20)
as
begin
	declare @strQuery as varchar(max)
	set @strQuery = 'update a set a.' + @ratioName +
	'=b.ItemValue from OutputTable_MktBased a inner join ' + @srcTable +
	' b on a.StockID=b.StockID and a.monthEnd=b.priceDate'
	exec(@strQuery)
end
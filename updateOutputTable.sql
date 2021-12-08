-- stored procedure to update financial ratios in outputTable
create proc updateOutputTable
@ratioName varchar(20),
@srcTable varchar(20)
as
begin
	declare @strQuery as varchar(max)
	set @strQuery = 'update a set a.' + @ratioName +
	'=b.ItemValue from outputTable a inner join ' + @srcTable +
	' b on a.StockID=b.StockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear'
	exec(@strQuery)
end
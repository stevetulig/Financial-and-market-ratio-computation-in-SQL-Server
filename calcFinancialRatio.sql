-- stored procedure to calculate financial ratios and store them in the table outputTable
USE [Zenith]
GO
/****** Object:  StoredProcedure [dbo].[updateOutputTable]    Script Date: 30/09/2022 6:54:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[calcFinancialRatio]
@ratioName varchar(20),
@ratioNumerator varchar(30),
@ratioDenominator varchar(30)
as
begin
	declare @strQuery as varchar(max)
	set @strQuery =
	'with cte1 (StockId, ReportMonth, ReportYear, FinRatio) as ' +
	'(' +
	'select a.StockID, a.ReportMonth, a.ReportYear, cast(a.ItemValue/b.ItemValue as float) ' +
	'from Financials a inner join Financials b ' +
	'on a.StockID=b.STockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear ' +
	'where b.ItemValue<>0 ' +
	'and a.Item=''' + @ratioNumerator + '''' +
	'and b.Item=''' + @ratioDenominator + '''' +
	')' +
	'update a set a.'+@ratioName+'=b.FinRatio ' +
	'from outputTable a inner join cte1 b ' +
	'on a.StockID=b.StockID and a.ReportMonth=b.ReportMonth and a.ReportYear=b.ReportYear'
	exec(@strQuery)
end
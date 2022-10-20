This task is part of a much larger research project I commenced in 2014 to investigate equity (share) trading strategies. Data were obtained for ASX stocks covering the period 2000 to 2013 and stored and processed using Microsoft SQL Server. This data includes company financials (i.e. annual financial statement data), and market-based data (i.e. derived from ASX data such as price, volume, shares outstanding etc.). In this task I compute financial ratios and other ‘signals’ and store them in tables suitable for use in later tasks such as<br>
* Searching for profitable trading strategies based on these ratios
* Analysing changes in ASX200 index membership, with a view to predicting and trading off these changes
* Creation of a Python (Tkinter) based application to allow for variations in research design
* Searching for profitable trading strategies using machine-learning algorithms

The output from this task consists of the following tables:
**Table** | **Description**
---|---
outputTable	| Financial ratios calculated from the annual financial statements
outputTableMktBased	| Ratios calculated from ASX market data (monthly)
financialRefDates	| Lookup table for matching portfolio rebalancing dates with the rows in outputTable

Calculation of ratios from the annual financial statements
----------------------------------------------------------
The outputTable table is created and populated using the script FinancialRatioManipulations.sql, which also creates and populates the financialRefDates table. The company (annual) financial data are stored in long format in the table “Financials” which has the following columns:

column_name	| data_type	| is_nullable
---|---|---
ID | int | NO
StockID | int | NO
ReportType | nvarchar | NO
ReportMonth | int | NO
ReportYear | int | NO
Item | nvarchar | NO
ItemValue | float | YES

I am only interested in rows where “Item” takes on a relatively small set of values such as “Net Profit after Tax Before Abnormals”, “Net Operating Cashflows”, “Total Assets” etc. I calculate a series of ratios based on these items. For any given firm, these ratios correspond to the end of the financial reporting period. Consequently, there is only one set of data points per firm per year – on the ASX most (but by no means all) of the data points correspond to a financial year end of June 30.

The financial ratios (1 data point per year) are then compiled into the “outputTable” table, which has the following columns:

column_name	| data_type	| is_nullable
---|---|---
StockID | int | NO
ReportMonth | int | NO
ReportYear | int | NO
B_P | float | YES
E_P | float | YES
ROE | float | YES
D_A | float | YES
CFO_A | float | YES
CFI_A | float | YES
CFF_A | float | YES
ACCRUALS | float | YES
EBITDA_EV | float | YES

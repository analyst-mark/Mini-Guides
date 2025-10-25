-- examples/verify.sql

SELECT COUNT(*) AS RowCount FROM dbo.DimDate;

SELECT MIN(CalendarDate) AS MinDate, MAX(CalendarDate) AS MaxDate FROM dbo.DimDate;

SELECT TOP 10 CalendarDate, ISOYear, ISOWeekNumber, WeekYearLabel
FROM dbo.DimDate
WHERE ISOYear <> CalendarYear
ORDER BY CalendarDate;

SELECT COUNT(DISTINCT MonthYearNumber) AS Months, COUNT(DISTINCT QuarterYearNumber) AS Quarters
FROM dbo.DimDate;

SELECT TOP 5 * FROM dbo.DimDate ORDER BY CalendarDate;
SELECT TOP 5 * FROM dbo.DimDate ORDER BY CalendarDate DESC;

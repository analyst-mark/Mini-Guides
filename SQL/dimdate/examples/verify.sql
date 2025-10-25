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



--- test
SELECT v.ColumnName, v.Value
FROM dbo.dimDate AS d
CROSS APPLY (VALUES
    ('DateKey',           CONVERT(varchar(20), d.DateKey)),
    ('CalendarDate',      CONVERT(varchar(10), d.CalendarDate, 120)),
    ('CalendarYear',      CONVERT(varchar(10), d.CalendarYear)),
    ('QuarterOfYear',     CONVERT(varchar(10), d.QuarterOfYear)),
    ('MonthOfYear',       CONVERT(varchar(10), d.MonthOfYear)),
    ('MonthName',         d.MonthName),
    ('MonthYear',         d.MonthYear),
    ('WeekOfYear',        CONVERT(varchar(10), d.WeekOfYear)),
    ('DayOfMonth',        CONVERT(varchar(10), d.DayOfMonth)),
    ('DayOfWeek',         CONVERT(varchar(10), d.DayOfWeek)),
    ('DayOfWeekName',     d.DayOfWeekName),
    ('IsWeekend',         CONVERT(varchar(1),  d.IsWeekend)),
    ('WeekEnding',        CONVERT(varchar(10), d.WeekEnding, 120)),
    ('MonthEnding',       CONVERT(varchar(10), d.MonthEnding, 120)),
    ('ISOWeekNumber',     CONVERT(varchar(10), d.ISOWeekNumber)),
    ('ISOYear',           CONVERT(varchar(10), d.ISOYear)),
    ('ISODayOfYear',      CONVERT(varchar(10), d.ISODayOfYear)),
    ('WeekYearLabel',     d.WeekYearLabel),
    ('WeekYearNumber',    CONVERT(varchar(10), d.WeekYearNumber)),
    ('MonthYearNumber',   CONVERT(varchar(10), d.MonthYearNumber)),
    ('QuarterYearNumber', CONVERT(varchar(10), d.QuarterYearNumber))
) AS v (ColumnName, Value)
WHERE d.CalendarDate = '2025-10-25';

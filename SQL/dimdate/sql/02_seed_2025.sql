-- 02_seed_2025.sql

DECLARE @StartDate DATE = '2025-01-01';
DECLARE @EndDate   DATE = '2025-12-31';

;WITH Dates AS (
    SELECT @StartDate AS [Date]
    UNION ALL
    SELECT DATEADD(DAY, 1, [Date]) FROM Dates WHERE [Date] < @EndDate
)
INSERT INTO dbo.DimDate (
    DateKey, CalendarDate, CalendarYear, QuarterOfYear, MonthOfYear, MonthName, MonthYear,
    WeekOfYear, DayOfMonth, DayOfWeek, DayOfWeekName, IsWeekend, WeekEnding, MonthEnding,
    ISOWeekNumber, ISOYear, ISODayOfYear, WeekYearLabel, WeekYearNumber,
    MonthYearNumber, QuarterYearNumber
)
SELECT
    CONVERT(INT, FORMAT([Date], 'yyyyMMdd')),
    [Date],
    YEAR([Date]),
    DATEPART(QUARTER, [Date]),
    MONTH([Date]),
    DATENAME(MONTH, [Date]),
    CONCAT(LEFT(DATENAME(MONTH, [Date]), 3), ' ', YEAR([Date])),
    DATEPART(WEEK, [Date]),
    DAY([Date]),
    ((DATEPART(WEEKDAY, [Date]) + @@DATEFIRST + 5) % 7 + 1),
    DATENAME(WEEKDAY, [Date]),
    CASE WHEN DATENAME(WEEKDAY, [Date]) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END,
    DATEADD(DAY, (7 - ((DATEPART(WEEKDAY, [Date]) + @@DATEFIRST - 2) % 7)), [Date]),
    EOMONTH([Date]),
    DATEPART(ISO_WEEK, [Date]),
    CASE 
        WHEN MONTH([Date]) = 1  AND DATEPART(ISO_WEEK, [Date]) >= 52 THEN YEAR([Date]) - 1
        WHEN MONTH([Date]) = 12 AND DATEPART(ISO_WEEK, [Date]) = 1  THEN YEAR([Date]) + 1
        ELSE YEAR([Date]) END,
    DATEPART(DAYOFYEAR, [Date]),
    CONCAT(
        CASE 
            WHEN MONTH([Date]) = 1  AND DATEPART(ISO_WEEK, [Date]) >= 52 THEN YEAR([Date]) - 1
            WHEN MONTH([Date]) = 12 AND DATEPART(ISO_WEEK, [Date]) = 1  THEN YEAR([Date]) + 1
            ELSE YEAR([Date]) END,
        '-W', RIGHT('0' + CAST(DATEPART(ISO_WEEK, [Date]) AS VARCHAR(2)), 2)
    ),
    (
        CASE 
            WHEN MONTH([Date]) = 1  AND DATEPART(ISO_WEEK, [Date]) >= 52 THEN YEAR([Date]) - 1
            WHEN MONTH([Date]) = 12 AND DATEPART(ISO_WEEK, [Date]) = 1  THEN YEAR([Date]) + 1
            ELSE YEAR([Date]) END
    ) * 100 + DATEPART(ISO_WEEK, [Date]),
    YEAR([Date]) * 100 + MONTH([Date]),
    YEAR([Date]) * 10 + DATEPART(QUARTER, [Date])
FROM Dates
OPTION (MAXRECURSION 0);

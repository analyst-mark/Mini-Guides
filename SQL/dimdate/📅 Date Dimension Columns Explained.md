

|**Column**|**Type**|**What It Means / How It’s Computed**|**Example (2025-04-01)**|
|---|---|---|---|
|`DateKey`|`INT`|Surrogate key in `YYYYMMDD` format (often generated as an integer).|`20250401`|
|`CalendarDate`|`DATE`|The actual calendar date.|`2025-04-01`|
|`CalendarYear`|`INT`|The year part of the date.|`2025`|
|`QuarterOfYear`|`TINYINT`|1–4, determined by the month:  <br>• Jan–Mar = 1  <br>• Apr–Jun = 2  <br>• Jul–Sep = 3  <br>• Oct–Dec = 4|`2`|
|`MonthOfYear`|`TINYINT`|Month number (1–12).|`4`|
|`MonthName`|`NVARCHAR(9)`|Full month name (localized).|`April`|
|`MonthYear`|`VARCHAR(12)`|Month name + year (formatted).|`April 2025`|
|`WeekOfYear`|`TINYINT`|Week number (1–53) based on standard calendar week (can vary by SQL `DATEPART(week, date)`).|`14`|
|`DayOfMonth`|`TINYINT`|Day number in the month (1–31).|`1`|
|`DayOfWeek`|`TINYINT`|Usually 1–7 (Monday=1 or Sunday=1, depending on convention).|`2` (if Monday=1)|
|`DayOfWeekName`|`NVARCHAR(9)`|Name of the weekday.|`Tuesday`|
|`IsWeekend`|`BIT`|`1` if Saturday or Sunday, else `0`.|`0`|
|`WeekEnding`|`DATE`|The date of the last day (e.g., Sunday) in that week.  <br>Computed: `DATEADD(DAY, 7 - DATEPART(WEEKDAY, CalendarDate), CalendarDate)` (depending on first-day-of-week setting).|`2025-04-06`|
|`MonthEnding`|`DATE`|The last day of the month.  <br>Can use: `EOMONTH(CalendarDate)`|`2025-04-30`|
|`ISOWeekNumber`|`INT`|ISO 8601 week number (1–53, Monday-based).|`14`|
|`ISOYear`|`INT`|ISO 8601 year (may differ from calendar year if near year boundary).|`2025`|
|`ISODayOfYear`|`INT`|Sequential day number of the year (1–366).|`91`|
|`WeekYearLabel`|`VARCHAR(10)`|Text label like `W14-2025` or `2025-W14`.|`2025-W14`|
|`WeekYearNumber`|`INT`|Combined numeric key for week/year (e.g., `YYYYWW`).|`202514`|
|`MonthYearNumber`|`INT`|Combined numeric key for month/year (e.g., `YYYYMM`).|`202504`|
|`QuarterYearNumber`|`INT`|Combined numeric key for quarter/year (e.g., `YYYYQ`).|`20252`|
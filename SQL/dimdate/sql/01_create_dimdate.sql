-- 01_create_dimdate.sql

IF OBJECT_ID('dbo.DimDate', 'U') IS NOT NULL
    DROP TABLE dbo.DimDate;

CREATE TABLE dbo.DimDate (
    DateKey             INT           NOT NULL PRIMARY KEY CLUSTERED,
    CalendarDate        DATE          NOT NULL UNIQUE,
    CalendarYear        INT           NOT NULL,
    QuarterOfYear       TINYINT       NOT NULL,
    MonthOfYear         TINYINT       NOT NULL,
    MonthName           NVARCHAR(9)   NOT NULL,
    MonthYear           VARCHAR(12)   NOT NULL,
    WeekOfYear          TINYINT       NOT NULL,
    DayOfMonth          TINYINT       NOT NULL,
    DayOfWeek           TINYINT       NOT NULL,
    DayOfWeekName       NVARCHAR(9)   NOT NULL,
    IsWeekend           BIT           NOT NULL,
    WeekEnding          DATE          NOT NULL,
    MonthEnding         DATE          NOT NULL,
    ISOWeekNumber       INT           NOT NULL,
    ISOYear             INT           NOT NULL,
    ISODayOfYear        INT           NOT NULL,
    WeekYearLabel       VARCHAR(10)   NOT NULL,
    WeekYearNumber      INT           NOT NULL,
    MonthYearNumber     INT           NOT NULL,
    QuarterYearNumber   INT           NOT NULL
);

CREATE NONCLUSTERED INDEX IX_DimDate_YearMonth ON dbo.DimDate (CalendarYear, MonthOfYear);
CREATE NONCLUSTERED INDEX IX_DimDate_YearQuarter ON dbo.DimDate (CalendarYear, QuarterOfYear);
CREATE NONCLUSTERED INDEX IX_DimDate_ISOYearWeek ON dbo.DimDate (ISOYear, ISOWeekNumber);
CREATE NONCLUSTERED INDEX IX_DimDate_Weekend ON dbo.DimDate (IsWeekend);
CREATE NONCLUSTERED INDEX IX_DimDate_MonthYearNumber ON dbo.DimDate (MonthYearNumber);
CREATE NONCLUSTERED INDEX IX_DimDate_WeekYearNumber ON dbo.DimDate (WeekYearNumber);

# Overview

This T‑SQL script bulk‑loads one or more NHS appointment CSV files from a local Windows folder into a _bronze_ landing table, with staging, validation, and logging. It is designed to be re‑runnable and to handle both CRLF and LF line endings.

---

## Objects & Paths Touched

- **Folder (input):** `C:\Users\mark\Documents\GitHub\GP Appointments Data Warehouse & Analytics - v2\data sets\`
    
- **Temp tables:** `#files`, `#lc`
    
- **Tables:**
    
    - `bronze.nhs_appointments_stage` (truncate/load per file)
        
    - `bronze.nhs_appointments_raw` (final append target; truncated at run start)
        
    - `dbo.load_log_nhs_appointments` (run log per file)
        
- **Extended stored proc:** `xp_cmdshell` (used to list files and count lines)
    

> **Note:** `xp_cmdshell` must be enabled for this to work. Consider using an agent proxy / least‑privilege account.

---

## High‑Level Flow

1. **Set input folder** via `@Folder` variable.
    
2. **Reset final landing table** with `TRUNCATE TABLE bronze.nhs_appointments_raw` (remove this if you need to append across runs).
    
3. **Build file list**
    
    - Create `#files` and populate it with `EXEC xp_cmdshell 'dir /b "...*.csv"'`.
        
    - Delete null/blank rows (xp_cmdshell often returns extra rows).
        
4. **Iterate files** with a FAST_FORWARD cursor over `#files`.
    
5. **Estimate expected row count per file**
    
    - For each file, execute: `cmd /c type "<file>" | find /v /c ""` into `#lc` to count physical lines.
        
    - Convert the first numeric result to `@expected` and subtract **1** for the CSV header.
        
6. **Stage‑table load (two attempts)**
    
    - **Attempt 1 (CRLF):**
        
        ```sql
        BULK INSERT bronze.nhs_appointments_stage
        FROM '<file>'
        WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0d0a', TABLOCK);
        ```
        
        Capture `@@ROWCOUNT` into `@inserted`.
        
    - **If mismatch**, retry **Attempt 2 (LF only):**
        
        ```sql
        BULK INSERT bronze.nhs_appointments_stage
        FROM '<file>'
        WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);
        ```
        
7. **Log the outcome** to `dbo.load_log_nhs_appointments` per file with:
    
    - `file_name` = short file name (no path)
        
    - `expected_rows` (from step 5)
        
    - `inserted_rows` (from BULK INSERT)
        
    - `attempt` = `'CRLF'` or `'LF'` or `'ERROR'`
        
    - `status` = `'OK'` or `'MISMATCH'` or `'ERROR'`
        
    - `err_msg` (only on catch)
        
8. **Promote to final**
    
    - Insert all rows from `bronze.nhs_appointments_stage` into `bronze.nhs_appointments_raw`, stamping `SourceFile` with the short file name `@f`.
        
9. **Repeat** for all files.
    
10. **Summary checks**
    
    - `SELECT COUNT(*)` across the final table.
        
    - Grouped row counts by `SourceFile`, with an example filter for files containing `'feb'`.
        

---

## Column Mapping (Stage → Final)

The script expects the staging table to have the following columns, loaded 1:1 into the final table:

- `SUB_ICB_LOCATION_CODE`
    
- `SUB_ICB_LOCATION_ONS_CODE`
    
- `SUB_ICB_LOCATION_NAME`
    
- `ICB_ONS_CODE`
    
- `REGION_ONS_CODE`
    
- `Appointment_Date`
    
- `APPT_STATUS`
    
- `HCP_TYPE`
    
- `APPT_MODE`
    
- `TIME_BETWEEN_BOOK_AND_APPT`
    
- `COUNT_OF_APPOINTMENTS`
    
- `SourceFile` _(added on insert to final)_
    

> Ensure the CSV header exactly matches the staging schema order/types (except `SourceFile`, which is not in the CSV).

---

## Error Handling

- Wrapped in `TRY…CATCH` per file.
    
- On any error:
    
    - Log a row with `attempt='ERROR'`, `status='ERROR'`, `inserted_rows=0`, and `err_msg=ERROR_MESSAGE()`.
        
    - Move on to the next file (no hard stop).
        

---

## Validation Logic

- **Expected vs Inserted:** Compares CSV physical lines minus header to inserted rows.
    
- **Line Endings:** Falls back from CRLF to LF to accommodate Unix‑style exports.
    
- **Post‑Load Summaries:** Provides total row count and per‑file counts for quick sanity checks.
    

---

## Operational Notes

- **Idempotency:** The final table is truncated at the start; re‑running will replace data. Remove that truncate if you need cumulative loads.
    
- **Performance:**
    
    - `TABLOCK` is used for faster `BULK INSERT`.
        
    - Staging is truncated before each file to minimize logging and simplify promotion.
        
- **Security:**
    
    - `xp_cmdshell` requires elevated permissions; consider alternatives (e.g., SSIS, PowerShell via Agent, or external table with PolyBase) in locked‑down environments.
        
- **File Names:** The log and `SourceFile` store only the base name (e.g., `appointments_2025_02.csv`), not the full path.
    

---

## Prerequisites & Assumptions

- SQL Server instance with `xp_cmdshell` **enabled** and permission to read the specified folder.
    
- The `bronze.nhs_appointments_stage` and `bronze.nhs_appointments_raw` tables exist with compatible schemas.
    
- The `dbo.load_log_nhs_appointments` table exists with at least the columns used in the `INSERT` statements above.
    
- CSVs have a single header row and are comma‑delimited.
    

---

## Suggested Enhancements (Optional)

- **Schema‑bound format file** to lock column order/types and handle text qualifiers.
    
- **Automated delimiter/qualifier detection** (e.g., handle `"` quotes, embedded commas, or UTF‑8 BOM via `CODEPAGE='65001'`).
    
- **Hash/checksum** per file and per batch for traceability.
    
- **Transactional batch** per file (wrap stage+final insert in one explicit transaction) if you want all‑or‑nothing per file.
    
- **Disable/Enable nonclustered indexes** on final table around the load if present.
    
- **Centralised config** table for folder path and patterns instead of hard‑coding.
    
- **Replace cursor** with set‑based pattern using `OPENROWSET(BULK...)` over a discovered file list when possible.
    

---

## How to Rerun Safely

1. Confirm the folder path is correct in `@Folder`.
    
2. Ensure no other sessions are using the stage/final tables.
    
3. Run the script end‑to‑end. Review `dbo.load_log_nhs_appointments` and the summary queries.
    
4. If any file shows `MISMATCH`, open the CSV to confirm header/encoding/line endings and adjust BULK options (e.g., `ROWTERMINATOR`, `CODEPAGE`).
    

---

## Quick Reference – Key Commands

- **List files:** `EXEC xp_cmdshell 'dir /b "<folder>*.csv"'`
    
- **Count lines:** `cmd /c type "<file>" | find /v /c ""`
    
- **Bulk load (CRLF):** `ROWTERMINATOR='0x0d0a'`
    
- **Bulk load (LF):** `ROWTERMINATOR='0x0a'`
    
- **Start at data row:** `FIRSTROW=2`
    

---

**End of notes.**



```SQL

  

--- Set your folder:

DECLARE @Folder NVARCHAR(max) =

N'C:\Users\mark\Documents\GitHub\GP Appointments Data Warehouse & Analytics - v2\data sets\';

  

-- Start with a clean final table (remove if appending):

TRUNCATE TABLE bronze.nhs_appointments_raw;

  

-- Get file list

IF OBJECT_ID('tempdb..#files') IS NOT NULL DROP TABLE #files;

CREATE TABLE #files (file_name NVARCHAR(max));

  

INSERT INTO #files(file_name)

EXEC xp_cmdshell 'dir /b "C:\Users\mark\Documents\GitHub\GP Appointments Data Warehouse & Analytics - v2\data sets\*.csv"';

  

DELETE FROM #files WHERE file_name IS NULL OR LTRIM(RTRIM(file_name)) = '';

  

DECLARE @f NVARCHAR(max), @full NVARCHAR(max);

DECLARE @expected INT, @inserted INT, @cmd NVARCHAR(max), @msg NVARCHAR(2000);

  

DECLARE cur CURSOR FAST_FORWARD FOR SELECT file_name FROM #files;

OPEN cur; FETCH NEXT FROM cur INTO @f;

  

WHILE @@FETCH_STATUS = 0

BEGIN

SET @full = @Folder + @f;

  

/* ----- count lines in file: type "file" | find /v /c "" ----- */

IF OBJECT_ID('tempdb..#lc') IS NOT NULL DROP TABLE #lc;

CREATE TABLE #lc (ln NVARCHAR(max));

SET @cmd = N'cmd /c type "' + @full + N'" ^| find /v /c ""';

INSERT INTO #lc(ln) EXEC xp_cmdshell @cmd;

-- find the numeric line

SELECT TOP (1) @expected = TRY_CONVERT(INT, ln) FROM #lc WHERE TRY_CONVERT(INT, ln) IS NOT NULL;

-- subtract header

SET @expected = ISNULL(@expected,0) - 1;

  

BEGIN TRY

/* ----- try CRLF first ----- */

TRUNCATE TABLE bronze.nhs_appointments_stage;

  

SET @cmd = N'

BULK INSERT bronze.nhs_appointments_stage

FROM ''' + @full + N'''

WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0d0a'', TABLOCK);';

EXEC(@cmd);

  

SET @inserted = @@ROWCOUNT;

  

IF (@inserted <> @expected)

BEGIN

/* ----- retry with LF ----- */

TRUNCATE TABLE bronze.nhs_appointments_stage;

  

SET @cmd = N'

BULK INSERT bronze.nhs_appointments_stage

FROM ''' + @full + N'''

WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', TABLOCK);';

EXEC(@cmd);

  

SET @inserted = @@ROWCOUNT;

  

INSERT INTO dbo.load_log_nhs_appointments(file_name, expected_rows, inserted_rows, attempt, status)

VALUES (@f, @expected, @inserted, 'LF', IIF(@inserted=@expected,'OK','MISMATCH'));

END

ELSE

BEGIN

INSERT INTO dbo.load_log_nhs_appointments(file_name, expected_rows, inserted_rows, attempt, status)

VALUES (@f, @expected, @inserted, 'CRLF', 'OK');

END

  

/* ----- move from stage to final and stamp source file ----- */

INSERT INTO bronze.nhs_appointments_raw

(

SUB_ICB_LOCATION_CODE, SUB_ICB_LOCATION_ONS_CODE, SUB_ICB_LOCATION_NAME,

ICB_ONS_CODE, REGION_ONS_CODE, Appointment_Date, APPT_STATUS, HCP_TYPE,

APPT_MODE, TIME_BETWEEN_BOOK_AND_APPT, COUNT_OF_APPOINTMENTS, SourceFile

)

SELECT

SUB_ICB_LOCATION_CODE, SUB_ICB_LOCATION_ONS_CODE, SUB_ICB_LOCATION_NAME,

ICB_ONS_CODE, REGION_ONS_CODE, Appointment_Date, APPT_STATUS, HCP_TYPE,

APPT_MODE, TIME_BETWEEN_BOOK_AND_APPT, COUNT_OF_APPOINTMENTS, @f

FROM bronze.nhs_appointments_stage;

END TRY

BEGIN CATCH

SET @msg = ERROR_MESSAGE();

INSERT INTO dbo.load_log_nhs_appointments(file_name, expected_rows, inserted_rows, attempt, status, err_msg)

VALUES (@f, @expected, 0, 'ERROR', 'ERROR', @msg);

END CATCH;

  

FETCH NEXT FROM cur INTO @f;

END

CLOSE cur; DEALLOCATE cur;

  

-- Summary checks

SELECT COUNT(*) AS total_rows_loaded FROM bronze.nhs_appointments_raw;

SELECT SourceFile, COUNT(*) rows

FROM bronze.nhs_appointments_raw

WHERE sourcefile LIKE '%feb%'

GROUP BY SourceFile

ORDER BY SourceFile;
```
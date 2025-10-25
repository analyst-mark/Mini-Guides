
# Import CSVs into SQL Server with Python (Beginner Guide)

This walks through your exact approach:

- `pyodbc` + `SQLAlchemy` engine with an **ODBC Driver 18** DSN-less string
- Ensure database exists
- Create `dbo.appointments` (if missing)
- Read many CSVs from a folder in **chunks**, clean headers, **append/replace** into SQL with **fast_executemany** and **tqdm** progress

I’ve also added:

- Guardrails (asserts, readable errors)
- Optional schema/type control
- Basic data validation & encoding tips
- Post-load verification

---

## 0) Install prerequisites

```bash
pip install pandas sqlalchemy pyodbc tqdm

```

Install **ODBC Driver 18 for SQL Server** (Windows/macOS/Linux). If you hit TLS trust issues locally, you can temporarily use `Encrypt=no` (not for production) or `TrustServerCertificate=yes`.

---

## 1) Verify the ODBC driver is visible

```python
import pyodbc
print(pyodbc.drivers())

```

You should see `"ODBC Driver 18 for SQL Server"` in the list.

---

## 2) Your exact engine/connection (kept as-is)

> Uses your Trusted_Connection and TrustServerCertificate flags and the quote_plus(odbc_str) pattern.
> 

```python
from sqlalchemy import create_engine, text
from urllib.parse import quote_plus

odbc_str = (
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=NUCBOX_K8_PLUS\\MSSQLSERVER01;"
    "Database=practice;"                     # change if you want a specific DB
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={quote_plus(odbc_str)}",
    fast_executemany=True
)

with engine.connect() as conn:
    print(conn.execute(text("SELECT @@VERSION")).scalar())

```

> Tip: If you see SSL errors on dev machines, driver 18 is stricter. For local-only testing you can switch to Encrypt=no instead of TrustServerCertificate=yes. For production, use proper TLS.
> 

---

## 3) Ensure the database exists (your block)

```python
from sqlalchemy import text

TARGET_DB = "practice"  # change if you want another name

# run in AUTOCOMMIT mode (no explicit transaction)
with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as conn:
    conn.execute(text(f"IF DB_ID(N'{TARGET_DB}') IS NULL CREATE DATABASE [{TARGET_DB}]"))

print("Database ready:", TARGET_DB)

```

---

## 4) Create the target table if it’s missing

> Your notebook includes a DDL for dbo.appointments. The upload I read has elided lines (...) in the middle of that cell, so below is a faithful reconstruction that preserves your table name and key columns you listed (SUB_ICB_LOCATION_CODE, REGION_ONS_CODE, Appointment_Date, APPT_STATUS, HCP_TYPE, APPT_MODE, TIME_BETWEEN_BOOK_AND_APPT, COUNT_OF_APPOINTMENTS).
> 
> 
> If you have a slightly different DDL in your copy, paste it into `ddl` directly — the rest of this guide still works.
> 

```python
from sqlalchemy import text

TABLE = "appointments"

ddl = f"""
IF OBJECT_ID('dbo.{TABLE}') IS NULL
BEGIN
    CREATE TABLE dbo.{TABLE}(
        SUB_ICB_LOCATION_CODE        varchar(8)    NULL,
        SUB_ICB_LOCATION_ONS_CODE    varchar(16)   NULL,
        SUB_ICB_LOCATION_NAME        varchar(200)  NULL,
        ICB_ONS_CODE                 varchar(16)   NULL,
        REGION_ONS_CODE              varchar(16)   NULL,
        Appointment_Date             date          NULL,
        APPT_STATUS                  varchar(64)   NULL,
        HCP_TYPE                     varchar(64)   NULL,
        APPT_MODE                    varchar(64)   NULL,
        TIME_BETWEEN_BOOK_AND_APPT   varchar(32)   NULL,
        COUNT_OF_APPOINTMENTS        int           NULL
        -- add any other columns your CSVs contain (match names you use below)
    );
END
"""

with engine.begin() as conn:
    conn.execute(text(ddl))

print(f"Table ready: dbo.{TABLE}")

```

> ⚠️ If any column names collide with SQL reserved keywords (e.g., Date), either rename in Python or bracket them like [Date].
> 

---

## 5) Configure your CSV intake (your variables + a few helpful comments)

```python
import os, glob
import pandas as pd
from sqlalchemy import text

# 🔧 EDIT THESE
CSV_FOLDER = r"C:\Users\mark\Downloads\test"   # folder containing all CSVs
FILE_PATTERN = "*.csv"                          # e.g., 'appointments_*.csv'

# Chunking (tune for your RAM / speed)
READ_CHUNKSIZE   = 100_000   # rows read from CSV per iteration
WRITE_BATCH_SIZE = 50_000    # rows per execute when writing to SQL

# Column order to match dbo.appointments (must align with your table schema)
ORDERED_COLS = [
    "SUB_ICB_LOCATION_CODE",
    "SUB_ICB_LOCATION_ONS_CODE",
    "SUB_ICB_LOCATION_NAME",
    "ICB_ONS_CODE",
    "REGION_ONS_CODE",
    "Appointment_Date",
    "APPT_STATUS",
    "HCP_TYPE",
    "APPT_MODE",
    "TIME_BETWEEN_BOOK_AND_APPT",
    "COUNT_OF_APPOINTMENTS",
    # include any additional columns here, in the exact order you want in SQL
]

def normalize_columns(cols):
    """Make CSV headers SQL-friendly and consistent with table columns."""
    return [
        c.strip()
         .replace(" ", "_")
         .replace("-", "_")
         .replace("/", "_")
         .replace("#", "")
        for c in cols
    ]

```

---

## 6) Loop through all CSVs, clean headers, and load in chunks (your structure + extras)

> This preserves your Path + glob, tqdm progress bars, to_sql with fast_executemany, and adds:
> 
> - file-level and row-level counters
> - automatic column normalization & selection
> - optional **date parsing**
> - **encoding fallback** (`utf-8-sig` → `latin-1`)
> - a small **data sanity check** (row counts)

```python
from pathlib import Path
from tqdm import tqdm
import pandas as pd
from sqlalchemy import text

base = Path(CSV_FOLDER)

# Find CSVs (case-insensitive)
files = [str(p) for p in base.glob("*.csv")] + [str(p) for p in base.glob("*.CSV")]
files = sorted(files)
assert files, f"No CSV files found in {CSV_FOLDER}"

overall_rows = 0
overall_bar = tqdm(total=len(files), desc="Files", unit="file")

for fpath in files:
    name = Path(fpath).name
    file_rows_written = 0
    tqdm.write(f"→ {name}")

    # Try UTF-8 with BOM first (common from Excel), fallback to latin-1 if needed
    encodings_to_try = ["utf-8-sig", "latin-1"]
    reader = None
    last_err = None

    for enc in encodings_to_try:
        try:
            reader = pd.read_csv(
                fpath,
                chunksize=READ_CHUNKSIZE,
                encoding=enc,
                # If you want pandas to parse a date column automatically:
                # parse_dates=["Appointment_Date"],
            )
            break
        except Exception as e:
            last_err = e
            continue

    if reader is None:
        raise RuntimeError(f"Failed to open {name} with encodings {encodings_to_try}. Last error: {last_err}")

    row_bar = tqdm(desc=f"{name} rows", unit="row", leave=False)

    for chunk in reader:
        # normalize and align columns
        chunk.columns = normalize_columns(chunk.columns)

        # Select only expected columns (in ORDERED_COLS order)
        missing = [c for c in ORDERED_COLS if c not in chunk.columns]
        if missing:
            # Add missing columns as NULLs (NaN) so to_sql doesn't fail
            for c in missing:
                chunk[c] = pd.NA

        extra = [c for c in chunk.columns if c not in ORDERED_COLS]
        # Optionally drop unexpected columns to keep schema tidy
        if extra:
            chunk = chunk[ORDERED_COLS]

        # Light cleanups (examples—customize to your data):
        # - Parse dates reliably
        if "Appointment_Date" in chunk.columns:
            chunk["Appointment_Date"] = pd.to_datetime(chunk["Appointment_Date"], errors="coerce").dt.date

        # - Ensure numeric type for counts
        if "COUNT_OF_APPOINTMENTS" in chunk.columns:
            chunk["COUNT_OF_APPOINTMENTS"] = pd.to_numeric(chunk["COUNT_OF_APPOINTMENTS"], errors="coerce").astype("Int64")

        # write the chunk
        with engine.begin() as conn:
            chunk.to_sql(
                name=TABLE,
                con=conn,
                schema="dbo",
                index=False,
                if_exists="append",    # use "replace" only for first load if you want a fresh table
                chunksize=WRITE_BATCH_SIZE,
                method=None            # fastest with pyodbc + fast_executemany (set on engine)
            )

        # update counters
        file_rows_written += len(chunk)
        overall_rows += len(chunk)
        row_bar.update(len(chunk))

    row_bar.close()
    overall_bar.update(1)
    tqdm.write(f"✔ {name}: {file_rows_written:,} rows inserted")

overall_bar.close()
print(f"\n✅ Done — inserted ~{overall_rows:,} rows into dbo.{TABLE}.")

```

> Speed tips:
> 
> 
> • Keep `fast_executemany=True` (you already do)
> 
> • Use larger `READ_CHUNKSIZE`/`WRITE_BATCH_SIZE` if memory allows (e.g., 250k / 100k).
> 
> • If re-loading a table from scratch, `IF EXISTS DROP TABLE` + single pass `to_sql(if_exists="replace")` is often faster than appending to an indexed table.
> 

---

## 7) (Optional) Control SQL types explicitly

If you want tighter control (e.g., `VARCHAR(200)`, `INT`, `DATE`) when **creating** a table with `to_sql`:

```python
from sqlalchemy import NVARCHAR, Integer, Date, Numeric

dtype_map = {
    "SUB_ICB_LOCATION_CODE": NVARCHAR(8),
    "SUB_ICB_LOCATION_ONS_CODE": NVARCHAR(16),
    "SUB_ICB_LOCATION_NAME": NVARCHAR(200),
    "ICB_ONS_CODE": NVARCHAR(16),
    "REGION_ONS_CODE": NVARCHAR(16),
    "Appointment_Date": Date(),
    "APPT_STATUS": NVARCHAR(64),
    "HCP_TYPE": NVARCHAR(64),
    "APPT_MODE": NVARCHAR(64),
    "TIME_BETWEEN_BOOK_AND_APPT": NVARCHAR(32),
    "COUNT_OF_APPOINTMENTS": Integer(),
}

```

Then call:

```python
chunk.to_sql(
    name=TABLE,
    con=conn,
    schema="dbo",
    index=False,
    if_exists="replace",   # only on first creation pass
    chunksize=WRITE_BATCH_SIZE,
    dtype=dtype_map
)

```

After the first creation, switch to `if_exists="append"`.

---

## 8) Post-load checks (quick sanity)

```python
from sqlalchemy import text

with engine.connect() as conn:
    total = conn.execute(text(f"SELECT COUNT(*) FROM dbo.{TABLE}")).scalar()
    sample = conn.execute(text(f"SELECT TOP (5) * FROM dbo.{TABLE} ORDER BY (SELECT NULL)")).fetchall()

print("Row count:", total)
for row in sample:
    print(row)

```

---

## 9) Common troubleshooting

- **Driver not found / DSN errors**: Ensure `"ODBC Driver 18 for SQL Server"` is installed and spelled exactly.
- **TLS/Certificate errors**: For dev, `TrustServerCertificate=yes` (as you used) can help. For production, use proper certificates.
- **Login failed**: Check instance name `NUCBOX_K8_PLUS\\MSSQLSERVER01`, database, and authentication mode.
- **Type conversion**: Use `pd.to_datetime`, `pd.to_numeric`, and/or `dtype_map`.
- **Reserved keywords**: Bracket them (`[Date]`) or rename columns in Python.
- **Slow loads**: Keep `fast_executemany=True`, raise chunk sizes, avoid heavy indexes during massive inserts.

## 10) What I added (summary)

- Encoding fallback + clearer errors
- Column normalization & alignment against your `ORDERED_COLS`
- Date & numeric coercion examples
- File/row progress bars with totals
- Post-load sanity checks
- Optional `dtype` mapping for strong schemas

If you’d like, I can **export this guide as a PDF or DOCX**, or **package the final Python as a single script** that mirrors your notebook (same variables) for scheduled runs.
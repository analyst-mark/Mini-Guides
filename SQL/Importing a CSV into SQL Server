# Importing a CSV into SQL Server with `BULK INSERT`

This guide shows how to import a CSV file into SQL Server using `BULK INSERT`, using an NHS GP Appointments dataset as an example. It’s written to be dropped straight into a GitHub repo (e.g. as `README.md`).

---

## 1. Prerequisites

Before you start, make sure:

- You have **SQL Server** (or SQL Server Express) installed.
- You can connect using **SQL Server Management Studio (SSMS)** or Azure Data Studio.
- Your login has permission to:
  - Create tables (or at least insert into the target table).
  - Run `BULK INSERT`.
- The SQL Server service account can **access the CSV file path**:
  - If SQL Server is running on your machine, a local path like `C:\...` is fine.
  - If SQL Server is on a different server, the file must be on that server or on a shared/network drive it can access.

---

## 2. Create the Target Table

Run this script in your target database (e.g. `USE YourDatabaseName;` first).

```sql
CREATE TABLE dbo.tests (
    SUB_ICB_LOCATION_CODE        VARCHAR(20),
    SUB_ICB_LOCATION_ONS_CODE    VARCHAR(20),
    SUB_ICB_LOCATION_NAME        VARCHAR(255),
    ICB_ONS_CODE                 VARCHAR(20),
    REGION_ONS_CODE              VARCHAR(20),

    -- Stored as text in the source CSV with values like '01APR2025'.
    -- You can keep as VARCHAR or later convert to a proper DATE column.
    Appointment_Date             VARCHAR(20),

    APPT_STATUS                  VARCHAR(50),
    HCP_TYPE                     VARCHAR(100),
    APPT_MODE                    VARCHAR(50),
    TIME_BETWEEN_BOOK_AND_APPT   VARCHAR(50),
    COUNT_OF_APPOINTMENTS        INT
);

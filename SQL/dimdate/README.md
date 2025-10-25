# DimDate (SQL Server)

A lightweight, ISO-aware date dimension table for SQL Server.  
Includes helpful derived columns and indexes for analytics and reporting.

## Structure

```
dimdate/
├─ README.md
├─ sql/
│  ├─ 01_create_dimdate.sql
│  └─ 02_seed_2025.sql
└─ examples/
   └─ verify.sql
```

## Quickstart

1. Run `sql/01_create_dimdate.sql` to create the table and indexes.
2. Run `sql/02_seed_2025.sql` to populate it for the year 2025.
3. Check your results with `examples/verify.sql`.

Expected results for 2025:
- 365 rows
- Range: 2025‑01‑01 → 2025‑12‑31
- ISO rollover: 2025‑12‑29 to 2025‑12‑31 → ISO year 2026, week 1.

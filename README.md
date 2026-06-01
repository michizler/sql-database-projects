# SQL Server Database Design & Analytics

Two production-style SQL Server projects built end to end in T-SQL: a normalised online-banking transactional database, and an analytics workload over real NHS prescribing data. Together they span the full database lifecycle, from relational design and normalisation, through programmable objects (stored procedures, functions, views, triggers), to analytical querying and business reporting.

**Stack:** Microsoft SQL Server, T-SQL, SQL Server Management Studio (SSMS)

> For the business problem behind each project and how the solution addresses it, see [PROJECT_BRIEF.md](project_brief.md).

---

## Repository structure

```
.
├── 01-online-bank-db/              # OLTP design, implementation & management
│   ├── sql/online_bank_db.sql      # Full build script: schema, data, objects, tests
│   ├── diagrams/erd.png            # Entity-relationship diagram
│   └── backup/OnlineBankDB.bak     # SQL Server backup (restore to reproduce)
├── 02-prescriptions-db/            # Analytics on NHS prescribing data
│   ├── data/                       # Source CSV files (NHS Bolton extract)
│   │   ├── Medical_Practice.csv
│   │   ├── Drugs.csv
│   │   ├── Prescriptions.csv
│   │   └── Prescription_Summary.csv
│   ├── sql/prescriptions_db.sql
│   ├── diagrams/schema.png
│   └── backup/PrescriptionsDB.bak
├── report/                         # Full technical report (design rationale, results)
│   ├── full_report.pdf
│   └── full_report.docx
├── PROJECT_BRIEF.md
└── README.md
```

---

## Project 1: Online Banking Database

A transactional database for a retail online bank, designed from a business requirements specification and normalised to Third Normal Form (3NF). The schema manages customers, accounts, transactions, overdue fees, and repayments, and is built to keep balances and transaction records accurate under high daily transaction volume.

![ERD](01-online-bank-db/diagrams/erd.png)

**Design**

- 9 related tables (`Customer`, `Address`, `Account`, `AccountType`, `CustomerAccount`, `Transaction`, `OverdueFee`, `Repayment`, `ArchivedCustomer`).
- `Address` separated from `Customer` to remove a transitive dependency; `AccountType` extracted into a lookup table so new account types can be added without schema change.
- Tables created in dependency order so every foreign key references an existing object.
- Integrity enforced through `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` constraints (email-format validation, minimum-age rule, restricted account-type values).
- Credentials stored as a salted hash (`BINARY(64)` with a `UNIQUEIDENTIFIER` salt) rather than plain text.

**Programmable objects**

- Stored procedures: search accounts by name (most recent first), insert a new customer with address handling, update an existing customer.
- User-defined function: returns loan and credit payments due within 5 days.
- View: a snapshot of all transactions carrying overdue fees.
- Triggers: auto-close a loan or credit-card account when its final payment completes; archive a customer record on deactivation while retaining it for marketing.
- A full test suite exercising every object, with before/after table states.

**Operational guidance** (in the report): data integrity and concurrency, database security, and backup and recovery, each applied to this specific banking scenario.

---

## Project 2: NHS Prescribing Data Analytics

Querying and analysis over a real NHS prescribing dataset for the Bolton region, framed around the needs of a pharmaceutical company that wants to understand which medications are prescribed, by which organisations, and in what quantities.

![Schema](02-prescriptions-db/diagrams/schema.png)

### Data

The `02-prescriptions-db/data/` folder holds the four source CSVs, a monthly extract of real prescribing data published by the NHS in England, narrowed to Bolton:

| File                       | Records | Description                                                                                                                                     |
| -------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `Medical_Practice.csv`     | 60      | Practice names and addresses; `PRACTICE_CODE` is the unique identifier.                                                                         |
| `Drugs.csv`                | many    | Drug details including chemical substance and product description, categorised by `BNF_CHAPTER_PLUS_CODE`; `BNF_CODE` is the unique identifier. |
| `Prescriptions.csv`        | many    | One row per prescription, linked to a practice (`PRACTICE_CODE`) and a drug (`BNF_CODE`), with `ITEMS`, `QUANTITY`, and `ACTUAL_COST`.          |
| `Prescription_Summary.csv` | many    | A derived reporting table summarising cost, items, and quantity per practice and `REPORT_MONTH`.                                                |

### Analysis

- CSV import, then primary and foreign keys added across `Medical_Practice`, `Drugs`, `Prescriptions`, and `Prescription_Summary`.
- Filtering and aggregation: drugs by form, rounded total quantity per prescription, and cost statistics (count, average, min, max) per BNF chapter.
- Window functions (`ROW_NUMBER`) to surface the most-prescribed chemical substance per month.
- Correlated subqueries to find each practice's single most expensive prescription (above a £4,000 threshold).
- Outlier detection using z-scores (cost more than three standard deviations above a drug's mean) to flag potentially erroneous prescriptions.
- Month-on-month trend analysis using self-joins to compute volume and percentage change per practice.

Each analytical query is paired with a business interpretation: specialist-clinic targeting, bulk-purchasing opportunities, anomaly investigation, and supply planning.

---

## How to reproduce

**Option A: restore from backup (fastest)**

1. In SSMS: _Databases_ → _Restore Database_ → _Device_, then select the `.bak` file from the relevant `backup/` folder.
2. Restore as `OnlineBankDB` or `PrescriptionsDB`.

**Option B: run the scripts**

1. Open the `.sql` file from the project's `sql/` folder in SSMS.
2. Execute top to bottom. The script creates the database, schema, sample data, and all objects.
3. For Project 2, import the four CSVs from `data/` via the Import Flat File Wizard before running the constraint and query sections. Column names are kept exactly as they appear in the source files so the scripts re-run cleanly.

---

## Skills demonstrated

Relational database design and 3NF normalisation, entity-relationship modelling, T-SQL implementation of tables, views, stored procedures, user-defined functions and triggers, constraint-based data integrity, transaction and concurrency considerations, database security and recovery planning, and advanced analytical querying (joins, subqueries, window functions, statistical outlier detection) on a real-world dataset.

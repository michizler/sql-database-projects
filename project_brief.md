# Project Brief

This repository contains two SQL Server projects built to real-world business briefs. Each was approached as a database consultant would: understand the business need, design or model the data, then implement and query it in T-SQL. This document explains the problem each project solves and how the solution addresses it. For setup and file structure, see the [README](README.md).

---

## Project 1: Online Banking Database

### The problem

An online bank is building a new database system to run its core operations. It needs to store customers, the accounts and products they hold, the transactions they make, the fees charged on late payments, and the repayments against those fees. The system has to track customer activity, account balances, and overdue payments accurately, because the bank processes hundreds of transactions a day and transaction detail and balances are business-critical. Closed accounts must be retained for marketing, and repayments must be recorded with date, amount, and method.

In short: design a database that is correct, keeps its data trustworthy under heavy use, and enforces the bank's business rules automatically rather than relying on application code or manual checks.

### The solution

A relational database normalised to Third Normal Form, with integrity and business rules pushed down into the database itself.

- **A clean schema.** Nine tables model customers, addresses, accounts, account types, the link between customers and accounts, transactions, overdue fees, and repayments. Address and account type are separated into their own tables so the design avoids duplication and adapts to future change.
- **Rules enforced at the data layer.** Constraints guarantee valid email formats, a minimum customer age, unique usernames, and a fixed set of account types and statuses, so bad data cannot enter the system in the first place.
- **Security by design.** Passwords are never stored in plain text; they are kept as a salted hash, the approach a real banking system would require.
- **Automation through triggers.** A trigger closes a loan or credit-card account the moment its final payment clears, and another archives a customer's record when they are deactivated, retaining it for marketing as the brief requires. These behaviours happen automatically and consistently.
- **Reusable access logic.** Stored procedures and a function handle common operations (searching accounts, finding payments due soon, onboarding and updating customers), and a view exposes transactions with their overdue fees for reporting.

### What it demonstrates

The work shows database design judgement (normalisation and modelling), the ability to enforce complex business rules in T-SQL, and an understanding of the operational concerns a real bank would care about: data integrity, concurrency, security, and recovery.

---

## Project 2: NHS Prescribing Data Analytics

### The problem

A pharmaceutical company wants to understand prescribing behaviour. Using a real monthly NHS dataset (here, an extract covering the Bolton region), it needs to know what medications are being prescribed, which practices are doing the prescribing, in what quantities, and at what cost. The goal is to turn four related raw data files into answers that can support commercial decisions, for example which drugs to negotiate bulk discounts on, which prescriptions look anomalous, and how prescribing is trending over time.

### The solution

A structured analytics workload built on top of the imported data.

- **A queryable foundation.** The four CSV files are imported and connected with primary and foreign keys so practices, drugs, prescriptions, and the monthly summary can be analysed together reliably.
- **Direct answers to business questions.** Queries return cost statistics per drug category, the most-prescribed substance each month, and each practice's most expensive prescription above a spending threshold.
- **Finding what matters commercially.** Additional analyses identify likely specialist practices (useful for targeted marketing), high-volume drugs prescribed across many practices (candidates for bulk-purchasing agreements), statistical outliers that may indicate data-entry errors or exceptional cases, and month-on-month changes in prescribing volume that signal shifting demand.

Each query is accompanied by a short explanation of the business reason for running it and how to read the result.

### What it demonstrates

The work shows the ability to take messy, real-world data and make it analysable, and to write advanced SQL (joins, subqueries, grouping, window functions, and statistical techniques such as z-score outlier detection) that produces insight a business can act on, not just rows of data.

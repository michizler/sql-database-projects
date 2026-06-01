-- ============================================================
-- TASK 2: PRESCRIPTIONS DATABASE
-- ============================================================


-- ============================================================
-- PART 1: CREATE DATABASE AND IMPORT CSV FILES INTO TABLES
-- ============================================================

CREATE DATABASE PrescriptionsDB;
GO
USE PrescriptionsDB;
GO

-- CSV files for tables were imported using "Import Flat File Wizard"

-- Add Foriegn Key constraints to Prescriptions table
ALTER TABLE dbo.Prescriptions
ADD CONSTRAINT FK_Prescriptions_Practice
    FOREIGN KEY (PRACTICE_CODE)
    REFERENCES dbo.Medical_Practice(PRACTICE_CODE);

ALTER TABLE dbo.Prescriptions
ADD CONSTRAINT FK_Prescriptions_Drugs
    FOREIGN KEY (BNF_CODE)
    REFERENCES dbo.Drugs(BNF_CODE);


-- Add Foreign and Primary Keys for Prescription_Summary table

ALTER TABLE dbo.Prescription_Summary
ADD SUMMARY_ID INT IDENTITY(1,1) NOT NULL;

ALTER TABLE dbo.Prescription_Summary
ADD CONSTRAINT PK_Prescriptions_Summary PRIMARY KEY (SUMMARY_ID);

ALTER TABLE dbo.Prescription_Summary
ADD CONSTRAINT FK_Summary_Practice
    FOREIGN KEY (PRACTICE_CODE)
    REFERENCES dbo.Medical_Practice(PRACTICE_CODE);



-- Verify row counts after import
SELECT 'Medical_Practice' AS TableName, COUNT(*) AS [RowCount] FROM dbo.Medical_Practice
UNION ALL
SELECT 'Drugs', COUNT(*) FROM dbo.Drugs
UNION ALL
SELECT 'Prescriptions', COUNT(*) FROM dbo.Prescriptions
UNION ALL
SELECT 'Prescription_Summary', COUNT(*) FROM dbo.Prescription_Summary;


-- ============================================================
-- Q2: Drugs in the Form of Tablets or Capsules
-- ============================================================

SELECT
    BNF_CODE,
    CHEMICAL_SUBSTANCE_BNF_DESCR,
    BNF_DESCRIPTION,
    BNF_CHAPTER_PLUS_CODE
FROM dbo.Drugs
WHERE BNF_DESCRIPTION LIKE '%tablet%'
   OR BNF_DESCRIPTION LIKE '%capsule%';


-- ============================================================
-- Q3: Total Quantity for Each Prescription (Rounded)
-- ============================================================

SELECT
    PRESCRIPTION_CODE,
    PRACTICE_CODE,
    BNF_CODE,
    ITEMS,
    QUANTITY,
    ROUND(ITEMS * QUANTITY, 0) AS TOTAL_QUANTITY_ROUNDED,
    CAST(ROUND(ITEMS * QUANTITY, 0) AS INT) AS TOTAL_QUANTITY_INT
FROM dbo.Prescriptions;


-- ============================================================
-- Q4: Most Prescribed Chemical Substance Per Month
-- ============================================================

WITH MonthlySubstanceCounts AS (
    SELECT
        ps.REPORT_MONTH,
        d.CHEMICAL_SUBSTANCE_BNF_DESCR,
        COUNT(*) AS PrescriptionCount,
        ROW_NUMBER() OVER (
            PARTITION BY ps.REPORT_MONTH
            ORDER BY COUNT(*) DESC
        ) AS RowNum
    FROM dbo.Prescription_Summary ps
    INNER JOIN dbo.Prescriptions p ON ps.PRACTICE_CODE = p.PRACTICE_CODE
    INNER JOIN dbo.Drugs d ON p.BNF_CODE = d.BNF_CODE
    GROUP BY ps.REPORT_MONTH, d.CHEMICAL_SUBSTANCE_BNF_DESCR
)
SELECT DISTINCT
    REPORT_MONTH,
    CHEMICAL_SUBSTANCE_BNF_DESCR AS MostPrescribedSubstance,
    PrescriptionCount
FROM MonthlySubstanceCounts
WHERE RowNum = 1
ORDER BY REPORT_MONTH;


-- ============================================================
-- Q5: Prescriptions per BNF Chapter with Cost Statistics
-- ============================================================

SELECT
    d.BNF_CHAPTER_PLUS_CODE,
    COUNT(p.PRESCRIPTION_CODE) AS NumberOfPrescriptions,
    ROUND(AVG(p.ACTUAL_COST), 2) AS AverageCost,
    ROUND(MIN(p.ACTUAL_COST), 2) AS MinimumCost,
    ROUND(MAX(p.ACTUAL_COST), 2) AS MaximumCost
FROM dbo.Prescriptions p
INNER JOIN dbo.Drugs d ON p.BNF_CODE = d.BNF_CODE
GROUP BY d.BNF_CHAPTER_PLUS_CODE
ORDER BY NumberOfPrescriptions DESC;


-- ============================================================
-- Q6: Most Expensive Prescription Per Practice (Over £4000)
-- ============================================================

SELECT
    mp.PRACTICE_NAME,
    p.PRACTICE_CODE,
    p.PRESCRIPTION_CODE,
    d.BNF_DESCRIPTION,
    p.ACTUAL_COST AS PrescriptionCost
FROM dbo.Prescriptions p
INNER JOIN dbo.Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
INNER JOIN dbo.Drugs d ON p.BNF_CODE = d.BNF_CODE
WHERE p.ACTUAL_COST = (
    SELECT MAX(p2.ACTUAL_COST)
    FROM dbo.Prescriptions p2
    WHERE p2.PRACTICE_CODE = p.PRACTICE_CODE
)
AND p.ACTUAL_COST > 4000
ORDER BY p.ACTUAL_COST DESC;


-- ============================================================
-- Q7: FOUR ADDITIONAL QUERIES
-- ============================================================

-- ============================================================
-- Q7a: Practice Specialisation Analysis

SELECT
    mp.PRACTICE_CODE,
    mp.PRACTICE_NAME,
    COUNT(DISTINCT d.BNF_CHAPTER_PLUS_CODE) AS ChaptersServed,
    COUNT(p.PRESCRIPTION_CODE) AS TotalPrescriptions
FROM dbo.Medical_Practice mp
INNER JOIN dbo.Prescriptions p ON mp.PRACTICE_CODE = p.PRACTICE_CODE
INNER JOIN dbo.Drugs d ON p.BNF_CODE = d.BNF_CODE
WHERE EXISTS (
    SELECT 1 FROM dbo.Prescriptions px
    WHERE px.PRACTICE_CODE = mp.PRACTICE_CODE
)
GROUP BY mp.PRACTICE_CODE, mp.PRACTICE_NAME
HAVING COUNT(DISTINCT d.BNF_CHAPTER_PLUS_CODE) <= 5
ORDER BY ChaptersServed ASC, TotalPrescriptions DESC;

-- EXPLANATION:
-- This query helps identify practices that may be specialist
-- clinics rather than general practices. A practice prescribing
-- from only 1-2 BNF chapters may focus on a specific area such
-- as mental health or cardiovascular care. The pharmaceutical
-- company could use this to target marketing of specialist
-- drugs to the relevant practices.


-- ============================================================
-- Q7b: Bulk Purchasing Opportunities

SELECT
    d.BNF_CODE,
    d.CHEMICAL_SUBSTANCE_BNF_DESCR,
    d.BNF_DESCRIPTION,
    COUNT(DISTINCT p.PRACTICE_CODE) AS NumberOfPractices,
    SUM(p.ITEMS) AS TotalItemsPrescribed,
    CAST(ROUND(SUM(p.ITEMS * p.QUANTITY), 0) AS INT) AS TotalUnitsPrescribed,
    ROUND(SUM(p.ACTUAL_COST), 2) AS TotalCost
FROM dbo.Drugs d
INNER JOIN dbo.Prescriptions p ON d.BNF_CODE = p.BNF_CODE
WHERE d.BNF_CODE IN (
    SELECT p2.BNF_CODE
    FROM dbo.Prescriptions p2
    GROUP BY p2.BNF_CODE
    HAVING COUNT(DISTINCT p2.PRACTICE_CODE) >= 10
)
GROUP BY d.BNF_CODE, d.CHEMICAL_SUBSTANCE_BNF_DESCR, d.BNF_DESCRIPTION
HAVING SUM(p.ITEMS) > 100
ORDER BY TotalUnitsPrescribed DESC;

-- EXPLANATION:
-- Drugs prescribed in high volumes across many practices
-- represent the strongest candidates for bulk purchasing
-- agreements. The pharmaceutical company can negotiate
-- discounts with suppliers for these high-demand products,
-- reducing costs across the Bolton region.


-- ============================================================
-- Q7c: Unusual or Potentially Erroneous Prescriptions

WITH DrugStats AS (
    SELECT
        BNF_CODE,
        AVG(ACTUAL_COST) AS AvgCost,
        STDEV(ACTUAL_COST) AS StdDevCost
    FROM dbo.Prescriptions
    GROUP BY BNF_CODE
    HAVING COUNT(*) > 5 AND STDEV(ACTUAL_COST) > 0
)
SELECT
    p.PRESCRIPTION_CODE,
    mp.PRACTICE_NAME,
    d.BNF_DESCRIPTION,
    ROUND(p.ACTUAL_COST, 2) AS PrescriptionCost,
    ROUND(ds.AvgCost, 2) AS AverageCostForDrug,
    ROUND(ds.StdDevCost, 2) AS StdDeviation,
    ROUND((p.ACTUAL_COST - ds.AvgCost) / ds.StdDevCost, 2) AS ZScore
FROM dbo.Prescriptions p
INNER JOIN DrugStats ds ON p.BNF_CODE = ds.BNF_CODE
INNER JOIN dbo.Medical_Practice mp ON p.PRACTICE_CODE = mp.PRACTICE_CODE
INNER JOIN dbo.Drugs d ON p.BNF_CODE = d.BNF_CODE
WHERE p.ACTUAL_COST > (ds.AvgCost + 3 * ds.StdDevCost)
ORDER BY ZScore DESC;

-- EXPLANATION:
-- Prescriptions with costs more than 3 standard deviations
-- above the mean for that drug are statistical outliers.
-- These could indicate errors in data entry (wrong quantity
-- or cost recorded), exceptional clinical cases requiring
-- unusually large quantities, or pricing anomalies that
-- warrant further investigation by the pharmaceutical company.


-- ============================================================
-- Q7d: Month-on-Month Comparison of Prescribing Volumes

WITH MonthlySummary AS (
    SELECT
        PRACTICE_CODE,
        REPORT_MONTH,
        SUM(TOTAL_ITEMS) AS MonthlyItems,
        ROUND(SUM(TOTAL_COST), 2) AS MonthlyCost
    FROM dbo.Prescription_Summary
    GROUP BY PRACTICE_CODE, REPORT_MONTH
)
SELECT
    curr.PRACTICE_CODE,
    mp.PRACTICE_NAME,
    curr.REPORT_MONTH AS CurrentMonth,
    prev.REPORT_MONTH AS PreviousMonth,
    curr.MonthlyItems AS CurrentItems,
    ISNULL(prev.MonthlyItems, 0) AS PreviousItems,
    curr.MonthlyItems - ISNULL(prev.MonthlyItems, 0) AS ItemChange,
    CASE
        WHEN prev.MonthlyItems IS NULL OR prev.MonthlyItems = 0 THEN NULL
        ELSE ROUND(((curr.MonthlyItems - prev.MonthlyItems) * 100.0
             / prev.MonthlyItems), 1)
    END AS PercentChange,
    curr.MonthlyCost AS CurrentCost,
    ISNULL(prev.MonthlyCost, 0) AS PreviousCost
FROM MonthlySummary curr
LEFT JOIN MonthlySummary prev
    ON curr.PRACTICE_CODE = prev.PRACTICE_CODE
    AND prev.REPORT_MONTH = CASE curr.REPORT_MONTH
        WHEN 'February' THEN 'January'
        WHEN 'March' THEN 'February'
        WHEN 'April' THEN 'March'
        WHEN 'May' THEN 'April'
        WHEN 'June' THEN 'May'
        WHEN 'July' THEN 'June'
        WHEN 'August' THEN 'July'
        WHEN 'September' THEN 'August'
        WHEN 'October' THEN 'September'
        WHEN 'November' THEN 'October'
        WHEN 'December' THEN 'November'
        ELSE NULL
    END
INNER JOIN dbo.Medical_Practice mp ON curr.PRACTICE_CODE = mp.PRACTICE_CODE
WHERE curr.REPORT_MONTH = 'February'  -- This can be changed to compare different months
ORDER BY PercentChange DESC;

-- EXPLANATION:
-- Comparing month-on-month prescribing volumes helps the
-- pharmaceutical company identify trends. A sudden spike in
-- prescriptions at a particular practice could indicate a
-- local health issue or a new prescriber. A significant drop
-- might suggest the practice has switched to an alternative
-- drug. Both scenarios are commercially relevant for planning
-- supply and sales strategy.

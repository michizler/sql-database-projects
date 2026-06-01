-- ============================================================
-- TASK 1: ONLINE BANKING DATABASE
-- ============================================================

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 1 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ============================================================
-- CREATING THE DATABASE
-- ============================================================
CREATE DATABASE OnlineBankDB;
GO
USE OnlineBankDB;
GO
-- ============================================================
-- CREATING THE TABLES
-- They were created in dependency order so that foreign key
-- references point to tables that already exist. I was getting uncomfortable errors without this order
-- ============================================================

-- ------------------------------------------------------------
-- TABLE 1: Address
-- ------------------------------------------------------------

-- DESIGN RATIONALE:
-- Address is separated from Customer just like in the SalfordBankLtd workshop
-- because address fields  (AddressLine1, AddressLine2, City, Postcode)
-- are NOT functionally dependent on CustomerID. Multiple customers
-- could share the same address (e.g., family members).
-- Used [] to escape reserved name for Address.

-- ------------------------------------------------------------
CREATE TABLE dbo.Address (
    AddressID       INT IDENTITY(1,1)   NOT NULL,
    AddressLine1    NVARCHAR(100)       NOT NULL,
    AddressLine2    NVARCHAR(100)       NULL,
    City            NVARCHAR(50)        NOT NULL,
    Postcode        NVARCHAR(10)        NOT NULL,

    CONSTRAINT PK_Address PRIMARY KEY (AddressID),

    -- In places like the UK, AddressLine1 + Postcode uniquely identifies
    -- a property, preventing duplicate address records.
    CONSTRAINT UC_Address UNIQUE (AddressLine1, Postcode)
);

-- ------------------------------------------------------------
-- TABLE 2: Customer
-- ------------------------------------------------------------
-- Here I took the security best practice from Week 10 and 
-- stored Password as a salted hash (BINARY(64)) not as plain text.
-- to prevent SQL injection.
-- ------------------------------------------------------------
CREATE TABLE dbo.Customer (
    CustomerID      INT IDENTITY(1,1)       NOT NULL,
    FirstName       NVARCHAR(50)            NOT NULL,
    LastName        NVARCHAR(50)            NOT NULL,
    AddressID       INT                     NOT NULL,
    DateOfBirth     DATE                    NOT NULL,
    Username        NVARCHAR(50)            NOT NULL,
    PasswordHash    BINARY(64)              NOT NULL,
    Salt            UNIQUEIDENTIFIER        NOT NULL,
    Email           NVARCHAR(100)           NULL,       -- Optional
    Telephone       NVARCHAR(20)            NULL,       -- Optional
    RegistrationDate DATETIME2              NOT NULL DEFAULT GETDATE(),
    IsActive        BIT                     NOT NULL DEFAULT 1,

    CONSTRAINT PK_Customer PRIMARY KEY (CustomerID),

    -- Username must be unique across all customers
    CONSTRAINT UQ_Customer_Username UNIQUE (Username),

    -- CHECK constraint to validate email format when provided
    -- This same pattern was used in Week 7 workshop (SalfordBankLtd). Applying it here
    CONSTRAINT CHK_Customer_Email CHECK (
        Email IS NULL OR Email LIKE '%_@_%._%'
    ),

    -- DOB sanity check: customer must be at least 16 years old to comply with
    -- account opening legal regulations.
    CONSTRAINT CHK_Customer_DOB CHECK (
        DateOfBirth <= DATEADD(YEAR, -16, GETDATE())
    ),

    -- Foreign key to Address table
    CONSTRAINT FK_Customer_Address FOREIGN KEY (AddressID)
        REFERENCES dbo.Address(AddressID)
);

-- ------------------------------------------------------------
-- TABLE 3: AccountType (Lookup / Reference Table)
-- ------------------------------------------------------------

-- DESIGN RATIONALE:
-- Account type name is a repeating value across many accounts.
-- As done in Week 7 SalfordBankLtd workshop, I normalised this 
-- into a separate lookup table. This also makes it easy to add new
-- account types in the future without modifying the Account
-- table structure.

-- ------------------------------------------------------------
CREATE TABLE dbo.AccountType (
    AccountTypeID   INT IDENTITY(1,1)   NOT NULL,
    TypeName        NVARCHAR(50)        NOT NULL,

    CONSTRAINT PK_AccountType PRIMARY KEY (AccountTypeID),
    CONSTRAINT UQ_AccountType_Name UNIQUE (TypeName),

    -- Data validation check for the five types of account type specified
    CONSTRAINT CHK_AccountType_Name CHECK (
        TypeName IN ('Savings', 'Checking', 'Loan', 'Credit Card', 'Investment')
    )
);

-- ------------------------------------------------------------
-- TABLE 4: Account
-- ------------------------------------------------------------
-- Stores each bank account/product.
-- ------------------------------------------------------------
CREATE TABLE dbo.Account (
    AccountID       INT IDENTITY(1,1)   NOT NULL,
    AccountName     NVARCHAR(100)       NOT NULL,
    AccountTypeID   INT                 NOT NULL,
    ReferenceNumber NVARCHAR(50)        NULL,       -- For loans; NULL for others
    OpeningDate     DATE                NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Status          NVARCHAR(20)        NOT NULL DEFAULT 'Active',
    StatusDate      DATETIME2           NULL,       -- When status last changed
    ClosureDate     DATE                NULL,       -- NULL if not closed
    Balance         DECIMAL(18,2)       NOT NULL DEFAULT 0.00,

    CONSTRAINT PK_Account PRIMARY KEY (AccountID),

    -- Another data validation check to restrict status to the four values specified in the brief
    CONSTRAINT CHK_Account_Status CHECK (
        Status IN ('Active', 'Dormant', 'Closed', 'Frozen')
    ),

    -- Foreign key to AccountType lookup table
    CONSTRAINT FK_Account_AccountType FOREIGN KEY (AccountTypeID)
        REFERENCES dbo.AccountType(AccountTypeID)
);

-- ------------------------------------------------------------
-- TABLE 5: CustomerAccount
-- ------------------------------------------------------------

-- DESIGN RATIONALE:
-- This would serve as the junction table. It resolves the many-to-many relationship
-- between Customer and Account. One customer can hold multiple
-- accounts, and one account can have multiple holders (joint
-- accounts). This idea was again borrowed from the
-- CustomerAccounts table in the Week 7 workshop.

-- The composite primary key (CustomerID, AccountID) ensures
-- that the same customer cannot be linked to the same account
-- more than once.

-- ------------------------------------------------------------
CREATE TABLE dbo.CustomerAccount (
    CustomerID  INT     NOT NULL,
    AccountID   INT     NOT NULL,
    DateLinked  DATE    NOT NULL DEFAULT CAST(GETDATE() AS DATE),

    CONSTRAINT PK_CustomerAccount PRIMARY KEY (CustomerID, AccountID),

    CONSTRAINT FK_CA_Customer FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customer(CustomerID),

    CONSTRAINT FK_CA_Account FOREIGN KEY (AccountID)
        REFERENCES dbo.Account(AccountID)
);

-- ------------------------------------------------------------
-- TABLE 6: Transaction
-- ------------------------------------------------------------
-- Records every banking transaction. Each transaction would be linked
-- to an Account and to the Customer who initiated it.
-- Added [] in the table_name because TRANSACTION is a reserved word.
-- ------------------------------------------------------------
CREATE TABLE dbo.[Transaction] (
    TransactionID       INT IDENTITY(1,1)   NOT NULL,
    AccountID           INT                 NOT NULL,
    CustomerID          INT                 NOT NULL,
    Amount              DECIMAL(18,2)       NOT NULL,
    TransactionType     NVARCHAR(50)        NOT NULL,
    TransactionDate     DATETIME2           NOT NULL DEFAULT GETDATE(),
    DueDate             DATE                NULL,       -- For loan/credit payments only
    CompletionDate      DATETIME2           NULL,       -- NULL if transaction is still pending
    Description         NVARCHAR(255)       NULL,

    CONSTRAINT PK_Transaction PRIMARY KEY (TransactionID),

    CONSTRAINT CHK_Transaction_Type CHECK (
        TransactionType IN ('Deposit', 'Withdrawal', 'Payment', 'Transfer', 'Fee')
    ),

    -- Ensure amount is positive
    CONSTRAINT CHK_Transaction_Amount CHECK (Amount > 0),

    CONSTRAINT FK_Transaction_Account FOREIGN KEY (AccountID)
        REFERENCES dbo.Account(AccountID),

    CONSTRAINT FK_Transaction_Customer FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customer(CustomerID)
);

-- ------------------------------------------------------------
-- TABLE 7: OverdueFee
-- ------------------------------------------------------------

-- Tracks overdue fees charged to customers for late payments.

-- ------------------------------------------------------------
CREATE TABLE dbo.OverdueFee (
    OverdueFeeID        INT IDENTITY(1,1)   NOT NULL,
    TransactionID       INT                 NOT NULL,
    FeeAmount           DECIMAL(18,2)       NOT NULL,
    DaysOverdue         INT                 NOT NULL,
    FeeDate             DATETIME2           NOT NULL DEFAULT GETDATE(),
    TotalOwed           DECIMAL(18,2)       NOT NULL,
    TotalRepaid         DECIMAL(18,2)       NOT NULL DEFAULT 0.00,
    OutstandingBalance  AS (TotalOwed - TotalRepaid),

    CONSTRAINT PK_OverdueFee PRIMARY KEY (OverdueFeeID),

    -- Fee amount must be positive
    CONSTRAINT CHK_OverdueFee_Amount CHECK (FeeAmount > 0),

    -- Days overdue must be at least 1
    CONSTRAINT CHK_OverdueFee_Days CHECK (DaysOverdue >= 1),

    -- TotalRepaid cannot exceed TotalOwed
    CONSTRAINT CHK_OverdueFee_Repaid CHECK (TotalRepaid <= TotalOwed),

    CONSTRAINT FK_OverdueFee_Transaction FOREIGN KEY (TransactionID)
        REFERENCES dbo.[Transaction](TransactionID)
);

-- ------------------------------------------------------------
-- TABLE 8: Repayment
-- ------------------------------------------------------------

-- Records individual repayments made by customers toward their
-- overdue fees. 

-- PaymentMethod is constrained to the three options specified:
-- Bank Transfer, Card, or Cash.

-- ------------------------------------------------------------
CREATE TABLE dbo.Repayment (
    RepaymentID     INT IDENTITY(1,1)   NOT NULL,
    OverdueFeeID    INT                 NOT NULL,
    RepaymentDate   DATETIME2           NOT NULL DEFAULT GETDATE(),
    Amount          DECIMAL(18,2)       NOT NULL,
    PaymentMethod   NVARCHAR(20)        NOT NULL,

    CONSTRAINT PK_Repayment PRIMARY KEY (RepaymentID),

    -- Amount must be positive
    CONSTRAINT CHK_Repayment_Amount CHECK (Amount > 0),

    -- Restrict to the three payment methods in the brief
    CONSTRAINT CHK_Repayment_Method CHECK (
        PaymentMethod IN ('Bank Transfer', 'Card', 'Cash')
    ),

    CONSTRAINT FK_Repayment_OverdueFee FOREIGN KEY (OverdueFeeID)
        REFERENCES dbo.OverdueFee(OverdueFeeID)
);

-- ============================================================
-- CREATE INDEXES
-- ============================================================
-- Non-clustered indexes on columns frequently used in
-- WHERE clauses and JOIN conditions.
-- ============================================================

-- Customers are frequently searched by name
CREATE NONCLUSTERED INDEX IX_Customer_LastName
    ON dbo.Customer (LastName);

-- Accounts are frequently filtered by status
CREATE NONCLUSTERED INDEX IX_Account_Status
    ON dbo.Account (Status);

-- Transactions are frequently filtered by date ranges
CREATE NONCLUSTERED INDEX IX_Transaction_Date
    ON dbo.[Transaction] (TransactionDate);

-- Transactions are frequently filtered by DueDate
-- (e.g., finding payments due within 5 days)
CREATE NONCLUSTERED INDEX IX_Transaction_DueDate
    ON dbo.[Transaction] (DueDate)
    WHERE DueDate IS NOT NULL;

CREATE UNIQUE NONCLUSTERED INDEX UQ_Account_RefNumber
    ON dbo.Account (ReferenceNumber)
    WHERE ReferenceNumber IS NOT NULL;

CREATE UNIQUE NONCLUSTERED INDEX UQ_Customer_Email
    ON dbo.Customer (Email)
    WHERE Email IS NOT NULL;

-- ============================================================
--                                       POPULATING THE DATABASE
-- ============================================================

-- ============================================================
-- TABLE 1: Address
-- ============================================================

SET IDENTITY_INSERT dbo.Address ON;

INSERT INTO dbo.Address (AddressID, AddressLine1, AddressLine2, City, Postcode)
VALUES
(1,  '14 Oak Avenue',        'Flat 2',       'Manchester',   'M1 4BT'),
(2,  '27 Elm Street',        NULL,           'Salford',      'M5 3AQ'),
(3,  '8 Birch Lane',         'Apt 5B',       'Bolton',       'BL1 2JN'),
(4,  '53 Maple Road',        NULL,           'Bury',         'BL9 0SN'),
(5,  '102 Cedar Close',      'Suite 3',      'Rochdale',     'OL11 1DL'),
(6,  '6 Willow Drive',       NULL,           'Oldham',       'OL1 3NR'),
(7,  '31 Pine Crescent',     NULL,           'Stockport',    'SK1 1EB'),
(8,  '19 Ash Grove',         'Floor 1',      'Wigan',        'WN1 1YB'),
(9,  '45 Hazel Way',         NULL,           'Trafford',     'M16 0QW'),
(10, '77 Chestnut Terrace',  'Unit 4',       'Tameside',     'OL6 7RL');

SET IDENTITY_INSERT dbo.Address OFF;

-- ============================================================
-- TABLE 2: Customer
-- ============================================================
-- Customer 10 has IsActive = 0 (closed account but retained
-- for marketing purposes as per the brief).
-- ============================================================

-- We insert customers one at a time so each gets a unique salt
DECLARE @salt1 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('James', 'Harrison', 1, '1985-03-15', 'jharrison', HASHBYTES('SHA2_512', 'JH@word1' + CAST(@salt1 AS NVARCHAR(36))), @salt1, 'james.harrison@email.com', '07700 100001', '2022-01-10', 1);

DECLARE @salt2 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Sarah', 'Harrison', 1, '1987-07-22', 'sharrison', HASHBYTES('SHA2_512', 'Sa3H@ss' + CAST(@salt2 AS NVARCHAR(36))), @salt2, 'sarah.harrison@email.com', '07700 100002', '2022-01-10', 1);

DECLARE @salt3 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Amina', 'Begum', 2, '1990-11-08', 'abegum', HASHBYTES('SHA2_512', 'Amin@ss99!' + CAST(@salt3 AS NVARCHAR(36))), @salt3, 'amina.begum@email.com', '07700 100003', '2022-03-05', 1);

DECLARE @salt4 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('David', 'Chen', 3, '1978-05-30', 'dchen', HASHBYTES('SHA2_512', 'D@vid2024!' + CAST(@salt4 AS NVARCHAR(36))), @salt4, 'david.chen@email.com', NULL, '2022-06-18', 1);

DECLARE @salt5 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Fatima', 'Ali', 4, '1995-09-12', 'fali', HASHBYTES('SHA2_512', 'F@tima95!' + CAST(@salt5 AS NVARCHAR(36))), @salt5, NULL, '07700 100005', '2023-01-20', 1);

DECLARE @salt6 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Michael', 'OBrien', 5, '1982-12-01', 'mobrien', HASHBYTES('SHA2_512', 'M1ch@el82' + CAST(@salt6 AS NVARCHAR(36))), @salt6, 'michael.obrien@email.com', '07700 100006', '2023-04-11', 1);

DECLARE @salt7 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Priya', 'Patel', 6, '1992-02-28', 'ppatel', HASHBYTES('SHA2_512', 'Pr1y@2023' + CAST(@salt7 AS NVARCHAR(36))), @salt7, 'priya.patel@email.com', '07700 100007', '2023-06-30', 1);

DECLARE @salt8 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Thomas', 'Walker', 7, '1970-08-19', 'twalker', HASHBYTES('SHA2_512', 'Th0m@sW!' + CAST(@salt8 AS NVARCHAR(36))), @salt8, 'thomas.walker@email.com', '07700 100008', '2023-09-15', 1);

DECLARE @salt9 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Emma', 'Jones', 8, '1998-04-05', 'ejones', HASHBYTES('SHA2_512', 'Emm@J0nes' + CAST(@salt9 AS NVARCHAR(36))), @salt9, 'emma.jones@email.com', '07700 100009', '2024-01-08', 1);

DECLARE @salt10 UNIQUEIDENTIFIER = NEWID();
INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth, Username, PasswordHash, Salt, Email, Telephone, RegistrationDate, IsActive)
VALUES ('Robert', 'Taylor', 9, '1975-06-25', 'rtaylor', HASHBYTES('SHA2_512', 'R0bert75!' + CAST(@salt10 AS NVARCHAR(36))), @salt10, 'robert.taylor@email.com', '07700 100010', '2021-05-20', 0);
-- Robert Taylor: IsActive = 0 (account closed, retained for marketing per brief)

-- ============================================================
-- TABLE 3: AccountType
-- ============================================================

INSERT INTO dbo.AccountType (TypeName)
VALUES
('Savings'),
('Checking'),
('Loan'),
('Credit Card'),
('Investment');

-- ============================================================
-- TABLE 4: Account
-- ============================================================

SET IDENTITY_INSERT dbo.Account ON;

INSERT INTO dbo.Account (AccountID, AccountName, AccountTypeID, ReferenceNumber, OpeningDate, Status, StatusDate, ClosureDate, Balance)
VALUES
(1,  'James Everyday Savings',       1, NULL,            '2022-01-15', 'Active',  NULL,         NULL,         5200.00),
(2,  'Harrison Joint Checking',      2, NULL,            '2022-01-15', 'Active',  NULL,         NULL,         3150.75),
(3,  'Amina Premium Savings',        1, NULL,            '2022-03-10', 'Active',  NULL,         NULL,         12000.00),
(4,  'David Growth Investment',       5, NULL,            '2022-07-01', 'Active',  NULL,         NULL,         25000.00),
(5,  'Fatima Home Loan',             3, 'LN-2023-00451', '2023-02-01', 'Active',  NULL,         NULL,         500.00),
(6,  'Michael Rewards Credit Card',  4, 'CC-2023-00812', '2023-04-20', 'Active',  NULL,         NULL,         150.00),
(7,  'Priya Fixed Savings',          1, NULL,            '2023-07-05', 'Active',  NULL,         NULL,         8500.00),
(8,  'Thomas Personal Loan',         3, 'LN-2023-01102', '2023-10-01', 'Active',  NULL,         NULL,         7800.00),
(9,  'Emma Student Checking',        2, NULL,            '2024-01-15', 'Active',  NULL,         NULL,         920.50),
(10, 'Robert Standard Savings',      1, NULL,            '2021-06-01', 'Closed',  '2024-06-15', '2024-06-15', 0.00),
(11, 'David Emergency Checking',     2, NULL,            '2022-08-01', 'Frozen',  '2025-01-10', NULL,         1500.00),
(12, 'Priya Credit Card',            4, 'CC-2024-00330', '2024-03-15', 'Active',  NULL,         NULL,         2200.00);

SET IDENTITY_INSERT dbo.Account OFF;

-- ============================================================
-- TABLE 5: CustomerAccount
-- ============================================================

INSERT INTO dbo.CustomerAccount (CustomerID, AccountID, DateLinked)
VALUES
(1,  1,  '2022-01-15'),  
(1,  2,  '2022-01-15'),   -- James -> Joint Checking (joint with Sarah)
(2,  2,  '2022-01-15'),   -- Sarah -> Joint Checking (joint with James)
(3,  3,  '2022-03-10'),  
(4,  4,  '2022-07-01'),   
(4,  11, '2022-08-01'),   
(5,  5,  '2023-02-01'),   
(6,  6,  '2023-04-20'),   
(7,  7,  '2023-07-05'),   
(7,  12, '2024-03-15'),  
(8,  8,  '2023-10-01'),   
(9,  9,  '2024-01-15'),   
(10, 10, '2021-06-01');   

-- ============================================================
-- TABLE 6: Transaction
-- ============================================================

SET IDENTITY_INSERT dbo.[Transaction] ON;

INSERT INTO dbo.[Transaction] (TransactionID, AccountID, CustomerID, Amount, TransactionType, TransactionDate, DueDate, CompletionDate, Description)
VALUES
-- Regular deposits and withdrawals (no due dates)
(1,  1,  1,  2000.00, 'Deposit',    '2022-02-01', NULL, '2022-02-01', 'Initial deposit'),
(2,  1,  1,  500.00,  'Withdrawal', '2022-06-15', NULL, '2022-06-15', 'Cash withdrawal'),
(3,  2,  1,  1500.00, 'Deposit',    '2022-03-01', NULL, '2022-03-01', 'Salary deposit'),
(4,  2,  2,  200.00,  'Withdrawal', '2022-04-10', NULL, '2022-04-10', 'ATM withdrawal'),
(5,  3,  3,  5000.00, 'Deposit',    '2022-04-01', NULL, '2022-04-01', 'Savings transfer'),
(6,  4,  4,  10000.00,'Deposit',    '2022-08-01', NULL, '2022-08-01', 'Investment deposit'),

-- Fatima's Loan payments (Account 5)
(7,  5,  5,  500.00,  'Payment',    '2023-06-01', '2023-06-15', '2023-06-10', 'Loan instalment 1'),
(8,  5,  5,  500.00,  'Payment',    '2023-09-01', '2023-09-15', '2023-09-12', 'Loan instalment 2'),
(9,  5,  5,  500.00,  'Payment',    DATEADD(DAY, -2, GETDATE()), DATEADD(DAY, 3, CAST(GETDATE() AS DATE)), NULL, 'Loan instalment 3 - pending'),
(10, 5,  5,  500.00,  'Payment',    DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 14, CAST(GETDATE() AS DATE)), NULL, 'Loan FINAL instalment - pending'),

-- Michael's Credit Card payments (Account 6)
(11, 6,  6,  300.00,  'Payment',    '2023-08-01', '2023-08-15', '2023-08-10', 'CC payment on time'),
(12, 6,  6,  250.00,  'Payment',    '2023-11-01', '2023-11-15', '2023-11-25', 'CC payment LATE - 10 days overdue'),
(13, 6,  6,  150.00,  'Payment',    DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 2, CAST(GETDATE() AS DATE)), NULL, 'CC FINAL payment - pending'),

-- Thomas's Loan payments (Account 8)
(14, 8,  8,  650.00,  'Payment',    '2024-01-01', '2024-01-15', '2024-01-12', 'Loan payment on time'),
(15, 8,  8,  650.00,  'Payment',    '2024-04-01', '2024-04-15', '2024-04-22', 'Loan payment LATE - 7 days overdue'),
(16, 8,  8,  650.00,  'Payment',    DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 4, CAST(GETDATE() AS DATE)), NULL, 'Loan payment pending'),

-- Emma's checking account activity
(17, 9,  9,  300.00,  'Deposit',    '2024-02-01', NULL, '2024-02-01', 'Part-time wages'),

-- Priya's Credit Card payment - LATE (Account 12)
(18, 12, 7,  400.00,  'Payment',    '2024-06-01', '2024-06-15', '2024-06-28', 'CC payment LATE - 13 days overdue'),

-- Payments due in MORE than 5 days
(19, 8,  8,  650.00,  'Payment',    DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 10, CAST(GETDATE() AS DATE)), NULL, 'Loan future payment'),
(20, 12, 7,  400.00,  'Payment',    DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 15, CAST(GETDATE() AS DATE)), NULL, 'CC future payment');

SET IDENTITY_INSERT dbo.[Transaction] OFF;

-- ============================================================
-- TABLE 7: OverdueFee
-- ============================================================

SET IDENTITY_INSERT dbo.OverdueFee ON;

INSERT INTO dbo.OverdueFee (OverdueFeeID, TransactionID, FeeAmount, DaysOverdue, FeeDate, TotalOwed, TotalRepaid)
VALUES
(1, 12, 75.00,  10, '2023-11-26', 75.00,  60.00),   -- Michael: 80% repaid (PASSES)
(2, 15, 45.50,  7,  '2024-04-23', 45.50,  15.00),   -- Thomas:  33% repaid (FAILS)
(3, 18, 91.00,  13, '2024-06-29', 91.00,  30.00),   -- Priya:   33% repaid (FAILS)
(4, 15, 30.00,  7,  '2024-04-23', 30.00,  0.00);    -- Thomas:  0%  repaid (FAILS)

SET IDENTITY_INSERT dbo.OverdueFee OFF;

-- ============================================================
-- TABLE 8: Repayment
-- ============================================================

SET IDENTITY_INSERT dbo.Repayment ON;

INSERT INTO dbo.Repayment (RepaymentID, OverdueFeeID, RepaymentDate, Amount, PaymentMethod)
VALUES
-- Michael's repayments on Fee 1 (total = £60)
(1, 1, '2023-12-01', 30.00, 'Bank Transfer'),
(2, 1, '2023-12-15', 20.00, 'Card'),
(3, 1, '2024-01-05', 10.00, 'Cash'),

-- Thomas's repayment on Fee 2 (total = £15)
(4, 2, '2024-05-01', 15.00, 'Bank Transfer'),

-- Priya's repayments on Fee 3 (total = £30)
(5, 3, '2024-07-10', 20.00, 'Card'),
(6, 3, '2024-07-25', 10.00, 'Bank Transfer'),

-- Additional repayment to show all three payment methods used
(7, 2, '2024-05-15', 0.50, 'Cash');
-- This would bring Thomas Fee 2 repayment to £15.50
-- We need to update the TotalRepaid accordingly

SET IDENTITY_INSERT dbo.Repayment OFF;

-- Update Thomas's Fee 2 TotalRepaid to reflect the extra £0.50
UPDATE dbo.OverdueFee SET TotalRepaid = 15.50 WHERE OverdueFeeID = 2;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Check row counts for all tables
SELECT 'Address' AS TableName, COUNT(*) AS Row_Count FROM dbo.Address
UNION ALL
SELECT 'Customer', COUNT(*) FROM dbo.Customer
UNION ALL
SELECT 'AccountType', COUNT(*) FROM dbo.AccountType
UNION ALL
SELECT 'Account', COUNT(*) FROM dbo.Account
UNION ALL
SELECT 'CustomerAccount', COUNT(*) FROM dbo.CustomerAccount
UNION ALL
SELECT 'Transaction', COUNT(*) FROM dbo.[Transaction]
UNION ALL
SELECT 'OverdueFee', COUNT(*) FROM dbo.OverdueFee
UNION ALL
SELECT 'Repayment', COUNT(*) FROM dbo.Repayment;

-- Verify joint account exists (should return 2 rows for Account 2)
SELECT ca.AccountID, c.FirstName, c.LastName
FROM dbo.CustomerAccount ca
INNER JOIN dbo.Customer c ON ca.CustomerID = c.CustomerID
WHERE ca.AccountID = 2;

-- Verify pending payments due within 5 days exist
SELECT t.TransactionID, a.AccountName, t.Amount, t.DueDate, t.CompletionDate
FROM dbo.[Transaction] t
INNER JOIN dbo.Account a ON t.AccountID = a.AccountID
WHERE t.CompletionDate IS NULL
  AND t.DueDate IS NOT NULL
  AND DATEDIFF(DAY, GETDATE(), t.DueDate) BETWEEN 0 AND 5;

-- Verify overdue fee repayment percentages
SELECT
    ovf.OverdueFeeID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    ovf.TotalOwed,
    ovf.TotalRepaid,
    ovf.OutstandingBalance,
    CAST(ROUND((ovf.TotalRepaid / ovf.TotalOwed) * 100, 1) AS DECIMAL(5,1)) AS RepaidPercentage,
    CASE WHEN ovf.TotalRepaid < (ovf.TotalOwed * 0.5) THEN 'BELOW 50%' ELSE 'ABOVE 50%' END AS Status
FROM dbo.OverdueFee ovf
INNER JOIN dbo.[Transaction] t ON ovf.TransactionID = t.TransactionID
INNER JOIN dbo.Customer c ON t.CustomerID = c.CustomerID;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 2 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ============================================================
-- Q2a: STORED PROCEDURE - Search Accounts by Name
-- ============================================================
-- Allows for full or partial match). Results are sorted by most recently
-- opened accounts first using ORDER BY OpeningDate DESC.
-- ============================================================
GO
CREATE PROCEDURE uspSearchAccountsByName
    @SearchName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.AccountID,
        a.AccountName,
        at.TypeName AS AccountType,
        a.ReferenceNumber,
        a.OpeningDate,
        a.Status,
        a.Balance
    FROM dbo.Account a
    INNER JOIN dbo.AccountType at ON a.AccountTypeID = at.AccountTypeID
    WHERE a.AccountName LIKE '%' + @SearchName + '%'
    ORDER BY a.OpeningDate DESC;
END;
GO


-- ============================================================
-- Q2b: USER-DEFINED FUNCTION - Payments Due in < 5 Days
-- ============================================================
-- Returns all loan or credit card payments that are
-- due within the next 5 days.
-- ============================================================

CREATE FUNCTION dbo.PaymentsDueSoon()
RETURNS TABLE
AS
RETURN
(
    SELECT
        t.TransactionID,
        c.CustomerID,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        a.AccountID,
        a.AccountName,
        at.TypeName AS AccountType,
        t.Amount,
        t.DueDate,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE), t.DueDate) AS DaysUntilDue,
        t.Description
    FROM dbo.[Transaction] t
    INNER JOIN dbo.Account a ON t.AccountID = a.AccountID
    INNER JOIN dbo.AccountType at ON a.AccountTypeID = at.AccountTypeID
    INNER JOIN dbo.Customer c ON t.CustomerID = c.CustomerID
    WHERE t.CompletionDate IS NULL                              -- Only pending payments
      AND t.DueDate IS NOT NULL                                 -- Only payments with a due date
      AND t.DueDate BETWEEN CAST(GETDATE() AS DATE)             -- From today
                        AND DATEADD(DAY, 5, CAST(GETDATE() AS DATE))  -- To 5 days from now
      AND at.TypeName IN ('Loan', 'Credit Card')                -- Only loan or credit card
);
GO


-- ============================================================
-- Q2c: STORED PROCEDURE - Insert New Customer
-- ============================================================

CREATE PROCEDURE uspInsertNewCustomer
    @FirstName      NVARCHAR(50),
    @LastName       NVARCHAR(50),
    @AddressLine1   NVARCHAR(100),
    @AddressLine2   NVARCHAR(100) = NULL,
    @City           NVARCHAR(50),
    @Postcode       NVARCHAR(10),
    @DateOfBirth    DATE,
    @Username       NVARCHAR(50),
    @Password       NVARCHAR(50),
    @Email          NVARCHAR(100) = NULL,
    @Telephone      NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION
    BEGIN TRY
        -- Generate a unique salt for password hashing
        DECLARE @Salt UNIQUEIDENTIFIER = NEWID();
        DECLARE @PasswordHash BINARY(64) = HASHBYTES('SHA2_512',
            @Password + CAST(@Salt AS NVARCHAR(36)));

        -- Check if the address already exists
        DECLARE @AddressID INT;
        SELECT @AddressID = AddressID
        FROM dbo.Address
        WHERE AddressLine1 = @AddressLine1 AND Postcode = @Postcode;

        -- If address doesn't exist, insert a new one
        IF @AddressID IS NULL
        BEGIN
            INSERT INTO dbo.Address (AddressLine1, AddressLine2, City, Postcode)
            VALUES (@AddressLine1, @AddressLine2, @City, @Postcode);

            SET @AddressID = SCOPE_IDENTITY();
        END

        -- Insert the customer record
        INSERT INTO dbo.Customer (FirstName, LastName, AddressID, DateOfBirth,
                              Username, PasswordHash, Salt, Email, Telephone)
        VALUES (@FirstName, @LastName, @AddressID, @DateOfBirth,
                @Username, @PasswordHash, @Salt, @Email, @Telephone);

        -- Return the new customer details (excluding password hash)
        DECLARE @NewCustomerID INT = SCOPE_IDENTITY();
        SELECT @NewCustomerID AS NewCustomerID, @FirstName AS FirstName,
               @LastName AS LastName, @Username AS Username;

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        -- If any error occurs, roll back the entire transaction
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Re-raise the error with details
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        RAISERROR(@ErrMsg, @ErrSeverity, 1);
    END CATCH
END;
GO


-- ============================================================
-- Q2d: STORED PROCEDURE - Update Existing Customer
-- ============================================================

CREATE PROCEDURE uspUpdateCustomer
    @CustomerID     INT,
    @FirstName      NVARCHAR(50)  = NULL,
    @LastName       NVARCHAR(50)  = NULL,
    @AddressLine1   NVARCHAR(100) = NULL,
    @AddressLine2   NVARCHAR(100) = NULL,
    @City           NVARCHAR(50)  = NULL,
    @Postcode       NVARCHAR(10)  = NULL,
    @Email          NVARCHAR(100) = NULL,
    @Telephone      NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION
    BEGIN TRY
        -- Check customer exists
        IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerID = @CustomerID)
        BEGIN
            RAISERROR('Customer with ID %d does not exist.', 16, 1, @CustomerID);
            RETURN;
        END

        -- If address fields are provided, handle address update
        IF @AddressLine1 IS NOT NULL AND @Postcode IS NOT NULL
        BEGIN
            DECLARE @NewAddressID INT;

            -- Check if the new address already exists
            SELECT @NewAddressID = AddressID
            FROM dbo.Address
            WHERE AddressLine1 = @AddressLine1 AND Postcode = @Postcode;

            -- If not, create it
            IF @NewAddressID IS NULL
            BEGIN
                INSERT INTO dbo.Address (AddressLine1, AddressLine2, City, Postcode)
                VALUES (@AddressLine1, @AddressLine2, @City, @Postcode);

                SET @NewAddressID = SCOPE_IDENTITY();
            END

            -- Update the customer's AddressID
            UPDATE dbo.Customer SET AddressID = @NewAddressID
            WHERE CustomerID = @CustomerID;
        END

        -- Update other customer fields (only if provided)
        UPDATE dbo.Customer
        SET
            FirstName = ISNULL(@FirstName, FirstName),
            LastName  = ISNULL(@LastName, LastName),
            Email     = ISNULL(@Email, Email),
            Telephone = ISNULL(@Telephone, Telephone)
        WHERE CustomerID = @CustomerID;

        -- Return the updated customer record
        SELECT c.CustomerID, c.FirstName, c.LastName,
               a.AddressLine1, a.AddressLine2, a.City, a.Postcode,
               c.Email, c.Telephone
        FROM dbo.Customer c
        INNER JOIN [Address] a ON c.AddressID = a.AddressID
        WHERE c.CustomerID = @CustomerID;

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        RAISERROR(@ErrMsg, @ErrSeverity, 1);
    END CATCH
END;
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 3 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ============================================================
-- VIEW - All Transactions with Overdue Fees
-- ============================================================

CREATE VIEW dbo.TransactionsWithOverdueFees
AS
SELECT
    t.TransactionID,
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    a.AccountID,
    a.AccountName,
    at.TypeName AS AccountType,
    t.Amount AS TransactionAmount,
    t.TransactionType,
    t.TransactionDate,
    t.DueDate,
    t.CompletionDate,
    CASE
        WHEN t.CompletionDate IS NULL THEN 'Pending'
        WHEN t.DueDate IS NOT NULL AND t.CompletionDate > t.DueDate THEN 'Completed Late'
        ELSE 'Completed On Time'
    END AS TransactionStatus,
    ovf.OverdueFeeID,
    ovf.FeeAmount,
    ovf.DaysOverdue,
    ovf.FeeDate,
    ovf.TotalOwed,
    ovf.TotalRepaid,
    ovf.OutstandingBalance
FROM dbo.[Transaction] t
INNER JOIN dbo.Account a ON t.AccountID = a.AccountID
INNER JOIN dbo.AccountType at ON a.AccountTypeID = at.AccountTypeID
INNER JOIN dbo.Customer c ON t.CustomerID = c.CustomerID
LEFT JOIN dbo.OverdueFee ovf ON t.TransactionID = ovf.TransactionID;
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 4 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ============================================================
-- TRIGGER - Auto-Close Loan/Credit Card on Final Payment
-- ============================================================
-- This follows the trigger patterns from Week 8 workshop.
-- ============================================================

CREATE TRIGGER t_AutoCloseAccount
ON dbo.[Transaction]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only proceed if CompletionDate was updated from NULL to a value
    IF UPDATE(CompletionDate)
    BEGIN
        DECLARE @AccountID INT;
        DECLARE @AccountTypeID INT;
        DECLARE @AccountTypeName NVARCHAR(50);
        DECLARE @PendingCount INT;

        -- Get the account details from the updated transaction
        SELECT @AccountID = i.AccountID
        FROM inserted i
        INNER JOIN deleted d ON i.TransactionID = d.TransactionID
        WHERE d.CompletionDate IS NULL AND i.CompletionDate IS NOT NULL;

        -- If no relevant update, exit
        IF @AccountID IS NULL RETURN;

        -- Check if the account is a Loan or Credit Card and currently Active
        SELECT @AccountTypeID = a.AccountTypeID,
               @AccountTypeName = at.TypeName
        FROM dbo.Account a
        INNER JOIN dbo.AccountType at ON a.AccountTypeID = at.AccountTypeID
        WHERE a.AccountID = @AccountID
          AND at.TypeName IN ('Loan', 'Credit Card')
          AND a.Status = 'Active';

        -- If not a Loan/CC or not Active, exit
        IF @AccountTypeName IS NULL RETURN;

        -- Count remaining pending payments for this account
        SELECT @PendingCount = COUNT(*)
        FROM dbo.[Transaction]
        WHERE AccountID = @AccountID
          AND CompletionDate IS NULL
          AND DueDate IS NOT NULL;

        -- If no more pending payments, close the account
        IF @PendingCount = 0
        BEGIN
            UPDATE dbo.Account
            SET Status = 'Closed',
                StatusDate = GETDATE(),
                ClosureDate = CAST(GETDATE() AS DATE),
                Balance = 0.00
            WHERE AccountID = @AccountID;

            PRINT 'TRIGGER: Account ' + CAST(@AccountID AS VARCHAR(10))
                  + ' (' + @AccountTypeName + ') has been automatically closed.'
                  + ' All scheduled payments have been completed.';
        END
    END
END;
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 5 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ============================================================
-- QUERY - Customers Who Paid Less Than 50% of Overdue Fees
-- ============================================================

SELECT
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    COUNT(ovf.OverdueFeeID) AS NumberOfUnderRepaidFees,
    SUM(ovf.TotalOwed) AS TotalAmountOwed,
    SUM(ovf.TotalRepaid) AS TotalAmountRepaid,
    CAST(ROUND(SUM(ovf.TotalRepaid) / NULLIF(SUM(ovf.TotalOwed), 0) * 100, 1)
         AS DECIMAL(5,1)) AS OverallRepaidPercentage
FROM dbo.OverdueFee ovf
INNER JOIN dbo.[Transaction] t ON ovf.TransactionID = t.TransactionID
INNER JOIN dbo.Customer c ON t.CustomerID = c.CustomerID
WHERE ovf.TotalRepaid < (ovf.TotalOwed * 0.5)
GROUP BY c.CustomerID, c.FirstName, c.LastName
ORDER BY NumberOfUnderRepaidFees DESC;

GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 6 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ============================================================
-- TEST CASES FOR TRIGGERS, PROCEDURES AND FUNCTIONS
-- ============================================================

-- ============================================================
-- Q2a TEST CASES
-- ============================================================

-- Should return 4 accounts
EXEC uspSearchAccountsByName @SearchName = 'Savings';

-- Should return 2 accounts
EXEC uspSearchAccountsByName @SearchName = 'Loan';

-- Should return 2 accounts
EXEC uspSearchAccountsByName @SearchName = 'Credit';

-- Should return 0 rows because Mortgage is not among AccountTypes
EXEC uspSearchAccountsByName @SearchName = 'Mortgage';

-- Should return 1 row
EXEC uspSearchAccountsByName @SearchName = 'Emma Student';

-- ============================================================
-- Q2b TEST CASES
-- ============================================================

-- Should return 3 rows
-- (Fatima due in 3 days, Michael due in 2 days, Thomas due in 4 days)
SELECT * FROM dbo.PaymentsDueSoon();

-- Filter the result further by account type
SELECT * FROM dbo.PaymentsDueSoon() WHERE AccountType = 'Loan';

-- This is the case even when future payments (>5+ days) are involved
-- This query should return rows NOT in the function result
SELECT t.TransactionID, t.DueDate,
       DATEDIFF(DAY, CAST(GETDATE() AS DATE), t.DueDate) AS DaysUntilDue
FROM dbo.[Transaction] t
WHERE t.CompletionDate IS NULL AND t.DueDate IS NOT NULL
  AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), t.DueDate) > 5;

-- ============================================================
-- Q2c TEST CASES
-- ============================================================

-- Inserting a new customer with a new address
EXEC uspInsertNewCustomer
    @FirstName = 'Liam',
    @LastName = 'Murphy',
    @AddressLine1 = '22 Victoria Road',
    @AddressLine2 = NULL,
    @City = 'Leeds',
    @Postcode = 'LS1 5QR',
    @DateOfBirth = '1993-07-14',
    @Username = 'lmurphy',
    @Password = 'L1am$ecure!',
    @Email = 'liam.murphy@email.com',
    @Telephone = '07700 200001';

-- Verify the customer was inserted
SELECT * FROM dbo.Customer WHERE Username = 'lmurphy';

-- Inserting a customer at an existing address (14 Oak Avenue)
-- This should reuse AddressID 1 instead of creating a duplicate
EXEC uspInsertNewCustomer
    @FirstName = 'Olivia',
    @LastName = 'Harrison',
    @AddressLine1 = '14 Oak Avenue',
    @AddressLine2 = 'Flat 2',
    @City = 'Manchester',
    @Postcode = 'M1 4BT',
    @DateOfBirth = '2000-11-30',
    @Username = 'oharrison',
    @Password = '0l1vi@2024',
    @Email = 'olivia.harrison@email.com',
    @Telephone = NULL;

-- Verify the customer was inserted with AddressID = 1
SELECT CustomerID, FirstName, LastName, AddressID, Username
FROM dbo.Customer WHERE Username = 'oharrison';

-- Inserting a customer with a DUPLICATE username — should FAIL
EXEC uspInsertNewCustomer
    @FirstName = 'Micah',
    @LastName = 'Reki',
    @AddressLine1 = '19 Reiner Street',
    @AddressLine2 = NULL,
    @City = 'Sheffield',
    @Postcode = 'S9 1DT',
    @DateOfBirth = '1990-01-01',
    @Username = 'lmurphy',   -- This username already exists (Liam Murphy uses it).
    @Password = 'MicP@sh19',
    @Email = 'micahreki@email.com',
    @Telephone = NULL;

-- Inserting a customer with optional fields left NULL
EXEC uspInsertNewCustomer
    @FirstName = 'Noah',
    @LastName = 'Williams',
    @AddressLine1 = '5 Bridge Street',
    @AddressLine2 = NULL,
    @City = 'Chester',
    @Postcode = 'CH1 1RE',
    @DateOfBirth = '1988-03-22',
    @Username = 'nwilliams',
    @Password = 'N0@hW!lls',
    @Email = NULL,
    @Telephone = NULL;

-- ============================================================
-- Q2d TEST CASES
-- ============================================================

-- Update only the email for Customer 5 (Fatima Ali)
-- BEFORE state:
SELECT CustomerID, FirstName, LastName, Email, Telephone
FROM dbo.Customer WHERE CustomerID = 5;

EXEC uspUpdateCustomer
    @CustomerID = 5,
    @Email = 'fatima.ali@email.com';

-- AFTER state (only email should change):
SELECT CustomerID, FirstName, LastName, Email, Telephone
FROM dbo.Customer WHERE CustomerID = 5;

-- Update name and telephone for Customer 9 (Emma Jones)
EXEC uspUpdateCustomer
    @CustomerID = 9,
    @FirstName = 'Emily',
    @LastName = 'Jones-Smith',
    @Telephone = '07700 999999';

SELECT CustomerID, FirstName, LastName, Telephone
FROM dbo.Customer WHERE CustomerID = 9;

-- Update address (move to a new address)
EXEC uspUpdateCustomer
    @CustomerID = 3,
    @AddressLine1 = '15 New Road',
    @City = 'Manchester',
    @Postcode = 'M2 4WU';

SELECT c.CustomerID, c.FirstName, a.AddressLine1, a.City, a.Postcode
FROM dbo.Customer c INNER JOIN dbo.Address a ON c.AddressID = a.AddressID
WHERE c.CustomerID = 3;

-- Updating a customer that doesn't exist — should raise error
EXEC uspUpdateCustomer
    @CustomerID = 29,
    @FirstName = 'Megan';

GO

-- ============================================================
-- Q3 TEST CASES
-- ============================================================

-- Test 1: View all rows
SELECT * FROM dbo.TransactionsWithOverdueFees
ORDER BY TransactionDate DESC;

-- Filter to only show transactions with overdue fees
-- Should return 4 rows
SELECT * FROM dbo.TransactionsWithOverdueFees
WHERE OverdueFeeID IS NOT NULL
ORDER BY TransactionDate;

-- Show only pending transactions
SELECT TransactionID, CustomerName, AccountName, TransactionAmount,
       DueDate, TransactionStatus
FROM dbo.TransactionsWithOverdueFees
WHERE TransactionStatus = 'Pending';

-- Show late payments with their overdue fee details
SELECT CustomerName, AccountName, TransactionAmount,
       DueDate, CompletionDate, DaysOverdue, FeeAmount,
       TotalOwed, TotalRepaid, OutstandingBalance
FROM dbo.TransactionsWithOverdueFees
WHERE TransactionStatus = 'Completed Late';

GO
-- ============================================================
-- Q4 TEST CASES
-- ============================================================

-- TRIGGER TEST CASE 1: Fatima's Home Loan (Account 5)
-- Currently has 2 pending payments (TransactionIDs 9 and 10)

-- BEFORE state:
SELECT AccountID, AccountName, Status, Balance FROM Account WHERE AccountID = 5;
SELECT TransactionID, CompletionDate, Description
FROM dbo.[Transaction] WHERE AccountID = 5 AND CompletionDate IS NULL;

-- Complete transaction 9 (not the last one)
-- The trigger should not close the account because transaction 10 is still pending
UPDATE dbo.[Transaction]
SET CompletionDate = GETDATE()
WHERE TransactionID = 9;

-- Account should still be Active
SELECT AccountID, AccountName, Status, Balance FROM dbo.Account WHERE AccountID = 5;

-- Complete transaction 10 (final payment)
-- The trigger should close the account now
UPDATE dbo.[Transaction]
SET CompletionDate = GETDATE()
WHERE TransactionID = 10;

-- AFTER state: Account should now be Closed
SELECT AccountID, AccountName, Status, StatusDate, ClosureDate, Balance
FROM dbo.Account WHERE AccountID = 5;


-- TRIGGER TEST CASE 2: Michael's Credit Card (Account 6)
-- Has 1 pending payment (TransactionID 13)

-- BEFORE state:
SELECT AccountID, AccountName, Status, Balance FROM dbo.Account WHERE AccountID = 6;

-- Complete the final credit card payment
UPDATE dbo.[Transaction]
SET CompletionDate = GETDATE()
WHERE TransactionID = 13;

-- AFTER state: Account should now be Closed
SELECT AccountID, AccountName, Status, StatusDate, ClosureDate, Balance
FROM dbo.Account WHERE AccountID = 6;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                                            -- ============================================================

                                                            -- --------------------------------- TASK 1 - QUESTION 7 -------------------------------------

                                                            -- ============================================================
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ============================================================
-- ADDITIONAL DATABASE OBJECTS
-- ============================================================

-- ============================================================
-- Q7a: STORED PROCEDURE - Generate Account Summary Report
-- ============================================================

GO
CREATE PROCEDURE uspCustomerAccountSummary
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check customer exists
    IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerID = @CustomerID)
    BEGIN
        RAISERROR('Customer with ID %d does not exist.', 16, 1, @CustomerID);
        RETURN;
    END

    -- Customer details
    SELECT c.CustomerID,
           c.FirstName + ' ' + c.LastName AS FullName,
           c.Email, c.Telephone, c.RegistrationDate, c.IsActive,
           a.AddressLine1, a.City, a.Postcode
    FROM dbo.Customer c
    INNER JOIN [Address] a ON c.AddressID = a.AddressID
    WHERE c.CustomerID = @CustomerID;

    -- Account summary with transaction counts
    SELECT
        acc.AccountID,
        acc.AccountName,
        at.TypeName AS AccountType,
        acc.Status,
        acc.Balance,
        acc.OpeningDate,
        COUNT(t.TransactionID) AS TotalTransactions,
        ISNULL(SUM(CASE WHEN t.TransactionType = 'Deposit' THEN t.Amount ELSE 0 END), 0) AS TotalDeposits,
        ISNULL(SUM(CASE WHEN t.TransactionType = 'Withdrawal' THEN t.Amount ELSE 0 END), 0) AS TotalWithdrawals,
        ISNULL(SUM(CASE WHEN t.CompletionDate IS NULL AND t.DueDate IS NOT NULL THEN 1 ELSE 0 END), 0) AS PendingPayments
    FROM dbo.CustomerAccount ca
    INNER JOIN dbo.Account acc ON ca.AccountID = acc.AccountID
    INNER JOIN dbo.AccountType at ON acc.AccountTypeID = at.AccountTypeID
    LEFT JOIN dbo.[Transaction] t ON acc.AccountID = t.AccountID
    WHERE ca.CustomerID = @CustomerID
    GROUP BY acc.AccountID, acc.AccountName, at.TypeName,
             acc.Status, acc.Balance, acc.OpeningDate;

    -- Outstanding overdue fees for this customer
    SELECT
        ovf.OverdueFeeID,
        acc.AccountName,
        ovf.TotalOwed,
        ovf.TotalRepaid,
        ovf.OutstandingBalance,
        ovf.DaysOverdue,
        ovf.FeeDate
    FROM dbo.OverdueFee ovf
    INNER JOIN dbo.[Transaction] t ON ovf.TransactionID = t.TransactionID
    INNER JOIN dbo.Account acc ON t.AccountID = acc.AccountID
    WHERE t.CustomerID = @CustomerID
      AND ovf.OutstandingBalance > 0;
END;
GO

-- Q7a TEST CASES
-- Customer 8 (Thomas) has a loan account with two overdue fees
EXEC uspCustomerAccountSummary @CustomerID = 8;

-- Customer 1 (James) has multiple accounts including joint
EXEC uspCustomerAccountSummary @CustomerID = 1;


-- ============================================================
-- Q7b: TRIGGER - Archive Customer on Deactivation
-- ============================================================

-- First create the archive table
CREATE TABLE dbo.ArchivedCustomer (
    ArchiveID       INT IDENTITY(1,1)   NOT NULL,
    CustomerID      INT                 NOT NULL,
    FirstName       NVARCHAR(50)        NOT NULL,
    LastName        NVARCHAR(50)        NOT NULL,
    Email           NVARCHAR(100)       NULL,
    Telephone       NVARCHAR(20)        NULL,
    DeactivationDate DATETIME2          NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_ArchivedCustomer PRIMARY KEY (ArchiveID)
);
GO

CREATE TRIGGER t_ArchiveDeactivatedCustomer
ON dbo.Customer
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only proceed if IsActive changed from 1 to 0
    IF UPDATE(IsActive)
    BEGIN
        INSERT INTO dbo.ArchivedCustomer (CustomerID, FirstName, LastName,
                                      Email, Telephone)
        SELECT i.CustomerID, i.FirstName, i.LastName, i.Email, i.Telephone
        FROM inserted i
        INNER JOIN deleted d ON i.CustomerID = d.CustomerID
        WHERE d.IsActive = 1 AND i.IsActive = 0;
    END
END;
GO

-- Q7b TEST CASES

-- BEFORE: Check ArchivedCustomer table is empty
SELECT * FROM dbo.ArchivedCustomer;

-- Deactivate Customer 5 (Fatima Ali)
UPDATE dbo.Customer SET IsActive = 0 WHERE CustomerID = 5;

-- AFTER: Fatima should now appear in the archive
SELECT * FROM dbo.ArchivedCustomer;

-- Verify Fatima is still in the Customer table (retained for marketing)
SELECT CustomerID, FirstName, LastName, IsActive
FROM dbo.Customer WHERE CustomerID = 5;


SELECT * FROM dbo.Customer;
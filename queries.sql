/* Banking Payments and Fraud Risk Analytics
   By Mary Babu
   SQL layer for the Power BI dashboard.
   Source: payments_200k.csv (200,000 real PaySim mobile money transactions)
   Load this file into any SQL engine (SQLite, PostgreSQL, SQL Server) after
   importing payments_200k.csv into a table called transactions. */

CREATE TABLE transactions (
    step            INTEGER,        -- simulation hour, 1 to 744 (30 days)
    type            TEXT,           -- PAYMENT, CASH_IN, CASH_OUT, TRANSFER, DEBIT
    amount          REAL,
    nameOrig        TEXT,           -- sending account id
    oldbalanceOrg   REAL,
    newbalanceOrig  REAL,
    nameDest        TEXT,           -- receiving account id (M prefix = merchant)
    oldbalanceDest  REAL,
    newbalanceDest  REAL,
    isFraud         INTEGER,        -- ground truth, 1 = fraud
    isFlaggedFraud  INTEGER         -- existing business rule flag
);


/* ---------------------------------------------------------------
   PAGE 1: EXECUTIVE OVERVIEW
   --------------------------------------------------------------- */

-- Total transactions, total value, overall fraud rate
SELECT
    COUNT(*)                                   AS total_transactions,
    ROUND(SUM(amount), 2)                      AS total_value,
    SUM(isFraud)                               AS fraud_count,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 3)  AS fraud_rate_pct,
    ROUND(AVG(amount), 2)                      AS avg_transaction_value
FROM transactions;

-- Fraud rate and count by transaction type
SELECT
    type,
    COUNT(*)                                   AS transaction_count,
    SUM(isFraud)                               AS fraud_count,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 3)  AS fraud_rate_pct
FROM transactions
GROUP BY type
ORDER BY fraud_count DESC;

-- Existing fraud rule effectiveness (how much fraud isFlaggedFraud actually catches)
SELECT
    SUM(isFlaggedFraud)                                            AS total_flagged,
    SUM(isFraud)                                                   AS total_fraud,
    SUM(CASE WHEN isFraud = 1 AND isFlaggedFraud = 1 THEN 1 ELSE 0 END) AS fraud_caught_by_rule,
    ROUND(100.0 * SUM(CASE WHEN isFraud = 1 AND isFlaggedFraud = 1 THEN 1 ELSE 0 END)
          / NULLIF(SUM(isFraud), 0), 1)                            AS pct_fraud_caught
FROM transactions;


/* ---------------------------------------------------------------
   PAGE 2: PAYMENT / TRANSACTION PERFORMANCE
   --------------------------------------------------------------- */

-- Volume and value by transaction type
SELECT
    type,
    COUNT(*)                AS transaction_count,
    ROUND(SUM(amount), 2)   AS total_value,
    ROUND(AVG(amount), 2)   AS avg_value
FROM transactions
GROUP BY type
ORDER BY transaction_count DESC;

-- Transaction volume over time (by simulation day, step is hourly, 24 steps = 1 day)
SELECT
    (step / 24) + 1                AS sim_day,
    COUNT(*)                        AS transaction_count,
    ROUND(SUM(amount), 2)           AS total_value,
    SUM(isFraud)                    AS fraud_count
FROM transactions
GROUP BY sim_day
ORDER BY sim_day;

-- Merchant vs customer destination split (data quality relevant: merchant balances are not tracked)
SELECT
    CASE WHEN nameDest LIKE 'M%' THEN 'Merchant' ELSE 'Customer' END AS dest_type,
    COUNT(*)                                                         AS transaction_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transactions), 1) AS pct_of_total
FROM transactions
GROUP BY dest_type;


/* ---------------------------------------------------------------
   PAGE 3: FRAUD AND RISK
   --------------------------------------------------------------- */

-- Fraud concentration: TRANSFER/CASH_OUT only, since no fraud exists outside these two types
SELECT
    type,
    COUNT(*)                                   AS transaction_count,
    SUM(isFraud)                               AS fraud_count,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 3)  AS fraud_rate_pct
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY type;

-- Full account drain as a risk signal (oldbalanceOrg > 0 and newbalanceOrig = 0)
SELECT
    isFraud,
    COUNT(*)                                                              AS transaction_count,
    SUM(CASE WHEN oldbalanceOrg > 0 AND newbalanceOrig = 0 THEN 1 ELSE 0 END) AS full_drain_count,
    ROUND(100.0 * SUM(CASE WHEN oldbalanceOrg > 0 AND newbalanceOrig = 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                                 AS full_drain_pct
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY isFraud;

-- Compounding risk segment: TRANSFER/CASH_OUT + full account drain
SELECT
    COUNT(*)                                   AS segment_size,
    SUM(isFraud)                               AS fraud_count,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 3)  AS fraud_rate_pct
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
  AND oldbalanceOrg > 0
  AND newbalanceOrig = 0;

-- Fraud amount profile vs legitimate (TRANSFER/CASH_OUT only)
SELECT
    isFraud,
    COUNT(*)                AS transaction_count,
    ROUND(AVG(amount), 2)   AS avg_amount,
    ROUND(MAX(amount), 2)   AS max_amount
FROM transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY isFraud;


/* ---------------------------------------------------------------
   PAGE 4: DATA QUALITY (supporting page, not customer facing)
   --------------------------------------------------------------- */

-- Origin balance reconciliation check
SELECT
    ROUND(100.0 * SUM(CASE WHEN ABS((oldbalanceOrg - amount) - newbalanceOrig) > 0.01
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_origin_mismatch
FROM transactions;

-- Destination balance reconciliation check, split by merchant vs customer
SELECT
    CASE WHEN nameDest LIKE 'M%' THEN 'Merchant' ELSE 'Customer' END AS dest_type,
    ROUND(100.0 * SUM(CASE WHEN ABS((oldbalanceDest + amount) - newbalanceDest) > 0.01
                           THEN 1 ELSE 0 END) / COUNT(*), 1)         AS pct_dest_mismatch
FROM transactions
GROUP BY dest_type;

-- Null and duplicate checks
SELECT COUNT(*) AS total_rows,
       COUNT(*) - COUNT(DISTINCT nameOrig || nameDest || step || amount) AS potential_duplicates
FROM transactions;

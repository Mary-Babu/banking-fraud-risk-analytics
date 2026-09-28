# Power BI dashboard spec

This is a page-by-page build spec for turning `payments_200k.csv` and `queries.sql` into a Power BI dashboard. Import the CSV directly into Power BI (Get Data > Text/CSV), then use the queries in `queries.sql` as a reference for the measures below, they're written in plain SQL but translate directly into DAX measures or Power Query steps.

## Page 1: Executive Overview

Cards across the top: total transactions (200,000), total transaction value, fraud count (147), fraud rate (0.073%), average transaction value.

Below that, two visuals: a donut or bar chart of transaction count by type, and a card or gauge showing the existing rule's catch rate (0 of 147, 0%). That last number is the one worth making prominent, it's the business case for the rest of the dashboard.

## Page 2: Payment Performance

Bar chart of transaction volume by type (PAYMENT, CASH_OUT, CASH_IN, TRANSFER, DEBIT). Line chart of transaction volume over time, using `step` grouped into simulation days (step / 24). A simple split visual showing merchant vs customer destination share, since that's directly tied to the data quality note on page 4.

## Page 3: Fraud and Risk

This is the core page. Bar chart of fraud rate by transaction type, filtered or highlighted to show TRANSFER and CASH_OUT are the only two with any fraud at all. A comparison visual (clustered bar or two cards side by side) showing full account drain rate for fraud (93.9%) vs legitimate (39.7%) transactions. A callout showing the compounding segment: TRANSFER/CASH_OUT transactions that fully drain the account sit at a 0.4% fraud rate, versus 0.073% overall.

## Page 4: Model Results and Data Quality

Table visual with the model comparison metrics (Accuracy, Precision, Recall, F1, ROC-AUC) for Logistic Regression, Random Forest, and XGBoost, with XGBoost highlighted as the preferred model. Below it, a small data quality callout: 76.7% origin balance mismatch, 87.1% destination balance mismatch, concentrated in merchant accounts where balances aren't tracked. This page reads as the "how was this analysis built and can it be trusted" page.

## General notes

Keep the same two-color system across all four pages (a neutral blue for volume/neutral metrics, a red or orange for fraud/risk metrics), consistent with the charts already in the notebook. Add a static filter or slicer for transaction type where useful, since PAYMENT/CASH_IN/DEBIT contribute zero fraud and clutter fraud-focused visuals if left in.

[README.md](https://github.com/user-attachments/files/32776484/README.md)
# Banking Payments and Fraud Risk Analytics

By Mary Babu

A bank's fraud rate looks reassuring on paper, 0.073% of 200,000 mobile money transactions in this dataset are actually fraud. That number alone would tell a risk team almost nothing about where to look. This project digs into 200,000 real transactions (a subset of the PaySim dataset, a widely used mobile money simulation built to mirror real transaction behavior) to find out where fraud actually concentrates, whether the existing detection rule is doing its job, and whether a model adds anything beyond what a manual review already shows.

## The approach

Same structure as an analyst would use on a live fraud queue: check the data quality first, segment by transaction type, look for where risk factors compound, test the current detection rule against ground truth, then build and evaluate a model against a naive baseline.

## Data quality

Before trusting any fraud pattern, the account balances needed a reconciliation check. 76.7% of transactions have an origin balance that doesn't mathematically reconcile with the amount moved, and 87.1% have the same issue on the destination side. Digging into why: the destination mismatch is concentrated in merchant accounts, where the source system doesn't track balances at all, both old and new balance sit at 0 regardless of transaction amount. That's a real limitation to flag rather than something to quietly work around, and it directly shaped which fields were usable for modeling.

## Where fraud actually happens

Every single fraud case in this dataset is either a TRANSFER or a CASH_OUT. PAYMENT, CASH_IN, and DEBIT transactions, which together make up over 60% of all volume, have zero fraud cases between them. That alone is a useful targeting rule: a monitoring team could ignore three of five transaction types and lose nothing.

Within TRANSFER and CASH_OUT, fraudulent transactions fully drain the sender's account 93.9% of the time, versus 39.7% for legitimate transactions in the same two types. Combining transaction type with a full account drain raises the fraud rate from a 0.073% baseline to 0.4%, a real but modest concentration on its own. That's honest context for why a rule alone isn't enough and a model is worth the extra step.

## The existing detection rule isn't working

The dataset includes a business rule flag (transfers over 200,000 get automatically flagged). It caught 0 of the 147 fraud cases in this sample. That's the actual justification for building a model here, not because manual segmentation failed, it clearly narrowed the problem down, but because the current automated flag isn't doing anything at all.

## The model

Fraud is rare enough (0.073% overall) that a naive model predicting "not fraud" for every transaction would be 99.926% accurate while catching zero fraud. Because fraud only ever appears in TRANSFER and CASH_OUT transactions, the model was trained on that subset only, which also makes the class imbalance more workable.

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC |
|---|---|---|---|---|---|
| Logistic Regression | 0.84 | 0.01 | 0.97 | 0.02 | 0.97 |
| Random Forest | 1.00 | 0.29 | 0.73 | 0.42 | 0.98 |
| **XGBoost** | **1.00** | **0.34** | **0.84** | **0.49** | **0.99** |

Logistic Regression catches 97% of fraud but at a precision of 0.01, about 99 out of every 100 transactions it flags are not fraud. That's not usable for a real review team, it would bury them in false alarms. XGBoost is the preferred model here: best ROC-AUC, best F1, and a precision/recall balance a fraud queue could actually work with.

XGBoost's top features (destination balance, full account drain, origin balance, and transaction amount) line up with what the manual segmentation already found, which is what makes the model trustworthy to act on instead of a black box.

## Recommendation

Restrict real-time fraud monitoring to TRANSFER and CASH_OUT transactions first, since no other transaction type has ever produced a fraud case in this data. Replace or supplement the static "transfers over 200,000" rule, since it caught zero actual fraud in this sample, with the model's ranked risk score. And treat a full account drain as a standing risk signal worth surfacing on its own, even before a transaction crosses any fixed dollar threshold.

## Files

`payments_200k.csv` is the source data (200,000 real PaySim mobile money transactions, sourced from the public PaySim dataset). `fraud_analysis.ipynb` is the full analysis notebook: data quality checks, segmentation, the existing rule's effectiveness, model comparison, and feature importance. `queries.sql` is the SQL layer behind the dashboard, covering executive overview, payment performance, fraud and risk, and data quality. `dashboard_spec.md` is the page-by-page spec for building the Power BI dashboard from these queries. `chart1.png` through `chart4.png` are the charts from the notebook.

## Tech stack

Python, pandas, scikit-learn, XGBoost, matplotlib/seaborn, SQL, Power BI.

## Running it

```
pip install pandas numpy scikit-learn xgboost matplotlib seaborn
jupyter notebook fraud_analysis.ipynb
```

# 📊 Dataset Access & Architecture

Due to GitHub's file size limits (>100MB), the full 490MB raw dataset (6.36M+ records) is hosted externally.

* **Raw Data Source:** [Kaggle — PaySim Synthetic Financial Datasets For Fraud Detection](https://www.kaggle.com/datasets/ealaxi/paysim1)
* **File Format:** CSV (`PS_20174392719_1491204439457_log.csv` / `fraud_transactions.csv`)
* **Converted Parquet Format:** Generated locally via DuckDB (`Python/01_bigquery_ingestion.py`) for cloud streaming into Google BigQuery.

### Schema Attributes:
| Attribute | Type | Description |
| :--- | :--- | :--- |
| `step` | INT64 | Time step in hours (1 step = 1 hour) |
| `type` | STRING | Transaction rail (`TRANSFER`, `CASH_OUT`, `PAYMENT`, etc.) |
| `amount` | NUMERIC | Transaction value in local currency |
| `nameOrig` | STRING | Customer ID originating the transaction |
| `oldbalanceOrg` | NUMERIC | Initial balance before transaction |
| `newbalanceOrig`| NUMERIC | New balance after transaction |
| `nameDest` | STRING | Recipient account ID |
| `oldbalanceDest`| NUMERIC | Initial balance of recipient |
| `newbalanceDest`| NUMERIC | New balance of recipient |
| `isFraud` | INT64 | Ground-truth fraud label (1 = Fraud, 0 = Normal) |
| `isFlaggedFraud`| INT64 | Legacy threshold flag (>200,000 units) |

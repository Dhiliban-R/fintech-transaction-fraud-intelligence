"""
01_bigquery_ingestion.py
Description: Local DuckDB Parquet conversion and Google BigQuery staging script.
Author: Dhiliban R
"""

import duckdb
from google.cloud import bigquery

PROJECT_ID = "fintech-fraud-intelligence"
DATASET_ID = "fraud_analytics"
TABLE_ID = "raw_transactions"
CSV_PATH = "/content/fraud_transactions.csv"
PARQUET_PATH = "/content/fraud_transactions.parquet"

def convert_csv_to_parquet():
    print("1. Converting CSV to Apache Parquet via DuckDB...")
    duckdb.query(f"""
        COPY (
            SELECT * 
            FROM read_csv_auto('{CSV_PATH}', header=True, ignore_errors=true)
        ) 
        TO '{PARQUET_PATH}' (FORMAT PARQUET);
    """)
    print("   Parquet conversion complete.")

def upload_parquet_to_bigquery():
    print("2. Streaming Parquet directly to Google BigQuery...")
    client = bigquery.Client(project=PROJECT_ID)
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    with open(PARQUET_PATH, "rb") as source_file:
        load_job = client.load_table_from_file(source_file, table_ref, job_config=job_config)

    load_job.result()
    print(f"   Table successfully created and populated: {table_ref}")

if __name__ == "__main__":
    convert_csv_to_parquet()
    upload_parquet_to_bigquery()

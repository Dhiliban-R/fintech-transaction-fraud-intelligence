-- =============================================================================
-- 01_schema_ddl.sql
-- Description: Star Schema Data Definition Language (DDL) for Google BigQuery
-- Author: Dhiliban R
-- =============================================================================

-- 1. Time Dimension
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.dim_step` (
    step_id INT64,
    simulation_day INT64,
    hour_of_day INT64,
    is_off_peak BOOL
);

-- 2. Transaction Rail Dimension
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.dim_transaction_types` (
    type_id STRING,
    rail_category STRING,
    is_outbound_rail BOOL
);

-- 3. Account Entity Dimension
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.dim_accounts` (
    account_id STRING,
    account_type STRING,
    first_activity_step INT64
);

-- 4. Central Partitioned Fact Table
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.fact_transactions` (
    transaction_id STRING,
    step_id INT64,
    type_id STRING,
    orig_account_id STRING,
    dest_account_id STRING,
    amount NUMERIC,
    oldbalance_orig NUMERIC,
    newbalance_orig NUMERIC,
    oldbalance_dest NUMERIC,
    newbalance_dest NUMERIC,
    orig_balance_delta NUMERIC,
    is_balance_depleted INT64,
    is_fraud INT64,
    is_flagged_fraud INT64
)
PARTITION BY RANGE_BUCKET(step_id, GENERATE_ARRAY(1, 744, 24));

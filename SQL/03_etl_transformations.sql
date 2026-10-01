-- =============================================================================
-- 03_etl_transformations.sql
-- Description: Star Schema Population and Semantic Analytical Views
-- Author: Dhiliban R
-- =============================================================================

-- 1. Populate Time Dimension
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.dim_step` AS
SELECT DISTINCT
    step AS step_id,
    CAST(FLOOR((step - 1) / 24) + 1 AS INT64) AS simulation_day,
    MOD(step - 1, 24) AS hour_of_day,
    CASE WHEN MOD(step - 1, 24) BETWEEN 0 AND 6 THEN TRUE ELSE FALSE END AS is_off_peak
FROM `fintech-fraud-intelligence.fraud_analytics.raw_transactions`
ORDER BY step_id;

-- 2. Populate Transaction Type Dimension
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.dim_transaction_types` AS
SELECT DISTINCT
    TRIM(UPPER(type)) AS type_id,
    CASE 
        WHEN TRIM(UPPER(type)) IN ('TRANSFER', 'CASH_OUT') THEN 'HIGH_RISK_OUTFLOW'
        ELSE 'STANDARD_CHANNEL'
    END AS rail_category,
    CASE 
        WHEN TRIM(UPPER(type)) IN ('TRANSFER', 'CASH_OUT', 'PAYMENT', 'DEBIT') THEN TRUE 
        ELSE FALSE 
    END AS is_outbound_rail
FROM `fintech-fraud-intelligence.fraud_analytics.raw_transactions`;

-- 3. Populate Account Entity Dimension
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.dim_accounts` AS
WITH combined_accounts AS (
    SELECT nameOrig AS account_id, step FROM `fintech-fraud-intelligence.fraud_analytics.raw_transactions`
    UNION ALL
    SELECT nameDest AS account_id, step FROM `fintech-fraud-intelligence.fraud_analytics.raw_transactions`
)
SELECT 
    account_id,
    CASE 
        WHEN STARTS_WITH(account_id, 'M') THEN 'MERCHANT'
        ELSE 'CUSTOMER'
    END AS account_type,
    MIN(step) AS first_activity_step
FROM combined_accounts
GROUP BY account_id, account_type;

-- 4. Populate Central Partitioned Fact Table with Engineered Features
CREATE OR REPLACE TABLE `fintech-fraud-intelligence.fraud_analytics.fact_transactions`
PARTITION BY RANGE_BUCKET(step_id, GENERATE_ARRAY(1, 744, 24)) AS
SELECT
    GENERATE_UUID() AS transaction_id,
    step AS step_id,
    TRIM(UPPER(type)) AS type_id,
    nameOrig AS orig_account_id,
    nameDest AS dest_account_id,
    CAST(amount AS NUMERIC) AS amount,
    CAST(oldbalanceOrg AS NUMERIC) AS oldbalance_orig,
    CAST(newbalanceOrig AS NUMERIC) AS newbalance_orig,
    CAST(oldbalanceDest AS NUMERIC) AS oldbalance_dest,
    CAST(newbalanceDest AS NUMERIC) AS newbalance_dest,
    CAST(oldbalanceOrg - newbalanceOrig AS NUMERIC) AS orig_balance_delta,
    CASE WHEN oldbalanceOrg > 0 AND newbalanceOrig = 0 THEN 1 ELSE 0 END AS is_balance_depleted,
    isFraud AS is_fraud,
    isFlaggedFraud AS is_flagged_fraud
FROM `fintech-fraud-intelligence.fraud_analytics.raw_transactions`;

-- 5. Semantic Presentation Layer: Enriched Transactions View
CREATE OR REPLACE VIEW `fintech-fraud-intelligence.fraud_analytics.vw_enriched_transactions` AS
SELECT
    f.transaction_id,
    f.step_id,
    s.simulation_day,
    s.hour_of_day,
    s.is_off_peak,
    f.type_id,
    tt.rail_category,
    tt.is_outbound_rail,
    f.orig_account_id,
    orig_acc.account_type AS orig_account_type,
    f.dest_account_id,
    dest_acc.account_type AS dest_account_type,
    f.amount,
    f.oldbalance_orig,
    f.newbalance_orig,
    f.oldbalance_dest,
    f.newbalance_dest,
    f.orig_balance_delta,
    f.is_balance_depleted,
    f.is_fraud,
    f.is_flagged_fraud,
    
    -- Risk Exposure Tiering
    CASE 
        WHEN f.amount >= 200000 THEN 'TIER_1_CRITICAL (>200k)'
        WHEN f.amount >= 50000  THEN 'TIER_2_HIGH (50k-200k)'
        WHEN f.amount >= 10000  THEN 'TIER_3_MEDIUM (10k-50k)'
        ELSE 'TIER_4_LOW (<10k)'
    END AS risk_exposure_tier,
    
    -- Exact Balance Drained Anomaly
    CASE 
        WHEN f.amount = f.oldbalance_orig AND f.newbalance_orig = 0 THEN 1 
        ELSE 0 
    END AS is_exact_drain

FROM `fintech-fraud-intelligence.fraud_analytics.fact_transactions` f
LEFT JOIN `fintech-fraud-intelligence.fraud_analytics.dim_step` s 
    ON f.step_id = s.step_id
LEFT JOIN `fintech-fraud-intelligence.fraud_analytics.dim_transaction_types` tt 
    ON f.type_id = tt.type_id
LEFT JOIN `fintech-fraud-intelligence.fraud_analytics.dim_accounts` orig_acc 
    ON f.orig_account_id = orig_acc.account_id
LEFT JOIN `fintech-fraud-intelligence.fraud_analytics.dim_accounts` dest_acc 
    ON f.dest_account_id = dest_acc.account_id;

-- 6. Semantic Presentation Layer: Mule Network Summary View
CREATE OR REPLACE VIEW `fintech-fraud-intelligence.fraud_analytics.vw_destination_mule_summary` AS
SELECT
    dest_account_id,
    COUNT(*) AS total_inward_transactions,
    SUM(amount) AS total_inward_volume,
    SUM(is_fraud) AS total_fraud_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END) AS total_fraud_volume_received,
    MAX(is_fraud) AS has_confirmed_fraud
FROM `fintech-fraud-intelligence.fraud_analytics.fact_transactions`
GROUP BY dest_account_id;

-- =============================================================================
-- 02_data_cleaning_audit.sql
-- Description: Data hygiene and mathematical integrity audits across raw logs
-- Author: Dhiliban R
-- =============================================================================

SELECT
    COUNT(*) AS total_rows,
    
    -- Check for NULL values across critical attributes
    COUNTIF(type IS NULL) AS null_types,
    COUNTIF(amount IS NULL) AS null_amounts,
    COUNTIF(nameOrig IS NULL) AS null_origin_accounts,
    COUNTIF(nameDest IS NULL) AS null_dest_accounts,
    COUNTIF(isFraud IS NULL) AS null_fraud_flags,
    
    -- Check for negative values (mathematical anomalies)
    COUNTIF(amount < 0) AS negative_amounts,
    COUNTIF(oldbalanceOrg < 0 OR newbalanceOrig < 0) AS negative_origin_balances,
    COUNTIF(oldbalanceDest < 0 OR newbalanceDest < 0) AS negative_dest_balances,
    
    -- Check for invalid transaction rail classifications
    COUNTIF(TRIM(UPPER(type)) NOT IN ('PAYMENT', 'TRANSFER', 'CASH_OUT', 'DEBIT', 'CASH_IN')) AS invalid_rail_types
FROM `fintech-fraud-intelligence.fraud_analytics.raw_transactions`;

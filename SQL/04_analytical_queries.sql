-- =============================================================================
-- 04_analytical_queries.sql
-- Description: Core business metrics, window functions, and legacy rule audits
-- Author: Dhiliban R
-- =============================================================================

-- Query 1: Rail Vulnerability & Basis Points (bps) Breakdown
SELECT
    type_id AS transaction_type,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 4) AS fraud_rate_pct,
    ROUND(SUM(amount), 2) AS total_processed_volume,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS total_fraud_volume,
    ROUND(
        (SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END) / NULLIF(SUM(amount), 0)) * 10000, 
        2
    ) AS fraud_basis_points_bps
FROM `fintech-fraud-intelligence.fraud_analytics.vw_enriched_transactions`
GROUP BY type_id
ORDER BY total_fraud_volume DESC;

-- Query 2: Origin "Zero-Balance Drain" Signature Breakdown
SELECT
    is_balance_depleted,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 4) AS fraud_probability_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS fraud_volume_lost
FROM `fintech-fraud-intelligence.fraud_analytics.vw_enriched_transactions`
WHERE rail_category = 'HIGH_RISK_OUTFLOW'
GROUP BY is_balance_depleted;

-- Query 3: Cumulative Bleed Timeline & 3-Step Rolling Moving Average
WITH hourly_fraud AS (
    SELECT 
        step_id,
        simulation_day,
        hour_of_day,
        COUNT(CASE WHEN is_fraud = 1 THEN 1 END) AS hourly_fraud_count,
        SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END) AS hourly_fraud_loss
    FROM `fintech-fraud-intelligence.fraud_analytics.vw_enriched_transactions`
    GROUP BY step_id, simulation_day, hour_of_day
)
SELECT
    step_id,
    simulation_day,
    hour_of_day,
    hourly_fraud_count,
    ROUND(hourly_fraud_loss, 2) AS hourly_fraud_loss,
    ROUND(SUM(hourly_fraud_loss) OVER (ORDER BY step_id), 2) AS running_cumulative_fraud_loss,
    ROUND(AVG(hourly_fraud_loss) OVER (ORDER BY step_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3step_avg_fraud_loss
FROM hourly_fraud
ORDER BY step_id;

-- Query 4: Top Money Mule Recipient Ranking (Dense Rank)
WITH mule_metrics AS (
    SELECT
        dest_account_id,
        total_inward_transactions,
        total_fraud_transactions,
        total_fraud_volume_received
    FROM `fintech-fraud-intelligence.fraud_analytics.vw_destination_mule_summary`
    WHERE total_fraud_transactions > 0
)
SELECT
    DENSE_RANK() OVER (ORDER BY total_fraud_volume_received DESC) AS risk_rank,
    dest_account_id,
    total_inward_transactions,
    total_fraud_transactions,
    ROUND(total_fraud_volume_received, 2) AS total_stolen_capital_received
FROM mule_metrics
LIMIT 10;

-- Query 5: Legacy Rule Performance & Undetected Capital Leakage Audit
SELECT
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS total_actual_fraud,
    SUM(CASE WHEN is_flagged_fraud = 1 THEN 1 ELSE 0 END) AS total_legacy_flagged,
    SUM(CASE WHEN is_fraud = 1 AND is_flagged_fraud = 1 THEN 1 ELSE 0 END) AS true_positives_caught,
    SUM(CASE WHEN is_fraud = 1 AND is_flagged_fraud = 0 THEN 1 ELSE 0 END) AS false_negatives_missed,
    ROUND(
        SUM(CASE WHEN is_fraud = 1 AND is_flagged_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END), 0), 
        4
    ) AS legacy_capture_rate_recall_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS total_fraud_capital_at_risk,
    ROUND(SUM(CASE WHEN is_fraud = 1 AND is_flagged_fraud = 0 THEN amount ELSE 0 END), 2) AS undetected_capital_leaked
FROM `fintech-fraud-intelligence.fraud_analytics.vw_enriched_transactions`;

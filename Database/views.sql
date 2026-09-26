-- 1. FIRST-EXPIRED, FIRST-OUT (FEFO) DISPENSING QUEUE 
-- Automatically sorts batches so pharmacists always dispense the oldest valid lot first.
CREATE OR REPLACE VIEW vw_fefo_dispensing_queue AS
SELECT 
    b.current_facility_id AS facility_id,
    f.name AS facility_name,
    f.facility_type,
    d.id AS drug_id,
    d.brand_name,
    d.generic_name,
    d.category AS drug_category,
    d.criticality,
    d.storage_condition,
    b.id AS batch_id,
    b.batch_number,
    b.expiry_date,
    (b.expiry_date - CURRENT_DATE) AS days_to_expiry,
    b.current_quantity,
    b.status AS batch_status,
    ROW_NUMBER() OVER (
        PARTITION BY b.current_facility_id, b.drug_id 
        ORDER BY b.expiry_date ASC
    ) AS fefo_priority_rank
FROM drug_batches b
JOIN drug_master d ON b.drug_id = d.id
JOIN facilities f ON b.current_facility_id = f.id
WHERE b.current_quantity > 0 
  AND b.status IN ('RELEASED', 'NEAR_EXPIRY')
  AND b.expiry_date > CURRENT_DATE;

-- 2. FACILITY REAL-TIME STOCK ALERT MATRIX 
-- Evaluates total facility stock against safety thresholds to flag deficits or surpluses.
CREATE OR REPLACE VIEW vw_facility_stock_alerts AS
WITH facility_stock AS (
    SELECT 
        ib.facility_id,
        ib.drug_id,
        SUM(ib.quantity_on_hand) AS total_on_hand,
        SUM(ib.quantity_reserved) AS total_reserved
    FROM inventory_balances ib
    GROUP BY ib.facility_id, ib.drug_id
)
SELECT 
    f.id AS facility_id,
    f.name AS facility_name,
    f.facility_type,
    f.district,
    d.id AS drug_id,
    d.brand_name,
    d.generic_name,
    d.criticality,
    d.min_stock_threshold,
    d.target_stock_level,
    COALESCE(fs.total_on_hand, 0) AS current_stock,
    CASE 
        WHEN COALESCE(fs.total_on_hand, 0) = 0 THEN 'OUT_OF_STOCK'
        WHEN COALESCE(fs.total_on_hand, 0) <= d.min_stock_threshold THEN 'LOW_STOCK'
        WHEN COALESCE(fs.total_on_hand, 0) > d.target_stock_level THEN 'OVERSTOCK'
        ELSE 'HEALTHY'
    END AS stock_status,
    CASE 
        WHEN COALESCE(fs.total_on_hand, 0) <= d.min_stock_threshold 
            THEN (d.target_stock_level - COALESCE(fs.total_on_hand, 0))
        ELSE 0 
    END AS replenishment_deficit_units,
    CASE 
        WHEN COALESCE(fs.total_on_hand, 0) > d.target_stock_level 
            THEN (COALESCE(fs.total_on_hand, 0) - d.target_stock_level)
        ELSE 0 
    END AS potential_surplus_units
FROM facilities f
CROSS JOIN drug_master d
LEFT JOIN facility_stock fs ON f.id = fs.facility_id AND d.id = fs.drug_id
WHERE f.facility_type IN ('DISTRICT_HOSPITAL', 'PRIMARY_HEALTH_CENTER', 'REGIONAL_WAREHOUSE');

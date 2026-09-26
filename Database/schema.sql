-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Optional PostGIS extension (uncomment if PostGIS is installed on your server)
-- CREATE EXTENSION IF NOT EXISTS "postgis";

-- Drop tables in reverse order of dependencies if recreating
DROP TABLE IF EXISTS system_notifications CASCADE;
DROP TABLE IF EXISTS audit_event_ledger CASCADE;
DROP TABLE IF EXISTS near_expiry_rescue_plans CASCADE;
DROP TABLE IF EXISTS transfer_shipment_links CASCADE;
DROP TABLE IF EXISTS transfer_recommendations CASCADE;
DROP TABLE IF EXISTS hospital_drug_risk_scores CASCADE;
DROP TABLE IF EXISTS daily_consumption_summary CASCADE;
DROP TABLE IF EXISTS drug_consumption_logs CASCADE;
DROP TABLE IF EXISTS shipment_items CASCADE;
DROP TABLE IF EXISTS shipments CASCADE;
DROP TABLE IF EXISTS inventory_transactions CASCADE;
DROP TABLE IF EXISTS inventory_balances CASCADE;
DROP TABLE IF EXISTS qc_inspections CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;
DROP TABLE IF EXISTS drug_batches CASCADE;
DROP TABLE IF EXISTS drug_master CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS facilities CASCADE;

-- ============================================================================
-- 1. FACILITIES & LOCATIONS (Warehouses & Hospitals)
-- ============================================================================
CREATE TABLE facilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    facility_type VARCHAR(30) NOT NULL CHECK (facility_type IN ('CENTRAL_WAREHOUSE', 'REGIONAL_WAREHOUSE', 'DISTRICT_HOSPITAL', 'PRIMARY_HEALTH_CENTER')),
    district VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL DEFAULT 'Maharashtra',
    address TEXT NOT NULL,
    latitude NUMERIC(9,6) NOT NULL,
    longitude NUMERIC(9,6) NOT NULL,
    bed_capacity INTEGER DEFAULT 0,
    current_bed_occupancy INTEGER DEFAULT 0,
    contact_phone VARCHAR(50),
    contact_email VARCHAR(150),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_facilities_type ON facilities(facility_type);
CREATE INDEX idx_facilities_district ON facilities(district);

-- ============================================================================
-- 2. USERS & ROLE-BASED ACCESS CONTROL (RBAC) (Module 11)
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('GOV_OFFICER', 'WAREHOUSE_MGR', 'PHARMACIST', 'VENDOR', 'ADMIN')),
    assigned_facility_id UUID REFERENCES facilities(id) ON DELETE SET NULL,
    phone VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_facility ON users(assigned_facility_id);

-- ============================================================================
-- 3. DRUG MASTER & BATCH LINEAGE (Module 01)
-- ============================================================================
CREATE TABLE drug_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drug_code VARCHAR(50) UNIQUE NOT NULL,
    brand_name VARCHAR(150) NOT NULL,
    generic_name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL, -- Antibiotic, Analgesic, Cardiovascular, Vaccine, etc.
    uom VARCHAR(30) NOT NULL,       -- vial, ampoule, tablet, strip, bottle
    dosage_form VARCHAR(50) NOT NULL, -- Injection, Tablet, Syrup, Infusion
    strength VARCHAR(50) NOT NULL,     -- 500mg, 10ml, 1g, etc.
    storage_condition VARCHAR(50) DEFAULT 'AMBIENT' CHECK (storage_condition IN ('AMBIENT', 'COLD_CHAIN', 'ULTRA_COLD', 'NARCOTIC')),
    criticality VARCHAR(20) DEFAULT 'ESSENTIAL' CHECK (criticality IN ('VITAL', 'ESSENTIAL', 'DESIRABLE')),
    unit_cost NUMERIC(10,2) NOT NULL DEFAULT 10.00,
    min_stock_threshold INTEGER NOT NULL DEFAULT 50,
    target_stock_level INTEGER NOT NULL DEFAULT 500,
    reorder_level INTEGER NOT NULL DEFAULT 150,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_drugs_category ON drug_master(category);
CREATE INDEX idx_drugs_criticality ON drug_master(criticality);

CREATE TABLE drug_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_number VARCHAR(100) NOT NULL,
    drug_id UUID NOT NULL REFERENCES drug_master(id) ON DELETE RESTRICT,
    manufacturing_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    initial_quantity INTEGER NOT NULL CHECK (initial_quantity > 0),
    current_quantity INTEGER NOT NULL CHECK (current_quantity >= 0),
    manufacturer_name VARCHAR(200) NOT NULL,
    qa_certificate_url TEXT,
    current_facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE RESTRICT,
    status VARCHAR(30) DEFAULT 'QUARANTINE' 
        CHECK (status IN ('QUARANTINE', 'RELEASED', 'NEAR_EXPIRY', 'RECALLED', 'EXPIRED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_batch_dates CHECK (expiry_date > manufacturing_date),
    CONSTRAINT uq_drug_batch UNIQUE (drug_id, batch_number)
);

CREATE INDEX idx_batches_expiry ON drug_batches(expiry_date, status);
CREATE INDEX idx_batches_facility ON drug_batches(current_facility_id, drug_id);

-- ============================================================================
-- 4. PROCUREMENT & VENDOR MANAGEMENT (Module 02)
-- ============================================================================
CREATE TABLE vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_code VARCHAR(50) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    license_number VARCHAR(100) NOT NULL,
    gmp_certified BOOLEAN DEFAULT TRUE,
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    address TEXT NOT NULL,
    performance_score NUMERIC(5,2) DEFAULT 100.00,
    is_active BOOLEAN DEFAULT TRUE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_number VARCHAR(50) UNIQUE NOT NULL,
    vendor_id UUID NOT NULL REFERENCES vendors(id),
    destination_facility_id UUID NOT NULL REFERENCES facilities(id),
    total_cost NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(30) DEFAULT 'SUBMITTED' 
        CHECK (status IN ('DRAFT', 'SUBMITTED', 'ACKNOWLEDGED', 'IN_TRANSIT', 'PARTIALLY_DELIVERED', 'COMPLETED', 'CANCELLED')),
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE NOT NULL,
    actual_delivery_date DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    ordered_quantity INTEGER NOT NULL CHECK (ordered_quantity > 0),
    unit_cost NUMERIC(10,2) NOT NULL,
    received_quantity INTEGER DEFAULT 0,
    accepted_quantity INTEGER DEFAULT 0,
    rejected_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE qc_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID NOT NULL REFERENCES purchase_orders(id),
    drug_batch_id UUID NOT NULL REFERENCES drug_batches(id),
    inspector_id UUID NOT NULL REFERENCES users(id),
    cold_chain_breached BOOLEAN DEFAULT FALSE,
    packaging_intact BOOLEAN DEFAULT TRUE,
    lab_test_passed BOOLEAN DEFAULT TRUE,
    inspection_decision VARCHAR(20) NOT NULL CHECK (inspection_decision IN ('ACCEPTED', 'REJECTED', 'PARTIAL')),
    rejected_quantity INTEGER DEFAULT 0,
    rejection_reason TEXT,
    inspection_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 5. INVENTORY BALANCES & TRANSACTION LEDGER (Module 03)
-- ============================================================================
CREATE TABLE inventory_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    drug_id UUID NOT NULL REFERENCES drug_master(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES drug_batches(id) ON DELETE CASCADE,
    quantity_on_hand INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    quantity_damaged INTEGER NOT NULL DEFAULT 0 CHECK (quantity_damaged >= 0),
    last_audited_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_facility_batch UNIQUE (facility_id, batch_id)
);

CREATE INDEX idx_inv_facility_drug ON inventory_balances(facility_id, drug_id);

CREATE TABLE inventory_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_type VARCHAR(30) NOT NULL 
        CHECK (transaction_type IN ('PO_RECEIPT', 'DISPENSE', 'TRANSFER_DISPATCH', 'TRANSFER_RECEIPT', 'AUDIT_ADJUSTMENT', 'DAMAGED_WRITE_OFF')),
    facility_id UUID NOT NULL REFERENCES facilities(id),
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    batch_id UUID NOT NULL REFERENCES drug_batches(id),
    quantity_delta INTEGER NOT NULL, -- Positive for addition, negative for deduction
    reason TEXT,
    reference_id UUID, -- Reference to PO ID, Transfer ID, or Dispense ID
    performed_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_inv_tx_timestamp ON inventory_transactions(created_at DESC);
CREATE INDEX idx_inv_tx_facility ON inventory_transactions(facility_id, drug_id);

-- ============================================================================
-- 6. DISTRIBUTION & SHIPMENT TRACKING (Module 04)
-- ============================================================================
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracking_number VARCHAR(100) UNIQUE NOT NULL,
    shipment_type VARCHAR(30) NOT NULL 
        CHECK (shipment_type IN ('VENDOR_TO_WH', 'WH_TO_WH', 'WH_TO_HOSPITAL', 'HOSPITAL_TO_HOSPITAL')),
    source_facility_id UUID NOT NULL REFERENCES facilities(id),
    destination_facility_id UUID NOT NULL REFERENCES facilities(id),
    carrier_name VARCHAR(150),
    driver_name VARCHAR(100),
    driver_contact VARCHAR(50),
    vehicle_number VARCHAR(50),
    dispatch_timestamp TIMESTAMP WITH TIME ZONE,
    expected_arrival_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_arrival_timestamp TIMESTAMP WITH TIME ZONE,
    status VARCHAR(30) DEFAULT 'CREATED' 
        CHECK (status IN ('CREATED', 'PICKING_PACKING', 'DISPATCHED', 'DELAYED', 'DELIVERED', 'RECEIVED', 'EXCEPTION')),
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_dest ON shipments(destination_facility_id, status);

CREATE TABLE shipment_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    batch_id UUID NOT NULL REFERENCES drug_batches(id),
    quantity_dispatched INTEGER NOT NULL CHECK (quantity_dispatched > 0),
    quantity_received INTEGER DEFAULT 0,
    quantity_rejected INTEGER DEFAULT 0,
    rejection_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 7. HOSPITAL CONSUMPTION & DEMAND INTELLIGENCE (Module 05)
-- ============================================================================
CREATE TABLE drug_consumption_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id UUID NOT NULL REFERENCES facilities(id),
    department_id VARCHAR(50) NOT NULL, -- ICU, Emergency, OPD, Surgery, Pediatrics
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    batch_id UUID NOT NULL REFERENCES drug_batches(id),
    quantity_dispensed INTEGER NOT NULL CHECK (quantity_dispensed > 0),
    patient_identifier_hash VARCHAR(64), -- Anonymized patient ID
    dispensed_by UUID NOT NULL REFERENCES users(id),
    dispensed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_dispense_hosp_drug ON drug_consumption_logs(hospital_id, drug_id, dispensed_at);

CREATE TABLE daily_consumption_summary (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id UUID NOT NULL REFERENCES facilities(id),
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    summary_date DATE NOT NULL,
    total_dispensed INTEGER NOT NULL DEFAULT 0,
    rolling_7d_avg NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    rolling_14d_avg NUMERIC(8,2) NOT NULL DEFAULT 0.00, -- ADC_14
    days_of_stock_remaining NUMERIC(6,2),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_hosp_drug_date UNIQUE (hospital_id, drug_id, summary_date)
);

CREATE INDEX idx_summary_runway ON daily_consumption_summary(days_of_stock_remaining);

-- ============================================================================
-- 8. HOSPITAL RISK & NEED SCORING ENGINE (Module 07 ⭐)
-- ============================================================================
CREATE TABLE hospital_drug_risk_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id UUID NOT NULL REFERENCES facilities(id),
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    current_stock INTEGER NOT NULL,
    daily_consumption NUMERIC(8,2) NOT NULL, -- ADC_14
    days_of_stock_remaining NUMERIC(6,2) NOT NULL,
    required_stock_level INTEGER NOT NULL,
    pipeline_stock INTEGER DEFAULT 0,
    stock_runway_score NUMERIC(5,2) NOT NULL DEFAULT 0.00, -- S_R (max 40)
    criticality_score NUMERIC(5,2) NOT NULL DEFAULT 0.00,   -- C_W (max 30)
    shortage_frequency_score NUMERIC(5,2) DEFAULT 0.00,    -- H_F (max 15)
    patient_surge_score NUMERIC(5,2) DEFAULT 0.00,         -- P_L (max 15)
    pipeline_credit_score NUMERIC(5,2) DEFAULT 0.00,       -- M_P (max -20)
    risk_score INTEGER NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'SURPLUS')),
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_hosp_drug_risk UNIQUE (hospital_id, drug_id)
);

CREATE INDEX idx_risk_score_level ON hospital_drug_risk_scores(risk_level, risk_score DESC);

-- ============================================================================
-- 9. INTELLIGENT LATERAL REDISTRIBUTION (Module 08 ⭐⭐⭐)
-- ============================================================================
CREATE TABLE transfer_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    batch_id UUID REFERENCES drug_batches(id),
    source_facility_id UUID NOT NULL REFERENCES facilities(id), -- Donor (Surplus)
    target_facility_id UUID NOT NULL REFERENCES facilities(id), -- Recipient (Deficit)
    recommended_quantity INTEGER NOT NULL CHECK (recommended_quantity > 0),
    distance_km NUMERIC(6,2) NOT NULL,
    estimated_transit_hours NUMERIC(4,1) NOT NULL,
    efficiency_score NUMERIC(8,2),
    justification_log JSONB NOT NULL, -- Detailed breakdown of score inputs
    transfer_type VARCHAR(30) DEFAULT 'SHORTAGE_DEFICIT' 
        CHECK (transfer_type IN ('SHORTAGE_DEFICIT', 'NEAR_EXPIRY_RESCUE')),
    status VARCHAR(30) DEFAULT 'PENDING_APPROVAL' 
        CHECK (status IN ('PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'DISPATCHED', 'COMPLETED', 'CANCELLED')),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transfer_status ON transfer_recommendations(status);
CREATE INDEX idx_transfer_target ON transfer_recommendations(target_facility_id, status);

CREATE TABLE transfer_shipment_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_id UUID NOT NULL REFERENCES transfer_recommendations(id),
    shipment_id UUID NOT NULL REFERENCES shipments(id),
    batch_id UUID NOT NULL REFERENCES drug_batches(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 10. NEAR-EXPIRY WASTAGE RESCUE PLANS (Module 09 ⭐⭐⭐)
-- ============================================================================
CREATE TABLE near_expiry_rescue_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES drug_batches(id),
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    source_facility_id UUID NOT NULL REFERENCES facilities(id),
    target_facility_id UUID NOT NULL REFERENCES facilities(id),
    days_to_expiry INTEGER NOT NULL,
    current_batch_quantity INTEGER NOT NULL,
    projected_local_burn INTEGER NOT NULL,
    at_risk_wastage_quantity INTEGER NOT NULL CHECK (at_risk_wastage_quantity > 0),
    projected_cost_saved NUMERIC(12,2) NOT NULL,
    status VARCHAR(30) DEFAULT 'RECOMMENDED' 
        CHECK (status IN ('RECOMMENDED', 'SANCTIONED', 'DISPATCHED', 'COMPLETED', 'EXPIRED_ON_SHELF')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 11. AUDIT EVENT LEDGER & ALERTS (Module 11)
-- ============================================================================
CREATE TABLE audit_event_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actor_id UUID NOT NULL REFERENCES users(id),
    actor_role VARCHAR(50) NOT NULL,
    actor_ip_address VARCHAR(45),
    facility_id UUID REFERENCES facilities(id),
    entity_name VARCHAR(100) NOT NULL, -- e.g., 'inventory_balances', 'transfer_recommendations'
    entity_id UUID NOT NULL,
    action_type VARCHAR(30) NOT NULL 
        CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE', 'APPROVE', 'REJECT', 'DISPATCH', 'RECEIVE', 'ADJUST')),
    previous_state JSONB,
    new_state JSONB,
    reason_for_change TEXT NOT NULL,
    record_hash VARCHAR(64) NOT NULL -- SHA-256 (prev_hash + new_state)
);

CREATE INDEX idx_audit_entity ON audit_event_ledger(entity_name, entity_id);
CREATE INDEX idx_audit_actor ON audit_event_ledger(actor_id, event_timestamp DESC);

CREATE TABLE system_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_role VARCHAR(50), -- Nullable for broadcast to role
    recipient_user_id UUID REFERENCES users(id),
    facility_id UUID REFERENCES facilities(id),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('CRITICAL', 'WARNING', 'INFO')),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    entity_name VARCHAR(100),
    entity_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notif_user ON system_notifications(recipient_user_id, is_read);
CREATE INDEX idx_notif_role ON system_notifications(recipient_role, is_read);

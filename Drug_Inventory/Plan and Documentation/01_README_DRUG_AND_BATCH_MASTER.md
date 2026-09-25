# 💊 Module 01: Drug & Batch Master Management

> **Core Foundational Layer:** Establishes the authoritative master record for all pharmaceutical substances and manages strict batch-level lineage across manufacturing, quarantine, distribution, and expiry.

---

## 🎯 1. Module Objective

In accordance with our core goal of delivering the **Right Product** and **Right Condition**, this module acts as the single source of truth for the entire supply chain. It decouples the clinical/generic definition of a medication from physical production lots (batches), enabling granular serialization and shelf-life tracking.

---

## 📋 2. Domain Specifications

### A. Drug Master Entity
Every therapeutic compound is registered with standardized national/international drug codification (e.g., RxNorm / NDC / WHO ATC):
* **Drug ID:** Universally unique identifier (UUID / Standard Code).
* **Drug Name:** Official commercial or common formulation name.
* **Generic / Brand Information:** Active Pharmaceutical Ingredient (API) vs. Proprietary brand name.
* **Drug Category:** Therapeutic class (e.g., Antibiotic, Cardiovascular, Analgesic, Vaccine, Oncology).
* **Unit of Measurement (UOM):** Dispensing unit (e.g., `vial`, `tablet`, `ampoule`, `strip`, `bottle`, `blister_pack`).
* **Minimum Stock Threshold ($Q_{min}$):** Absolute safety floor below which critical stockout warnings trigger.
* **Maximum / Target Stock Level ($Q_{max}$):** Upper storage ceiling to prevent capital lockup and local overstocking.
* **Reorder Level ($Q_{reorder}$):** Economic order point considering lead time.
* **Storage Requirements:** Temperature sensitivity flags:
  * Ambient ($15^\circ\text{C} - 25^\circ\text{C}$)
  * Cold Chain ($2^\circ\text{C} - 8^\circ\text{C}$)
  * Ultra-Cold ($-20^\circ\text{C} \text{ to } -80^\circ\text{C}$)
  * Controlled Substance / Narcotic Lockbox requirements.
* **Criticality / Priority Index (VED Classification):**
  * **V (Vital):** Life-saving drug; zero stockout tolerance (e.g., Adrenaline, Insulin, Antivenom).
  * **E (Essential):** Clinical necessity; high priority (e.g., Antibiotics, Antihypertensives).
  * **D (Desirable):** Supportive therapy; standard priority (e.g., Multivitamins, Antacids).
* **Status:** Active / Discontinued / Suspended.

### B. Batch-Level Entity
Every physical shipment entering our network is broken down into verifiable batches:
* **Batch ID:** Unique manufacturer-assigned lot number.
* **Drug ID:** Foreign key linking to the parent Drug Master.
* **Manufacturing Date ($T_{mfg}$):** Production timestamp.
* **Expiry Date ($T_{exp}$):** Date beyond which the drug becomes clinically unsafe or inactive.
* **Total Batch Quantity:** Initial volume manufactured / received.
* **Manufacturing & Quality Information:** Manufacturer license number, QA certificate URL, lab assay test results.
* **Current Physical Location:** Warehouse ID or Hospital ID currently holding custody.
* **Batch Status:**
  * `QUARANTINE`: Awaiting QA lab inspection.
  * `RELEASED`: Cleared for distribution and dispensing.
  * `NEAR_EXPIRY`: Flagged by our near-expiry engine ($< 90$ days remaining).
  * `RECALLED`: Administratively locked due to defect alert.
  * `EXPIRED`: Locked; zero dispensing permitted.

---

## 🗄️ 3. Database Schema Blueprint

```sql
-- Drug Master Table
CREATE TABLE drug_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drug_code VARCHAR(50) UNIQUE NOT NULL,
    brand_name VARCHAR(150) NOT NULL,
    generic_name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    uom VARCHAR(30) NOT NULL,
    dosage_form VARCHAR(50) NOT NULL, -- Tablet, Syrup, Injection
    strength VARCHAR(50) NOT NULL,     -- 500mg, 10ml, etc.
    storage_condition VARCHAR(50) DEFAULT 'AMBIENT' CHECK (storage_condition IN ('AMBIENT', 'COLD_CHAIN', 'ULTRA_COLD', 'NARCOTIC')),
    criticality VARCHAR(20) DEFAULT 'ESSENTIAL' CHECK (criticality IN ('VITAL', 'ESSENTIAL', 'DESIRABLE')),
    min_stock_threshold INTEGER NOT NULL DEFAULT 50,
    target_stock_level INTEGER NOT NULL DEFAULT 500,
    reorder_level INTEGER NOT NULL DEFAULT 150,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Batch Master Table
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
    current_location_id UUID NOT NULL, -- References warehouses(id) or hospitals(id)
    current_location_type VARCHAR(20) NOT NULL CHECK (current_location_type IN ('WAREHOUSE', 'HOSPITAL')),
    status VARCHAR(30) DEFAULT 'QUARANTINE' CHECK (status IN ('QUARANTINE', 'RELEASED', 'NEAR_EXPIRY', 'RECALLED', 'EXPIRED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_dates CHECK (expiry_date > manufacturing_date),
    CONSTRAINT uq_drug_batch UNIQUE (drug_id, batch_number)
);

CREATE INDEX idx_batches_expiry ON drug_batches(expiry_date, status);
CREATE INDEX idx_batches_location ON drug_batches(current_location_id, drug_id);
```

---

## 🔌 4. API Endpoints

| Method | Endpoint | Description | Role Required |
|---|---|---|---|
| `POST` | `/api/v1/drugs` | Register a new drug master record | `GOV_OFFICER` |
| `GET` | `/api/v1/drugs` | Filterable catalog (by category, VED criticality, storage) | All Authenticated |
| `GET` | `/api/v1/drugs/{id}` | Detailed drug view with linked active batches | All Authenticated |
| `PUT` | `/api/v1/drugs/{id}` | Update thresholds, reorder points, or active status | `GOV_OFFICER` |
| `POST` | `/api/v1/batches` | Register incoming batch from procurement order | `WAREHOUSE_MGR` |
| `GET` | `/api/v1/batches/expiring` | Query batches expiring within $N$ days | `GOV_OFFICER`, `PHARMACIST` |
| `PATCH` | `/api/v1/batches/{id}/status` | Update batch status (e.g. quarantine release, recall) | `GOV_OFFICER`, `QA_OFFICER` |

---

## ⚡ 5. Integration with Our Innovation Layer

The granular batch metadata maintained here forms the prerequisite foundation for:
1. **Our Near-Expiry Redistribution Engine (Module 09):** Batches nearing expiry are identified by `expiry_date` and matched with hospital burn rates to avoid expiration waste.
2. **First-Expired, First-Out (FEFO) Enforcement:** When fulfilling dispensing orders or distribution requests, stock allocation is strictly sorted by `ORDER BY expiry_date ASC`.

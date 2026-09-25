# 🏭 Module 02: Procurement & Vendor Management

> **Inbound Supply Operations:** Governs the end-to-end commercial lifecycle—from vendor onboarding and purchase order (PO) generation to stringent dockside Quality Control (QC) inspection, batch acceptance/rejection, and vendor scorecard calculation.

---

## 🎯 1. Module Objective

This module guarantees the **Right Cost**, **Right Product**, and **Right Condition** right at the entry point of the supply chain. By recording quality assays and delivery punctuality, our system ensures that substandard pharmaceuticals never enter the distribution network and that supplier reliability is dynamically measured.

---

## 🏢 2. Domain Specifications

### A. Vendor Management & Performance Tracking
* **Vendor Profile:** Corporate registration, Good Manufacturing Practice (GMP) certifications, tax identification, contact hierarchy, and cold-chain compliance capabilities.
* **Drug Catalog Authorization:** Specific list of Drug Master IDs the vendor is legally certified and contracted to supply.
* **Historical Ledger:** Complete historical logs of past purchase orders, delivered lots, delivery transit durations, and quality test outcomes.
* **Vendor Performance Index ($VPI \in [0, 100]$):** Calculated across three weighted components:
  1. **Fulfillment Rate ($F_r$ - 40%):** $\frac{\text{Accepted Quantity}}{\text{Ordered Quantity}}$
  2. **On-Time Delivery Rate ($O_d$ - 35%):** $\frac{\text{On-Time Deliveries}}{\text{Total Completed Shipments}}$
  3. **Quality Compliance Rate ($Q_c$ - 25%):** $\frac{\text{Accepted Batches}}{\text{Total Batches Inspected}}$

$$VPI = (0.40 \times F_r) + (0.35 \times O_d) + (0.25 \times Q_c)$$

### B. Purchase Order (PO) & Procurement Management
* **PO Lifecycle:**
  `DRAFT` ──► `SUBMITTED` ──► `VENDOR_ACKNOWLEDGED` ──► `IN_TRANSIT` ──► `PARTIALLY_DELIVERED` ──► `FULFILLED` / `CANCELLED`
* **Order Fields:** Unique PO Number, Central/Regional Warehouse destination, Line items (Drug ID, target unit cost, quantity), delivery terms, contractual delivery deadline ($T_{expected}$).
* **Tracking Quantities:**
  * $\text{Ordered Quantity}$
  * $\text{Received Quantity}$
  * $\text{Accepted Quantity}$
  * $\text{Rejected Quantity}$
  * $\text{Pending Quantity} = \text{Ordered Quantity} - \text{Accepted Quantity}$

### C. Quality Control (QC) & Inspection Gateway
* **Receiving Dock Inspection:** Every consignment arriving at the warehouse gate is isolated into a physical and digital **Quarantine Zone**.
* **Inspection Protocol:**
  * Physical package condition (seal integrity, leakage, crushed cartons).
  * Cold-chain data logger reading (verifying temperature remained between $2^\circ\text{C} - 8^\circ\text{C}$ throughout transit).
  * Batch analytical assay certificate verification.
* **Acceptance / Rejection Workflow:**
  * **Accepted Batches:** Stock status shifts from `QUARANTINE` to `RELEASED`. Inward inventory balance is incremented.
  * **Rejected Batches:** Stock marked `REJECTED`, moved to isolation area, return manifest generated, and vendor penalty applied.

---

## 🗄️ 3. Database Schema Blueprint

```sql
-- Vendors Table
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Purchase Orders Table
CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_number VARCHAR(50) UNIQUE NOT NULL,
    vendor_id UUID NOT NULL REFERENCES vendors(id),
    destination_warehouse_id UUID NOT NULL,
    total_cost NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(30) DEFAULT 'SUBMITTED' 
        CHECK (status IN ('DRAFT', 'SUBMITTED', 'ACKNOWLEDGED', 'IN_TRANSIT', 'PARTIALLY_DELIVERED', 'COMPLETED', 'CANCELLED')),
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE NOT NULL,
    actual_delivery_date DATE,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Purchase Order Items Table
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

-- QC Inspection Records
CREATE TABLE qc_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID NOT NULL REFERENCES purchase_orders(id),
    drug_batch_id UUID NOT NULL REFERENCES drug_batches(id),
    inspector_id UUID NOT NULL,
    cold_chain_breached BOOLEAN DEFAULT FALSE,
    packaging_intact BOOLEAN DEFAULT TRUE,
    lab_test_passed BOOLEAN DEFAULT TRUE,
    inspection_decision VARCHAR(20) NOT NULL CHECK (inspection_decision IN ('ACCEPTED', 'REJECTED', 'PARTIAL')),
    rejected_quantity INTEGER DEFAULT 0,
    rejection_reason TEXT,
    inspection_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 🔌 4. API Endpoints

| Method | Endpoint | Description | Role Required |
|---|---|---|---|
| `POST` | `/api/v1/vendors` | Register new pharmaceutical vendor | `GOV_OFFICER` |
| `GET` | `/api/v1/vendors` | List vendors with performance scorecards | `GOV_OFFICER`, `WAREHOUSE_MGR` |
| `POST` | `/api/v1/procurement/orders` | Create formal purchase order | `GOV_OFFICER` |
| `GET` | `/api/v1/procurement/orders` | Query purchase orders by status/vendor | All Roles |
| `PATCH` | `/api/v1/procurement/orders/{id}/status` | Vendor updates order status (`ACKNOWLEDGED`, `IN_TRANSIT`) | `VENDOR` |
| `POST` | `/api/v1/procurement/qc-inspect` | Record gate QC inspection result and release batch | `WAREHOUSE_MGR`, `QA_OFFICER` |

---

## 💡 5. Value to Our System Architecture

By ensuring strict incoming quality gates and recording verified lead times, our procurement module provides accurate real-time values for the **Pending Pipeline Ratio ($P_r$)** and **Average Delivery Lead Time ($L_t$)**, which directly feed into **Our Hospital Risk Engine (Module 07)** to prevent duplicate emergency procurements.

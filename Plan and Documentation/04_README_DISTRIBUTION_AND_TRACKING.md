# 🚚 Module 04: Distribution & Supply Chain Movement Tracking

> **Physical Logistics & Transit Integrity:** Governs multi-echelon transport corridors across warehouses and healthcare facilities, providing live shipment visibility, route monitoring, delay detection, and custody handover verification.

---

## 🎯 1. Module Objective

This module guarantees the **Right Place** and **Right Time** of our core objective. It provides real-time custody tracking across:
1. **Primary Distribution:** Vendor ──► Central Warehouse
2. **Secondary Distribution:** Central Warehouse ──► Regional Warehouse ──► Hospital
3. **Lateral Distribution (Our Innovation):** Hospital ──► Hospital transfers (moving stock from low-need surplus facilities to high-need deficit facilities)

---

## 🗺️ 2. Domain Hierarchy & Physical Movements

```
                    ┌─────────────────────────┐
                    │      Pharma Vendor      │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │    Central Warehouse    │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
         ┌─────────────────────┐   ┌─────────────────────┐
         │ Regional Warehouse  │   │ Regional Warehouse  │
         └──────────┬──────────┘   └──────────┬──────────┘
                    │                         │
                    ▼                         ▼
         ┌─────────────────────┐   ┌─────────────────────┐
         │     Hospital A      │◄──┼─────────────────────┤
         │     (High Need)     │   │     Hospital B      │
         └─────────────────────┘   │   (Surplus Stock)   │
                    ▲              └─────────────────────┘
                    │                         │
                    └─────────────────────────┘
                    Lateral Inter-Facility Transfer
                     (Our Key Innovation Flow)
```

### Shipment Lifecycle States
* `CREATED`: Transfer or dispatch order approved; shipping manifest drafted.
* `PICKING_PACKING`: Warehouse/pharmacy team isolating specific batches.
* `DISPATCHED`: Cargo picked up by logistics carrier; in transit.
* `DELAYED`: Automated alert when current timestamp exceeds expected arrival window.
* `DELIVERED`: Carrier arrives at destination dock.
* `RECEIVED`: Pharmacist scans batch barcodes, verifies quantity, and signs off.
* `EXCEPTION`: Discrepancy noted (missing cartons, transit damage, cold chain breach).

---

## ⏱️ 3. Real-Time Delay Detection & SLA Monitoring

Our logistics engine continuously computes expected transit times based on road distance between facilities:
$$\text{Expected Arrival Time } (T_{exp\_arr}) = T_{dispatch} + \frac{\text{Distance (km)}}{\text{Average Speed (km/h)}} + \text{Buffer Time}$$

If $\text{Current Timestamp} > T_{exp\_arr}$ and status remains `IN_TRANSIT`:
1. The shipment status dynamically flips to `DELAYED`.
2. An automated SMS/Email notification is dispatched to both source and receiving facility administrators.
3. The in-transit pipeline buffer is de-weighted in **Our Hospital Risk Engine (Module 07)** to prevent underestimating facility urgency.

---

## 🗄️ 4. Database Schema Blueprint

```sql
-- Shipments Header Table
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracking_number VARCHAR(100) UNIQUE NOT NULL,
    shipment_type VARCHAR(30) NOT NULL 
        CHECK (shipment_type IN ('VENDOR_TO_WH', 'WH_TO_WH', 'WH_TO_HOSPITAL', 'HOSPITAL_TO_HOSPITAL')),
    source_location_id UUID NOT NULL,
    source_location_type VARCHAR(20) NOT NULL,
    destination_location_id UUID NOT NULL,
    destination_location_type VARCHAR(20) NOT NULL,
    carrier_name VARCHAR(150),
    driver_contact VARCHAR(50),
    vehicle_number VARCHAR(50),
    dispatch_timestamp TIMESTAMP WITH TIME ZONE,
    expected_arrival_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_arrival_timestamp TIMESTAMP WITH TIME ZONE,
    status VARCHAR(30) DEFAULT 'CREATED' 
        CHECK (status IN ('CREATED', 'PICKING_PACKING', 'DISPATCHED', 'DELAYED', 'DELIVERED', 'RECEIVED', 'EXCEPTION')),
    approved_by UUID, -- Links to authorized officer for inter-facility transfers
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shipment Line Items (Batch Level Serialization)
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

CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_dest ON shipments(destination_location_id, status);
```

---

## 🔌 5. API Endpoints

| Method | Endpoint | Description | Role Required |
|---|---|---|---|
| `POST` | `/api/v1/shipments` | Create dispatch manifest for approved transfer | `WAREHOUSE_MGR`, `PHARMACIST` |
| `PATCH` | `/api/v1/shipments/{id}/dispatch` | Mark shipment as picked up & in transit | Logistics Carrier / Sender |
| `GET` | `/api/v1/shipments/active` | Query all in-transit shipments across network | `GOV_OFFICER`, `WAREHOUSE_MGR` |
| `POST` | `/api/v1/shipments/{id}/receive` | Confirm receipt, log verified quantities & update inventory | Receiving `PHARMACIST` |

---

## 💡 6. Supporting Our Innovation Layer

This tracking module directly supports **our core idea of moving stock from low-need hospitals to high-need hospitals**. Instead of treating inter-hospital transfers as informal ad-hoc loans, our system tracks every transferred batch with the exact same rigor, digital audit trail, and cold-chain guarantees as a multi-million-dollar procurement order from a primary pharmaceutical vendor.

# 🏛️ System Architecture Blueprint: Smart Drug Supply Chain & Redistribution System

> **Comprehensive Technical Architecture:** Details our complete end-to-end system design, data flows, sequence diagrams, mathematical decision systems, and security boundaries.

---

## 🎯 1. Core Objective: The "7 Rights" Realization

Our architectural framework directly addresses each of the "7 Rights" of pharmaceutical logistics:

```
                  ┌──────────────────────────────────────────────┐
                  │           THE "7 RIGHTS" OF OUR SYSTEM       │
                  └──────────────────────┬───────────────────────┘
                                         │
       ┌──────────────────┬──────────────┴─────────────┬──────────────────┐
       ▼                  ▼                            ▼                  ▼
1. Right Product   2. Right Quantity             3. Right Place     4. Right Time
Standardized       Consumption-Driven            Geospatial Multi-  Lead-Time Shortage
Drug Master &      Burn Rates & Runway           Echelon Routing    Prediction Engine
Lot Verification   Allocation Models             & Dispatch         & Dispatch Triggers
       │                  │                            │                  │
       └──────────────────┼────────────────────────────┼──────────────────┘
                          │                            │
                          ▼                            ▼
                   5. Right Condition           6. Right Cost
                   Continuous Cold-Chain        Full Ledger & Transit
                   IoT & FEFO Enforcement       Cost Visibility
                          │
                          ▼
                   7. Right People
                   Strict Multi-Tenant RBAC
                   & Tamper-Evident Audit
```

---

## 🏗️ 2. High-Level Component & Service Architecture

```mermaid
flowchart TD
    subgraph Clients["Presentation Layer (Next.js / React)"]
        UI_GOV[State Officer Dashboard]
        UI_PHARM[Hospital Pharmacist Dashboard]
        UI_WH[Warehouse Manager Dashboard]
        UI_VEND[Procurement Vendor Dashboard]
    end

    subgraph Gateway["API Gateway & Security Layer"]
        AUTH[JWT Authentication & Multi-Tenant RBAC Filter]
        RATE[Rate Limiter & Audit Interceptor]
    end

    subgraph CoreServices["Core Transactional Micro-Services"]
        SVC_DRUG[Drug & Batch Master Service]
        SVC_PROC[Procurement & QC Service]
        SVC_INV[Multi-Echelon Inventory Ledger]
        SVC_DIST[Distribution & Logistics Tracker]
        SVC_CONS[Hospital Consumption Telemetry]
        SVC_QUAL[Quality, Quarantine & FEFO Service]
    end

    subgraph InnovationEngines["Our Proprietary Innovation Layer ⭐⭐⭐"]
        ENG_RISK[Module 07: Hospital Risk & Need Scoring Engine]
        ENG_REDIST[Module 08: Lateral Redistribution Decision Engine]
        ENG_EXPIRY[Module 09: Near-Expiry Wastage Elimination Engine]
    end

    subgraph SharedInfra["Data & Messaging Tier"]
        DB[(PostgreSQL 16 + PostGIS Spatial Engine)]
        CACHE[(Redis: Risk Scores & Pub/Sub Alerts)]
        QUEUE[(Celery / BullMQ Background Workers)]
        AUDIT[(Immutable Hash-Chained Audit Store)]
    end

    Clients --> Gateway
    Gateway --> CoreServices
    CoreServices --> DB
    CoreServices --> QUEUE
    
    QUEUE --> InnovationEngines
    InnovationEngines --> CACHE
    InnovationEngines --> DB
    InnovationEngines --> AUDIT
    
    CACHE -.-> Clients
```

---

## 🔁 3. Complete End-to-End Operational Sequences

### Sequence A: Procurement to Warehouse to Clinical Consumption
```mermaid
sequenceDiagram
    autonumber
    actor V as Vendor
    actor W as Warehouse Manager
    actor P as Hospital Pharmacist
    participant API as Our Backend API
    participant DB as PostgreSQL Ledger

    Note over V,W: Inward Procurement & QC
    V->>API: Mark PO Dispatched (Shipment in transit)
    API-->>W: Dockside Inward Notification
    V->>W: Physical delivery arrives at warehouse
    W->>API: Post QC Inspection (Temp loggers, lab assay)
    API->>DB: Status -> RELEASED (Inventory balance incremented)

    Note over W,P: Distribution to Hospital
    W->>API: Create Dispatch Manifest to Hospital
    API->>DB: Status -> IN_TRANSIT
    P->>API: Scan Batch Barcodes at Receiving Dock
    API->>DB: Hospital Stock Incremented (Batch Custody Handed Over)

    Note over P,DB: Clinical Dispensing
    P->>API: Log Patient Dispensing (Ward: ICU)
    API->>DB: Available Stock Decremented, Consumption Event Logged
    API-->>DB: Update 14-Day Rolling Daily Burn Rate
```

---

### Sequence B: Our Intelligent Redistribution Sequence (Inter-Hospital Balancing)
```mermaid
sequenceDiagram
    autonumber
    participant WORKER as Background Scoring Worker
    participant RE as Our Hospital Risk Engine
    participant RDE as Our Redistribution Engine
    actor GOV as State Medical Officer
    actor P_DON as Donor Pharmacist
    actor P_REC as Recipient Pharmacist
    participant DB as System Ledger

    WORKER->>RE: Trigger Network-Wide Scan
    RE->>DB: Query Stock Runways & Burn Rates
    RE-->>RDE: Identify Recipient (Risk Score 87, Runway 3.5 Days)
    RE-->>RDE: Identify Donor (Risk Score 12, Surplus Stock 2,400 Units)
    
    RDE->>RDE: Calculate Safe Transfer Quantity & PostGIS Distance
    RDE->>DB: Insert Transfer Recommendation (PENDING_APPROVAL)
    
    RDE-->>GOV: Push Decision Support Alert to Dashboard
    GOV->>GOV: Review Clinical Need, Distance & Stock Impact
    GOV->>DB: Authorize Transfer Recommendation (Digitally Signed)
    
    DB-->>P_DON: Outbound Transfer Pick-and-Pack Notice
    P_DON->>DB: Dispatch Transfer Shipment
    DB-->>P_REC: Inbound Tracking Manifest Generated
    P_REC->>DB: Confirm Barcode Scan & Inward Receipt
    DB->>DB: Rebalance Both Facility Ledgers & Clear High-Risk Alert
```

---

### Sequence C: Our Near-Expiry Redistribution Sequence (FEFO Wastage Mitigation)
```mermaid
sequenceDiagram
    autonumber
    participant WORKER as Near-Expiry Scheduler
    participant NED as Our Near-Expiry Engine
    actor GOV as District Drug Controller
    actor HA as Hospital A (Low Burn Rate)
    actor HB as Hospital B (High Burn Rate)
    participant DB as System Ledger

    WORKER->>NED: Daily Batch Shelf-Life Scan
    NED->>DB: Query Batches with Expiry <= 60 Days
    NED->>NED: Calculate (Batch Qty - Local Projected Burn)
    Note over NED: Hospital A: 1,000 vials on hand, burns 20/day, expires in 30 days.<br/>Projected consumption = 600 vials. At-Risk Wastage = 400 vials!
    
    NED->>DB: Find Nearby Hospital with Absorption Capacity
    Note over NED: Hospital B: burns 100 vials/day, has 2-day runway.<br/>Can consume all 400 vials in 4 days!
    
    NED->>DB: Generate Near-Expiry Rescue Plan
    NED-->>GOV: High-Priority Wastage Warning on Portal
    GOV->>DB: Sanction FEFO Emergency Transfer
    HA->>DB: Dispatch 400 Vials
    HB->>DB: Receive & Prioritize into FEFO Queue
    Note over HB: Entire batch consumed safely before expiry date. Zero wastage.
```

---

## ⚖️ 4. Baseline Scope vs. Our Innovation Matrix

| Operational Scope | Industry Baseline Coverage | Our System's Proprietary Innovation |
|---|---|---|
| **Procurement** | Static PO creation, simple quantity tally | Dynamic lead-time tracking, automated VPI vendor scorecard, dockside cold-chain QC gate |
| **Inventory** | Basic item count at warehouse | Granular multi-echelon ledger: `Location → Drug → Batch → Quantity → Expiry → Condition` |
| **Consumption** | Periodic monthly inventory counts | Real-time point-of-care dispensing telemetry, rolling 14-day SMA burn rate |
| **Shortage Detection** | Reactive: *"We are out of stock today"* | Proactive: *"Days of Stock Remaining < 5 days; shortage predicted next Tuesday"* |
| **Inter-Facility Transfers** | Informal, manual phone calls between doctors | **⭐ Transparent Hospital Risk Scoring ($0-100$)** + **⭐⭐⭐ Decision-Support Matching Engine** with distance optimization and human approval |
| **Expiry Handling** | Passive write-offs and fiscal destruction | **⭐⭐⭐ Proactive Near-Expiry Wastage Elimination Engine** transferring at-risk units to high-turnover centers |
| **Governance & Access** | Single admin password or flat roles | 4 Dedicated, isolated dashboards + immutable hash-chained audit ledger |

---

## 🔒 5. Security, Tenancy & Compliance

1. **Authentication & Authorization:** JWT with asymmetric RSA-256 signing containing user role, assigned facility UUID, and permission scopes.
2. **Multi-Tenancy Isolation:** Row-Level Security (RLS) in PostgreSQL prevents hospital pharmacists from querying or modifying sibling facility records without explicit state-level transfer context.
3. **Data Integrity & Traceability:** Immutable audit ledger storing previous state, new state, user ID, IP address, and SHA-256 block hash for every state modification.

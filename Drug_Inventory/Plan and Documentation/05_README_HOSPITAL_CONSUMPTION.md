# 📈 Module 05: Hospital Consumption & Demand Intelligence

> **Point-of-Care Demand Telemetry:** Captures granular dispensing data from inpatient wards, outpatient clinics, and emergency rooms, establishing dynamic burn rates and projecting future pharmaceutical requirements.

---

## 🎯 1. Module Objective

Traditional supply chains fail because they treat replenishment as an episodic, manual requisition process. This module bridges clinical dispensing with supply chain forecasting, ensuring that every dispensed unit updates the facility's burn rate in real time.

```
Drug Master ──► Facility Stock ──► Daily Dispensing ──► Historical Demand Curve ──► Future Requirement Projection
```

---

## 📊 2. Consumption Tracking Dimensions

Our system aggregates dispensing transactions across multiple temporal and spatial dimensions:
* **Daily Consumption ($C_{daily}$):** The number of units dispensed per 24-hour cycle.
* **Weekly & Monthly Aggregations:** Rolling 7-day, 14-day, and 30-day moving averages ($\text{SMA}_{7}$, $\text{SMA}_{14}$, $\text{SMA}_{30}$).
* **Consumption by Drug & Formulation:** Isolating high-turnover vs. slow-moving stock.
* **Consumption by Hospital & Ward:** Differentiating consumption between Intensive Care Units (ICU), General Surgery, Outpatient Department (OPD), and Pediatrics.
* **Peak Consumption Detection:** Automated spike identification during seasonal disease outbreaks (e.g., Dengue/Malaria infusions during monsoon seasons).

---

## 🔮 3. Shortage Prediction & Demand Intelligence

Our system intentionally shifts the paradigm:
$$\text{From: "The hospital is already out of stock (Reactive Crisis)"}$$
$$\text{To: "The hospital is likely to run out in 4 days (Proactive Window)"}$$

### The Core Runway Formula
$$\text{Days of Stock Remaining} = \frac{\text{Current Available Stock } (S_{avail})}{\text{Average Daily Consumption } (ADC_{14})}$$

Where $ADC_{14}$ represents the smoothed 14-day rolling daily burn rate:
$$ADC_{14} = \frac{1}{14} \sum_{i=1}^{14} \text{Daily Dispensed Units}_{t-i}$$

### Projected Stockout Date
$$\text{Estimated Stockout Timestamp} = \text{Current Timestamp} + (\text{Days of Stock Remaining} \times 24 \text{ hours})$$

### Required Replenishment Quantity ($Q_{required}$)
$$\text{Safety Buffer Stock} = ADC_{14} \times \text{Safety Days (e.g. 7 days)}$$
$$Q_{required} = \max\left(0, \; (\text{Target Stock Level} - S_{avail}) + \text{Safety Buffer Stock} - S_{pipeline}\right)$$

Where $S_{pipeline}$ is verified stock currently in transit.

---

## 🗄️ 4. Database Schema Blueprint

```sql
-- Individual Dispensing Logs (Point of Care)
CREATE TABLE drug_consumption_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id UUID NOT NULL,
    department_id VARCHAR(50), -- e.g. ICU, Emergency, OPD
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    batch_id UUID NOT NULL REFERENCES drug_batches(id),
    quantity_dispensed INTEGER NOT NULL CHECK (quantity_dispensed > 0),
    patient_identifier_hash VARCHAR(64), -- Anonymized for HIPAA/privacy
    dispensed_by UUID NOT NULL,
    dispensed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pre-Aggregated Daily Demand Matrix (For Sub-Millisecond Intelligence Queries)
CREATE TABLE daily_consumption_summary (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id UUID NOT NULL,
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    summary_date DATE NOT NULL,
    total_dispensed INTEGER NOT NULL DEFAULT 0,
    rolling_7d_avg NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    rolling_14d_avg NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    days_of_stock_remaining NUMERIC(6,2),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_hosp_drug_date UNIQUE (hospital_id, drug_id, summary_date)
);

CREATE INDEX idx_dispense_hosp_drug ON drug_consumption_logs(hospital_id, drug_id, dispensed_at);
CREATE INDEX idx_summary_runway ON daily_consumption_summary(days_of_stock_remaining);
```

---

## 🔌 5. API Endpoints

| Method | Endpoint | Description | Role Required |
|---|---|---|---|
| `POST` | `/api/v1/consumption/dispense` | Log patient dispensing transaction & adjust inventory | `PHARMACIST` |
| `GET` | `/api/v1/consumption/facilities/{id}/metrics` | Retrieve daily, weekly, and monthly consumption trends | Facility Staff / Officer |
| `GET` | `/api/v1/consumption/forecast/{hospital_id}/{drug_id}` | Calculate days of stock and predicted stockout date | All Authenticated |
| `GET` | `/api/v1/consumption/anomalies` | Identify sudden consumption spikes (> 200% of SMA) | `GOV_OFFICER` |

---

## 💡 6. Fueling Our Innovation Layer

The calculated **Average Daily Consumption (ADC)** and **Days of Stock Remaining** serve as the two primary continuous variables feeding into:
1. **Our Hospital Risk / Need Scoring Engine (Module 07)** to determine immediate facility vulnerability.
2. **Our Near-Expiry Redistribution Engine (Module 09)** to compute whether a facility will consume an expiring batch in time or generate preventable wastage.

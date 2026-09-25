# ⭐ Module 07: Hospital Risk & Need Scoring Engine (Our Core Innovation)

> **Predictive Vulnerability Intelligence:** A transparent, explainable, and rule-based scoring engine that quantifies drug stockout risk across healthcare facilities on a scale of $0 - 100$.

---

## 🎯 1. Module Objective

Rather than waiting for a peripheral or rural hospital to run out of an essential medication, **our proposed innovation** continuously computes a composite **Hospital Need & Risk Score**. This provides health administrators with a proactive vulnerability map, prioritizing facilities that require immediate replenishment or inter-hospital stock balancing.

---

## 🧮 2. The Risk Scoring Model (Transparent & Defensible)

In public health operations, "black-box" machine learning models often suffer from lack of trust and unexplainable outputs. Therefore, **our system implements a mathematically rigorous, transparent, rule-based scoring algorithm** that is fully explainable to medical officers.

### Scoring Factors & Normalized Inputs
For hospital $h$ and drug $d$, the score considers 5 core operational dimensions:

1. **Stock Runway Ratio ($S_R \in [0, 40]$ pts):**
   Evaluates days of stock remaining against delivery lead time ($L = 5\text{ days}$ standard lead time buffer):
   $$\text{Days of Stock} = \frac{S_{avail}}{\max(1, ADC_{14})}$$
   $$S_R = \min\left(40, \; \max\left(0, \; 40 \times \left(1 - \frac{\text{Days of Stock}}{14}\right)\right)\right)$$
   *(If days of stock $\le 0$, $S_R = 40$. If days of stock $\ge 14$, $S_R = 0$)*.

2. **Drug Criticality Multiplier ($C_W \in [0, 30]$ pts):**
   Reflects the vital clinical impact of the pharmaceutical substance:
   * **VITAL (Life-Saving):** $30\text{ points}$
   * **ESSENTIAL (Curative / Critical Care):** $20\text{ points}$
   * **DESIRABLE (Supportive Therapy):** $10\text{ points}$

3. **Historical Shortage Frequency ($H_F \in [0, 15]$ pts):**
   Penalizes facilities with recurrent stockout events over the preceding 90 days:
   $$H_F = \min\left(15, \; \text{Stockout Incidents in 90 Days} \times 5\right)$$

4. **Inpatient Patient Load & Surge Factor ($P_L \in [0, 15]$ pts):**
   Captures immediate bed occupancy or active patient count surges relative to baseline capacity:
   $$P_L = \min\left(15, \; \max\left(0, \; \left(\frac{\text{Current Bed Occupancy}}{\text{Normal Bed Capacity}} - 1.0\right) \times 15\right)\right)$$

5. **Inbound Pipeline Mitigation Credit ($M_P \in [0, -20]$ pts):**
   Reduces panic scoring if verified replenishments are already in transit:
   $$M_P = -\min\left(20, \; \left(\frac{S_{pipeline}}{\max(1, ADC_{14})} \times 5\right)\right)$$

### Composite Hospital Risk Score ($R_{h,d}$)
$$R_{h,d} = \text{Clamp}_{0}^{100}\left(S_R + C_W + H_F + P_L + M_P\right)$$

---

## 🚦 3. Risk Classification Tiers

| Score Range | Risk Level | Action Protocol |
|---|---|---|
| **$80 - 100$** | 🚨 **CRITICAL / HIGH** | Immediate redistribution candidate. System flags state dashboard and generates inter-facility transfer transfer recommendation. |
| **$60 - 79$** | ⚠️ **ELEVATED / MEDIUM** | Expedited warehouse dispatch queued. Facility notified to restrict non-emergency elective usage. |
| **$30 - 59$** | 🟢 **NORMAL / SAFE** | Routine replenishment cycle. Inventory within healthy operating boundaries. |
| **$0 - 29$** | 📦 **SURPLUS / EXCESS** | Potential donor facility. Identified as candidate source for lateral transfers to high-risk facilities. |

---

## 📊 4. Conceptual Example Output

```text
============================================================
FACILITY RISK AUDIT CARD
============================================================
Hospital:             District Civil Hospital Alpha
Drug:                 Atropine Sulphate Injection (1 mg/mL)
Criticality:          VITAL (Life-Saving)
────────────────────────────────────────────────────────────
Current Available:    800 ampoules
Daily Consumption:    200 ampoules/day
Days of Stock:        4.0 Days
Target Stock:         2,500 ampoules
Pipeline Inbound:     0 ampoules
Historical Stockouts: 2 incidents (Past 90 days)
────────────────────────────────────────────────────────────
Component Breakdown:
  - Stock Runway Factor:       28.5 / 40.0
  - Clinical Criticality:      30.0 / 30.0
  - Historical Shortage Factor: 10.0 / 15.0
  - Patient Load Surge:         8.5 / 15.0
  - Inbound Pipeline Credit:    0.0 / -20.0
────────────────────────────────────────────────────────────
COMPOSITE RISK SCORE: 77 / 100
RISK LEVEL:           HIGH (Immediate Action Required)
RECOMMENDED ACTION:   Trigger Lateral Transfer from Hospital Beta (Surplus: 1,800 units)
============================================================
```

---

## 🗄️ 5. Database Schema Blueprint

```sql
-- Hospital Risk State Table
CREATE TABLE hospital_drug_risk_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id UUID NOT NULL,
    drug_id UUID NOT NULL REFERENCES drug_master(id),
    current_stock INTEGER NOT NULL,
    daily_consumption NUMERIC(8,2) NOT NULL,
    days_of_stock_remaining NUMERIC(6,2) NOT NULL,
    required_stock_level INTEGER NOT NULL,
    pipeline_stock INTEGER DEFAULT 0,
    risk_score INTEGER NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'SURPLUS')),
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_hosp_drug_risk UNIQUE (hospital_id, drug_id)
);

CREATE INDEX idx_risk_score_level ON hospital_drug_risk_scores(risk_level, risk_score DESC);
```

---

## 🔌 6. API Endpoints

| Method | Endpoint | Description | Role Required |
|---|---|---|---|
| `GET` | `/api/v1/intelligence/risk-scores` | Query facility risk matrix across state | `GOV_OFFICER` |
| `GET` | `/api/v1/intelligence/risk-scores/hospitals/{id}` | Detailed risk profile for specific facility | Hospital Staff / Officer |
| `POST` | `/api/v1/intelligence/risk-scores/recalculate` | Force instantaneous re-computation after major demand surge | `GOV_OFFICER` |

---

## 💡 7. Value to Our Innovation Layer

This module is the **brain** of our solution. By continuously calculating risk across every facility, it serves as the automated trigger that instructs **Our Intelligent Redistribution Engine (Module 08)** to formulate peer-to-peer transfer recommendations.

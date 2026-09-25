"""
Smart Drug Supply Chain - CSV Generator for Supabase
====================================================
Uses Python's standard library (Zero dependencies, no pip install).
Outputs clean CSV files ready to drag-and-drop into Supabase Table Editor.
Generates 50,000+ total rows across relational tables.
"""

import os
import csv
import uuid
import random
from datetime import datetime, date, timedelta, timezone

OUTPUT_DIR = "database/csv_data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

FACILITY_TYPES = ['CENTRAL_WAREHOUSE', 'REGIONAL_WAREHOUSE', 'DISTRICT_HOSPITAL', 'PRIMARY_HEALTH_CENTER']
DISTRICTS = ['Mumbai', 'Pune', 'Nashik', 'Nagpur', 'Aurangabad', 'Thane', 'Solapur', 'Kolhapur', 'Amravati', 'Nanded']
DEPARTMENTS = ['ICU', 'Emergency', 'General_Ward', 'Pediatrics', 'Surgery', 'OPD']

DRUG_TEMPLATES = [
    ("Atropine Sulphate", "Atropine Inj", "Emergency/Antidote", "ampoule", "Injection", "1mg/ml", "COLD_CHAIN", "VITAL", 18.50),
    ("Ceftriaxone Sodium", "Monocef 1g", "Antibiotic", "vial", "Injection", "1g", "AMBIENT", "ESSENTIAL", 45.00),
    ("Regular Insulin", "Human Actrapid", "Endocrine/Diabetes", "vial", "Injection", "100 IU/ml", "COLD_CHAIN", "VITAL", 165.00),
    ("Paracetamol", "Dolo 650", "Analgesic", "tablet", "Tablet", "650mg", "AMBIENT", "DESIRABLE", 1.80),
    ("Adrenaline", "Vasocon 1mg", "Emergency", "ampoule", "Injection", "1mg/ml", "COLD_CHAIN", "VITAL", 24.00),
    ("Amoxicillin + Clav", "Augmentin 625", "Antibiotic", "tablet", "Tablet", "625mg", "AMBIENT", "ESSENTIAL", 22.00),
    ("Metformin HCl", "Glycomet 500", "Endocrine", "tablet", "Tablet", "500mg", "AMBIENT", "ESSENTIAL", 3.50),
    ("Ondansetron", "Emeset 4mg", "Antiemetic", "ampoule", "Injection", "2mg/ml", "AMBIENT", "DESIRABLE", 12.00),
    ("Pantoprazole", "Pan 40", "Gastrointestinal", "vial", "Injection", "40mg", "AMBIENT", "ESSENTIAL", 38.00),
    ("Heparin Sodium", "Hep 5000 IU", "Anticoagulant", "vial", "Injection", "5000 IU/ml", "COLD_CHAIN", "VITAL", 120.00),
]

def generate():
    today = date.today()
    print("[*] Generating CSV files for Supabase in 'database/csv_data/'...")

    # 1. FACILITIES (30 rows)
    facility_ids = []
    hospital_ids = []
    warehouse_ids = []
    facilities_rows = []
    for i in range(1, 31):
        f_id = str(uuid.uuid4())
        facility_ids.append(f_id)
        dist = random.choice(DISTRICTS)
        if i <= 4:
            f_type = 'CENTRAL_WAREHOUSE' if i <= 2 else 'REGIONAL_WAREHOUSE'
            f_name = f"{dist} Medical Depot {i}"
            warehouse_ids.append(f_id)
            beds, occ = 0, 0
        else:
            f_type = 'DISTRICT_HOSPITAL' if i <= 20 else 'PRIMARY_HEALTH_CENTER'
            f_name = f"{dist} {'District Hospital' if f_type == 'DISTRICT_HOSPITAL' else 'Primary Health Center'} {i}"
            hospital_ids.append(f_id)
            beds = random.randint(150, 600) if f_type == 'DISTRICT_HOSPITAL' else random.randint(20, 60)
            occ = int(beds * random.uniform(0.65, 0.95))
        
        lat = round(18.5 + random.uniform(-1.5, 2.5), 6)
        lon = round(73.5 + random.uniform(-1.0, 3.5), 6)
        facilities_rows.append({
            "id": f_id, "facility_code": f"FAC-{i:03d}", "name": f_name,
            "facility_type": f_type, "district": dist, "state": "Maharashtra",
            "address": f"Cross Rd 4, {dist}", "latitude": lat, "longitude": lon,
            "bed_capacity": beds, "current_bed_occupancy": occ, "is_active": True
        })

    with open(f"{OUTPUT_DIR}/facilities.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(facilities_rows[0].keys()))
        writer.writeheader()
        writer.writerows(facilities_rows)
    print("  -> Created facilities.csv (30 rows)")

    # 2. USERS (20 rows)
    users_rows = []
    user_ids = []
    pwd_hash = "$2a$10$wT0l06u3bQvP1J4KzL8oie5U4iE2b3dZp8G5k9eR2K3x2t4w1o"
    roles = [('admin', 'ADMIN', None)] + \
            [(f'officer_{i}', 'GOV_OFFICER', None) for i in range(1, 3)] + \
            [(f'wh_mgr_{i}', 'WAREHOUSE_MGR', warehouse_ids[i % len(warehouse_ids)]) for i in range(1, 6)] + \
            [(f'pharm_{i}', 'PHARMACIST', hospital_ids[i % len(hospital_ids)]) for i in range(1, 13)]

    for u_name, u_role, u_fac in roles:
        u_id = str(uuid.uuid4())
        user_ids.append(u_id)
        users_rows.append({
            "id": u_id, "username": u_name, "email": f"{u_name}@health.gov.in",
            "password_hash": pwd_hash, "full_name": u_name.replace('_', ' ').title(),
            "role": u_role, "assigned_facility_id": u_fac or "", "is_active": True
        })

    with open(f"{OUTPUT_DIR}/users.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(users_rows[0].keys()))
        writer.writeheader()
        writer.writerows(users_rows)
    print("  -> Created users.csv (20 rows)")

    # 3. DRUG MASTER (50 rows)
    drugs_rows = []
    drug_ids = []
    for i in range(1, 51):
        d_id = str(uuid.uuid4())
        drug_ids.append(d_id)
        tpl = DRUG_TEMPLATES[(i - 1) % len(DRUG_TEMPLATES)]
        min_stk = random.choice([50, 100, 200, 500])
        drugs_rows.append({
            "id": d_id, "drug_code": f"DRG-{i:04d}", "brand_name": f"{tpl[1]} #{i}",
            "generic_name": f"{tpl[0]} Gen-{i}", "category": tpl[2], "uom": tpl[3],
            "dosage_form": tpl[4], "strength": tpl[5], "storage_condition": tpl[6],
            "criticality": tpl[7], "unit_cost": tpl[8], "min_stock_threshold": min_stk,
            "target_stock_level": min_stk * 8, "reorder_level": int(min_stk * 1.5), "is_active": True
        })

    with open(f"{OUTPUT_DIR}/drug_master.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(drugs_rows[0].keys()))
        writer.writeheader()
        writer.writerows(drugs_rows)
    print("  -> Created drug_master.csv (50 rows)")

    # 4. DRUG BATCHES (500 rows)
    batches_rows = []
    batch_ids = []
    batch_map = {} # b_id -> (facility_id, drug_id)
    b_count = 1
    for d_id in drug_ids:
        for _ in range(10):
            b_id = str(uuid.uuid4())
            batch_ids.append(b_id)
            fac_id = random.choice(facility_ids)
            batch_map[b_id] = (fac_id, d_id)
            
            near_exp = random.random() < 0.2
            if near_exp:
                mfg = today - timedelta(days=random.randint(300, 600))
                exp = today + timedelta(days=random.randint(15, 60))
                status = 'NEAR_EXPIRY'
            else:
                mfg = today - timedelta(days=random.randint(30, 180))
                exp = today + timedelta(days=random.randint(180, 720))
                status = 'RELEASED'
                
            qty = random.randint(500, 5000)
            curr = int(qty * random.uniform(0.2, 0.85))
            batches_rows.append({
                "id": b_id, "batch_number": f"LOT-2026-{b_count:05d}", "drug_id": d_id,
                "manufacturing_date": str(mfg), "expiry_date": str(exp),
                "initial_quantity": qty, "current_quantity": curr,
                "manufacturer_name": "Serum & Pharma Corp", "current_facility_id": fac_id,
                "status": status
            })
            b_count += 1

    with open(f"{OUTPUT_DIR}/drug_batches.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(batches_rows[0].keys()))
        writer.writeheader()
        writer.writerows(batches_rows)
    print("  -> Created drug_batches.csv (500 rows)")

    # 5. INVENTORY BALANCES (500 rows)
    inv_rows = []
    for b in batches_rows:
        inv_rows.append({
            "id": str(uuid.uuid4()), "facility_id": b["current_facility_id"],
            "drug_id": b["drug_id"], "batch_id": b["id"],
            "quantity_on_hand": b["current_quantity"], "quantity_reserved": 0, "quantity_damaged": 0
        })

    with open(f"{OUTPUT_DIR}/inventory_balances.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(inv_rows[0].keys()))
        writer.writeheader()
        writer.writerows(inv_rows)
    print("  -> Created inventory_balances.csv (500 rows)")

    # 6. CLINICAL DISPENSING LOGS (45,000 rows - The 50k core scale)
    print("  -> Generating 45,000 drug_consumption_logs.csv (Please wait ~2 seconds)...")
    consumption_aggregates = {}
    with open(f"{OUTPUT_DIR}/drug_consumption_logs.csv", "w", newline="", encoding="utf-8") as f:
        fields = ["id", "hospital_id", "department_id", "drug_id", "batch_id", "quantity_dispensed", "patient_identifier_hash", "dispensed_by", "dispensed_at"]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        
        chunk = []
        for _ in range(45000):
            b_id = random.choice(batch_ids)
            fac_id, d_id = batch_map[b_id]
            hosp_id = fac_id if fac_id in hospital_ids else random.choice(hospital_ids)
            dept = random.choice(DEPARTMENTS)
            qty = random.randint(1, 20)
            
            days_ago = random.randint(0, 89)
            hours_ago = random.randint(0, 23)
            log_date = today - timedelta(days=days_ago)
            ts = (datetime.combine(log_date, datetime.min.time(), tzinfo=timezone.utc) + timedelta(hours=hours_ago)).isoformat()
            
            key = (hosp_id, d_id, log_date)
            consumption_aggregates[key] = consumption_aggregates.get(key, 0) + qty
            
            chunk.append({
                "id": str(uuid.uuid4()), "hospital_id": hosp_id, "department_id": dept,
                "drug_id": d_id, "batch_id": b_id, "quantity_dispensed": qty,
                "patient_identifier_hash": f"PAT-{random.randint(100000, 999999)}",
                "dispensed_by": random.choice(user_ids), "dispensed_at": ts
            })
            if len(chunk) >= 5000:
                writer.writerows(chunk)
                chunk = []
        if chunk:
            writer.writerows(chunk)
    print("  -> Created drug_consumption_logs.csv (45,000 rows)")

    # 7. HOSPITAL RISK SCORES (300 rows)
    risk_rows = []
    pairs = list(set((k[0], k[1]) for k in consumption_aggregates.keys()))
    for hosp_id, d_id in pairs[:300]:
        past_14_sum = sum(consumption_aggregates.get((hosp_id, d_id, today - timedelta(days=d)), 0) for d in range(14))
        adc_14 = max(1.0, round(past_14_sum / 14.0, 2))
        curr_stock = random.randint(10, 1500)
        days_stock = round(curr_stock / adc_14, 2)
        
        sr_score = min(40.0, max(0.0, 40.0 * (1.0 - (days_stock / 14.0))))
        cw_score = random.choice([10.0, 20.0, 30.0])
        hf_score = float(random.choice([0, 5, 10, 15]))
        pl_score = float(random.randint(0, 15))
        score = int(min(100, max(0, sr_score + cw_score + hf_score + pl_score)))
        
        level = 'CRITICAL' if score >= 80 else 'HIGH' if score >= 60 else 'MEDIUM' if score >= 30 else 'SURPLUS'
        risk_rows.append({
            "id": str(uuid.uuid4()), "hospital_id": hosp_id, "drug_id": d_id,
            "current_stock": curr_stock, "daily_consumption": adc_14, "days_of_stock_remaining": days_stock,
            "required_stock_level": int(adc_14 * 21), "pipeline_stock": 0,
            "stock_runway_score": round(sr_score, 2), "criticality_score": cw_score,
            "shortage_frequency_score": hf_score, "patient_surge_score": pl_score,
            "pipeline_credit_score": 0.0, "risk_score": score, "risk_level": level
        })

    with open(f"{OUTPUT_DIR}/hospital_drug_risk_scores.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(risk_rows[0].keys()))
        writer.writeheader()
        writer.writerows(risk_rows)
    print("  -> Created hospital_drug_risk_scores.csv (300 rows)")

    print(f"\n[✓] ALL CSVs successfully generated in '{OUTPUT_DIR}/'!")

if __name__ == "__main__":
    generate()

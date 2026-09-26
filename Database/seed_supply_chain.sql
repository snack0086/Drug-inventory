 DO $$
    DECLARE
        v_central_wh UUID; v_reg_wh UUID; v_hosp_1 UUID; v_hosp_2 UUID;
        v_officer UUID; v_wh_mgr UUID;
        v_drug_1 UUID; v_drug_2 UUID; v_drug_3 UUID;
        v_batch_1 UUID; v_batch_2 UUID;
        v_vendor_1 UUID; v_vendor_2 UUID;
        v_po_1 UUID; v_po_2 UUID;
        v_shipment_1 UUID; v_shipment_2 UUID;
    BEGIN
        SELECT id INTO v_central_wh FROM facilities WHERE facility_type = 'CENTRAL_WAREHOUSE' LIMIT 1;
        SELECT id INTO v_reg_wh FROM facilities WHERE facility_type = 'REGIONAL_WAREHOUSE' LIMIT 1;
        SELECT id INTO v_hosp_1 FROM facilities WHERE facility_type = 'DISTRICT_HOSPITAL' LIMIT 1;
        SELECT id INTO v_hosp_2 FROM facilities WHERE facility_type = 'DISTRICT_HOSPITAL' OFFSET 1 LIMIT 1;

        SELECT id INTO v_officer FROM users WHERE role = 'GOV_OFFICER' LIMIT 1;
        SELECT id INTO v_wh_mgr FROM users WHERE role = 'WAREHOUSE_MGR' LIMIT 1;

        SELECT id INTO v_drug_1 FROM drug_master LIMIT 1;
        SELECT id INTO v_drug_2 FROM drug_master OFFSET 1 LIMIT 1;
        SELECT id INTO v_drug_3 FROM drug_master OFFSET 2 LIMIT 1;

        SELECT id INTO v_batch_1 FROM drug_batches WHERE drug_id = v_drug_1 LIMIT 1;
        SELECT id INTO v_batch_2 FROM drug_batches WHERE drug_id = v_drug_2 LIMIT 1;

        -- 1. Vendors (Safe Upsert)
        INSERT INTO vendors (id, vendor_code, company_name, license_number, email, phone, address, performance_score)
        VALUES
        (gen_random_uuid(), 'VEND-CIPLA', 'Cipla Pharmaceuticals Ltd', 'MH-FDA-2024-8891', 'orders@cipla.com', '+91 22 2482 6000', 'Peninsula Business
  Park, Mumbai', 98.50)
        ON CONFLICT (vendor_code) DO UPDATE SET company_name = EXCLUDED.company_name
        RETURNING id INTO v_vendor_1;

        IF v_vendor_1 IS NULL THEN
            SELECT id INTO v_vendor_1 FROM vendors WHERE vendor_code = 'VEND-CIPLA';
        END IF;

        INSERT INTO vendors (id, vendor_code, company_name, license_number, email, phone, address, performance_score)
        VALUES
        (gen_random_uuid(), 'VEND-SUNPH', 'Sun Pharma Industries', 'MH-FDA-2023-1102', 'supply@sunpharma.com', '+91 22 4324 4324', 'Goregaon East,
  Mumbai', 94.20)
        ON CONFLICT (vendor_code) DO UPDATE SET company_name = EXCLUDED.company_name
        RETURNING id INTO v_vendor_2;

        IF v_vendor_2 IS NULL THEN
            SELECT id INTO v_vendor_2 FROM vendors WHERE vendor_code = 'VEND-SUNPH';
        END IF;

        -- 2. Purchase Orders (Safe Insert)
        INSERT INTO purchase_orders (id, po_number, vendor_id, destination_facility_id, total_cost, status, order_date, expected_delivery_date,
  created_by)
        VALUES
        (gen_random_uuid(), 'PO-2026-001', v_vendor_1, v_central_wh, 125000.00, 'IN_TRANSIT', CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE + INTERVAL
  '2 days', v_officer)
        ON CONFLICT (po_number) DO NOTHING
        RETURNING id INTO v_po_1;

        IF v_po_1 IS NOT NULL THEN
            INSERT INTO purchase_order_items (po_id, drug_id, ordered_quantity, unit_cost, received_quantity)
            VALUES
            (v_po_1, v_drug_1, 5000, 18.50, 0),
            (v_po_1, v_drug_2, 2000, 45.00, 0);
        END IF;

        INSERT INTO purchase_orders (id, po_number, vendor_id, destination_facility_id, total_cost, status, order_date, expected_delivery_date,
  actual_delivery_date, created_by)
        VALUES
        (gen_random_uuid(), 'PO-2026-002', v_vendor_2, v_central_wh, 330000.00, 'COMPLETED', CURRENT_DATE - INTERVAL '15 days', CURRENT_DATE - INTERVAL
  '8 days', CURRENT_DATE - INTERVAL '7 days', v_officer)
        ON CONFLICT (po_number) DO NOTHING
        RETURNING id INTO v_po_2;

        IF v_po_2 IS NOT NULL THEN
            INSERT INTO purchase_order_items (po_id, drug_id, ordered_quantity, unit_cost, received_quantity, accepted_quantity, rejected_quantity)
            VALUES
            (v_po_2, v_drug_3, 2000, 165.00, 2000, 1950, 50);

            IF v_batch_1 IS NOT NULL AND v_wh_mgr IS NOT NULL THEN
                INSERT INTO qc_inspections (po_id, drug_batch_id, inspector_id, cold_chain_breached, packaging_intact, lab_test_passed,
  inspection_decision, rejected_quantity, rejection_reason)
                VALUES
                (v_po_2, v_batch_1, v_wh_mgr, FALSE, TRUE, TRUE, 'ACCEPTED', 0, 'Inspected at dock. Thermal data loggers intact.');
            END IF;
        END IF;

        -- 3. Shipments (Safe Insert)
        INSERT INTO shipments (id, tracking_number, shipment_type, source_facility_id, destination_facility_id, carrier_name, driver_name, driver_contact,
  vehicle_number, dispatch_timestamp, expected_arrival_timestamp, status, approved_by)
        VALUES
        (gen_random_uuid(), 'TRK-2026-WH-HOSP', 'WH_TO_HOSPITAL', v_central_wh, v_hosp_1, 'ColdChain Logistics Ltd', 'Suresh Kumar', '+91 98111 22334',
  'MH-12-Q-4491', NOW() - INTERVAL '4 hours', NOW() + INTERVAL '3 hours', 'DISPATCHED', v_officer)
        ON CONFLICT (tracking_number) DO NOTHING
        RETURNING id INTO v_shipment_1;

        IF v_shipment_1 IS NOT NULL AND v_batch_1 IS NOT NULL THEN
            INSERT INTO shipment_items (shipment_id, drug_id, batch_id, quantity_dispatched)
            VALUES (v_shipment_1, v_drug_1, v_batch_1, 500);
        END IF;

        INSERT INTO shipments (id, tracking_number, shipment_type, source_facility_id, destination_facility_id, carrier_name, driver_name, driver_contact,
  vehicle_number, dispatch_timestamp, expected_arrival_timestamp, status, approved_by)
        VALUES
        (gen_random_uuid(), 'TRK-2026-LAT-001', 'HOSPITAL_TO_HOSPITAL', v_hosp_2, v_hosp_1, 'State Medical Express', 'Ramesh Yadav', '+91 98222 33445',
  'MH-14-BT-1092', NOW() - INTERVAL '10 hours', NOW() - INTERVAL '2 hours', 'DELAYED', v_officer)
        ON CONFLICT (tracking_number) DO NOTHING
        RETURNING id INTO v_shipment_2;

        IF v_shipment_2 IS NOT NULL AND v_batch_2 IS NOT NULL THEN
            INSERT INTO shipment_items (shipment_id, drug_id, batch_id, quantity_dispatched)
            VALUES (v_shipment_2, v_drug_2, v_batch_2, 300);
        END IF;
    END $$;
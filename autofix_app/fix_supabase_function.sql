-- CORRECTED VERSION: Use proper vehicle_id relationship instead of Guid
CREATE OR REPLACE FUNCTION public.fetch_jobcard(
    start_date text,
    end_date text,
    guid text
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_date date;
    v_end_date date;
    result jsonb;
BEGIN
    -- Convert input strings to actual dates
    v_start_date := start_date::date;
    v_end_date   := end_date::date;
 
    -- Use the correct relationship: reports.vehicle_id = vehicles.id
    SELECT jsonb_agg(
        jsonb_build_object(
            'Guid', r.id,
            'date', to_char(r.created_at, 'DD-MM-YYYY'),
            'model', v.vehicle_name,
            'odometer', v.odometer,
            'owner_name', v."Owner name",
            'phonenumber', NULL,
            'company_name', r.company_name,  -- Use the actual company_name from reports
            'deliverydate', NULL,
            'mobilenumber', v."MobileNumber",
            'chasis_number', v."Chasis Number",
            'engine_number', v."Engine Number",
            'contact_number', r.client_phone,
            'executive_name', COALESCE(e.username, 'Not Assigned'),
            'vehicle_number', v."Vehicle Number",
            'odometer_reading', r.odometer_reading,
            'last_service_date', NULL,
            'booking_person_name', r."Owner name"
        )
    )
    INTO result
    FROM reports r
    LEFT JOIN vehicles v ON v.id = r.vehicle_id  -- Correct relationship
    LEFT JOIN auth.users e ON e.id = r.executive_id  -- Get executive name
    WHERE r.created_at::date BETWEEN v_start_date AND v_end_date
      AND r.id = guid::integer;  -- Convert guid to integer if it's an ID
 
    RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

-- ALTERNATIVE: If you want to filter by company as well
CREATE OR REPLACE FUNCTION public.fetch_jobcard_by_company(
    start_date text,
    end_date text,
    guid text,
    company_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_date date;
    v_end_date date;
    result jsonb;
BEGIN
    -- Convert input strings to actual dates
    v_start_date := start_date::date;
    v_end_date   := end_date::date;
 
    -- Use the correct relationship with company filtering
    SELECT jsonb_agg(
        jsonb_build_object(
            'Guid', r.id,
            'date', to_char(r.created_at, 'DD-MM-YYYY'),
            'model', v.vehicle_name,
            'odometer', v.odometer,
            'owner_name', v."Owner name",
            'phonenumber', NULL,
            'company_name', r.company_name,
            'deliverydate', NULL,
            'mobilenumber', v."MobileNumber",
            'chasis_number', v."Chasis Number",
            'engine_number', v."Engine Number",
            'contact_number', r.client_phone,
            'executive_name', COALESCE(e.username, 'Not Assigned'),
            'vehicle_number', v."Vehicle Number",
            'odometer_reading', r.odometer_reading,
            'last_service_date', NULL,
            'booking_person_name', r."Owner name"
        )
    )
    INTO result
    FROM reports r
    LEFT JOIN vehicles v ON v.id = r.vehicle_id
    LEFT JOIN auth.users e ON e.id = r.executive_id
    WHERE r.created_at::date BETWEEN v_start_date AND v_end_date
      AND r.id = guid::integer
      AND (company_name IS NULL OR r.company_name = company_name);  -- Optional company filter
 
    RETURN COALESCE(result, '[]'::jsonb);
END;
$function$;

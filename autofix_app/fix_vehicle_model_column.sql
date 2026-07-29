-- Fix vehicle_models table column name issue
-- The error occurs because there was inconsistency between column names:
-- - Supabase database has: "Model name" (with space and capital M) 
-- - Some code was referencing: 'model' (lowercase, no space)
-- - Local SQLite cache uses: 'model'

-- SOLUTION: Keep database column as "Model name" and update all code to use this consistently

-- FIXED FILES:
-- 1. lib/services/database_helper.dart - Line 91: Use model['Model name'] for local cache
-- 2. lib/screens/admin/vehicle_management_screen.dart - Line 77: Use 'Model name' for Supabase insert
-- 3. All other files were already correctly using "Model name"

-- No database changes needed - all code now consistently uses "Model name"

-- Verify current database structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'vehicle_models' 
AND table_schema = 'public';

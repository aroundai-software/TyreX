# AutoFix App - Predefined Materials System Implementation Guide

## Overview

This guide explains how to implement the predefined materials system in the AutoFix app. The system allows executives to search and select materials from a predefined list instead of manually typing them, reducing errors and standardizing material entries.

---

## Features

✅ **Searchable Material Dropdown** - Real-time search with case-insensitive matching  
✅ **Category Organization** - Materials grouped by category (Engine & Oil, Brake System, etc.)  
✅ **Fast Selection** - One-click material selection from dropdown  
✅ **Material Details** - Each material shows category, unit, and description  
✅ **Standardized Entries** - Eliminates typing errors and inconsistencies  
✅ **Easy Management** - Add/remove materials from database as needed  

---

## Implementation Steps

### Step 1: Create Materials Table in Supabase

1. **Open Supabase Dashboard**
   - Navigate to your AutoFix project
   - Go to SQL Editor

2. **Run the SQL Script**
   - Open the file: `database/materials_setup.sql`
   - Copy all SQL code
   - Paste into Supabase SQL Editor
   - Click "Run" to execute

3. **Verify Table Creation**
   - Go to "Table Editor" in Supabase
   - You should see a new `materials` table
   - Verify it contains ~100+ sample materials across 12 categories

**Sample Categories:**
- Engine & Oil
- Cooling System
- Brake System
- Suspension & Steering
- Electrical & Battery
- Transmission & Drivetrain
- Tire & Wheel
- Fuel System
- Exhaust System
- Body & Paint
- Interior & Upholstery
- Cooling & AC
- Miscellaneous

### Step 2: Verify Database Schema

The `materials` table should have these columns:

```sql
- id (BIGSERIAL PRIMARY KEY)
- name (VARCHAR 255, UNIQUE)
- category (VARCHAR 100)
- unit (VARCHAR 50)
- description (TEXT)
- is_active (BOOLEAN, default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Indexes created:**
- `idx_materials_name` - For fast name searches
- `idx_materials_category` - For category filtering
- `idx_materials_active` - For active status filtering

### Step 3: Backend Integration (Already Done)

The following methods have been added to `SupabaseService`:

#### `getAllMaterials()`
```dart
Future<List<Map<String, dynamic>>> getAllMaterials()
```
- Fetches all active materials
- Returns materials sorted by category and name
- Used for initial dropdown population

#### `searchMaterials(String query)`
```dart
Future<List<Map<String, dynamic>>> searchMaterials(String query)
```
- Searches materials by name (case-insensitive)
- Returns matching materials
- Used for real-time search filtering

#### `getMaterialsByCategory(String category)`
```dart
Future<List<Map<String, dynamic>>> getMaterialsByCategory(String category)
```
- Fetches materials for a specific category
- Returns materials sorted by name
- Can be used for category-based filtering

#### `getMaterialCategories()`
```dart
Future<List<String>> getMaterialCategories()
```
- Fetches all unique material categories
- Returns list of category names
- Can be used for category dropdown

### Step 4: UI Integration (Already Done)

#### Material Search Dropdown Widget

**File:** `lib/widgets/material_search_dropdown.dart`

Features:
- Real-time search with debouncing
- Dropdown list with material details
- Category and unit information display
- Loading state handling
- Error handling with user feedback

**Usage:**
```dart
MaterialSearchDropdown(
  hintText: 'Search and select material',
  onMaterialSelected: (materialName) {
    // Handle material selection
    setState(() {
      _itemMaterials[key]!.add(materialName);
    });
  },
)
```

#### Integration in Update Screen

**File:** `lib/screens/update_screen.dart`

The material dropdown has been integrated in two places:

1. **Customer Complaints Section** (Line ~2215)
   - Allows adding materials for each complaint
   - Materials are stored in `_itemMaterials` map

2. **Additional Suggestions Section** (Line ~2481)
   - Allows adding materials for each suggestion
   - Same material selection workflow

---

## Usage Workflow

### For Executives

1. **Open Update Form**
   - Select a job from the list
   - Update form opens with complaints/suggestions

2. **Add Materials**
   - Scroll to "Materials" section
   - Click on material search field
   - Start typing to search (e.g., "oil", "brake", "filter")
   - Select material from dropdown
   - Material appears as a chip/tag
   - Repeat to add more materials

3. **Remove Materials**
   - Click the "X" icon on material chip
   - Material is removed from list

4. **Save Update**
   - Click "Save Update" or "Save & Continue"
   - Materials are saved with the job update

### Example Search Queries

- "oil" → Shows: Engine Oil 5W-30, Engine Oil 10W-40, Oil Filter, etc.
- "brake" → Shows: Brake Pads, Brake Fluid, Brake Disc, etc.
- "filter" → Shows: Oil Filter, Air Filter, Cabin Air Filter, Fuel Filter, etc.
- "pump" → Shows: Water Pump, Fuel Pump, AC Compressor, etc.

---

## Managing Materials

### Adding New Materials

1. **Via Supabase Dashboard**
   - Go to Table Editor → materials
   - Click "Insert row"
   - Fill in: name, category, unit, description
   - Set is_active to true
   - Save

2. **Via SQL**
   ```sql
   INSERT INTO materials (name, category, unit, description, is_active)
   VALUES ('New Material Name', 'Category', 'Unit', 'Description', true);
   ```

### Deactivating Materials

Instead of deleting, set `is_active` to false:

```sql
UPDATE materials SET is_active = false WHERE name = 'Old Material';
```

### Editing Materials

```sql
UPDATE materials 
SET name = 'Updated Name', 
    description = 'Updated description'
WHERE id = 123;
```

### Viewing All Materials

```sql
SELECT category, COUNT(*) as count 
FROM materials 
WHERE is_active = true 
GROUP BY category 
ORDER BY category;
```

---

## Database Queries Reference

### Get All Materials (Sorted by Category)
```sql
SELECT id, name, category, unit, description
FROM materials
WHERE is_active = true
ORDER BY category, name;
```

### Search Materials by Name
```sql
SELECT id, name, category, unit, description
FROM materials
WHERE is_active = true
AND name ILIKE '%search_term%'
ORDER BY category, name;
```

### Get Materials by Category
```sql
SELECT id, name, category, unit, description
FROM materials
WHERE is_active = true
AND category = 'Engine & Oil'
ORDER BY name;
```

### Get All Categories
```sql
SELECT DISTINCT category
FROM materials
WHERE is_active = true
ORDER BY category;
```

### Count Materials by Category
```sql
SELECT category, COUNT(*) as count
FROM materials
WHERE is_active = true
GROUP BY category
ORDER BY category;
```

---

## Sample Materials List

### Engine & Oil (8 materials)
- Engine Oil 5W-30
- Engine Oil 10W-40
- Engine Oil 15W-40
- Oil Filter
- Air Filter
- Cabin Air Filter
- Spark Plugs
- Fuel Filter

### Cooling System (5 materials)
- Coolant/Antifreeze
- Radiator Hose
- Water Pump
- Thermostat
- Radiator Cap

### Brake System (7 materials)
- Brake Pads (Front)
- Brake Pads (Rear)
- Brake Fluid
- Brake Disc/Rotor
- Brake Shoes
- Brake Hose
- Brake Caliper

### Suspension & Steering (7 materials)
- Shock Absorber
- Spring
- Ball Joint
- Tie Rod End
- Sway Bar Link
- Steering Rack
- Power Steering Fluid

### Electrical & Battery (8 materials)
- Car Battery
- Alternator
- Starter Motor
- Headlight Bulb
- Tail Light Bulb
- Wiper Blade
- Battery Cable
- Fuse

### Transmission & Drivetrain (7 materials)
- Transmission Fluid
- Clutch Plate
- Clutch Release Bearing
- Drive Belt
- Differential Oil
- CV Joint Boot
- Axle Shaft

### Tire & Wheel (5 materials)
- Tire (4-Wheeler)
- Wheel Alignment
- Wheel Balancing
- Wheel Bearing
- Tire Patch

### Fuel System (5 materials)
- Fuel Pump
- Fuel Injector
- Fuel Tank
- Fuel Pressure Regulator
- Fuel Line

### Exhaust System (5 materials)
- Muffler
- Catalytic Converter
- Exhaust Pipe
- Oxygen Sensor
- Silencer

### Body & Paint (8 materials)
- Car Paint (Spray)
- Primer
- Putty
- Sandpaper
- Dent Puller
- Door Handle
- Window Regulator
- Weatherstrip

### Interior & Upholstery (6 materials)
- Seat Cover
- Floor Mat
- Dashboard Pad
- Steering Wheel Cover
- Door Panel Trim
- Headliner

### Cooling & AC (6 materials)
- AC Refrigerant
- AC Compressor
- AC Condenser
- AC Evaporator
- AC Filter
- Expansion Valve

### Miscellaneous (8 materials)
- Lubricant/Grease
- Sealant
- Adhesive
- Cleaning Solution
- Rust Remover
- Gasket
- Bolt & Nut Set
- Hose Clamp

---

## Technical Details

### Data Flow

```
Executive Updates Job
    ↓
Update Form Opens
    ↓
Material Search Dropdown Loads
    ↓
SupabaseService.getAllMaterials()
    ↓
Materials Table Query
    ↓
Dropdown Displays Materials
    ↓
Executive Types Search Query
    ↓
SupabaseService.searchMaterials(query)
    ↓
Filtered Results Display
    ↓
Executive Selects Material
    ↓
Material Added to _itemMaterials Map
    ↓
Material Chip Displayed
    ↓
Save Update
    ↓
Materials Saved with Job Data
```

### Performance Optimization

- **Indexes**: Database indexes on name, category, and is_active for fast queries
- **Lazy Loading**: Materials loaded only when dropdown is opened
- **Search Debouncing**: Real-time search with minimal database queries
- **Caching**: Materials cached in widget state to reduce repeated queries

### Error Handling

- Network errors: User-friendly error messages
- Empty results: "No materials found" message
- Loading state: Circular progress indicator
- Graceful fallback: Can still manually enter materials if dropdown fails

---

## Troubleshooting

### Materials Not Appearing

**Problem**: Dropdown shows "No materials available"

**Solutions**:
1. Verify SQL script was executed successfully
2. Check `materials` table exists in Supabase
3. Verify `is_active = true` for materials
4. Check network connection
5. Review console logs for errors

### Search Not Working

**Problem**: Search returns no results

**Solutions**:
1. Verify material names in database
2. Check case sensitivity (search is case-insensitive)
3. Try partial name search
4. Verify `is_active = true` for materials

### Dropdown Not Opening

**Problem**: Material search field doesn't open dropdown

**Solutions**:
1. Verify `MaterialSearchDropdown` widget is imported
2. Check for console errors
3. Verify `onMaterialSelected` callback is defined
4. Test on different device/emulator

### Performance Issues

**Problem**: Dropdown is slow to load

**Solutions**:
1. Verify database indexes are created
2. Check network latency
3. Reduce number of materials if needed
4. Consider pagination for large lists

---

## Future Enhancements

Potential improvements for the materials system:

1. **Material Pricing**
   - Add cost per unit to materials
   - Auto-calculate material costs in job updates

2. **Material Inventory**
   - Track material stock levels
   - Alert when materials are low
   - Auto-order when stock reaches threshold

3. **Material History**
   - Track which materials are most frequently used
   - Suggest materials based on job type
   - Analytics on material usage patterns

4. **Material Bundles**
   - Create bundles of commonly used materials
   - Quick selection of bundle instead of individual items

5. **Material Customization**
   - Allow executives to create custom materials
   - Admin approval workflow for custom materials

6. **Material Images**
   - Add product images to materials
   - Visual reference for executives

---

## Support & Questions

For issues or questions about the materials system:

1. Check the troubleshooting section above
2. Review console logs for error messages
3. Verify database schema matches documentation
4. Test with sample materials first
5. Contact development team with specific error messages

---

## Version History

- **v1.0** (Current)
  - Initial implementation of predefined materials system
  - Searchable dropdown with 100+ sample materials
  - 12 material categories
  - Real-time search functionality
  - Integration with update form

---

## Files Modified/Created

### New Files
- `lib/widgets/material_search_dropdown.dart` - Material dropdown widget
- `database/materials_setup.sql` - Database schema and sample data

### Modified Files
- `lib/services/supabase_service.dart` - Added material service methods
- `lib/screens/update_screen.dart` - Integrated material dropdown

### Configuration Files
- No additional configuration required

---

## License & Attribution

This materials system is part of the AutoFix app and follows the same license terms.

---

**Last Updated**: November 2025  
**Status**: Production Ready

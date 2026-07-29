# SQL Commands for Materials System

## Quick Copy-Paste Commands

### 1. Create Materials Table

```sql
CREATE TABLE IF NOT EXISTS materials (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  category VARCHAR(100),
  unit VARCHAR(50),
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2. Create Indexes

```sql
CREATE INDEX IF NOT EXISTS idx_materials_name ON materials(name);
CREATE INDEX IF NOT EXISTS idx_materials_category ON materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_active ON materials(is_active);
```

### 3. Verify Table Creation

```sql
SELECT * FROM materials LIMIT 5;
```

---

## Verification Queries

### Count All Materials

```sql
SELECT COUNT(*) as total_materials FROM materials WHERE is_active = true;
```

**Expected Result**: ~100 materials

### Count by Category

```sql
SELECT category, COUNT(*) as count 
FROM materials 
WHERE is_active = true 
GROUP BY category 
ORDER BY category;
```

**Expected Result**: 12-13 categories with materials

### List All Categories

```sql
SELECT DISTINCT category 
FROM materials 
WHERE is_active = true 
ORDER BY category;
```

### Search for Specific Material

```sql
SELECT * FROM materials 
WHERE name ILIKE '%oil%' 
AND is_active = true;
```

---

## Management Queries

### Add New Material

```sql
INSERT INTO materials (name, category, unit, description, is_active)
VALUES ('New Material Name', 'Category Name', 'Unit', 'Description', true);
```

**Example:**
```sql
INSERT INTO materials (name, category, unit, description, is_active)
VALUES ('Synthetic Oil 0W-20', 'Engine & Oil', 'Liter', 'Premium synthetic engine oil', true);
```

### Update Material

```sql
UPDATE materials 
SET name = 'Updated Name', 
    description = 'Updated description'
WHERE id = 123;
```

### Deactivate Material

```sql
UPDATE materials SET is_active = false WHERE name = 'Material Name';
```

### Reactivate Material

```sql
UPDATE materials SET is_active = true WHERE name = 'Material Name';
```

### Delete Material (Permanent)

```sql
DELETE FROM materials WHERE id = 123;
```

---

## Search Queries

### Search by Name

```sql
SELECT * FROM materials 
WHERE name ILIKE '%search_term%' 
AND is_active = true
ORDER BY category, name;
```

### Search by Category

```sql
SELECT * FROM materials 
WHERE category = 'Engine & Oil' 
AND is_active = true
ORDER BY name;
```

### Search by Unit

```sql
SELECT * FROM materials 
WHERE unit = 'Liter' 
AND is_active = true
ORDER BY category, name;
```

### Complex Search

```sql
SELECT * FROM materials 
WHERE (name ILIKE '%oil%' OR category ILIKE '%engine%')
AND is_active = true
ORDER BY category, name;
```

---

## Statistics Queries

### Materials per Category

```sql
SELECT category, COUNT(*) as count 
FROM materials 
WHERE is_active = true 
GROUP BY category 
ORDER BY count DESC, category;
```

### Materials by Unit Type

```sql
SELECT unit, COUNT(*) as count 
FROM materials 
WHERE is_active = true 
GROUP BY unit 
ORDER BY count DESC;
```

### Inactive Materials

```sql
SELECT * FROM materials 
WHERE is_active = false 
ORDER BY category, name;
```

### Recently Added Materials

```sql
SELECT * FROM materials 
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

## Bulk Operations

### Deactivate All Materials in Category

```sql
UPDATE materials 
SET is_active = false 
WHERE category = 'Category Name';
```

### Reactivate All Materials

```sql
UPDATE materials SET is_active = true;
```

### Update All Descriptions

```sql
UPDATE materials 
SET description = 'Updated description' 
WHERE description IS NULL;
```

### Add Category to Materials Without One

```sql
UPDATE materials 
SET category = 'Miscellaneous' 
WHERE category IS NULL;
```

---

## Cleanup Queries

### Remove Duplicate Materials (Keep Latest)

```sql
DELETE FROM materials 
WHERE id NOT IN (
  SELECT MAX(id) FROM materials GROUP BY LOWER(name)
);
```

### Remove Empty Descriptions

```sql
UPDATE materials 
SET description = 'No description' 
WHERE description IS NULL OR description = '';
```

### Standardize Category Names

```sql
UPDATE materials 
SET category = 'Engine & Oil' 
WHERE category ILIKE '%engine%' OR category ILIKE '%oil%';
```

---

## Export Queries

### Export All Materials as CSV

```sql
COPY (
  SELECT id, name, category, unit, description, is_active, created_at
  FROM materials
  WHERE is_active = true
  ORDER BY category, name
) TO STDOUT WITH CSV HEADER;
```

### Export by Category

```sql
COPY (
  SELECT name, unit, description
  FROM materials
  WHERE category = 'Engine & Oil'
  AND is_active = true
  ORDER BY name
) TO STDOUT WITH CSV HEADER;
```

---

## Troubleshooting Queries

### Check Table Structure

```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'materials';
```

### Check Indexes

```sql
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'materials';
```

### Check for Duplicates

```sql
SELECT name, COUNT(*) as count 
FROM materials 
GROUP BY LOWER(name) 
HAVING COUNT(*) > 1;
```

### Check Data Integrity

```sql
SELECT 
  COUNT(*) as total,
  COUNT(CASE WHEN name IS NULL THEN 1 END) as null_names,
  COUNT(CASE WHEN category IS NULL THEN 1 END) as null_categories,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive
FROM materials;
```

---

## Performance Queries

### Check Query Performance

```sql
EXPLAIN ANALYZE
SELECT * FROM materials 
WHERE name ILIKE '%oil%' 
AND is_active = true;
```

### Check Index Usage

```sql
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'materials';
```

### Check Table Size

```sql
SELECT 
  pg_size_pretty(pg_total_relation_size('materials')) as total_size,
  pg_size_pretty(pg_relation_size('materials')) as table_size,
  pg_size_pretty(pg_indexes_size('materials')) as indexes_size;
```

---

## Backup & Restore

### Backup Materials Table

```sql
CREATE TABLE materials_backup AS SELECT * FROM materials;
```

### Restore from Backup

```sql
TRUNCATE TABLE materials;
INSERT INTO materials SELECT * FROM materials_backup;
```

### Compare Backup with Current

```sql
SELECT * FROM materials
EXCEPT
SELECT * FROM materials_backup
UNION ALL
SELECT * FROM materials_backup
EXCEPT
SELECT * FROM materials;
```

---

## Quick Reference

| Task | Command |
|------|---------|
| View all materials | `SELECT * FROM materials;` |
| Count materials | `SELECT COUNT(*) FROM materials;` |
| Search by name | `SELECT * FROM materials WHERE name ILIKE '%term%';` |
| Add material | `INSERT INTO materials (name, category, unit, description, is_active) VALUES (...);` |
| Update material | `UPDATE materials SET ... WHERE id = ...;` |
| Deactivate | `UPDATE materials SET is_active = false WHERE ...;` |
| Delete | `DELETE FROM materials WHERE id = ...;` |
| View categories | `SELECT DISTINCT category FROM materials;` |
| Count by category | `SELECT category, COUNT(*) FROM materials GROUP BY category;` |

---

## Notes

- Always use `ILIKE` for case-insensitive searches
- Use `is_active = true` to filter active materials
- Never delete materials directly; use `is_active = false` instead
- Always backup before bulk operations
- Test queries on small dataset first
- Use indexes for better performance

---

**Last Updated**: November 2025

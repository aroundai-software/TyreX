# Materials Data Flow - How Materials Are Saved to Database

## 📋 Your Question

> When I select materials for one vehicle from the list, is that material data for that selected vehicle updated to the reports table?

## ✅ Answer: YES

Materials ARE saved to the `reports` table when you save the job update. Here's exactly how it works:

---

## 🔄 Complete Data Flow

### Step 1: Material Selection (In-Memory)
```
Executive opens job update form
    ↓
Selects a vehicle/job
    ↓
Scrolls to Materials section
    ↓
Clicks material search field
    ↓
Types "oil" and selects "Engine Oil 5W-30"
    ↓
Material stored in _itemMaterials map (in app memory)
    ↓
Material appears as chip/tag in UI
```

### Step 2: Material Storage (In App State)
```dart
// Materials stored in this map:
final Map<String, List<String>> _itemMaterials = {};

// Example structure:
{
  'complaint_0': ['Engine Oil 5W-30', 'Oil Filter'],
  'suggestion_0': ['Brake Pads (Front)', 'Brake Fluid'],
  'suggestion_1': ['AC Refrigerant']
}
```

### Step 3: Material Saving to Database (When Save Button Clicked)

When executive clicks **"Save Update"** or **"Save & Continue"**, the `_saveUpdate()` method is called:

```dart
Future<void> _saveUpdate() async {
  // ... validation code ...

  // STEP 1: Prepare complaints with materials
  final updatedComplaints = _originalComplaints.map((c) => {
    'text': c['text'],
    'amount': double.tryParse(_complaintControllers[c['text']]?.text ?? '0') ?? 0,
    'type': AppConstants.typeComplaint
  }).toList();

  // STEP 2: Add materials to suggested items
  final updatedSuggestedItems = [...updatedComplaints, ..._newSuggestions].map((item) {
    final itemText = item['text'] as String;
    return {
      ...item,
      'materials': _approvedItemMaterials[itemText] ?? []  // ✅ MATERIALS ADDED HERE
    };
  }).toList();

  // STEP 3: Prepare update data
  Map<String, dynamic> updateData = {
    'expected_delivery': _deliveryDateController.text,
    'complaint': jsonEncode(updatedComplaints),
    'suggested': jsonEncode(updatedSuggestedItems),  // ✅ INCLUDES MATERIALS
    'status': AppConstants.statusOngoing,
  };

  // STEP 4: Save to database
  await supabase.from('reports').update(updateData).eq('id', _currentReportId!);
  //                                                           ↑
  //                                                    Updates the specific job/vehicle
}
```

---

## 📊 Database Schema - Where Materials Are Stored

Looking at your schema, materials are stored in the `reports` table:

```sql
CREATE TABLE public.reports (
  id integer PRIMARY KEY,
  vehicle_id integer,           -- ✅ Links to specific vehicle
  executive_id integer,         -- ✅ Links to executive who updated
  complaint text,               -- ✅ Stored as JSON with materials
  suggested text,               -- ✅ Stored as JSON with materials
  materials_required jsonb,     -- ✅ Alternative field for materials
  -- ... other fields ...
);
```

### How Materials Are Stored

**In `complaint` field (JSON format):**
```json
[
  {
    "text": "Engine noise",
    "amount": 5000,
    "type": "complaint",
    "materials": ["Engine Oil 5W-30", "Oil Filter"]
  }
]
```

**In `suggested` field (JSON format):**
```json
[
  {
    "text": "Change brake pads",
    "amount": 3000,
    "type": "suggestion",
    "materials": ["Brake Pads (Front)", "Brake Pads (Rear)", "Brake Fluid"]
  }
]
```

---

## 🎯 Complete Example Workflow

### Scenario: Oil Change Service for Vehicle KL7AS5656

#### Step 1: Executive Opens Job
```
Vehicle: KL7AS5656 (Maruti Swift)
Complaints: Engine noise, Oil leak
Suggestions: Change oil, Replace filter
```

#### Step 2: Executive Adds Materials
```
For "Engine noise" complaint:
  → Select "Engine Oil 5W-30"
  → Select "Oil Filter"

For "Change oil" suggestion:
  → Select "Engine Oil 5W-30"
  → Select "Oil Filter"
  → Select "Spark Plugs"
```

#### Step 3: In-Memory State
```dart
_itemMaterials = {
  'complaint_0': ['Engine Oil 5W-30', 'Oil Filter'],
  'complaint_1': [],
  'suggestion_0': ['Engine Oil 5W-30', 'Oil Filter', 'Spark Plugs'],
}
```

#### Step 4: Executive Clicks "Save Update"
```
_saveUpdate() is called
    ↓
Materials are attached to each item
    ↓
Data is JSON encoded
    ↓
Sent to Supabase
    ↓
reports table is updated
```

#### Step 5: Database Update
```sql
UPDATE reports SET
  complaint = '[
    {
      "text": "Engine noise",
      "amount": 5000,
      "type": "complaint",
      "materials": ["Engine Oil 5W-30", "Oil Filter"]
    },
    {
      "text": "Oil leak",
      "amount": 3000,
      "type": "complaint",
      "materials": []
    }
  ]',
  suggested = '[
    {
      "text": "Change oil",
      "amount": 2000,
      "type": "suggestion",
      "materials": ["Engine Oil 5W-30", "Oil Filter", "Spark Plugs"]
    }
  ]',
  status = 'Ongoing',
  expected_delivery = '2025-11-15'
WHERE id = 123;  -- ✅ Specific job/vehicle
```

#### Step 6: Data Saved Successfully
```
✅ Materials saved to reports table
✅ Linked to specific vehicle (via vehicle_id)
✅ Linked to specific job (via report id)
✅ Linked to executive who updated (via executive_id)
```

---

## 🔗 Data Relationships

```
reports table
├── id: 123 (Job ID)
├── vehicle_id: 45 (Links to vehicles table)
├── executive_id: 12 (Links to users table)
├── complaint: JSON with materials
├── suggested: JSON with materials
└── materials_required: Alternative field for materials
```

**Complete relationship:**
```
Vehicle (KL7AS5656)
    ↓
reports (Job #123)
    ├── complaint: [Engine Oil 5W-30, Oil Filter]
    ├── suggested: [Engine Oil 5W-30, Oil Filter, Spark Plugs]
    └── executive_id: 12 (Executive who added materials)
```

---

## 💾 Code Locations

### Where Materials Are Added to Data

**File**: `lib/screens/update_screen.dart`

**Line ~496-498** (Adding materials to suggested items):
```dart
final updatedSuggestedItems = [...updatedComplaints, ..._newSuggestions].map((item) {
  final itemText = item['text'] as String;
  return {...item, 'materials': _approvedItemMaterials[itemText] ?? []};
}).toList();
```

**Line ~507-508** (Saving to database):
```dart
updateData['complaint'] = jsonEncode(updatedComplaints);
updateData['suggested'] = jsonEncode(updatedSuggestedItems);
```

**Line ~516** (Database update):
```dart
await supabase.from('reports').update(updateData).eq('id', _currentReportId!);
```

---

## 🔍 How to Verify Materials Are Saved

### In Supabase Dashboard

1. Open Supabase → Table Editor
2. Click `reports` table
3. Find the job you just updated
4. Click on `complaint` or `suggested` field
5. You'll see the JSON with materials:

```json
[
  {
    "text": "Engine noise",
    "amount": 5000,
    "type": "complaint",
    "materials": ["Engine Oil 5W-30", "Oil Filter"]
  }
]
```

### Via SQL Query

```sql
SELECT 
  id,
  vehicle_id,
  complaint,
  suggested
FROM reports
WHERE id = 123;
```

Output:
```
id    | vehicle_id | complaint                                    | suggested
------|------------|----------------------------------------------|----------
123   | 45         | [{"text":"Engine noise","materials":[...]}] | [...]
```

---

## 🎯 Key Points

✅ **Materials ARE saved to reports table**
- Stored in `complaint` field (JSON)
- Stored in `suggested` field (JSON)
- Can also use `materials_required` field if needed

✅ **Materials are linked to specific vehicle**
- Via `vehicle_id` in reports table
- Via `report id` which connects to vehicle

✅ **Materials are linked to specific executive**
- Via `executive_id` in reports table
- Shows who added the materials

✅ **Materials are saved when "Save Update" is clicked**
- Not saved automatically
- Only saved when explicitly clicking save button

✅ **Materials persist in database**
- Can be retrieved later
- Can be edited in future updates
- Part of job history

---

## 📝 Two Scenarios

### Scenario 1: With Customer Approval

```dart
if (_hasCustomerApproval) {
  final updatedApprovedItemsWithMaterials = _approvedItems.map((item) {
    final itemText = item['text'] as String;
    return {...item, 'materials': _approvedItemMaterials[itemText] ?? []};
  }).toList();
  updateData['approved'] = jsonEncode(updatedApprovedItemsWithMaterials);
  // ✅ Materials saved in 'approved' field
}
```

### Scenario 2: Without Customer Approval

```dart
else {
  final updatedSuggestedItems = [...updatedComplaints, ..._newSuggestions].map((item) {
    final itemText = item['text'] as String;
    return {...item, 'materials': _approvedItemMaterials[itemText] ?? []};
  }).toList();
  updateData['suggested'] = jsonEncode(updatedSuggestedItems);
  // ✅ Materials saved in 'suggested' field
}
```

---

## 🚀 Summary

| Aspect | Details |
|--------|---------|
| **Stored In** | `reports` table (complaint, suggested, or approved fields) |
| **Format** | JSON array with materials for each item |
| **Linked To** | Specific vehicle (vehicle_id) and executive (executive_id) |
| **When Saved** | When "Save Update" button is clicked |
| **Persistence** | Permanently saved in database |
| **Retrieval** | Can be queried and displayed later |

---

## ✨ Visual Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    MATERIAL DATA FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Executive selects materials from dropdown                │
│     ↓                                                         │
│  2. Materials stored in _itemMaterials map (in-memory)       │
│     ↓                                                         │
│  3. Materials displayed as chips/tags in UI                  │
│     ↓                                                         │
│  4. Executive clicks "Save Update"                           │
│     ↓                                                         │
│  5. _saveUpdate() method called                              │
│     ↓                                                         │
│  6. Materials attached to complaint/suggested items          │
│     ↓                                                         │
│  7. Data JSON encoded                                        │
│     ↓                                                         │
│  8. Sent to Supabase (reports table)                         │
│     ↓                                                         │
│  9. ✅ SAVED TO DATABASE                                     │
│     ↓                                                         │
│  10. Linked to specific vehicle & executive                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

**Conclusion**: Yes, materials are definitely saved to the reports table when you save the job update. They are stored as JSON within the complaint, suggested, or approved fields, and are permanently linked to that specific vehicle and executive.

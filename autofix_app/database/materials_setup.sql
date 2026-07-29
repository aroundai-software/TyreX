-- ============================================================================
-- AutoFix App - Materials Table Setup
-- ============================================================================
-- This SQL script creates the materials table and inserts sample materials
-- for the AutoFix app's job update form.
--
-- Run this script in your Supabase SQL editor to set up the materials system.
-- ============================================================================

-- Create materials table
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

-- Create index for faster searches
CREATE INDEX IF NOT EXISTS idx_materials_name ON materials(name);
CREATE INDEX IF NOT EXISTS idx_materials_category ON materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_active ON materials(is_active);

-- ============================================================================
-- Sample Materials Data
-- ============================================================================
-- Insert sample materials organized by category

-- Engine & Oil Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Engine Oil 5W-30', 'Engine & Oil', 'Liter', 'Synthetic engine oil 5W-30'),
('Engine Oil 10W-40', 'Engine & Oil', 'Liter', 'Mineral engine oil 10W-40'),
('Engine Oil 15W-40', 'Engine & Oil', 'Liter', 'Mineral engine oil 15W-40'),
('Oil Filter', 'Engine & Oil', 'Piece', 'Standard oil filter'),
('Air Filter', 'Engine & Oil', 'Piece', 'Engine air filter'),
('Cabin Air Filter', 'Engine & Oil', 'Piece', 'Cabin air filter'),
('Spark Plugs', 'Engine & Oil', 'Set', 'Set of spark plugs'),
('Fuel Filter', 'Engine & Oil', 'Piece', 'Fuel filter cartridge')
ON CONFLICT (name) DO NOTHING;

-- Cooling System Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Coolant/Antifreeze', 'Cooling System', 'Liter', 'Engine coolant antifreeze'),
('Radiator Hose', 'Cooling System', 'Piece', 'Radiator hose assembly'),
('Water Pump', 'Cooling System', 'Piece', 'Engine water pump'),
('Thermostat', 'Cooling System', 'Piece', 'Engine thermostat'),
('Radiator Cap', 'Cooling System', 'Piece', 'Radiator pressure cap')
ON CONFLICT (name) DO NOTHING;

-- Brake System Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Brake Pads (Front)', 'Brake System', 'Set', 'Front brake pad set'),
('Brake Pads (Rear)', 'Brake System', 'Set', 'Rear brake pad set'),
('Brake Fluid', 'Brake System', 'Liter', 'DOT 3 brake fluid'),
('Brake Disc/Rotor', 'Brake System', 'Piece', 'Brake disc rotor'),
('Brake Shoes', 'Brake System', 'Set', 'Brake shoe set'),
('Brake Hose', 'Brake System', 'Piece', 'Brake hose assembly'),
('Brake Caliper', 'Brake System', 'Piece', 'Brake caliper assembly')
ON CONFLICT (name) DO NOTHING;

-- Suspension & Steering Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Shock Absorber', 'Suspension & Steering', 'Piece', 'Shock absorber assembly'),
('Spring', 'Suspension & Steering', 'Piece', 'Suspension spring'),
('Ball Joint', 'Suspension & Steering', 'Piece', 'Ball joint assembly'),
('Tie Rod End', 'Suspension & Steering', 'Piece', 'Tie rod end'),
('Sway Bar Link', 'Suspension & Steering', 'Piece', 'Sway bar link'),
('Steering Rack', 'Suspension & Steering', 'Piece', 'Steering rack assembly'),
('Power Steering Fluid', 'Suspension & Steering', 'Liter', 'Power steering fluid')
ON CONFLICT (name) DO NOTHING;

-- Electrical & Battery Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Car Battery', 'Electrical & Battery', 'Piece', 'Car battery 12V'),
('Alternator', 'Electrical & Battery', 'Piece', 'Alternator assembly'),
('Starter Motor', 'Electrical & Battery', 'Piece', 'Starter motor'),
('Headlight Bulb', 'Electrical & Battery', 'Piece', 'Headlight bulb'),
('Tail Light Bulb', 'Electrical & Battery', 'Piece', 'Tail light bulb'),
('Wiper Blade', 'Electrical & Battery', 'Piece', 'Wiper blade'),
('Battery Cable', 'Electrical & Battery', 'Piece', 'Battery cable assembly'),
('Fuse', 'Electrical & Battery', 'Piece', 'Car fuse')
ON CONFLICT (name) DO NOTHING;

-- Transmission & Drivetrain Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Transmission Fluid', 'Transmission & Drivetrain', 'Liter', 'Automatic transmission fluid'),
('Clutch Plate', 'Transmission & Drivetrain', 'Piece', 'Clutch plate assembly'),
('Clutch Release Bearing', 'Transmission & Drivetrain', 'Piece', 'Clutch release bearing'),
('Drive Belt', 'Transmission & Drivetrain', 'Piece', 'Serpentine drive belt'),
('Differential Oil', 'Transmission & Drivetrain', 'Liter', 'Differential gear oil'),
('CV Joint Boot', 'Transmission & Drivetrain', 'Piece', 'CV joint boot'),
('Axle Shaft', 'Transmission & Drivetrain', 'Piece', 'Axle shaft assembly')
ON CONFLICT (name) DO NOTHING;

-- Tire & Wheel Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Tire (4-Wheeler)', 'Tire & Wheel', 'Piece', 'Car tire'),
('Wheel Alignment', 'Tire & Wheel', 'Service', 'Wheel alignment service'),
('Wheel Balancing', 'Tire & Wheel', 'Service', 'Wheel balancing service'),
('Wheel Bearing', 'Tire & Wheel', 'Piece', 'Wheel bearing assembly'),
('Tire Patch', 'Tire & Wheel', 'Piece', 'Tire puncture patch')
ON CONFLICT (name) DO NOTHING;

-- Fuel System Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Fuel Pump', 'Fuel System', 'Piece', 'Electric fuel pump'),
('Fuel Injector', 'Fuel System', 'Piece', 'Fuel injector'),
('Fuel Tank', 'Fuel System', 'Piece', 'Fuel tank assembly'),
('Fuel Pressure Regulator', 'Fuel System', 'Piece', 'Fuel pressure regulator'),
('Fuel Line', 'Fuel System', 'Piece', 'Fuel line hose')
ON CONFLICT (name) DO NOTHING;

-- Exhaust System Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Muffler', 'Exhaust System', 'Piece', 'Exhaust muffler'),
('Catalytic Converter', 'Exhaust System', 'Piece', 'Catalytic converter'),
('Exhaust Pipe', 'Exhaust System', 'Piece', 'Exhaust pipe assembly'),
('Oxygen Sensor', 'Exhaust System', 'Piece', 'O2 sensor'),
('Silencer', 'Exhaust System', 'Piece', 'Exhaust silencer')
ON CONFLICT (name) DO NOTHING;

-- Body & Paint Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Car Paint (Spray)', 'Body & Paint', 'Can', 'Automotive spray paint'),
('Primer', 'Body & Paint', 'Can', 'Automotive primer'),
('Putty', 'Body & Paint', 'Kg', 'Body filler putty'),
('Sandpaper', 'Body & Paint', 'Sheet', 'Sandpaper assorted'),
('Dent Puller', 'Body & Paint', 'Piece', 'Dent puller tool'),
('Door Handle', 'Body & Paint', 'Piece', 'Door handle assembly'),
('Window Regulator', 'Body & Paint', 'Piece', 'Window regulator motor'),
('Weatherstrip', 'Body & Paint', 'Meter', 'Door weatherstrip seal')
ON CONFLICT (name) DO NOTHING;

-- Interior & Upholstery Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Seat Cover', 'Interior & Upholstery', 'Set', 'Car seat cover set'),
('Floor Mat', 'Interior & Upholstery', 'Set', 'Car floor mat set'),
('Dashboard Pad', 'Interior & Upholstery', 'Piece', 'Dashboard padding'),
('Steering Wheel Cover', 'Interior & Upholstery', 'Piece', 'Steering wheel cover'),
('Door Panel Trim', 'Interior & Upholstery', 'Piece', 'Door panel trim'),
('Headliner', 'Interior & Upholstery', 'Meter', 'Ceiling headliner fabric')
ON CONFLICT (name) DO NOTHING;

-- Cooling & AC Materials
INSERT INTO materials (name, category, unit, description) VALUES
('AC Refrigerant', 'Cooling & AC', 'Kg', 'Air conditioning refrigerant R134a'),
('AC Compressor', 'Cooling & AC', 'Piece', 'AC compressor assembly'),
('AC Condenser', 'Cooling & AC', 'Piece', 'AC condenser unit'),
('AC Evaporator', 'Cooling & AC', 'Piece', 'AC evaporator coil'),
('AC Filter', 'Cooling & AC', 'Piece', 'AC cabin filter'),
('Expansion Valve', 'Cooling & AC', 'Piece', 'AC expansion valve')
ON CONFLICT (name) DO NOTHING;

-- Miscellaneous Materials
INSERT INTO materials (name, category, unit, description) VALUES
('Lubricant/Grease', 'Miscellaneous', 'Kg', 'Multi-purpose lubricant grease'),
('Sealant', 'Miscellaneous', 'Tube', 'Automotive sealant'),
('Adhesive', 'Miscellaneous', 'Tube', 'Automotive adhesive'),
('Cleaning Solution', 'Miscellaneous', 'Liter', 'Engine cleaning solution'),
('Rust Remover', 'Miscellaneous', 'Can', 'Rust remover spray'),
('Gasket', 'Miscellaneous', 'Piece', 'Engine gasket set'),
('Bolt & Nut Set', 'Miscellaneous', 'Set', 'Assorted bolts and nuts'),
('Hose Clamp', 'Miscellaneous', 'Piece', 'Stainless steel hose clamp')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- Verification Query
-- ============================================================================
-- Run this to verify all materials were inserted successfully
-- SELECT category, COUNT(*) as count FROM materials WHERE is_active = true GROUP BY category ORDER BY category;

-- Expected output should show materials organized by category with counts

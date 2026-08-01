import 'dart:io';

void main() {
  final file = File('tyre.txt');
  final lines = file.readAsLinesSync();
  
  final out = File('tyre_catalog_update.sql');
  final sink = out.openWrite();
  
  sink.writeln('-- 1. Alter Table to add new columns');
  sink.writeln('ALTER TABLE public.tyre_catalog ADD COLUMN IF NOT EXISTS li_si TEXT;');
  sink.writeln('ALTER TABLE public.tyre_catalog ADD COLUMN IF NOT EXISTS basic_price NUMERIC;');
  sink.writeln('ALTER TABLE public.tyre_catalog ADD COLUMN IF NOT EXISTS billing_price NUMERIC;');
  sink.writeln('');
  
  sink.writeln('-- (Optional) Clear existing catalog if you want a fresh start:');
  sink.writeln('-- TRUNCATE TABLE public.tyre_catalog;');
  sink.writeln('');
  
  sink.writeln('-- 2. Insert Data');
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    final parts = line.split('\t');
    if (parts.length >= 5) {
      final size = parts[0].replaceAll("'", "''");
      final li_si = parts[1].replaceAll("'", "''");
      final model = parts[2].replaceAll("'", "''");
      final basicPrice = double.tryParse(parts[3]) ?? 0;
      final billingPrice = double.tryParse(parts[4]) ?? 0;
      
      sink.writeln("INSERT INTO public.tyre_catalog (brand, model, size, company_name, li_si, basic_price, billing_price) VALUES ('Continental', '$model', '$size', 'Continental India', '$li_si', $basicPrice, $billingPrice);");
    }
  }
  
  sink.close();
  print('Generated tyre_catalog_update.sql');
}

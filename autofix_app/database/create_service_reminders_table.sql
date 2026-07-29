-- Create service_reminders table for Next Service Reminder feature
-- Run this SQL script in your Supabase SQL Editor

CREATE TABLE public.service_reminders (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  report_id integer NOT NULL,
  vehicle_id integer NOT NULL,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  vehicle_number text NOT NULL,
  vehicle_brand text NOT NULL,
  vehicle_model text NOT NULL,
  last_service_date timestamp with time zone NOT NULL,
  next_service_due_date date NOT NULL,
  follow_up_status text NOT NULL DEFAULT 'pending'::text,
  notes text,
  contacted_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT service_reminders_pkey PRIMARY KEY (id),
  CONSTRAINT service_reminders_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.reports(id) ON DELETE CASCADE,
  CONSTRAINT service_reminders_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE CASCADE,
  CONSTRAINT service_reminders_follow_up_status_check CHECK (follow_up_status IN ('pending', 'contacted', 'scheduled', 'no_response', 'completed'))
);

-- Create indexes for better performance
CREATE INDEX idx_service_reminders_next_service_due_date ON public.service_reminders(next_service_due_date);
CREATE INDEX idx_service_reminders_follow_up_status ON public.service_reminders(follow_up_status);
CREATE INDEX idx_service_reminders_customer_phone ON public.service_reminders(customer_phone);
CREATE INDEX idx_service_reminders_vehicle_number ON public.service_reminders(vehicle_number);

-- Enable Row Level Security (RLS)
ALTER TABLE public.service_reminders ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (simplified for now - adjust based on your authentication setup)
-- Note: Since your users table uses integer IDs but Supabase auth uses UUIDs,
-- we'll use a more permissive policy for now. You can tighten this later based on your auth setup.

-- Policy to allow authenticated users to view service reminders
CREATE POLICY "Allow authenticated users to view service reminders" ON public.service_reminders
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy to allow authenticated users to update service reminders
CREATE POLICY "Allow authenticated users to update service reminders" ON public.service_reminders
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Policy to allow authenticated users to insert service reminders
CREATE POLICY "Allow authenticated users to insert service reminders" ON public.service_reminders
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Add a trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_service_reminders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_service_reminders_updated_at
  BEFORE UPDATE ON public.service_reminders
  FOR EACH ROW
  EXECUTE FUNCTION update_service_reminders_updated_at();

-- Optional: Add some sample data for testing (remove in production)
-- INSERT INTO public.service_reminders (
--   report_id, vehicle_id, customer_name, customer_phone, 
--   vehicle_number, vehicle_brand, vehicle_model,
--   last_service_date, next_service_due_date, follow_up_status
-- ) VALUES (
--   1, 1, 'John Doe', '9876543210',
--   'KL07AS5656', 'Toyota', 'Camry',
--   '2024-08-01 10:00:00+00', '2024-11-01', 'pending'
-- );

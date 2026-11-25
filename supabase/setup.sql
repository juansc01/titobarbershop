-- ============================================
-- TITO'S BARBER SHOP - MIGRACIÓN COMPLETA
-- Ejecutar este archivo entero en el SQL Editor de Supabase
-- https://supabase.com/dashboard/project/pcosrxvuzzenfwgyylcq/sql
-- ============================================

-- ==========================================
-- PARTE 1: ESQUEMA
-- ==========================================

-- Settings table
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Barbers table
CREATE TABLE IF NOT EXISTS barbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  photo_url TEXT,
  color TEXT DEFAULT '#6366f1',
  active BOOLEAN DEFAULT true,
  email TEXT,
  phone TEXT,
  bio TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Services table
CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  duration INTEGER NOT NULL DEFAULT 30,
  price DECIMAL(10,2) NOT NULL DEFAULT 0,
  color TEXT DEFAULT '#6366f1',
  active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Barber-Service relationship
CREATE TABLE IF NOT EXISTS barber_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barber_id UUID NOT NULL REFERENCES barbers(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  UNIQUE(barber_id, service_id)
);

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  notes TEXT,
  total_visits INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Working hours table
CREATE TABLE IF NOT EXISTS working_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barber_id UUID NOT NULL REFERENCES barbers(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_working BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(barber_id, day_of_week)
);

-- Scheduled schedule programs table
CREATE TABLE IF NOT EXISTS schedule_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barber_id UUID NOT NULL REFERENCES barbers(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE,
  notes TEXT,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT schedule_program_dates_valid CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Scheduled hours by day for each program
CREATE TABLE IF NOT EXISTS schedule_program_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES schedule_programs(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_working BOOLEAN DEFAULT true,
  break_start_time TIME,
  break_end_time TIME,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(program_id, day_of_week),
  CONSTRAINT schedule_program_hours_time_order CHECK (start_time < end_time),
  CONSTRAINT schedule_program_hours_break_valid CHECK (
    (break_start_time IS NULL AND break_end_time IS NULL)
    OR (
      break_start_time IS NOT NULL
      AND break_end_time IS NOT NULL
      AND start_time < break_start_time
      AND break_start_time < break_end_time
      AND break_end_time < end_time
    )
  )
);

-- Vacations table
CREATE TABLE IF NOT EXISTS vacations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barber_id UUID NOT NULL REFERENCES barbers(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Blocked times table
CREATE TABLE IF NOT EXISTS blocked_times (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barber_id UUID NOT NULL REFERENCES barbers(id) ON DELETE CASCADE,
  start_datetime TIMESTAMPTZ NOT NULL,
  end_datetime TIMESTAMPTZ NOT NULL,
  reason TEXT,
  block_type TEXT DEFAULT 'block' CHECK (block_type IN ('block', 'break', 'absence')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Appointments table
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barber_id UUID NOT NULL REFERENCES barbers(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'completed', 'cancelled', 'no_show')),
  notes TEXT,
  price DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_appointments_barber_id ON appointments(barber_id);
CREATE INDEX IF NOT EXISTS idx_appointments_start_time ON appointments(start_time);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);
CREATE INDEX IF NOT EXISTS idx_appointments_customer_id ON appointments(customer_id);
CREATE INDEX IF NOT EXISTS idx_working_hours_barber ON working_hours(barber_id);
CREATE INDEX IF NOT EXISTS idx_schedule_programs_barber ON schedule_programs(barber_id);
CREATE INDEX IF NOT EXISTS idx_schedule_program_hours_program ON schedule_program_hours(program_id);
CREATE INDEX IF NOT EXISTS idx_blocked_times_barber ON blocked_times(barber_id);
CREATE INDEX IF NOT EXISTS idx_vacations_barber ON vacations(barber_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);

-- Enable RLS
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE working_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_program_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_times ENABLE ROW LEVEL SECURITY;
ALTER TABLE vacations ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE barber_services ENABLE ROW LEVEL SECURITY;

-- Policies (acceso público por ahora)
CREATE POLICY "Allow all on barbers" ON barbers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on services" ON services FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on customers" ON customers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on appointments" ON appointments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on working_hours" ON working_hours FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on schedule_programs" ON schedule_programs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on schedule_program_hours" ON schedule_program_hours FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on blocked_times" ON blocked_times FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on vacations" ON vacations FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on settings" ON settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on barber_services" ON barber_services FOR ALL USING (true) WITH CHECK (true);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_barbers_updated_at BEFORE UPDATE ON barbers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_services_updated_at BEFORE UPDATE ON services FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_working_hours_updated_at BEFORE UPDATE ON working_hours FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_schedule_programs_updated_at BEFORE UPDATE ON schedule_programs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_schedule_program_hours_updated_at BEFORE UPDATE ON schedule_program_hours FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION validate_schedule_program_period()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.end_date IS NOT NULL AND NEW.end_date < NEW.start_date THEN
    RAISE EXCEPTION 'PROGRAM_END_BEFORE_START';
  END IF;

  IF NEW.cancelled_at IS NULL AND EXISTS (
    SELECT 1
    FROM schedule_programs sp
    WHERE sp.barber_id = NEW.barber_id
      AND sp.id <> NEW.id
      AND sp.cancelled_at IS NULL
      AND daterange(sp.start_date, COALESCE(sp.end_date, 'infinity'::date), '[]')
          && daterange(NEW.start_date, COALESCE(NEW.end_date, 'infinity'::date), '[]')
  ) THEN
    RAISE EXCEPTION 'SCHEDULE_PERIOD_OVERLAP';
  END IF;

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS validate_schedule_program_period_trigger ON schedule_programs;
CREATE TRIGGER validate_schedule_program_period_trigger
  BEFORE INSERT OR UPDATE ON schedule_programs
  FOR EACH ROW
  EXECUTE FUNCTION validate_schedule_program_period();

-- ==========================================
-- PARTE 2: DATOS INICIALES
-- ==========================================

-- Peluquero: Nacho
INSERT INTO barbers (name, photo_url, color, active, bio) VALUES
('Nacho', 'PLACEHOLDER_IMAGE_DESCRIPCION: Fotografía del peluquero Nacho', '#6366f1', true, 'Barbero profesional con años de experiencia');

-- Servicios
INSERT INTO services (name, description, duration, price, color, active, sort_order) VALUES
('Corte y peinado', 'Corte de pelo profesional con peinado incluido', 45, 10.00, '#6366f1', true, 1),
('Barba (Solo Barba)', 'Arreglo y perfilado de barba profesional', 20, 5.00, '#8b5cf6', true, 2),
('Corte y Barba', 'Servicio completo de corte de pelo y arreglo de barba', 45, 12.00, '#ec4899', true, 3);

-- Asignar todos los servicios a Nacho
INSERT INTO barber_services (barber_id, service_id)
SELECT b.id, s.id FROM barbers b, services s WHERE b.name = 'Nacho';

-- Horario laboral: Lunes a Viernes 09:00-15:00
INSERT INTO working_hours (barber_id, day_of_week, start_time, end_time, is_working)
SELECT b.id, d.day, '09:00'::TIME, '15:00'::TIME, true
FROM barbers b, (VALUES (0),(1),(2),(3),(4)) AS d(day)
WHERE b.name = 'Nacho';

-- Sábado y Domingo cerrado
INSERT INTO working_hours (barber_id, day_of_week, start_time, end_time, is_working)
SELECT b.id, d.day, '09:00'::TIME, '15:00'::TIME, false
FROM barbers b, (VALUES (5),(6)) AS d(day)
WHERE b.name = 'Nacho';

-- Configuración general
INSERT INTO settings (key, value) VALUES
('business_name', '"Tito''s Barber Shop"'),
('business_phone', '""'),
('business_email', '""'),
('business_address', '""'),
('slot_interval', '15'),
('allow_online_booking', 'true');

-- ============================================
-- ¡LISTO! La base de datos está configurada.
-- ============================================


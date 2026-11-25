-- Migration: Scheduled working hours by date range
-- Adds future schedule programs without replacing weekly default hours.

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
  CONSTRAINT schedule_program_hours_unique_day UNIQUE (program_id, day_of_week),
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

CREATE INDEX IF NOT EXISTS idx_schedule_programs_barber ON schedule_programs(barber_id);
CREATE INDEX IF NOT EXISTS idx_schedule_programs_period ON schedule_programs(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_schedule_program_hours_program ON schedule_program_hours(program_id);

ALTER TABLE schedule_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_program_hours ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all on schedule_programs" ON schedule_programs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on schedule_program_hours" ON schedule_program_hours FOR ALL USING (true) WITH CHECK (true);

CREATE TRIGGER update_schedule_programs_updated_at
  BEFORE UPDATE ON schedule_programs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_schedule_program_hours_updated_at
  BEFORE UPDATE ON schedule_program_hours
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_schedule_program_period_trigger ON schedule_programs;
CREATE TRIGGER validate_schedule_program_period_trigger
  BEFORE INSERT OR UPDATE ON schedule_programs
  FOR EACH ROW
  EXECUTE FUNCTION validate_schedule_program_period();


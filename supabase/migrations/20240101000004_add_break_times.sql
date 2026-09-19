-- Add break times to working_hours table
ALTER TABLE working_hours
ADD COLUMN break_start_time TIME,
ADD COLUMN break_end_time TIME;

-- Add comment for clarity
COMMENT ON COLUMN working_hours.break_start_time IS 'Start time of break (lunch, etc.). NULL means no break.';
COMMENT ON COLUMN working_hours.break_end_time IS 'End time of break. Both break columns must be NULL or both must have values.';


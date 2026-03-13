-- Add device_id column: SHA-256 hash (first 12 chars) of device info.
-- Stable per device, privacy-friendly. Allows filtering logs by device.
ALTER TABLE app_logs ADD COLUMN IF NOT EXISTS device_id text;

CREATE INDEX idx_app_logs_device_id ON app_logs (device_id);

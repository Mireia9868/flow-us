CREATE TABLE IF NOT EXISTS pilot_events (
  event_id TEXT PRIMARY KEY NOT NULL,
  visitor_id TEXT NOT NULL,
  cohort TEXT NOT NULL,
  event TEXT NOT NULL,
  occurred_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS pilot_events_cohort_time ON pilot_events (cohort, occurred_at);

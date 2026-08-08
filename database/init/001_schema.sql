CREATE TABLE IF NOT EXISTS sensors (
    sensor_id       VARCHAR(64) PRIMARY KEY,
    name            VARCHAR(128) NOT NULL,
    location        VARCHAR(128),
    sensor_type     VARCHAR(64) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sensor_metrics (
    metric_id               BIGSERIAL PRIMARY KEY,
    sensor_id               VARCHAR(64) NOT NULL,
    window_start            TIMESTAMPTZ NOT NULL,
    window_end              TIMESTAMPTZ NOT NULL,
    avg_temperature_c       NUMERIC(7, 2),
    max_temperature_c       NUMERIC(7, 2),
    avg_vibration_rms       NUMERIC(10, 4),
    avg_rpm                 NUMERIC(10, 2),
    health_score            NUMERIC(5, 2),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_sensor_metrics_sensor
        FOREIGN KEY (sensor_id)
        REFERENCES sensors(sensor_id),

    CONSTRAINT chk_metric_window
        CHECK (window_end > window_start),

    CONSTRAINT chk_health_score
        CHECK (
            health_score IS NULL
            OR health_score BETWEEN 0 AND 100
        ),

    CONSTRAINT uq_sensor_metric_window
        UNIQUE (sensor_id, window_start, window_end)
);

CREATE TABLE IF NOT EXISTS alerts (
    alert_id            BIGSERIAL PRIMARY KEY,
    sensor_id           VARCHAR(64) NOT NULL,
    event_time          TIMESTAMPTZ NOT NULL,
    alert_type          VARCHAR(64) NOT NULL,
    severity            VARCHAR(16) NOT NULL,
    message             TEXT,
    observed_value      NUMERIC(12, 4),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_alert_sensor
        FOREIGN KEY (sensor_id)
        REFERENCES sensors(sensor_id),

    CONSTRAINT chk_alert_severity
        CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL'))
);

CREATE INDEX IF NOT EXISTS idx_sensor_metrics_sensor_time
    ON sensor_metrics(sensor_id, window_start DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_sensor_time
    ON alerts(sensor_id, event_time DESC);

INSERT INTO sensors (
    sensor_id,
    name,
    location,
    sensor_type
)
VALUES
    ('motor-01', 'Motor 01', 'Line A', 'motor'),
    ('motor-02', 'Motor 02', 'Line A', 'motor'),
    ('motor-03', 'Motor 03', 'Line B', 'motor')
ON CONFLICT (sensor_id) DO NOTHING;
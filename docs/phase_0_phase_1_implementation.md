# Phase 0 and Phase 1 Implementation Guide - Ubuntu 26.04 Baseline

## Project: Real-Time Sensor Analytics Platform

This document implements the first two phases of the project:

- **Phase 0 - Project bootstrap and local development conventions**
- **Phase 1 - PostgreSQL running in Docker with persistent storage and an initial relational schema**

At the end of Phase 1, Kafka and Spark are **not** running yet. The goal is to establish a clean project structure and learn the Docker/PostgreSQL fundamentals independently before adding distributed-system components.


## Environment baseline and version policy

This guide is aligned to the development machine used for the project:

| Component | Version / platform |
|---|---|
| Host OS | Ubuntu 26.04 LTS (Resolute), Linux amd64 |
| Python | 3.14.4 |
| Docker Engine | 29.7.2 |
| Docker Compose | 5.4.0 |
| Git | 2.53.0 |
| PostgreSQL | 18.4 |
| PostgreSQL container | `postgres:18.4-bookworm` |

Version policy for this project:

1. Prefer stable versions available for Ubuntu 26.04 when a tool is installed directly on the host.
2. For containerized infrastructure, use official container images and explicitly pin the version used by the project.
3. Do not use preview/beta releases for the main learning environment unless a later phase explicitly needs them.
4. Do not use an unqualified `latest` container tag in the project configuration. An explicit tag makes the environment easier to reproduce and reason about.
5. Python project dependencies introduced in later phases should live in a virtual environment and be selected for compatibility with Python 3.14.4.

As of this guide revision, PostgreSQL 18.4 is the current stable PostgreSQL release. PostgreSQL 19 is still a development/beta release. Ubuntu 26.04 also provides PostgreSQL 18.4 packages. Although PostgreSQL could therefore be installed directly with `apt`, this project intentionally runs it in Docker so that the database lifecycle, networking, volumes, and service isolation are part of the exercise.

The PostgreSQL container is Debian-based (`bookworm`). This does not conflict with the Ubuntu 26.04 host: containers provide their own userspace and dependencies while sharing the host Linux kernel.

Later phases will select Kafka and Spark versions using the same rule: current stable releases first, then compatibility verification with the host architecture and Python version before pinning them in the project.

References:

- PostgreSQL 18.4 release notes: https://www.postgresql.org/docs/18/release-18-4.html
- Ubuntu 26.04 PostgreSQL 18 package: https://packages.ubuntu.com/resolute/postgresql-18
- PostgreSQL Docker Official Image: https://hub.docker.com/_/postgres
- PySpark installation requirements: https://spark.apache.org/docs/latest/api/python/getting_started/install.html

---

# 1. Target architecture after Phase 1

At this point, the system is intentionally small:

```text
Host machine
│
├── Git repository
│   ├── compose.yaml
│   ├── .env
│   └── database/
│       └── init/
│           └── 001_schema.sql
│
└── Docker
    │
    └── PostgreSQL container
         │
         └── PostgreSQL data volume
```

The important Docker concepts introduced are:

- image
- container
- Docker Compose
- environment variables
- port mapping
- volume
- container lifecycle
- health checks
- container logs
- executing commands inside a container

The important PostgreSQL concepts introduced are:

- database
- schema
- tables
- primary keys
- foreign keys
- constraints
- indexes
- SQL queries
- persistent database storage

---

# 2. Phase 0 - Project bootstrap

## 2.1 Goal

Create a clean repository and establish the conventions that later phases will use.

Phase 0 should not contain Kafka, Spark, application APIs, or frontend code yet.

## 2.2 Prerequisites and Docker access

The required host tools are already installed. Verify the expected baseline:

```bash
python3 --version
git --version
docker version
docker compose version
```

The current machine reports a Docker socket permission error similar to:

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

This means the Docker CLI is installed, but the current user cannot access the Docker daemon socket. Resolve this before starting Phase 1.

First check that the daemon itself is running:

```bash
sudo systemctl status docker
```

If it is not running:

```bash
sudo systemctl start docker
```

Then verify that Docker works with elevated privileges:

```bash
sudo docker info
```

If that succeeds, configure the normal development user to use Docker without `sudo`:

```bash
getent group docker || sudo groupadd docker
sudo usermod -aG docker "$USER"
```

Group membership is normally applied after logging out and back in. For the current shell, you can instead start a shell with the new group immediately:

```bash
newgrp docker
```

Now verify:

```bash
docker info
docker run --rm hello-world
```

Both commands should succeed without `sudo` before continuing.

> Security note: membership in the `docker` group effectively grants root-level privileges through the Docker daemon. This is the standard Docker Engine development setup, but it is important to understand the security implication. Docker rootless mode is an alternative, but this guide uses the normal Docker daemon plus `docker` group to keep the learning environment straightforward.

Official reference: https://docs.docker.com/engine/install/linux-postinstall/

## 2.3 Create the repository

```bash
mkdir spark-sensor-platform
cd spark-sensor-platform

git init
```

Create the initial directory structure:

```bash
mkdir -p database/init
mkdir -p producer
mkdir -p spark
mkdir -p backend
mkdir -p docs
```

The repository should now look like:

```text
spark-sensor-platform/
├── backend/
├── database/
│   └── init/
├── docs/
├── producer/
└── spark/
```

The directories are created now so that the future architecture is visible, but only `database/` is implemented in Phase 1.

## 2.4 Create `.gitignore`

Create `.gitignore`:

```gitignore
# Local environment configuration
.env

# Python
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/

# IDE/editor
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db

# Logs
*.log

# Spark local/checkpoint output used in development
.checkpoints/
spark-warehouse/

# Local data exports
*.parquet
*.csv
```

The important rule is that `.env` is not committed because it may eventually contain credentials or environment-specific configuration.

## 2.5 Create `.env.example`

Create `.env.example`:

```dotenv
POSTGRES_DB=sensor_platform
POSTGRES_USER=sensor_app
POSTGRES_PASSWORD=sensor_app_dev_password
POSTGRES_PORT=5432
```

Then create the local file:

```bash
cp .env.example .env
```

The intended convention is:

```text
.env.example
    committed to Git
    documents required configuration

.env
    local configuration
    ignored by Git
```

For this learning project the password is deliberately simple. It must not be reused for a real or internet-accessible system.

## 2.6 Create a minimal README

Create `README.md`:

```markdown
# Spark Sensor Platform

Learning project using:

- Apache Kafka
- Apache Spark
- Docker
- PostgreSQL

The system will simulate sensor telemetry, publish it through Kafka,
process it with Spark Structured Streaming, and persist derived metrics
and alerts in PostgreSQL.
```

## 2.7 Phase 0 acceptance criteria

Phase 0 is complete when:

```text
[ ] Git repository exists
[ ] Docker daemon is running
[ ] Docker commands work without `sudo`
[ ] `docker run --rm hello-world` succeeds
[ ] Docker Compose command works
[ ] Repository directories exist
[ ] .gitignore exists
[ ] .env.example exists
[ ] local .env exists and is ignored by Git
[ ] README.md exists
```

Useful verification:

```bash
git status
```

`.env` should not appear as an untracked file.

Create the first commit:

```bash
git add .
git commit -m "chore: bootstrap project structure"
```

---

# 3. Phase 1 - PostgreSQL with Docker

## 3.1 Goal

Run PostgreSQL in a Docker container and persist its database files in a Docker volume.

The architecture becomes:

```text
Host
│
│ localhost:5432
│
▼
Docker port mapping
│
▼
PostgreSQL container
│
▼
postgres_data volume
```

This phase deliberately uses a single service so that Docker concepts can be understood before Kafka and Spark add networking complexity.

---

# 4. Create `compose.yaml`

At the repository root, create `compose.yaml`:

```yaml
services:
  postgres:
    image: postgres:18.4-bookworm
    restart: unless-stopped

    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

    ports:
      - "${POSTGRES_PORT}:5432"

    volumes:
      - postgres_data:/var/lib/postgresql
      - ./database/init:/docker-entrypoint-initdb.d:ro

    healthcheck:
      test:
        [
          "CMD-SHELL",
          "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
        ]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 5s

volumes:
  postgres_data:
```

## 4.1 What this file means

### `services`

A Compose project contains one or more services.

```yaml
services:
  postgres:
```

`postgres` is the service name. Later, other containers on the same Compose network will be able to use `postgres` as a hostname.

For example, a future Spark container will connect to:

```text
postgres:5432
```

not:

```text
localhost:5432
```

Inside a container, `localhost` means that container itself.

### `image`

```yaml
image: postgres:18.4-bookworm
```

This tells Docker to create the container from the PostgreSQL image.

Conceptually:

```text
Docker image
    ↓
container instance
```

We explicitly use `postgres:18.4-bookworm`. PostgreSQL 18.4 is the current stable PostgreSQL release and the version provided by Ubuntu 26.04 updates. The exact image tag also makes this learning environment reproducible.

When upgrading PostgreSQL later, we will change this tag deliberately and treat a major-version upgrade as a database migration task rather than allowing it to happen implicitly.

### `environment`

```yaml
environment:
  POSTGRES_DB: ${POSTGRES_DB}
```

Compose reads the values from `.env`.

The PostgreSQL image uses these variables during the initial database creation.

### `ports`

```yaml
ports:
  - "${POSTGRES_PORT}:5432"
```

This means:

```text
host port            container port
   5432      --->        5432
```

From the host machine:

```text
localhost:5432
```

reaches PostgreSQL inside the container.

Other Docker services do not need this host port mapping to communicate with PostgreSQL; they will eventually use Docker's internal network.

### `volumes`

```yaml
- postgres_data:/var/lib/postgresql
```

For PostgreSQL 18 and newer, the official Docker image changed its storage layout. The image's default `PGDATA` for PostgreSQL 18 is `/var/lib/postgresql/18/docker`, and the recommended volume mount point is now `/var/lib/postgresql`.

Therefore the project mounts the named volume at:

```text
/var/lib/postgresql
```

not the older PostgreSQL 17-and-earlier path `/var/lib/postgresql/data`. This version-specific change is important because using an old mount pattern with PostgreSQL 18 can result in the database files not being stored where you expect.

The named volume separates the persistent data from the container lifecycle:

```text
PostgreSQL container
       │
       ▼
postgres_data
```

The container can be replaced while the database survives.

The second mount:

```yaml
- ./database/init:/docker-entrypoint-initdb.d:ro
```

makes initialization SQL available inside the PostgreSQL container.

`ro` means read-only.

### `healthcheck`

The health check runs:

```bash
pg_isready
```

Docker can therefore distinguish between:

```text
container process is running
```

and:

```text
PostgreSQL is ready to accept database connections
```

This distinction becomes important when Kafka, Spark, and backend services are added later.

---

# 5. Create the initial PostgreSQL schema

Create:

```text
database/init/001_schema.sql
```

with the following content:

```sql
CREATE TABLE IF NOT EXISTS sensors (
    sensor_id       VARCHAR(64) PRIMARY KEY,
    name            VARCHAR(128) NOT NULL,
    location        VARCHAR(128),
    sensor_type     VARCHAR(64) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sensor_metrics (
    metric_id           BIGSERIAL PRIMARY KEY,
    sensor_id           VARCHAR(64) NOT NULL,
    window_start        TIMESTAMPTZ NOT NULL,
    window_end          TIMESTAMPTZ NOT NULL,
    avg_temperature_c   NUMERIC(7, 2),
    max_temperature_c   NUMERIC(7, 2),
    avg_vibration_rms   NUMERIC(10, 4),
    avg_rpm             NUMERIC(10, 2),
    health_score        NUMERIC(5, 2),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

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
    alert_id         BIGSERIAL PRIMARY KEY,
    sensor_id        VARCHAR(64) NOT NULL,
    event_time       TIMESTAMPTZ NOT NULL,
    alert_type       VARCHAR(64) NOT NULL,
    severity         VARCHAR(16) NOT NULL,
    message          TEXT,
    observed_value   NUMERIC(12, 4),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

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
```

---

# 6. Why this database model exists

The relationships are:

```text
                 sensors
                    │
              sensor_id (PK)
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
   sensor_metrics           alerts
   sensor_id (FK)        sensor_id (FK)
```

## `sensors`

Contains relatively static sensor metadata.

Example:

```text
motor-03
Motor 03
Line B
motor
```

## `sensor_metrics`

Contains the windowed metrics that Spark will eventually calculate.

For example:

```text
sensor_id:         motor-03
window_start:      10:00:00
window_end:        10:00:10
avg_temperature:   71.8
avg_vibration:     1.42
avg_rpm:           1794
health_score:      94
```

## `alerts`

Contains exceptional conditions detected by the processing pipeline.

For example:

```text
sensor_id:       motor-03
alert_type:      HIGH_TEMPERATURE
severity:        WARNING
observed_value:  96.7
```

This separation lets us learn normalization and relational integrity rather than putting everything into one table.

---

# 7. Validate the Compose configuration

Before starting anything:

```bash
docker compose config
```

This expands environment variables and validates the Compose file.

Do this frequently while learning Docker Compose.

---

# 8. Start PostgreSQL

Run:

```bash
docker compose up -d postgres
```

Explanation:

```text
docker compose
    use the Compose project

up
    create/start required resources

-d
    detached mode

postgres
    start only the postgres service
```

Check the service:

```bash
docker compose ps
```

You should eventually see the PostgreSQL service reported as healthy.


Verify the PostgreSQL version running inside the container:

```bash
docker compose exec postgres postgres --version
```

Expected major/minor version for this guide:

```text
postgres (PostgreSQL) 18.4
```

---

# 9. Inspect Docker state

## 9.1 List containers

```bash
docker ps
```

## 9.2 Read PostgreSQL logs

```bash
docker compose logs postgres
```

Follow logs interactively:

```bash
docker compose logs -f postgres
```

Stop following with `Ctrl+C`.

## 9.3 Inspect volumes

```bash
docker volume ls
```

Compose normally prefixes the volume name with the Compose project name.

Inspect a specific volume if desired:

```bash
docker volume inspect <volume-name>
```

---

# 10. Connect to PostgreSQL

For this phase, use the `psql` client already installed inside the PostgreSQL container.

```bash
docker compose exec postgres \
  psql -U sensor_app -d sensor_platform
```

This teaches another important Docker operation:

```text
docker compose exec
```

means:

```text
execute a command inside an already-running service container
```

You should now have a PostgreSQL prompt similar to:

```text
sensor_platform=#
```

---

# 11. First SQL exercises

Inside `psql`, list tables:

```sql
\dt
```

Describe `sensors`:

```sql
\d sensors
```

Read the initial sensors:

```sql
SELECT *
FROM sensors
ORDER BY sensor_id;
```

Insert another sensor:

```sql
INSERT INTO sensors (
    sensor_id,
    name,
    location,
    sensor_type
)
VALUES (
    'motor-04',
    'Motor 04',
    'Line B',
    'motor'
);
```

Query it:

```sql
SELECT sensor_id, name, location
FROM sensors
WHERE sensor_id = 'motor-04';
```

Exit `psql`:

```text
\q
```

---

# 12. Test persistence

Persistence is one of the most important experiments in Phase 1.

First confirm that `motor-04` exists.

Then stop the service:

```bash
docker compose down
```

Check:

```bash
docker ps
```

The PostgreSQL container should no longer be running.

Start it again:

```bash
docker compose up -d postgres
```

Reconnect:

```bash
docker compose exec postgres \
  psql -U sensor_app -d sensor_platform
```

Then run:

```sql
SELECT *
FROM sensors
WHERE sensor_id = 'motor-04';
```

The row should still exist.

This demonstrates:

```text
container lifecycle != data lifecycle
```

because `postgres_data` survived the container recreation.

---

# 13. Important initialization behavior

Files under:

```text
/docker-entrypoint-initdb.d
```

are executed by the official PostgreSQL container initialization process only when the PostgreSQL data directory is empty.

Therefore, if you change:

```text
database/init/001_schema.sql
```

after PostgreSQL has already initialized its volume, simply restarting the container will not rerun the script.

For normal development, schema changes should eventually use migrations.

For these first learning phases, you can deliberately reset the database with:

```bash
docker compose down -v
```

and then:

```bash
docker compose up -d postgres
```

**Warning:** `docker compose down -v` deletes the Compose project's named volumes. In this project that means deleting the PostgreSQL database data.

Use it only when you intentionally want a clean database.

---

# 14. Useful Docker lifecycle commands

Start/create services:

```bash
docker compose up -d
```

See service state:

```bash
docker compose ps
```

See logs:

```bash
docker compose logs
```

Stop services without deleting containers:

```bash
docker compose stop
```

Start stopped services:

```bash
docker compose start
```

Stop and remove Compose containers/networks:

```bash
docker compose down
```

Stop, remove containers, and delete named volumes:

```bash
docker compose down -v
```

Run a command inside PostgreSQL:

```bash
docker compose exec postgres <command>
```

Inspect all running Docker containers:

```bash
docker ps
```

---

# 15. Experiments to perform before Phase 2

Do not only run the commands once. Modify the system and observe what Docker/PostgreSQL do.

## Experiment A - Container recreation

```bash
docker compose down
docker compose up -d
```

Confirm that your SQL data survives.

## Experiment B - Volume deletion

After intentionally creating test data:

```bash
docker compose down -v
docker compose up -d
```

Confirm that the database is initialized from `001_schema.sql` again and manually inserted data is gone.

## Experiment C - Change the host port

Change `.env`:

```dotenv
POSTGRES_PORT=5433
```

Recreate the service:

```bash
docker compose down
docker compose up -d postgres
```

Conceptually:

```text
host localhost:5433
        ↓
container postgres:5432
```

The PostgreSQL process inside the container did not change ports; only the host-to-container mapping changed.

Restore the original port afterward if desired.

## Experiment D - Constraint violation

Try inserting an invalid alert severity:

```sql
INSERT INTO alerts (
    sensor_id,
    event_time,
    alert_type,
    severity
)
VALUES (
    'motor-01',
    NOW(),
    'TEST_ALERT',
    'INVALID'
);
```

PostgreSQL should reject it because of:

```sql
CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL'))
```

This demonstrates that data integrity rules belong in the database as well as in application code.

## Experiment E - Foreign-key violation

Try:

```sql
INSERT INTO alerts (
    sensor_id,
    event_time,
    alert_type,
    severity
)
VALUES (
    'does-not-exist',
    NOW(),
    'TEST_ALERT',
    'WARNING'
);
```

PostgreSQL should reject it because `sensor_id` must exist in `sensors`.

---

# 16. Phase 1 acceptance criteria

Phase 1 is complete when all of the following are true:

```text
[ ] `docker compose config` succeeds
[ ] PostgreSQL starts successfully
[ ] PostgreSQL reports version 18.4
[ ] PostgreSQL becomes healthy
[ ] PostgreSQL is reachable through `docker compose exec`
[ ] `sensors`, `sensor_metrics`, and `alerts` exist
[ ] the initial three sensors exist
[ ] primary-key behavior has been observed
[ ] foreign-key behavior has been observed
[ ] CHECK constraints have been observed
[ ] indexes exist
[ ] the PostgreSQL volume is mounted at `/var/lib/postgresql`
[ ] data survives `docker compose down` + `up`
[ ] data disappears after an intentional `docker compose down -v`
[ ] the difference between host port and container port is understood
[ ] the difference between a container and a volume is understood
```

Then commit Phase 1:

```bash
git add .
git commit -m "feat: add PostgreSQL development environment"
```

---

# 17. Expected repository after Phase 1

```text
spark-sensor-platform/
├── .env                 # local only; ignored by Git
├── .env.example
├── .gitignore
├── README.md
├── compose.yaml
│
├── backend/
│
├── database/
│   └── init/
│       └── 001_schema.sql
│
├── docs/
│   └── phase_0_phase_1_implementation.md
│
├── producer/
│
└── spark/
```

---

# 18. What not to add yet

Avoid introducing the following during these phases:

```text
Kafka
Spark
FastAPI
Vue
Kubernetes
PostgreSQL GUI tools
ORMs
migration frameworks
cloud services
```

They are useful later, but adding them now would hide the fundamental concepts being learned.

For Phase 1, using `psql` directly is preferable because it exposes SQL and PostgreSQL behavior without another abstraction layer.

---

# 19. What Phase 2 will add

The next phase should introduce Kafka as a second Docker service.

The architecture will evolve from:

```text
PostgreSQL
```

to:

```text
Python producer
      │
      ▼
    Kafka

PostgreSQL
```

At first Kafka and PostgreSQL will be independent. The purpose will be to learn Kafka topics, partitions, producers, consumers, offsets, and Docker networking before Spark connects the two parts of the system.

Only after Kafka itself is understood should the pipeline become:

```text
Producer
   ↓
Kafka
   ↓
Spark
   ↓
PostgreSQL
```

---

# 20. Core concepts you should be able to explain after Phase 1

Before moving on, make sure you can answer these without memorizing commands:

1. What is the difference between a Docker image and a container?
2. What does Docker Compose provide?
3. Why is PostgreSQL running in a container instead of being installed directly on the host?
4. What is a Docker volume?
5. Why does PostgreSQL data survive when the container is removed?
6. What does `5432:5432` mean?
7. What is the difference between `localhost:5432` and `postgres:5432`?
8. What is a Docker health check?
9. What is a PostgreSQL primary key?
10. What is a foreign key?
11. What is a database constraint?
12. Why were indexes created on `(sensor_id, time)` columns?
13. Why are initialization scripts not a replacement for database migrations?
14. What is destroyed by `docker compose down`?
15. What additional resource is destroyed by `docker compose down -v`?

If these concepts are clear, Phase 2 can add Kafka without turning the project into a collection of unexplained configuration files.

# Phase 2 — Apache Kafka Infrastructure and Fundamentals

This phase adds Apache Kafka to the existing Docker Compose environment and establishes the event-streaming layer that will later connect the sensor producer to Apache Spark.

At the end of this phase, the system will be:

```text
Ubuntu host
│
│  localhost:9092
│
└──────────────► Kafka container
                    │
                    │ kafka:29092
                    │ (Docker network)
                    │
                    ├── future Producer container
                    └── future Spark container

PostgreSQL continues running independently in the same Compose project.
```

No Python Kafka producer and no Spark application are added yet.

The goal of Phase 2 is to understand Kafka itself before programming against it.

---

## 2.0 Environment and version baseline

This project currently uses:

```text
Host OS:          Ubuntu 26.04 LTS
Architecture:     linux/amd64
Docker Engine:    29.7.2
Docker Compose:   5.4.0
Git:              2.53.0
Python:           3.14.4
PostgreSQL:       18.4
Apache Kafka:     4.3.1
```

Use the official JVM-based Apache Kafka image:

```text
apache/kafka:4.3.1
```

Do not use `latest` in the project Compose file. Pinning the version makes the development environment reproducible.

Kafka 4.x uses KRaft mode; ZooKeeper is not part of this project.

The Kafka Docker image contains the Java runtime required by Kafka, so Java does not need to be installed on the Ubuntu host merely to run this Kafka container.

---

## 2.1 Learning objectives

By the end of Phase 2, you should be able to explain:

- what a Kafka broker is;
- what a Kafka controller is;
- what KRaft is;
- why our development node has both `broker` and `controller` roles;
- what a topic is;
- what a partition is;
- what an offset is;
- what a producer does;
- what a consumer does;
- what a consumer group is;
- why ordering is defined per partition rather than globally across a topic;
- what a replication factor means;
- why a one-broker cluster can only use replication factor 1;
- the difference between `listeners` and `advertised.listeners`;
- why Kafka needs one address for the Ubuntu host and another for Docker containers;
- what the Kafka named volume persists;
- how to inspect topics and consumer groups with Kafka CLI tools.

---

## 2.2 Kafka mental model

For this phase, think of Kafka as a durable distributed event log.

```text
Producer
    │
    ▼
Kafka topic
    │
    ▼
Consumer
```

The future project flow will be:

```text
Sensor producer
      │
      ▼
sensor_raw topic
      │
      ▼
Apache Spark
      │
      ├──► PostgreSQL
      └──► sensor_alerts topic
```

Kafka and PostgreSQL have different roles:

```text
Kafka
    event streams
    event transport
    durable event log

PostgreSQL
    relational persistent state
    tables
    constraints
    SQL queries
```

---

## 2.3 Broker and controller

A Kafka **broker** handles event data:

```text
producer
   │
   ▼
broker
   │
   ├── stores records
   ├── serves consumers
   └── hosts topic partitions
```

A Kafka **controller** manages cluster metadata and coordination:

```text
Which brokers exist?
Which topics exist?
Which partitions exist?
Where are partitions located?
Which broker leads each partition?
```

For this development project we use one Kafka process with both roles:

```text
one Kafka node
      │
      ├── broker
      └── controller
```

This is called **combined mode**. It is appropriate for a small development environment, but not the architecture normally chosen for a fault-tolerant production cluster.

---

## 2.4 KRaft and why there is no ZooKeeper

Older Kafka deployments used Apache ZooKeeper for cluster metadata and coordination.

Modern Kafka uses KRaft. Kafka 4.x no longer supports ZooKeeper mode.

For our single-node development cluster:

```text
Kafka node 1
│
├── Controller
│     └── metadata management
│
└── Broker
      └── event storage and client requests
```

The relevant configuration is:

```yaml
KAFKA_NODE_ID: 1
KAFKA_PROCESS_ROLES: broker,controller
```

---

## 2.5 Start Phase 2 with the GitHub workflow

Phase 0.5 established that normal work should not be performed directly on `main`.

Synchronize:

```bash
git switch main
git pull --ff-only
```

Create a feature branch:

```bash
git switch -c feat/kafka-infrastructure
```

Verify:

```bash
git branch --show-current
```

Expected:

```text
feat/kafka-infrastructure
```

Optionally create a GitHub Issue first:

```text
Add Kafka development infrastructure
```

The eventual PR can contain:

```text
Closes #<issue-number>
```

---

## 2.6 Update `.env`

Add:

```dotenv
KAFKA_VERSION=4.3.1
KAFKA_HOST_PORT=9092
```

For example:

```dotenv
POSTGRES_DB=sensor_platform
POSTGRES_USER=sensor_app
POSTGRES_PASSWORD=sensor_app_dev_password
POSTGRES_PORT=5432

KAFKA_VERSION=4.3.1
KAFKA_HOST_PORT=9092
```

If the project contains `.env.example`, add the Kafka settings there too.

Do not commit the real `.env` if it contains credentials.

---

## 2.7 Add Kafka to `compose.yaml`

Keep the existing PostgreSQL service and add this Kafka service:

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
      - "127.0.0.1:${POSTGRES_PORT}:5432"

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

  kafka:
    image: apache/kafka:${KAFKA_VERSION}
    restart: unless-stopped

    ports:
      - "127.0.0.1:${KAFKA_HOST_PORT}:9092"

    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller

      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: >-
        CONTROLLER:PLAINTEXT,
        INTERNAL:PLAINTEXT,
        HOST:PLAINTEXT

      KAFKA_LISTENERS: >-
        CONTROLLER://:9093,
        INTERNAL://:29092,
        HOST://:9092

      KAFKA_ADVERTISED_LISTENERS: >-
        INTERNAL://kafka:29092,
        HOST://localhost:${KAFKA_HOST_PORT}

      KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093

      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR: 1

      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"

      KAFKA_LOG_DIRS: /tmp/kraft-combined-logs
      CLUSTER_ID: 4L6g3nShT-eMCtK--X86sw

    volumes:
      - kafka_data:/tmp/kraft-combined-logs

    healthcheck:
      test:
        [
          "CMD-SHELL",
          "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >/dev/null 2>&1"
        ]
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 10s

volumes:
  postgres_data:
  kafka_data:
```

Before starting anything:

```bash
docker compose config
```

Then:

```bash
docker compose config --services
```

Expected:

```text
postgres
kafka
```

And:

```bash
docker compose config --volumes
```

Expected to include:

```text
postgres_data
kafka_data
```

---

## 2.8 Understand the important Compose fields

### Image

```yaml
image: apache/kafka:${KAFKA_VERSION}
```

With `KAFKA_VERSION=4.3.1`, Compose resolves this to:

```yaml
image: apache/kafka:4.3.1
```

### Port publishing

```yaml
ports:
  - "127.0.0.1:${KAFKA_HOST_PORT}:9092"
```

With `KAFKA_HOST_PORT=9092`:

```text
Ubuntu host                 Kafka container

127.0.0.1:9092 ───────────► port 9092
```

The host port is on the left; the container port is on the right.

### Node ID

```yaml
KAFKA_NODE_ID: 1
```

Every KRaft node has its own node ID.

### Process roles

```yaml
KAFKA_PROCESS_ROLES: broker,controller
```

This single process is both a broker and controller.

---

## 2.9 The most important Kafka-in-Docker concept: listeners

Kafka networking is more subtle than an ordinary HTTP server.

Two settings matter:

```text
listeners
advertised.listeners
```

`listeners` tells Kafka where to listen.

Our configuration is:

```yaml
KAFKA_LISTENERS: >-
  CONTROLLER://:9093,
  INTERNAL://:29092,
  HOST://:9092
```

Kafka listens on:

```text
CONTROLLER → 9093
INTERNAL   → 29092
HOST       → 9092
```

`advertised.listeners` tells clients which addresses they should use after the bootstrap connection.

```yaml
KAFKA_ADVERTISED_LISTENERS: >-
  INTERNAL://kafka:29092,
  HOST://localhost:${KAFKA_HOST_PORT}
```

This gives two client views of the same broker.

### Client on Ubuntu

Future Python code running directly on Ubuntu will use:

```text
localhost:9092
```

### Client inside Docker Compose

A future Spark container will use:

```text
kafka:29092
```

The service name:

```yaml
services:
  kafka:
```

becomes a DNS name on the Compose network.

Inside a Spark container, `localhost` would mean the Spark container itself, not Kafka.

---

## 2.10 Listener security protocol map

We invented logical listener names:

```text
CONTROLLER
INTERNAL
HOST
```

Kafka must know which protocol each uses:

```yaml
KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: >-
  CONTROLLER:PLAINTEXT,
  INTERNAL:PLAINTEXT,
  HOST:PLAINTEXT
```

For this local phase, all three use `PLAINTEXT`: no TLS and no authentication.

That is acceptable for local development bound to loopback. It is not a production security configuration.

---

## 2.11 Inter-broker and controller listeners

```yaml
KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
```

This designates the internal listener for broker-to-broker communication.

We currently have only one broker, but the configuration is still required.

```yaml
KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
```

This designates the controller communication listener.

The controller listener is not used for ordinary producer/consumer traffic.

---

## 2.12 Controller quorum voters

```yaml
KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
```

Breakdown:

```text
1 @ kafka : 9093
│    │       │
│    │       └── controller port
│    └────────── Compose hostname
└─────────────── node ID
```

Our development controller quorum has one node.

---

## 2.13 Why several replication settings are `1`

Our cluster contains one broker.

Kafka has internal topics for consumer offsets, transactions, and other state. Defaults may assume multiple brokers, so we explicitly configure single-node-compatible values:

```yaml
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR: 1
KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR: 1
```

These values are for this development cluster, not a production availability design.

---

## 2.14 Disable automatic topic creation

```yaml
KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
```

We want topic creation to be explicit so that we deliberately choose:

```text
topic name
partition count
replication factor
```

This makes Kafka behavior easier to understand.

---

## 2.15 Kafka data volume

```yaml
volumes:
  - kafka_data:/tmp/kraft-combined-logs
```

with:

```yaml
KAFKA_LOG_DIRS: /tmp/kraft-combined-logs
```

means:

```text
Kafka container
│
│ /tmp/kraft-combined-logs
│
└──────────────► Docker named volume
                  kafka_data
```

`kafka_data` is a name chosen by us.

The container path is the location we configured Kafka to use for its persistent log data.

---

## 2.16 Cluster ID

```yaml
CLUSTER_ID: 4L6g3nShT-eMCtK--X86sw
```

A KRaft cluster has a cluster ID.

For this project, use a fixed development cluster ID. Do not randomly change it after the Kafka volume has been initialized.

---

## 2.17 Kafka health check

```yaml
healthcheck:
  test:
    [
      "CMD-SHELL",
      "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >/dev/null 2>&1"
    ]
```

This checks whether the broker responds to a Kafka client operation.

The distinction is:

```text
container running
        ≠
Kafka ready
```

Inspect health with:

```bash
docker compose ps
```

---

## 2.18 Start Kafka

Pull the image:

```bash
docker compose pull kafka
```

Inspect it:

```bash
docker images apache/kafka
```

Start the environment:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

Inspect logs:

```bash
docker compose logs kafka
```

Follow them live if needed:

```bash
docker compose logs -f kafka
```

`Ctrl-C` stops following logs; it does not stop the Kafka container.

---

## 2.19 Inspect the Kafka container

Open a shell:

```bash
docker compose exec kafka bash
```

Then inspect:

```bash
hostname
ls /opt/kafka/bin
echo "$KAFKA_LOG_DIRS"
ls -la /tmp/kraft-combined-logs
```

Exit:

```bash
exit
```

---

## 2.20 Verify internal Kafka connectivity

Run:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-broker-api-versions.sh   --bootstrap-server kafka:29092
```

A successful response confirms that Kafka is reachable through the Docker-network listener.

Notice the endpoint:

```text
kafka:29092
```

---

## 2.21 Create the main topic

Create:

```text
sensor_raw
```

with three partitions:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --create   --topic sensor_raw   --partitions 3   --replication-factor 1
```

The choices are:

```text
Topic:              sensor_raw
Partitions:         3
Replication factor: 1
```

Three partitions are useful for learning partition-based parallelism.

---

## 2.22 Understand replication factor

Replication factor means how many broker copies of each partition Kafka maintains.

Example:

```text
replication factor 3

partition 0
├── broker 1
├── broker 2
└── broker 3
```

Our cluster has only one broker, so replication factor 1 is the only valid choice.

Try this deliberate failure:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --create   --topic invalid-replication-test   --partitions 1   --replication-factor 2
```

Read the error carefully. The failure is the purpose of the experiment.

---

## 2.23 List and describe topics

List:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --list
```

Describe `sensor_raw`:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --describe   --topic sensor_raw
```

Look for:

```text
PartitionCount: 3
ReplicationFactor: 1
```

and partitions 0, 1, and 2.

---

## 2.24 Topic, partition, and offset

A topic is divided into partitions:

```text
sensor_raw

partition 0
0  1  2  3  4 ...

partition 1
0  1  2  3 ...

partition 2
0  1  2  3  4 ...
```

The numbers are offsets.

An offset identifies a record's position within one partition.

Therefore:

```text
topic + partition + offset
```

identifies a Kafka record position.

Example:

```text
sensor_raw / partition 2 / offset 17
```

There is no single topic-wide offset.

---

## 2.25 Ordering guarantee

Kafka preserves order within a partition.

```text
partition 0

offset 0 → A
offset 1 → B
offset 2 → C
```

A consumer sees:

```text
A → B → C
```

There is no single global ordering across separate partitions.

This is why message keys matter.

---

## 2.26 Start a console consumer

Open terminal A:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --from-beginning   --property print.key=true   --property print.partition=true   --property print.offset=true   --property print.timestamp=true
```

Leave it running.

---

## 2.27 Start a console producer

Open terminal B:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-producer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --property parse.key=true   --property key.separator=:
```

Enter:

```text
motor-01:{"sensor_id":"motor-01","temperature_c":72.4}
motor-02:{"sensor_id":"motor-02","temperature_c":68.1}
motor-01:{"sensor_id":"motor-01","temperature_c":73.0}
```

The consumer should display the records.

Stop producer and consumer with `Ctrl-C`.

---

## 2.28 Understand message keys

The producer input:

```text
motor-01:{"sensor_id":"motor-01","temperature_c":72.4}
```

contains:

```text
key
motor-01

value
{"sensor_id":"motor-01","temperature_c":72.4}
```

Using `sensor_id` as the key is intentional.

Kafka can consistently map the same key to the same partition:

```text
motor-01 ──► partition 2
motor-02 ──► partition 0
motor-03 ──► partition 1
motor-01 ──► partition 2
```

The exact partition numbers are not important.

The important property is that records for one sensor can remain together, preserving per-sensor order.

---

## 2.29 Observe partitions and offsets

Run the consumer again with:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --from-beginning   --property print.key=true   --property print.partition=true   --property print.offset=true
```

Produce records with repeated keys and compare their partition numbers.

Offsets increase independently in each partition.

---

## 2.30 Consumer groups

A consumer group represents one logical consuming application.

Create one:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --group phase2-consumer   --from-beginning   --property print.key=true   --property print.partition=true   --property print.offset=true
```

Let it consume records, then stop it.

---

## 2.31 Inspect consumer-group offsets

Run:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-consumer-groups.sh   --bootstrap-server kafka:29092   --describe   --group phase2-consumer
```

Look for:

```text
TOPIC
PARTITION
CURRENT-OFFSET
LOG-END-OFFSET
LAG
```

Conceptually:

```text
LOG-END-OFFSET = 100
CURRENT-OFFSET = 92

LAG = 8
```

Consumer lag is a key streaming-system monitoring concept.

---

## 2.32 Consumer-group restart experiment

Produce more records.

Then restart the same group:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --group phase2-consumer   --property print.key=true   --property print.partition=true   --property print.offset=true
```

The group has stored progress, so it can continue from committed offsets rather than behaving like a completely new consumer.

---

## 2.33 Two consumers in the same group

Because `sensor_raw` has three partitions, use two consumers to observe partition assignment.

Terminal A:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --group parallel-demo   --property print.partition=true   --property print.key=true
```

Terminal B: run the same command.

Produce more events.

Conceptually Kafka may assign:

```text
partition 0 ──► consumer A
partition 1 ──► consumer B
partition 2 ──► consumer A
```

The exact assignment may differ.

Within one consumer group, a partition is assigned to at most one active consumer at a time.

This gives the important relationship:

```text
useful consumers
    ≤
partitions
```

for one topic inside one consumer group.

---

## 2.34 Different groups consume independently

Different consumer groups maintain independent offsets.

```text
                sensor_raw
                /                       /                        ▼            ▼
       group analytics   group audit
       offset = 100      offset = 57
```

One group does not consume records "away" from another group.

Kafka is not simply a destructive queue.

---

## 2.35 Inspect all consumer groups

List groups:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-consumer-groups.sh   --bootstrap-server kafka:29092   --list
```

Describe one:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-consumer-groups.sh   --bootstrap-server kafka:29092   --describe   --group parallel-demo
```

---

## 2.36 Kafka persistence experiment

Ensure `sensor_raw` contains records.

Inspect volumes:

```bash
docker compose volumes
```

or:

```bash
docker volume ls
```

Now:

```bash
docker compose down
```

The containers are removed, but named volumes remain.

Start again:

```bash
docker compose up -d
```

Wait for healthy services:

```bash
docker compose ps
```

Read existing data:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server kafka:29092   --topic sensor_raw   --from-beginning
```

Previously stored records should still exist.

This demonstrates:

```text
container lifecycle
        ≠
data lifecycle
```

---

## 2.37 Warning: `docker compose down -v`

Do not casually run:

```bash
docker compose down -v
```

Your Compose project now has:

```text
postgres_data
kafka_data
```

`-v` removes Compose-managed named volumes and can destroy both PostgreSQL and Kafka data.

If you intentionally want to reset only Kafka:

```bash
docker compose down
docker compose volumes
docker volume rm <actual-kafka-volume-name>
docker compose up -d
```

Inspect the exact volume name before deleting it.

---

## 2.38 Create the future alerts topic

Create:

```text
sensor_alerts
```

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --create   --topic sensor_alerts   --partitions 1   --replication-factor 1
```

List topics:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --list
```

Expected project topics:

```text
sensor_alerts
sensor_raw
```

Kafka internal topics may also exist and commonly begin with `__`.

---

## 2.39 Why different partition counts?

For this learning project:

```text
sensor_raw
    3 partitions

sensor_alerts
    1 partition
```

`sensor_raw` is the high-volume input stream and gives us a meaningful parallelism exercise.

`sensor_alerts` initially has much lower expected throughput.

Partition counts affect:

```text
parallelism
ordering
resource usage
scalability
```

They should be chosen intentionally.

---

## 2.40 Inspect topic configuration

Describe:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --describe   --topic sensor_raw
```

Inspect explicit topic overrides:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-configs.sh   --bootstrap-server kafka:29092   --entity-type topics   --entity-name sensor_raw   --describe
```

Kafka has broker defaults as well as per-topic overrides.

---

## 2.41 Retention concept

Kafka consumption does not normally mean:

```text
read → delete
```

Records remain according to retention policies.

This is why a consumer with:

```text
--from-beginning
```

can reread stored records.

Keep these concepts separate:

```text
consumer progress
    tracked by offsets

record retention
    controlled independently
```

Do not change the project retention policy yet.

---

## 2.42 Inspect the Docker network

Run:

```bash
docker network ls
```

Find the Compose network, normally similar to:

```text
spark-sensor-platform_default
```

Inspect:

```bash
docker network inspect <network-name>
```

You should see both services attached:

```text
postgres
kafka
```

This is why future services can resolve `kafka` and `postgres` through Docker DNS.

---

## 2.43 Host endpoint versus Docker endpoint

Keep this table in mind:

| Client location | Kafka bootstrap address |
|---|---|
| Program running directly on Ubuntu | `localhost:9092` |
| Program running in the Compose network | `kafka:29092` |
| Kafka KRaft controller communication | `kafka:9093` |

Future Python producer on Ubuntu:

```python
bootstrap_servers = "localhost:9092"
```

Future Spark inside Docker:

```text
kafka.bootstrap.servers = kafka:29092
```

---

## 2.44 Validate the complete Phase 2 environment

Run:

```bash
docker compose config
docker compose ps
docker compose images
docker compose logs kafka --tail 100
```

Then:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --list
```

Then:

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --describe   --topic sensor_raw
```

You should be able to explain what each command verifies.

---

## 2.45 Git review before committing

Check:

```bash
git status
git diff
```

Stage deliberately:

```bash
git add compose.yaml .env.example
```

If documentation changed:

```bash
git add docs/
```

Review:

```bash
git diff --staged
```

Verify that the real `.env` has not been staged if it contains credentials.

---

## 2.46 Suggested commits

For example:

```bash
git commit -m "feat(kafka): add single-node KRaft broker"
```

If documentation is separate:

```bash
git commit -m "docs(kafka): document local broker workflow"
```

Inspect:

```bash
git log --oneline --decorate -5
```

---

## 2.47 Push and open the PR

Push:

```bash
git push -u origin feat/kafka-infrastructure
```

Open:

```text
feat/kafka-infrastructure
        ↓
       main
```

Suggested PR title:

```text
feat(kafka): add local Kafka infrastructure
```

Useful PR verification commands:

```bash
docker compose config
docker compose up -d
docker compose ps
```

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --list
```

```bash
docker compose exec kafka   /opt/kafka/bin/kafka-topics.sh   --bootstrap-server kafka:29092   --describe   --topic sensor_raw
```

Also document the manual producer/consumer test.

---

## 2.48 Self-review checklist

```text
[ ] Kafka image version is pinned.
[ ] No ZooKeeper service was added.
[ ] Kafka is configured in KRaft mode.
[ ] Host Kafka access uses localhost:9092.
[ ] Docker Kafka access uses kafka:29092.
[ ] The controller uses port 9093.
[ ] Kafka has a persistent named volume.
[ ] Single-node internal replication settings use 1.
[ ] Automatic topic creation is disabled.
[ ] No credentials were committed.
[ ] PostgreSQL still starts correctly.
[ ] `docker compose config` succeeds.
[ ] Both containers become healthy.
[ ] `sensor_raw` has 3 partitions.
[ ] `sensor_alerts` exists.
[ ] Console producer/consumer communication works.
```

Resolve PR review conversations and use **Squash and merge** as established in Phase 0.5.

---

## 2.49 Synchronize after merge

```bash
git switch main
git pull --ff-only
git branch -d feat/kafka-infrastructure
git fetch --prune
```

Inspect:

```bash
git log --oneline --graph --decorate -10
```

---

## 2.50 Phase completion checklist

### Docker / Compose

```text
[ ] `docker compose config` succeeds.
[ ] PostgreSQL still starts correctly.
[ ] Kafka starts correctly.
[ ] Kafka becomes healthy.
[ ] The Kafka image is pinned to 4.3.1.
[ ] The `kafka_data` named volume exists.
[ ] Kafka data survives `docker compose down` + `up`.
```

### Kafka architecture

```text
[ ] I understand broker vs controller.
[ ] I understand why this node uses combined KRaft mode.
[ ] I understand why ZooKeeper is absent.
[ ] I understand `KAFKA_NODE_ID`.
[ ] I understand `KAFKA_PROCESS_ROLES`.
[ ] I understand the purpose of the cluster ID.
```

### Networking

```text
[ ] I understand `listeners`.
[ ] I understand `advertised.listeners`.
[ ] I understand why host clients use `localhost:9092`.
[ ] I understand why Docker clients use `kafka:29092`.
[ ] I understand what the controller listener on port 9093 is for.
```

### Topics and partitions

```text
[ ] `sensor_raw` exists.
[ ] `sensor_raw` has 3 partitions.
[ ] `sensor_alerts` exists.
[ ] replication factor is 1.
[ ] I understand why replication factor 2 cannot work with one broker.
[ ] I understand ordering is guaranteed per partition.
[ ] I understand what an offset identifies.
```

### Producers / consumers

```text
[ ] I manually produced records using the Kafka CLI.
[ ] I manually consumed records using the Kafka CLI.
[ ] I produced records with sensor IDs as keys.
[ ] I observed partition numbers and offsets.
[ ] I understand why keys are useful for sensor ordering.
```

### Consumer groups

```text
[ ] I created a named consumer group.
[ ] I inspected its committed offsets.
[ ] I inspected its lag.
[ ] I restarted the same group and observed its progress.
[ ] I ran two consumers in the same group.
[ ] I understand how partitions are distributed among consumers.
[ ] I understand that different consumer groups track offsets independently.
```

### Git / GitHub

```text
[ ] Work was performed on `feat/kafka-infrastructure`.
[ ] Changes were reviewed with `git diff`.
[ ] Staged changes were reviewed with `git diff --staged`.
[ ] No `.env` secrets were committed.
[ ] The branch was pushed.
[ ] A Pull Request was opened.
[ ] The PR was self-reviewed.
[ ] The PR was squash-merged.
[ ] Local `main` was synchronized afterward.
[ ] The local feature branch was deleted.
```

---

## 2.51 What we deliberately do not add yet

Do not add these in Phase 2:

```text
Python Kafka producer
Spark
Kafka UI
Schema Registry
Avro
Protobuf
SASL authentication
TLS
multi-broker Kafka
Kafka Connect
Kubernetes
```

Phase 2 should stay focused on:

```text
Docker
  +
single-node Kafka
  +
topics
  +
partitions
  +
offsets
  +
consumer groups
  +
CLI experiments
```

---

## 2.52 Resulting architecture

After Phase 2:

```text
                    Ubuntu host
                        │
            ┌───────────┴───────────┐
            │                       │
            │ localhost:9092        │ localhost:5432
            ▼                       ▼
      ┌───────────┐           ┌────────────┐
      │   Kafka   │           │ PostgreSQL │
      │   4.3.1   │           │    18.4    │
      └─────┬─────┘           └──────┬─────┘
            │                        │
            ▼                        ▼
       kafka_data              postgres_data

Docker network:

Kafka service:             kafka
Kafka internal endpoint:   kafka:29092
PostgreSQL service:        postgres
PostgreSQL endpoint:       postgres:5432
```

The next phase can introduce the real application producer:

```text
Python sensor simulator
        │
        │ localhost:9092
        ▼
      Kafka
        │
        ▼
    sensor_raw
```

Only after that works should Spark be introduced as a Kafka consumer.

---

## References

Official Apache Kafka documentation:

- Kafka downloads:
  https://kafka.apache.org/community/downloads/

- Kafka 4.3 documentation:
  https://kafka.apache.org/43/

- Kafka quickstart:
  https://kafka.apache.org/quickstart/

- Kafka Docker image usage guide:
  https://github.com/apache/kafka/blob/trunk/docker/examples/README.md

- Kafka broker configuration:
  https://kafka.apache.org/43/configuration/broker-configs/

- Kafka basic operations:
  https://kafka.apache.org/43/operations/basic-kafka-operations/

- KRaft vs ZooKeeper:
  https://kafka.apache.org/43/getting-started/zk2kraft/

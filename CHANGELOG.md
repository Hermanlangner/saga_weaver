# Changelog

## 0.3.0 - Unreleased

### Added

- Application-owned facades through `use SagaWeaver, otp_app: ...`.
- `SagaWeaver.handle/2` and `fetch/2` with explicit result contracts.
- `route/1` and `handle/2` callbacks on `SagaWeaver.Saga`.
- Backend-neutral `%SagaWeaver.Instance{}` with pure state/context helpers.
- Structured `%SagaWeaver.Error{}` values.
- Common `SagaWeaver.Storage` behaviour and conformance tests.
- PostgreSQL, Redis, and supervised in-memory storage implementations.
- Telemetry spans for message handling and storage operations.
- `mix saga_weaver.install` for PostgreSQL and Redis setup.
- A minimal executable quickstart under `examples/quickstart/`.

### Changed

- New sagas retain completed records as replay-protection tombstones.
- Saga state transitions are committed once after successful handlers.
- State and context keys are normalized to strings across adapters.
- Redis storage uses an application-owned Redix connection and bounded atomic
  compare-and-set retries.
- Completed tombstones reject stale in-flight transitions.
- Route keys are checked against the persisted saga owner before handling, and
  callbacks cannot change an instance key or saga identity during a commit.
- Redis terms are decoded in safe mode and malformed records return
  tagged errors.
- Expected routing, callback, configuration, and storage failures return tagged
  errors instead of pattern-match exceptions.
- Package metadata now describes SagaWeaver rather than the original project
  name.

### Removed

- The unreleased 0.3 API no longer carries the 0.2 orchestrator, saga schema,
  identifier DSL, global configuration, supervisor, or storage adapters.
- PostgreSQL and Redis use only the 0.3 instance data shape; no legacy record
  decoding or migration helpers are included.

## 0.2.0

- Published PostgreSQL and Redis saga storage with optimistic concurrency.
- Added message correlation, state/context assignment, and completion support.

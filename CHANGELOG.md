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
- `SagaWeaver.Compatibility.v1_key/2` for persisted identifier migration.

### Changed

- New sagas retain completed records as replay-protection tombstones.
- Saga state transitions are committed once after successful handlers.
- State and context keys are normalized to strings across adapters.
- Redis storage uses an application-owned Redix connection and bounded atomic
  compare-and-set retries.
- Completed tombstones reject stale in-flight transitions.
- Route keys are checked against the persisted saga owner before handling, and
  callbacks cannot change an instance key or saga identity during a commit.
- Redis legacy terms are decoded in safe mode and malformed records return
  tagged errors.
- Expected routing, callback, configuration, and storage failures return tagged
  errors instead of pattern-match exceptions.
- Package metadata now describes SagaWeaver rather than the original project
  name.

### Deprecated

- Adding `{SagaWeaver, []}` to an application supervision tree.
- `SagaWeaver.execute_saga/2` in favor of `handle/2`.
- `SagaWeaver.retrieve_saga/2` in favor of `fetch/2`.
- `started_by`, `identity_key_mapping`, and `handle_message/2` for new sagas.
- Direct use of `SagaWeaver.Orchestrator`, `SagaWeaver.SagaSchema`, and the
  modules under `SagaWeaver.Adapters`.

### Compatibility

- Existing PostgreSQL rows use the same table and columns and remain readable.
- Existing Redis values containing `%SagaWeaver.SagaSchema{}` remain readable.
- The exact 0.2 identifier algorithm remains available through
  `SagaWeaver.Compatibility.v1_key/2`.
- Deprecated 0.2 entry points retain their legacy result values and
  delete-on-completion semantics during the migration release.

## 0.2.0

- Published PostgreSQL and Redis saga storage with optimistic concurrency.
- Added message correlation, state/context assignment, and completion support.

# Architecture

Status: Accepted for SagaWeaver 0.3

## Context

SagaWeaver 0.2 combined message correlation, orchestration, process lifecycle,
and backend selection behind global application configuration. The public
runtime value was an Ecto schema, completion deleted records, and PostgreSQL
and Redis adapters exposed different operational behavior.

Version 0.3 replaces that prototype API with a smaller application integration
surface. Because no released consumers or persisted production instances need
migration, the design does not retain the 0.2 API or data shape.

## Decisions

### Synchronous Core

The core API is synchronous and owns no runtime process. A handler call routes
one message, loads or creates one instance, invokes one callback, and commits
one transition. Applications own and supervise long-lived resources such as
Ecto repositories and Redix connections.

### Application-Owned Facades

Applications define a facade with `use SagaWeaver, otp_app: :my_app`. This
provides a stable project API and resolves configuration from the host
application. The direct `SagaWeaver.handle/3` and `fetch/3` functions remain
available for tests and dynamic integrations.

### Explicit Routing

`route/1` returns `{:start, key}`, `{:continue, key}`, or `:ignore`. Combining
correlation and lifecycle intent prevents a continuation event from silently
creating an incomplete saga. Keys are durable strings chosen by the
application.

### Pure Transitions

`SagaWeaver.Instance` is independent of Ecto and Redis. Its helpers update an
in-memory value and accumulate a delta. Storage receives that delta only after
`handle/2` succeeds, so callback errors cannot leave partially written state.

### Common Storage Semantics

Every new adapter implements `fetch/2`, idempotent `insert_new/2`, and atomic
`commit/3`. Disjoint concurrent deltas must merge. Conflicts use bounded retries
and become structured storage errors after exhaustion.

Completed instances are retained and remain fetchable. Replayed messages for a
completed key are ignored, and stale in-flight transitions cannot mutate the
completed tombstone. Data retention and purging are intentionally a separate
policy.

### Clean API Boundary

Version 0.3 exposes only the facade, explicit saga callbacks, backend-neutral
instances, and the common storage contract. The 0.2 orchestrator, schema,
identifier DSL, global configuration, supervisor, and storage adapters are not
part of the package. PostgreSQL and Redis persist only the 0.3 instance shape.

### Backend Dependencies

`postgrex` remains optional because it is the host application's database
driver. `ecto` and `ecto_sql` support the included PostgreSQL storage module,
while `redix` supports the included Redis storage module. Splitting storage
implementations into separate packages is a future packaging decision rather
than a compatibility constraint.

## Consequences

- Hosts have explicit ownership of infrastructure and failure domains.
- Saga callback tests can use a supervised in-memory adapter without a database.
- Storage implementations can be checked against one conformance suite.
- Completed rows consume storage until an application-defined purge policy is
  introduced.
- At-least-once delivery still requires application side effects to be
  idempotent; an atomic state commit cannot make arbitrary external effects
  exactly once.

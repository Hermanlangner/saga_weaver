# Architecture

Status: Accepted for SagaWeaver 0.3

## Context

SagaWeaver 0.2 combined message correlation, orchestration, process lifecycle,
and backend selection behind global application configuration. The public
runtime value was an Ecto schema, completion deleted records, and PostgreSQL
and Redis adapters exposed different operational behavior.

Version 0.3 needs a smaller application integration surface without invalidating
published APIs or making active 0.2 saga records unreadable.

## Decisions

### Synchronous Core

The core API is synchronous and owns no runtime process. A handler call routes
one message, loads or creates one instance, invokes one callback, and commits
one transition. Applications own and supervise long-lived resources such as
Ecto repositories and Redix connections.

The deprecated `{SagaWeaver, []}` child remains startable for one migration
release, but new integrations do not add it to their supervision trees.

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

### Compatibility Boundary

The 0.2 functions and saga DSL remain deprecated wrappers. They keep legacy
return values, identifiers, and delete-on-completion behavior. PostgreSQL uses
the existing table shape; Redis can decode serialized `%SagaWeaver.SagaSchema{}`
terms; `SagaWeaver.Compatibility.v1_key/2` preserves the old identifier
algorithm for active-instance migrations.

Compatibility code remains separate from the new engine so legacy behavior
does not become an accidental requirement of the new API.

### Backend Dependencies

`postgrex` remains optional because it is only a database driver. `ecto` and
`ecto_sql` remain required in 0.3 because the published 0.2 PostgreSQL API and
`SagaWeaver.SagaSchema` must still compile and load. `redix` remains required
for the same migration release because the published Redis adapter remains
loadable. Making those libraries optional would require conditional module
definitions or breaking removal of the compatibility surface, so that change
is deferred to a major release.

## Consequences

- Hosts have explicit ownership of infrastructure and failure domains.
- Saga callback tests can use a supervised in-memory adapter without a database.
- Storage implementations can be checked against one conformance suite.
- Completed rows consume storage until an application-defined purge policy is
  introduced.
- At-least-once delivery still requires application side effects to be
  idempotent; an atomic state commit cannot make arbitrary external effects
  exactly once.
- Legacy modules and backend dependencies remain part of the package during the
  migration release.

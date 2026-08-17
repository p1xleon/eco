# Offline Mode — Assessment & Implementation Plan

Branch: `feat/offline-mode`

> For the current state in short form — what works, what is left, how to verify
> it — read [offline-mode.md](offline-mode.md) instead. This document is the
> original assessment and design, kept for the reasoning behind each decision
> (including the ones that were reversed).

> **Status:** Phases 1, 2, 4 and 6 are implemented, plus the parts of Phase 5
> that survived verification and the retry/backoff half of Phase 3. What is
> left of Phase 3 is the part that needs a server migration: `updated_at` delta
> pulls and `deleted_at` soft deletes. Replication still lives in the
> repositories rather than a standalone engine — correct, but it will want
> extracting when delta pulls land. See §8 for the record of what shipped.
>
> The transaction/category reference bug is fixed too — see §9. That one needs
> a migration applied to the Supabase project, though the app is written to work
> either way.
>
> Nothing here has been run on a device yet.

## 1. Verdict

**There is no offline mode.** There is a local database and some incidental
resilience, but nothing that makes offline a supported, coherent state.

What exists today:

- Isar is the read path for every screen. `TransactionRepository.getAll()`,
  `CategoryRepository.getAll()` and `RecurringTransactionRepository.getAll()`
  all return local rows, so data stays visible without a network.
- Creates degrade gracefully. `TransactionRepository.add()` wraps the upload in
  `try/catch` and falls back to a local-only row with `remoteId == null`
  ([transaction_repository.dart:55](../lib/features/transactions/data/repositories/transaction_repository.dart#L55)).
- Unsynced creates are retried on the next read via
  `_uploadPendingLocalTransactions()` / `_uploadPendingLocalCategories()` /
  `_uploadPendingLocalTemplates()`.
- A connectivity listener in
  [auth_gate.dart:55](../lib/core/auth/auth_gate.dart#L55) refreshes
  transactions and recurring templates when the interface comes back up.
- The transaction filter already exposes `SyncStatusFilter.localOnly` /
  `syncedOnly`, so the concept of an unsynced row is partly surfaced.

That is "survives a dropped request", not offline mode. The word `offline`
appears nowhere in `lib/`.

## 2. Concrete gaps

Ordered by user-visible severity.

### P0 — offline edits and deletes fail outright

`TransactionRepository.update()` and `delete()` call the remote **unguarded**,
unlike `add()`:

```dart
// update() — transaction_repository.dart:99
if (remote.isAuthenticated && tx.remoteId != null) {
  final saved = await updateRemoteTransaction(tx);   // throws offline
  ...
}
```

```dart
// delete() — transaction_repository.dart:122
if (remote.isAuthenticated && local.remoteId != null) {
  await deleteRemoteTransaction(local.remoteId!);    // throws offline
}
await _isar.writeTxn(...);                            // never reached
```

`remote.isAuthenticated` only checks that a cached user object exists — it is
true offline. So editing or deleting any *already-synced* transaction with no
network throws; the UI catches it and shows an error snackbar
([transaction_details_page.dart:347](../lib/features/transactions/presentation/pages/transaction_details_page.dart#L347),
[:370](../lib/features/transactions/presentation/pages/transaction_details_page.dart#L370),
[add_transaction_page.dart:152](../lib/features/transactions/presentation/pages/add_transaction_page.dart#L152)).
The change is simply lost. Only rows created while offline can be edited
offline.

### P0 — offline edits to synced rows are silently reverted

Even if the write above succeeded locally, `_syncLocalCache()` does
`clear()` + `putAll(remoteTransactions)` + re-insert of `remoteId == null` rows
([transaction_repository.dart:181](../lib/features/transactions/data/repositories/transaction_repository.dart#L181)).
Any local modification to a row that *has* a `remoteId` is destroyed on the next
successful sync. The server always wins because the client has no way to say
"this row is dirty".

### P0 — offline deletes resurrect

Categories and recurring templates swallow remote-delete failures and delete
locally anyway. With no tombstone, the next pull re-inserts the row from the
server. The delete looks like it worked, then quietly undoes itself.

### P1 — every read blocks on the network while offline

`getAll()` is `upload → fetch → merge → read local`. Offline, that means each
provider refresh waits out the Supabase/HTTP timeout before rendering cached
data. There is no connectivity check in front of the remote calls and no
short-circuit; on a flaky connection the app feels frozen rather than offline.

### P1 — the user is never told what state they are in

No offline banner, no "pending sync" badge on rows, no last-synced timestamp, no
manual "sync now". `SyncStatusFilter.localOnly` is the only hint and it is
buried in the filter sheet. Failures surface as generic error snackbars that
look like bugs.

### P1 — offline app launch ~~is unverified and probably fragile~~ (partly resolved)

**Verified against the gotrue source, 2026-08-17.** A token refresh that fails
for network reasons throws `AuthRetryableFetchException`
(`gotrue-2.20.0/lib/src/fetch.dart:46,190`), and `_callRefreshToken` only clears
the session when the error is *not* retryable
(`gotrue_client.dart:1396-1398`). So a refresh failure while offline preserves
the session and emits no `signedOut` event — **the lockout scenario below is not
real for network failures**, and no offline-session fallback was built.

The rest of this section still stands:

- `main()` hard-throws if `.env` is missing, before anything else runs
  ([main.dart:26](../lib/main.dart#L26)) — a config problem, not an offline one,
  but it is on the cold-start path.
- `authStateProvider` was a raw `StreamProvider` with no initial value, so a slow
  first emission showed a spinner rather than cached content. It also re-emitted
  on every token refresh, and since `transactionsProvider` watches it, each
  refresh triggered a full refetch. Both fixed.
- `signOut()` threw with no connection even though gotrue clears the local
  session before it calls the server, so logout appeared to fail while having
  already happened. Fixed.

### P2 — structural

- No sync metadata anywhere: no `syncState`, no `localUpdatedAt`, no
  `lastSyncedAt`. `remoteId == null` is overloaded to mean "pending create",
  which cannot express pending update or pending delete.
- Full-table pull every time; no `updated_at` delta fetch, no server-side soft
  delete, so remote deletions can only be applied by wiping the table.
- No retry/backoff policy and no ordering guarantee between queued operations
  (a create and its later edit can be pushed out of order).
- Recurring instance generation
  ([recurring_transaction_service.dart](../lib/features/recurring/domain/services/recurring_transaction_service.dart))
  writes through the same repositories, so it inherits every issue above.
- `connectivity_plus` reports *interface* state, not reachability. Captive
  portals and dead uplinks read as online.
- `TransactionPresetRepository` is local-only with no remote counterpart — fine,
  but it means presets silently do not follow the user across devices. Decide
  whether that is intended.

## 3. Target design

Local-first: **Isar is the source of truth. The network is a background
replicator.** Every write commits locally and returns immediately; sync happens
after, asynchronously, and never blocks the UI.

### 3.1 Sync metadata on every syncable model

Add to `TransactionModel`, `CategoryModel`, `RecurringTransactionModel`:

```dart
enum SyncState { synced, pendingCreate, pendingUpdate, pendingDelete }

@enumerated
SyncState syncState = SyncState.synced;

DateTime? localUpdatedAt;   // set on every local mutation
DateTime? remoteUpdatedAt;  // server's updated_at at last successful pull
String?   lastSyncError;    // surfaced in the sync screen
int       syncAttempts = 0; // backoff / poison-pill detection
```

Isar tolerates added fields (existing rows default), so no manual migration is
needed — but rows written before this change must be backfilled to
`synced`/`pendingCreate` based on `remoteId` in a one-shot migration step at
startup.

`pendingDelete` replaces hard local deletion: the row is hidden from all queries
and physically removed only after the server confirms.

### 3.2 Connectivity as a real provider

`lib/core/network/connectivity_provider.dart`:

- `connectivityProvider` — `connectivity_plus` stream, interface level.
- `onlineStatusProvider` — `Offline | Online | Degraded`, combining the
  interface state with an actual reachability probe (a cheap authenticated
  Supabase call, debounced, with backoff) so captive portals do not read as
  online.

Repositories consult this before attempting remote work, so offline reads return
from Isar instantly instead of waiting for a timeout. The ad-hoc listener in
`auth_gate.dart` is deleted in favour of this.

### 3.3 A sync engine

`lib/core/sync/sync_engine.dart` — one place that owns replication:

1. **Push** — collect rows where `syncState != synced`, in dependency order
   (categories → recurring templates → transactions, since transactions
   reference categories and templates reference categories). Per row:
   `pendingCreate` → insert, `pendingUpdate` → update, `pendingDelete` → delete
   then purge locally. On success set `synced` and store `remoteUpdatedAt`; on
   failure increment `syncAttempts`, record `lastSyncError`, keep the row queued.
2. **Pull** — fetch `where updated_at > lastPulledAt` per table instead of the
   whole table, apply into Isar **without** `clear()`, skipping any row that is
   locally dirty (that row is resolved by conflict policy instead).
3. **Reconcile deletes** — requires a server-side soft-delete column so a pull
   can learn about rows deleted elsewhere. Until that migration lands, a
   periodic full reconcile (id-set diff, not `clear()`) is the fallback.
4. Persist `lastPulledAt` per collection.

Triggers: app start, transition to online, foreground resume, manual "Sync now",
and a debounced trigger after each local write.

Exposed as `syncStatusProvider` — `idle | syncing | error`, pending count, last
success time — for the UI.

### 3.4 Conflict policy

Last-write-wins on `updated_at`, with local dirty rows preferred unless the
remote row is strictly newer:

- local dirty, remote unchanged since `remoteUpdatedAt` → push local.
- local dirty, remote newer → remote wins for the record; keep the losing local
  version in a `SyncConflictModel` collection so it is recoverable and visible
  rather than silently dropped.
- local clean → remote wins.

Deletes beat updates (a `pendingDelete` still pushes even if the remote row
changed).

This is deliberately simple. Field-level merge is not worth it for this data
shape; single-user-multi-device is the realistic contention case.

### 3.5 Auth offline

- Treat a cached Supabase session as sufficient to enter the app. Persist a
  minimal `lastKnownUserId` locally and let `AuthGate` admit the user on that
  when the auth stream has not yet produced a session **and** the device is
  offline.
- Distinguish "signed out" (explicit sign-out, or a real 401) from "cannot reach
  auth server". Only the former clears local data.
- Never call `IsarService.resetLocalData()` on a network-caused auth failure.
- Sign-in and sign-up genuinely require network — show a clear "you need a
  connection to sign in" state instead of a raw error.

### 3.6 UI

- Persistent offline banner in `AppShell` when `onlineStatusProvider` is offline,
  plus a pending-changes count.
- Per-row pending/failed badge in `TransactionCard`, driven by `syncState`
  (replacing the `remoteId == null` heuristic).
- A **Sync** section in Settings: status, last synced time, pending count,
  "Sync now", and a list of failed items with their error and a retry action.
- Any action that truly cannot work offline (sign-in, sign-up, account changes)
  is disabled with an explanation rather than allowed to fail.

## 4. Server-side changes

New Supabase migration alongside the existing ones in `supabase/migrations/`:

- `deleted_at timestamptz` on `transactions`, `categories`,
  `recurring_transactions`, plus RLS policy updates and filtering of soft-deleted
  rows from normal selects. Enables delete propagation on pull.
- Index on `(user_id, updated_at)` for each table to make delta pulls cheap.
- Ensure `updated_at` is set by a trigger on every update (there is already
  `20260313002000_add_transactions_updated_at.sql` and a "relax" migration —
  verify the current state before adding more).
- Optional but recommended: accept a client-generated UUID as the primary key on
  insert, so a row has a stable identity before it ever reaches the server. This
  removes a whole class of duplicate-on-retry bugs (a create that succeeded
  server-side but whose response was lost is currently re-sent as a new row).

## 5. Implementation phases

Each phase is independently shippable and leaves the app in a working state.

### Step 0 — verify assumptions — done

1. ~~Cold start with a valid cached session~~ and 2. ~~with an expired access
   token~~ — **answered from the gotrue source**, see the P1 section above. A
   network-caused refresh failure keeps the session, so neither cold start
   falls through to the login page, and no offline-session fallback was built.
3. Time a `transactionsProvider` refresh offline — **still worth doing on a
   device**, to confirm the connectivity short-circuit removed the timeout wait.

### Phase 1 — stop losing data (P0, small)

- Wrap remote calls in `update()` and `delete()` the way `add()` already is, so
  local writes always commit.
- Introduce `syncState` + `localUpdatedAt` on the three models and set them on
  every mutation. Backfill existing rows at startup.
- Make `_syncLocalCache()` skip rows whose `syncState != synced` instead of
  clearing the table.
- Implement `pendingDelete` tombstones and filter them out of every query.

After this phase, offline edits and deletes work and survive a sync.

### Phase 2 — connectivity and non-blocking reads

- Add `connectivity_provider.dart` and `onlineStatusProvider`.
- Short-circuit remote work in all three repositories when offline; add explicit
  short timeouts when online so a degraded network cannot hang a screen.
- Remove the connectivity listener from `auth_gate.dart`.

### Phase 3 — sync engine

- Add `sync_engine.dart` and `syncStatusProvider`; move the push/pull logic out
  of the repositories, leaving them as local-only data access plus a "mark
  dirty" call.
- Wire triggers (start, reconnect, resume, manual, post-write debounce) with
  exponential backoff and a cap on `syncAttempts`.
- Add the server migration and switch the pull to `updated_at` deltas + soft
  deletes.

### Phase 4 — UI

- Offline banner, per-row badges, Settings sync section, failed-item retry.

### Phase 5 — auth hardening

- Offline session admission and the signed-out / unreachable distinction from
  §3.5.

### Phase 6 — tests

The repo has one placeholder widget test. This work needs real coverage:

- Repository tests against a temp Isar instance with a faked remote source:
  offline create/update/delete, reconnect-and-push, delete tombstone survives a
  pull, dirty row is not clobbered.
- Sync engine tests: ordering, backoff, each conflict branch, duplicate
  suppression on a lost insert response.
- A widget test for the offline banner and pending badge.

## 6. Files affected

| Area | Files |
| --- | --- |
| New | `lib/core/network/connectivity_provider.dart`, `lib/core/sync/sync_engine.dart`, `lib/core/sync/sync_state.dart`, `lib/core/sync/sync_status_provider.dart`, `lib/core/sync/sync_conflict_model.dart` |
| Models | `transaction_model.dart`, `category_model.dart`, `recurring_transaction_model.dart` (+ regenerate `.g.dart`) |
| Repositories | `transaction_repository.dart`, `category_repository.dart`, `recurring_transaction_repository.dart` |
| Bootstrap | `main.dart`, `isar_service.dart`, `auth_gate.dart`, `auth_provider.dart` |
| UI | `app_shell.dart`, `transaction_card.dart`, `settings_page.dart`, `login_page.dart`, `sign_up_page.dart` |
| Server | new file in `supabase/migrations/` |

## 7. Open questions

1. **Transaction presets** are local-only today. Sync them, or document them as
   device-local?
2. **Import** (`import_transactions_page.dart`) can create hundreds of rows at
   once; `addAll()` currently uploads them one at a time. Should the sync engine
   batch pushes, and should a large offline import be allowed to queue
   unbounded?
3. **Conflict visibility** — is a recoverable conflict record (§3.4) worth the
   UI surface, or is silent last-write-wins acceptable for a single-user app?
4. **Client-generated UUIDs** (§4) are the clean fix for duplicate-on-retry but
   touch every table's primary key. Worth doing now, or defer?

## 8. What shipped

Implemented on this branch. Phase 3 is deliberately not done: replication still
lives in the repositories rather than a standalone engine, and pulls are still
full-table.

### New

| File | Role |
| --- | --- |
| `lib/core/sync/sync_state.dart` | `SyncState` enum + `isPending` / `isVisible` |
| `lib/core/sync/sync_backfill.dart` | Idempotent startup repair: `remoteId == null` ⇒ `pendingCreate` |
| `lib/core/sync/sync_providers.dart` | `pendingSyncCountProvider`, `syncFailuresProvider`, `syncNow(ref)`, `retryFailedSync(ref)` |
| `lib/core/sync/sync_gate.dart` | Collapses concurrent and back-to-back sync passes over one collection |
| `lib/core/network/network_monitor.dart` | Interface state + reachability backoff, single source of `isOnline` |
| `lib/core/network/remote_call.dart` | Timeout wrapper, network-vs-server error classification |
| `lib/core/network/connectivity_provider.dart` | Riverpod view of the monitor |
| `lib/shared/widgets/sync_status_banner.dart` | Offline / pending strip above the nav bar |
| `test/transaction_repository_offline_test.dart` | 17 tests |
| `test/category_repository_offline_test.dart` | 4 tests |
| `test/recurring_repository_offline_test.dart` | 4 tests |
| `test/sync_status_banner_test.dart` | 4 tests |
| `test/transaction_category_reference_test.dart` | 8 tests |
| `test/support/` | Temp-Isar harness and in-memory fake remotes |

37 tests in total, plus the pre-existing smoke test. All pass; none of it has
run on a device.

### Changed

- **Models** gained `syncState`, `localUpdatedAt`, `syncAttempts` and
  `lastSyncError` (`.g.dart` regenerated). Isar defaults the enum to index 0,
  which is why `synced` is first and why the backfill exists.
- **Retry budget**: a record the server *rejects* burns one of
  `maxSyncAttempts` (5) tries and remembers the error; after that it stops
  retrying on its own, so one permanently invalid record cannot slow every
  read forever. A record that failed because the device was **offline** is not
  charged — that is not the record's fault. Editing a record, or the Try again
  button, restores its budget.
- **Sync gate**: one reconnect used to sync categories three times over,
  because several providers refresh at once and recurring pulls categories on
  the way. Concurrent passes now join the one in flight, and a pass that just
  succeeded is not repeated within two seconds. Explicit requests
  (pull-to-refresh, Sync now, reconnect) always bypass the window.
- **Recovery service** ignores tombstoned records, so a pending delete is not
  used as evidence for rebuilding a template, and a recovered template is
  correctly queued as a create.
- **Repositories** are local-first: write to Isar, then replicate. `update()`
  and `delete()` no longer throw offline; deletes tombstone instead of vanishing;
  the pull merge skips dirty records, preserves local ids, and reconciles
  server-side deletions without `clear()`.
- **Remote sources** wrap every call in `remoteCall` (12s timeout) and paginate
  fetches at 1000 rows — the delete reconcile treats a fetch as the complete
  server state, which is only safe if it really is complete.
- **`auth_provider`** seeds from the persisted session and drops duplicate
  events; **`auth_repository.signOut()`** tolerates being offline.
- **`auth_gate`** drives reconnect sync from `NetworkMonitor` instead of its own
  connectivity listener.
- **UI**: sync banner in the shell, "Not synced" tag on pending transaction
  cards, a Sync section in Settings with a manual trigger and a list of stuck
  records with their error and a Try again button, offline-aware sign-in/sign-up
  errors, and a logout dialog that warns when unsynced changes are about to be
  wiped.
- **Triggers**: replication now runs on app start, on reconnect, on foreground
  resume, on pull-to-refresh, and on demand from Settings.
- **`SyncStatusFilter`** now keys off `syncState`, so a synced record edited
  offline correctly reads as local-only.

### Not done

- **The bulk upgrade of historical category references** (§9), by design.
- **The server-side half of Phase 3**: `updated_at` delta pulls and `deleted_at`
  soft deletes, which need a migration applied to the Supabase project. Until
  then every pull is a full-table read, made safe by paginating so the
  delete-reconcile can trust it. No migration file was added, because an
  unapplied migration the client does not use yet is just a trap.
- **Extracting a standalone sync engine.** Replication lives in the three
  repositories. That is correct but duplicated three ways; it is worth
  extracting when delta pulls arrive and the logic gets more intricate.
- **Conflict records** (§3.4) — resolution is silent last-write-wins today.
- **Anything on a device.** Every check so far is `flutter analyze`, unit and
  widget tests, and reading the gotrue source.

## 9. Category references on transactions

`transactions.category_id` is a `bigint` holding the **device-local Isar id** of
the category, while `recurring_transactions.category_id` already holds the
category's uuid. Local ids differ per device, so a second device maps a pulled
transaction onto whichever category happens to hold that integer. Single-device
use is unaffected, which is why it went unnoticed.

### The fix

`supabase/migrations/20260817000000_add_transactions_category_remote_id.sql`
adds a nullable `category_remote_id uuid` **alongside** the legacy column.
Nothing is dropped or rewritten, and `category_id` is still written on every
push, so a client running the old code keeps working against the new schema.

The app writes both and prefers the uuid when reading. If the uuid does not
resolve locally — a category from a device this one has not synced with — it
falls back to the legacy integer rather than dropping the row.

### Applied 2026-08-17, via the Supabase dashboard

The `.sql` file is the record of what was run, not something the CLI applied —
see [supabase/migrations/README.md](../supabase/migrations/README.md).

The app never required it. `CategoryRemoteIdFallback` retries the first write
rejected for that column without it, remembers the answer for the session, and
carries on using the legacy column. Reads need nothing: a column that does not
exist is simply absent from the response. So the new app works against the old
schema, and the old app works against the new schema. That fallback is dormant
now, and worth keeping: it is what makes rolling the app back, or an older build
still installed somewhere, harmless.

### Historical rows are deliberately left alone

Rows written before the column existed keep only the legacy integer, and the app
does **not** bulk-rewrite them. This device cannot know what another device's
integer meant; guessing would freeze a wrong reference and hand it to every
other device. They upgrade naturally when the user next edits the transaction,
where the category on screen is authoritative.

If you want the historical rows migrated wholesale, that is a deliberate,
user-initiated action — worth a button that says what it assumes, not a silent
background rewrite.

## 10. Worth checking first on a device

1. Airplane mode: create, edit and delete, then reconnect and confirm the queue
   drains and the banner clears.
2. Cold start in airplane mode with a valid session — the gotrue source says
   this works, but it is the assumption everything else rests on.
3. Timing of a `transactionsProvider` refresh offline, to confirm the
   connectivity short-circuit removed the timeout wait (Step 0, item 3).
4. Logout with pending changes: it now offers "Sync, then log out" when online,
   and refuses to wipe anything if the sync does not drain the queue. Discarding
   is still possible, but only via an explicit "Discard N changes" button.
5. That a transaction saved on one device shows the right category on another —
   the point of §9. Needs the migration applied and two devices.

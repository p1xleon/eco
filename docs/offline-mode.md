# Offline mode

Status of the offline/sync work on `feat/offline-mode`.

For the original assessment, the design rationale and the record of decisions
that were reversed along the way, see
[offline-mode-plan.md](offline-mode-plan.md).

**Nothing in here has been run on a device yet.** It is verified by
`flutter analyze`, 38 unit and widget tests, and by reading the gotrue source.
See [Verifying on a device](#verifying-on-a-device).

## What it does now

The app is local-first: Isar is the source of truth and the network is a
background replicator.

- **Every write commits locally first**, then replicates. Creating, editing and
  deleting all work with no connection and nothing is lost.
- **Deletes made offline stay deleted.** They become tombstones, hidden from the
  UI and purged only once the server confirms.
- **Edits made offline survive the next sync.** A record with unpushed changes
  is skipped by the pull rather than overwritten.
- **Reads never wait on a dead network.** Connectivity is checked before any
  remote call, and every call is capped at 12 seconds.
- **The user can see the state**: a banner above the nav bar when offline or
  when changes are queued, a "Not synced" tag on affected transactions, and a
  Sync section in Settings with a manual trigger and a list of anything stuck.
- **Logging out no longer discards unsynced work** without saying so.

Replication runs on app start, on reconnect, on foreground resume, on
pull-to-refresh, and on demand from Settings.

## How it works

| Piece | Role |
| --- | --- |
| `core/sync/sync_state.dart` | `SyncState` (`synced` / `pendingCreate` / `pendingUpdate` / `pendingDelete`), the retry cap |
| `core/sync/sync_backfill.dart` | Startup repair for records written before sync state existed |
| `core/sync/sync_gate.dart` | Collapses concurrent and back-to-back sync passes |
| `core/sync/sync_providers.dart` | Pending count, stuck records, `syncNow`, `retryFailedSync` |
| `core/network/network_monitor.dart` | Interface state plus a reachability backoff — the single source of `isOnline` |
| `core/network/remote_call.dart` | Timeout wrapper and network-vs-server error classification |
| `shared/widgets/sync_status_banner.dart` | The banner |

Every syncable record carries `syncState`, `localUpdatedAt`, `syncAttempts` and
`lastSyncError`. Push/pull logic lives in the three repositories.

Three details worth knowing:

- **Conflicts are last-write-wins**, with local pending changes preferred until
  they are pushed. The losing version is discarded, not kept.
- **Rejections cost a retry budget** (5 attempts). Failing because the device is
  offline does *not* count — that is not the record's fault. Once exhausted, a
  record stops retrying on its own and appears in Settings with its error.
- **Pulls are full-table**, paginated at 1000 rows. The delete-reconcile treats a
  fetch as the complete server state, which is only sound because it pages.

## What's done

**Data safety**
- Offline create, edit and delete no longer fail or get reverted
- Tombstones, so offline deletes are not resurrected by the next pull
- Local ids preserved across pulls (they used to churn on every sync)
- Pagination, so the delete-reconcile cannot wipe rows past the first 1000
- Logout offers "Sync, then log out", and refuses to wipe if the sync does not
  drain the queue

**Sync behaviour**
- Connectivity short-circuit and per-call timeouts
- Retry budget with error capture, and a manual retry
- Sync gate — one reconnect used to sync categories three times over
- Triggers on start, reconnect, resume, pull-to-refresh and manual

**Auth**
- Seeded from the persisted session; duplicate token-refresh events no longer
  trigger a full refetch
- `signOut()` tolerates being offline
- Offline-aware sign-in and sign-up errors

**Correctness**
- Transactions now reference categories by uuid, not by a device-local integer
  (see [Server state](#server-state))
- The recurring recovery service ignores tombstoned records
- `SyncStatusFilter` keys off sync state, so a synced record edited offline
  reads as local-only

**Tests** — 38, in `test/`: transaction, category and recurring repositories,
category references and the pre-migration fallback, and the banner.

## What's left

**Needs a device.** Everything below the line is optional; this is not.

1. **Delta pulls and soft deletes.** Every sync is still a full-table read of
   every collection. Needs `deleted_at` columns, an `updated_at` trigger so the
   cursor is server-owned, and `(user_id, updated_at)` indexes. Fine at current
   scale.
2. **Extracting a sync engine.** Push/pull is duplicated across three
   repositories. Correct, but worth consolidating when delta pulls make it more
   intricate.
3. **Duplicate-on-retry.** A create that succeeds server-side but whose response
   is lost is re-sent as a new row. Client-generated UUIDs would remove the whole
   class; it touches every primary key, so it pairs with the migration above.
4. **Conflict records.** Resolution is silent last-write-wins; the losing version
   is not kept.
5. **Bulk upgrade of historical category references** — deliberately not done.
   No device can know what another device's integer meant, so this should be an
   explicit user action that states its assumption, never a background rewrite.
6. **Transaction presets** are local-only and do not follow the user across
   devices. Needs a decision more than code.
7. **`main()` hard-throws on a missing `.env`**, on the cold-start path. Not
   offline-specific.

## Verifying on a device

1. **Airplane mode**: create, edit and delete a transaction, then reconnect.
   The queue should drain and the banner should clear. This exercises most of
   the new code at once.
2. **Cold start in airplane mode** with a valid session. The gotrue source says
   the session survives a failed refresh, but it is the assumption everything
   else rests on.
3. **Time a refresh offline** — it should return instantly from cache rather
   than waiting out a timeout.
4. **Logout with pending changes** — the sync-first path, and the refusal to
   wipe when it cannot drain.
5. **Two devices, one account**: a transaction saved on one shows the right
   category on the other. This is what the migration below unblocked, and it
   cannot be checked any other way.

## Server state

`transactions.category_remote_id` was added on 2026-08-17 via the Supabase
dashboard. The app works with or without it —
`CategoryRemoteIdFallback` drops the column and retries if the server rejects
it, so an older build, or a rollback, stays harmless.

Existing rows keep only the legacy integer until the user next edits them.

Schema changes on this project are applied by hand through the dashboard. The
`supabase/migrations/` folder is a *record*, not an applied history — read
[its README](../supabase/migrations/README.md) before touching the CLI, because
`db push` would replay a migration that writes to real rows.

Still open on the server, none of it urgent:

- `categories`, `recurring_transactions` and `transactions.status` are not
  described in the migrations folder, so it cannot rebuild the database and two
  tables' RLS policies are not reviewable from the repo.
- Confirm whether `recurring_transactions.next_due_date` is `timestamptz`. The
  `end_date` column is `timestamp without time zone`; if they disagree there is
  a latent timezone bug in due-date maths, unrelated to offline mode.

# Collections: group transactions under a named collection

## Goal
Let the user group finances (a trip, a renovation) into a named **Collection**. A
collection has its own page with its own totals. Its transactions still appear in the
normal list, dashboard and analytics, so overall totals do not change.

## Decisions
- A transaction belongs to **at most one** collection (`collectionId` is nullable).
- A collection is a grouping, not a separate ledger. Nothing is excluded from totals.
- Deleting a collection un-assigns its transactions. It never deletes them.
- Name is the new term "Collection" everywhere (code, UI, SQL).

## Scope
In: create, rename, recolour, delete a collection; assign a collection on the add/edit
transaction form; per-collection income, expense and net; filter the transaction list
by collection; offline sync; collection name encrypted like category names; backup/restore.

Out (later): budgets, archiving, collections on recurring templates or bulk add,
per-collection analytics page.

## Design
Copies the `categories` feature, which already has everything needed.

- `lib/features/collections/` with `CollectionModel` (Isar: id, remoteId, name, color,
  icon, sync fields), mapper (encrypts `name` only, like categories),
  remote source, repository, providers.
- `TransactionModel.collectionId` (int?). Server column `collection_remote_id`, mirroring
  `category_remote_id`, so a transaction can reference a collection by its remote id.
- `TransactionFilter.collectionId`, applied in the same place as `categoryId`.
- UI: Collections page (list with income / expense / net per collection, create / edit /
  delete); tap a collection to open the transactions list pre-filtered by it. Optional
  "Collection" picker in `transaction_form_shared.dart`. Collection chip in the filter sheet.
  Entry added to `app_shell.dart` navigation.
- Totals use the existing cent-rounded money helpers (`core/utils/money.dart`).

## Data and sync
- Migration `create_collections.sql`: table `collections` (id, user_id, name, color, icon,
  created_at) with RLS policies identical to `categories`; plus
  `alter table transactions add column collection_remote_id uuid references collections(id)
  on delete set null`.
- Sync pushes a collection before the transactions that reference it, the same order
  categories use. Backfill covers existing rows (they have no collection).
- Backup codec treats the collection field and the collections list as optional, so old
  backups still restore.

## Error handling
- Deleting a collection on the server nulls `collection_remote_id` (FK `on delete set null`);
  locally the repository clears `collectionId` on affected transactions in the same
  Isar write transaction.
- A transaction whose collection is missing locally is shown as unassigned.

## Testing
Follow existing patterns: `collection_repository_offline_test`, transaction mapper
round-trip with `collectionId`, filter test, per-collection totals test, delete-unassigns
test, and an extended `backup_round_trip_test` including an old-format backup.

## Risks
Isar schema change needs `build_runner` regeneration. Old backups lacking the
field must not fail restore.

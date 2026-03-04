# Task 3: Fix Race Conditions in Repository Files

## Objective
Fix race conditions in 3 repository files by wrapping read-modify-write operations in Drift transactions and replacing loop-delete with batch delete.

## Changes Made

### 1. cell_progress_repository.dart
- **addDistance()**: Wrapped in `_db.transaction()` to ensure atomic read-modify-write
- **incrementVisitCount()**: Wrapped in `_db.transaction()` to ensure atomic read-modify-write
- **getCellsByFogState()**: Replaced in-memory `.where()` filter with Drift WHERE clause
- **getCellCountByFogState()**: Replaced in-memory count loop with Drift WHERE clause

### 2. collection_repository.dart
- **clearUserCollections()**: Replaced load-all-then-loop-delete pattern with single batch DELETE WHERE operation
  - OLD: Load all records, iterate, delete individually (N queries)
  - NEW: Single atomic `(_db.delete(...).where(...)).go()` operation

### 3. profile_repository.dart
- **addDistance()**: Wrapped in `_db.transaction()` to ensure atomic read-modify-write
- **incrementCurrentStreak()**: Wrapped in `_db.transaction()` to ensure atomic read-modify-write

## Test Results
✅ All 30 persistence tests passed
✅ flutter analyze: 0 errors (pre-existing info-level warnings only)

## Verification
- Transaction usage: 4 methods wrapped (2 in cell_progress, 2 in profile)
- WHERE clause usage: 3 methods updated (2 in cell_progress, 1 in collection)
- Batch delete: 1 method optimized (clearUserCollections)

## Commit
```
🐛 fix(persistence): add transactions and batch delete to repositories
Commit: 118ebfa
```

## Impact
- Eliminates race conditions in concurrent read-modify-write operations
- Improves query efficiency by using database-level WHERE clauses
- Reduces database round-trips in bulk delete operations

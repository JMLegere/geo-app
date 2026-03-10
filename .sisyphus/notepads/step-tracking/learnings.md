# Step Tracking Migration Learnings

## Migration v10 Execution (2026-03-10)

### Pattern Confirmation
- Drift migrations follow consistent pattern: increment schemaVersion, add handler in onUpgrade()
- Use `m.addColumn(table, table.columnGetter)` for adding columns
- Default values with `withDefault(const Constant(0))` ensure backward compatibility
- Non-nullable int columns with defaults prevent null issues

### Code Generation
- `flutter pub run build_runner build` regenerates app_database.g.dart
- Generated code includes:
  - GeneratedColumn<int> definitions with proper metadata
  - Column inclusion in allColumns list
  - Verification metadata for type checking
- No manual edits needed to generated code

### Test Fixture Updates
- When schema changes, all LocalPlayerProfile constructor calls must be updated
- Affected files: ProfileRepository, integration tests
- Use factory functions (makeProfile) to centralize defaults
- Test helpers in test/core/persistence/test_helpers.dart provide createTestDatabase()

### Integration Test Pattern
- Use NativeDatabase.memory() for in-memory test databases
- Import drift.dart with `hide isNotNull` to avoid matcher conflicts
- Test round-trip: insert → read → verify values
- Test defaults: insert without optional fields → verify defaults applied
- Test updates: insert → update → read → verify new values

### Backward Compatibility
- Adding columns with defaults is safe for existing data
- Existing profiles get default values (0) for new columns
- No data loss or migration issues
- All existing tests pass without modification (except fixture updates)

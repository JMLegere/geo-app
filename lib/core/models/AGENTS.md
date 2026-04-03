# core/models

Immutable value objects for all domain entities. No UI, no Riverpod, no I/O.

**23 models total.** Key types: `FogState`, `IucnStatus`, `ItemDefinition` (sealed, 7 subclasses), `ItemInstance`, `Affix`, `FaunaDefinition`, `AnimalType`, `AnimalClass`, `Climate`, `Habitat`, `Season`, `Continent`, `CellProperties`, `AnimalSize`, `CellEvent`, `DiscoveryEvent`.

**Key rules:**
- All models annotated `@immutable`. Manual `toJson()`/`fromJson()` — no code generation.
- `IucnStatus.weight` follows 3^x progression: LC=243, NT=81, VU=27, EN=9, CR=3, EX=1.
- `FaunaDefinition.animalType` auto-computed from `taxonomicClass` in constructor.
- `ItemDefinition` equality by `id` field.
- `ItemInstance.id` is UUID v4.
- `Climate.fromLatitude()` boundaries: 23.5°/55°/66.5°.

See /lib/core/AGENTS.md for full model API and field details.

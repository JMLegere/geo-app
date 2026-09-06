# EarthNova UI acceptance specification — issue 596

**Status: target BDD, not implemented UI acceptance tests.** The user requested the BDD first and then a solution-direction interview. There is deliberately no phased implementation plan here.

The [issue](https://github.com/JMLegere/geo-app/issues/596) and its [final decision sheet](https://github.com/JMLegere/geo-app/issues/596#issuecomment-5554192054) define the desired player experience. This package encodes all **111 remaining-list decisions** plus **27 earlier baseline records** in **53 Cucumber scenarios**. A027 was an obsolete “still open” baseline note; its effective answer is the later visual/interaction-rule decision.

## Read the specification

| Area | Feature |
| --- | --- |
| Palette, tokens, controls, cards, typography | [presentation](../../../features/ui596/presentation.feature) |
| Search, categories, sorting, filters, scroll context | [Pack browsing](../../../features/ui596/pack-browsing.feature) |
| Unknown, shared Base Item knowledge, failure boundaries | [knowledge](../../../features/ui596/knowledge.feature) |
| Modal behavior, overflow, Help, counters | [inspection](../../../features/ui596/inspection.feature) |
| Buttons, Identification, Discovery, sounds, Encounters | [feedback](../../../features/ui596/feedback.feature) |
| Loading, errors, Player isolation, response measurements | [resilience](../../../features/ui596/resilience.feature) |
| Original artwork, small-icon trials, motion, accessibility | [art and accessibility](../../../features/ui596/art-and-accessibility.feature) |
| Properties, rarity applicability, costs, shared-system boundaries | [domain boundaries](../../../features/ui596/domain-boundaries.feature) |

[decisions.json](decisions.json) preserves the normalized answer for every Q001–Q111 and A001–A027 and maps each to one or more stable UI596 scenario IDs. Scenario tags repeat the requirement IDs. Multiple requirements share a scenario where they form one observable outcome; separate success, failure, and identity cases remain distinct.

## Validation and execution status

From the repository root, using its existing Node development dependencies:

```sh
npm install --ignore-scripts --no-audit --no-fund --package-lock=false
npm run spec:ui596:check
npm run superbdd:cucumber
```

- `spec:ui596:check` runs the traceability validator tests, compiles the target Gherkin with the public `@cucumber/cucumber/api` source loader, and verifies all decision references and scenario tags.
- It checks **syntax and coverage**, not whether a running app satisfies the specification.
- The target files live under `features/ui596/`, outside the existing default Cucumber path globs. The existing runtime suite is unchanged.
- Target step definitions are intentionally absent. No catch-all, no-op, “pending means success,” or self-validating UI model has been added.
- Binding these scenarios to real widget, use-case, adapter, visual, or measured evidence belongs to the subsequent solution direction. A separate simulator that merely repeats the Gherkin would not prove Flutter behavior.
- `@behavior` identifies intended observable behavior; `@visual_review` requires rendered evidence; `@calibration` requires actual-size comparative artifacts; `@measurement` requires a measurement protocol; `@specification` describes an integrity boundary.
- Every feature also carries `@target_specification`. These tags describe evidence needed, not passed tests.
- The new syntax/traceability command is explicitly invoked; this change does not silently add a green product-behavior gate to the current CI workflow.

## Recorded validation

Using repository baseline `f96a841b4eba5468ee9c0958b36c52d67c60b3b7`, Node 24.19.0, and Cucumber 12.9.0 (resolved within the repository's existing `^12.2.0` range):

- 53 target scenarios parsed; all 111 question records and 27 baseline records traced.
- 8 validator tests passed, including missing/duplicate decisions, bad scenario references, blank answers, uncompiled scenarios, and source mismatch.
- The existing default Cucumber suite passed: 24 scenarios, 148 steps.
- No target UI behavior, Flutter tests, EAC checks, production calls, or deployment were run by this specification-only task. PR CI supplies repository-wide checks when available.

## Reconciliation with current source

The baseline below was inspected before writing the target specification. Existing code is evidence, not an instruction to discard newer user decisions.

| Source | What it establishes | Consequence for the BDD |
| --- | --- | --- |
| `features/exploration-discovery-pack.feature` | Examination records shared Base Item knowledge; browsing itself is read-only; default order is newest-first | Reuse this meaning for Unknown; keep distinct Item identities and read-only browsing |
| `supabase/migrations/100_item_examination_service.sql` | Journal primary key is Player/user plus Base Item; examination is owner-bound and idempotent | No separate per-instance New flag or second journal is required by the target |
| `supabase/migrations/103_item_examination_base_identity_projection.sql` | Unexamined projection withholds identity and artwork; examined projection reveals permitted content | Actual-icon black silhouettes require a compatible visual projection; asset delivery is a solution question, not secretly chosen here |
| `lib/features/pack/presentation/screens/pack_screen.dart` | Current small viewport uses three columns, text labels and a generic unknown icon | Five columns, names only on selection and actual-art silhouettes are target changes, not claimed current behavior |
| `features/exploration-discovery-identification.feature` | Distinct known-Villager Service; retained exact versions; hold/reveal commits; cancel before commit writes nothing | New visual feedback must preserve this authoritative flow |
| `product/design/organisms/species-card.organism` | IUCN meaning stays scientific | Legacy `rarity` field names are not permission to invent a rarity mechanic |
| `lib/shared/design/foundations/spacing.dart` | Shared spacing values already exist | Calibrate from the existing vocabulary; do not invent a second token system |
| `CONTEXT.md` and ADRs 0008/0010 | Bounded Player-scoped working set; 100ms p95 local response; supported Identification command durability | Keep refresh usable where allowed; never invent broad offline mutation support |

The root guidance references `.agents/constraints.md`, but it is absent from the inspected tree. No contents were assumed.

## Fixed semantics

- **Unknown:** this Player has never inspected this stable Base Item. New and Unknown were two labels for that one mechanic; the canonical label is **Unknown**.
- First successful Examination clears Unknown across that Player's current and future Items of the Base Item. A new version or additional copy does not reset it.
- Unknown artwork is the actual icon shape in black, not a category silhouette. Its shape may be recognizable; full identity metadata and unrolled values must still respect the knowledge boundary.
- Knowledge, per-Item Identification, and the Identification-triggered Discovery milestone remain distinct.
- The 12px/16px animal icons are comparative trials, not production sizes or tap-target sizes.
- Rarity, resource costs, rewards, progression and secondary tabs are conditional on existing defined mechanics. Food/Orb are not forced into Disciplines.
- UI roles come from the design-system palette. Qualitative appearance and selected ratios are specified; unmeasured hex values, font family, frame timings and token dimensions are not fabricated.
- Single-line Item-name shrinking below normal readability was explicitly chosen; preserve the exception and expose its cost in visual review.
- Earlier user instructions prevail over reference imitation. Still screenshots cannot establish unobserved animation or behavior.

## Next conversation

Discuss solution direction before choosing a phased implementation: art production and reuse, the delivery of safe Unknown silhouettes, how the existing Flutter design vocabulary should express the tactile reference, and what evidence should set exact visual tokens. These are topics for the interview, not a selected architecture, dependency list, implementation order, or deployment commitment.


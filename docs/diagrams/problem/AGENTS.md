# Problem Space — Agent Guidance

> These canvases define **what players need** and **why**, independent of implementation.
> They are the source of truth for product scope and player intent.
>
> For implementation details, see `docs/diagrams/solution/`.
> For the full catalog, see `docs/diagrams/index.md`.

---

## What This Is

49 JTBD (Jobs-to-be-Done) canvases organized in a 4-level hierarchy. Each canvas
maps one player need from aspiration down to system requirements.

Every canvas answers: **Who** needs this, **why** they need it, **what** success
looks like, **how** they feel, and **what** the system must provide.

---

## Hierarchy

```
L0  Aspirational goal (1 canvas)
 └─ L1  Core game job (1 canvas)
     └─ L2  Major job areas (10 canvases)
         └─ L3  Specific tasks (37 canvases)
```

| Level | What it captures | Stability |
|-------|-----------------|-----------|
| L0 | Why the game exists — the emotional promise | Permanent. Never changes. |
| L1 | What the player is building — the core loop | Permanent. Changes only if the game pivots. |
| L2 | Major job areas — discover, identify, curate, etc. | Stable. New L2s only for major feature categories. |
| L3 | Specific tasks — navigate map, hold-to-identify, etc. | Evolves. New L3s as features are designed. |

---

## The Tree

```
L0: Become an explorer who discovers and cares about the natural world
 └─ L1: Build and grow my personal wildlife world
     ├─ A: Discover wildlife while exploring the real world
     │   ├─ A.1: Navigate the real-world map
     │   ├─ A.2: Reveal fog-of-war by visiting cells
     │   ├─ A.3: Encounter and collect specimens
     │   └─ A.4: Follow treasure maps (directed quests)
     ├─ B: Identify specimens in my collection
     │   ├─ B.1: Browse and organize my pack
     │   ├─ B.2: Reveal specimen identity (hold-to-identify)
     │   ├─ B.3: Understand specimen stats and traits
     │   └─ B.4: Decide what to keep, donate, or trade
     ├─ C: Curate a sanctuary through donations
     │   ├─ C.1: Discover and browse collections
     │   ├─ C.2: Donate specimens to fill collection slots
     │   └─ C.3: Complete collection bundles
     ├─ D: Reconnect with progress on return
     │   ├─ D.1: Review personal progress (recap)
     │   ├─ D.2: See community milestones
     │   ├─ D.3: Track achievements and milestones
     │   └─ D.4: Maintain daily streaks
     ├─ E: Share my world with other explorers
     │   ├─ E.1: Trade specimens
     │   ├─ E.2: Compare sanctuaries and leaderboards
     │   ├─ E.3: Participate in community goals
     │   └─ E.4: Sense other explorers (ambient presence)
     ├─ F: Manage my explorer identity
     │   ├─ F.1: Create account and sign in
     │   ├─ F.2: Customize profile
     │   ├─ F.3: Manage account settings
     │   └─ F.4: Learn the game (onboarding)
     ├─ G: Tend and nurture sanctuary animals
     │   ├─ G.1: Feed and care for placed animals
     │   ├─ G.2: Place animals in sanctuary (spatial puzzle)
     │   └─ G.3: Observe animal needs and behaviors
     ├─ H: Craft and trade resources
     │   ├─ H.1: Earn and manage orbs
     │   ├─ H.2: Breed specimens
     │   └─ H.3: Craft lures and cosmetics
     ├─ I: Meet NPCs and fulfill requests
     │   ├─ I.1: Discover NPCs on the map
     │   ├─ I.2: Accept and complete NPC bundles
     │   └─ I.3: Visit the town hub
     └─ S: [System] Keep the world growing
         ├─ S.1: Enrich species for identification
         ├─ S.2: Sync data between device and server
         ├─ S.3: Persist progress reliably
         ├─ S.4: Animate the world (spring physics, particles)
         └─ S.5: Observe and monitor system health
```

---

## File Naming

```
{level-or-letter}{number}-{slug}.mmd
```

| Pattern | Example | What |
|---------|---------|------|
| `l0-*.mmd` | `l0-become-explorer.mmd` | L0 aspirational |
| `l1-*.mmd` | `l1-build-wildlife-world.mmd` | L1 core |
| `a-*.mmd` | `a-discover-wildlife.mmd` | L2 job area |
| `a1-*.mmd` | `a1-navigate-map.mmd` | L3 specific task |
| `s-*.mmd` | `s-system-growing.mmd` | L2 system job |
| `s1-*.mmd` | `s1-enrich-species.mmd` | L3 system task |

Files sort alphabetically into the tree order.

---

## Canvas Structure

Every `.mmd` file uses `flowchart TD` with two subgraphs:

### JTBD Subgraph
| Field | What it captures |
|-------|-----------------|
| Job Performer | Who has this need (player archetype or system) |
| Aspirations | The emotional/functional goal behind the job |
| Focus Job | One-sentence job statement |
| Job Steps | **L0-L2**: Child jobs from the hierarchy (the decomposition IS the steps). **L3**: 4-6 concrete user actions (literal UI interactions) |
| Success Criteria | How we know this job is done well |
| Emotions | The feeling arc through the job |

### System Spec Subgraph
| Field | What it captures |
|-------|-----------------|
| Inputs | What data/events trigger this job |
| Outputs | What data/state changes result |
| Skill Feed | Which of the 5 skills this feeds (+1 per action) |
| Gating | What must be true before this job can start |
| Data | Which tables/services are involved |
| Components | Which Flutter/Dart components implement this |
| Resolves | Which critique issues (from `prd-game-systems-review.md`) this addresses |

---

## How to Use These Canvases

### Building a feature
1. Find the L3 canvas for the feature
2. Read the JTBD subgraph to understand the player's goal and emotions
3. Read the System Spec for inputs, outputs, gating, data requirements
4. Cross-reference with the matching solution diagram (e.g., B.2 → `solution/6-4-identification-flow.mmd`)
5. Build to satisfy the success criteria

### Adding a new feature
1. Identify which L2 area it belongs to (A-I or S)
2. Create a new L3 canvas following the naming pattern
3. Fill both subgraphs completely
4. Update this tree and `docs/diagrams/index.md`
5. Create matching solution diagram(s) if needed

### Evaluating a design decision
1. Find the affected canvases
2. Check: does the decision serve the job performer's aspirations?
3. Check: does it satisfy the success criteria?
4. Check: does it preserve the intended emotions?
5. If it conflicts with any canvas, the decision needs discussion

---

## Status Legend

| Tag | Meaning |
|-----|---------|
| NEEDS HUMAN REVIEW | AI-generated, awaiting human review and approval |
| APPROVED | Reviewed and approved by human |
| PHASE N | Part of implementation phase N (see `prd-game-systems.md` §13) |

All canvases are in scope. Nothing is deferred.
All diagrams currently set to `NEEDS HUMAN REVIEW` — first line of every `.mmd` file.

---

## Cross-References

| Canvas | Solution Diagrams | PRD Section |
|--------|------------------|-------------|
| A (Discover) | 6-1, 7-4 | §2 Game Loop |
| A.1 (Navigate) | 8-1 | Backlog: Map & Exploration |
| A.2 (Fog) | — | Backlog: Fog-of-war |
| A.3 (Encounter) | 6-1, 7-4 | §2, §4 |
| A.4 (Treasure maps) | — | Backlog: Treasure maps |
| B (Identify) | 6-4, 7-1, 7-2 | §3 Item Lifecycle |
| B.1 (Pack) | 8-1 | design.md §10 |
| B.2 (Hold) | 6-4, 8-2 | §3, §5 Animation |
| B.3 (Stats) | 7-1 | §6 TCG Card |
| B.4 (Decide) | — | §2 Game Loop (DECIDE step) |
| C (Sanctuary) | 6-5, 7-3 | §7 Sanctuary |
| C.1 (Browse) | 8-1 | §7 |
| C.2 (Donate) | 6-5 | §7 |
| C.3 (Bundles) | 7-3 | §7 |
| D (Reconnect) | 6-6 | §8 Recap |
| D.1 (Recap) | 6-6 | §8 |
| D.2 (Community) | — | §9 Community |
| D.3 (Achievements) | — | Backlog: Achievements |
| D.4 (Streaks) | — | Backlog: Streaks |
| E (Social) | — | §9 Community |
| E.1 (Trade) | — | §9 Trading economy |
| E.2 (Compare) | — | §9 Friendly competition |
| E.3 (Goals) | — | §9 Cooperative milestone |
| E.4 (Presence) | — | §9 Ambient presence |
| F (Identity) | 6-7 | design.md §4 |
| F.1 (Auth) | 6-7 | design.md §4 |
| F.2 (Profile) | — | Backlog: Auth & Accounts |
| F.3 (Settings) | — | design.md §2 |
| F.4 (Onboarding) | — | §1 Core Feel (No Onboarding) |
| G (Tend) | — | Backlog: Sanctuary & Caretaking |
| G.1 (Feed) | — | Backlog: Food system, orb production |
| G.2 (Place) | — | Backlog: Sanctuary placement |
| G.3 (Observe) | — | Backlog: Tamagotchi mechanics |
| H (Craft) | — | §10 Orbs, Backlog: Economy |
| H.1 (Orbs) | — | §10 Orbs |
| H.2 (Breed) | — | Backlog: Breeding |
| H.3 (Craft) | — | Backlog: Orb spend |
| I (NPCs) | — | Backlog: Town tab, NPC bundles |
| I.1 (Discover NPCs) | — | Backlog: Town tab |
| I.2 (NPC Bundles) | — | Backlog: NPC bundles |
| I.3 (Town) | — | Backlog: Town tab |
| S (System) | 5-2, 5-4, 6-2, 6-3 | §4 Enrichment |
| S.1 (Enrich) | 5-2, 6-2, 4-5 | §4 |
| S.2 (Sync) | 6-3, 4-4 | Critique 2.2 |
| S.3 (Persist) | 5-4, 6-4 | Critique 2.4 |
| S.4 (Animate) | — | §5 Animation System |
| S.5 (Observe) | 10-1 | design.md §6, §12 |

# EarthNova Domain

EarthNova is a real-world exploration game in which movement through the world can trigger Encounters and players accumulate persistent Items in Pack. This glossary records only language that has been resolved.

**Status:** Frozen as EarthNova’s current domain foundation on 2026-07-20 after browser review. This freezes the resolved language, not the intentionally open areas: Encounter rates, remaining Outcome and Condition kinds, Condition precedence, Orb behavior, Home Module behavior, Discipline tuning, and the exact bounded-context map. Reopen a settled rule only when play-loop evidence, implementation discovery, or an explicit product decision contradicts it.

## Modeling Heuristic

EarthNova should pair a welcoming, humane player experience with a precise, inspectable systems core. Judge concepts first by whether they create warmth, clarity, low-pressure play, and meaningful attachment; then pressure-test whether their underlying rules are explicit, composable, data-legible, and deep enough to reward mastery. Existing games are comparative evidence, not templates: identify the pattern that makes a reference work, adapt it to EarthNova’s purpose, and preserve EarthNova’s own ontology and voice.

## Language

**Exploration**:
The player activity of moving through and inspecting the world, including entering Cells.
_Avoid_: Discovery when referring to Cell entry

**Player Position**:
The canonical current location of a Player, regardless of which enabled input updates it.
_Avoid_: separate GPS and desktop positions

**Desktop Mode**:
An available, enabled input mode for controlled Desktop Traversal. It changes Player Position input only and preserves native Map mouse click, wheel zoom, and drag pan; it does not change gameplay semantics.
_Avoid_: desktop gameplay rules, a parallel world state

**Desktop Traversal**:
Focused keyboard movement that updates Player Position while Desktop Mode is enabled. Crossing a Cell border creates ordinary Cell Visits and Encounters with no desktop provenance.
_Avoid_: simulated Visits, desktop-only Encounters, input-specific provenance

**Cell Visit**:
One recorded occurrence of a Player entering a Cell; the same Player may have many Cell Visits to the same Cell. Every Cell Visit resolves one Selector whose candidates are stable Encounter Definitions plus an explicit None outcome. Selecting a Definition binds its current published Encounter Definition Version and creates one Encounter; selecting None creates no Encounter. Conditions control first-visit-only content, cooldowns, recurrence, and suppression. A Cell Visit therefore creates zero or one Encounter, never several.
_Avoid_: one permanent Player–Cell association, selection only on first visit, mandatory Encounter, implicit no-event result, more than one Encounter per Cell Visit

**Encounter Definition**:
A stable identity for reusable authored Encounter content. Editing an Encounter Definition creates a new immutable Encounter Definition Version rather than mutating an existing version.
_Avoid_: Encounter occurrence, mutable authored content, Encounter Type values derived from Item Categories

**Encounter Definition Version**:
One immutable version of an Encounter Definition, owning its optional eligibility Condition and one or more Encounter Options. Existing Encounters retain their exact version when newer versions are authored.
_Avoid_: mutable latest-only definition, flattened copy in every Encounter

**Encounter**:
One specific transient occurrence created only when a Cell-entry Selector chooses an Encounter Definition. The Encounter is associated with the Player and Cell Visit, references the selected Definition’s current published immutable Encounter Definition Version, and stores its selected Option, resolution state, and committed Outcome results. Each Cell entry creates at most one Encounter.
_Avoid_: Encounter Definition, latest-version lookup after occurrence creation, implicit None Encounter, Find

**Encounter Option**:
A resolvable branch owned by an Encounter Definition Version. The Player selects among exposed Options; an automatic Encounter Definition Version has one implicit Option. The selected Option resolves one or more Encounter Outcomes in domain-significant order.
_Avoid_: separate automatic-event model, unordered effect bag

**Encounter Outcome**:
One atomic, typed domain operation in the ordered outcome sequence of a selected Encounter Option. Encounter Outcome kinds form a closed, deliberately extended set with explicit payloads; there is no arbitrary script or custom-code escape hatch. Outcomes may generate Items or apply non-Item effects. The concrete initial kind set remains unresolved.
_Avoid_: assuming every Encounter Outcome is an Item; arbitrary order; generic script Outcome; hidden custom behavior

**Encounter Resolution Plan**:
The complete proposed resolution of one selected Encounter Option. Planning evaluates Conditions, resolves Selectors, and simulates every typed Outcome in domain-significant order without mutating durable state. The Plan must validate completely before all Outcomes and results commit in one atomic transaction; if planning or commit fails, no Outcome is applied and the Encounter remains unresolved with an explicit failure.
_Avoid_: partial Outcome commits, persistence during planning, compensation-based normal flow

**Generate Item Outcome**:
The canonical Encounter Outcome kind that references one Selector whose candidates are stable Base Item identities. Resolution selects exactly one Base Item, binds its current published Base Item Version at that moment, creates exactly one Item permanently referencing that Version with no Property Values yet, and places it in Pack subject to the derived Identification rule. The applied Outcome result preserves the resolved Version. Granting multiple Items requires multiple ordered Generate Item Outcomes.
_Avoid_: pinning Base Item Versions in Encounter content, latest-Version lookup after Item creation, Item quantity payload, fixed Item Category, Encounter Type, rolling Property Values before Identification

**Reveal Venue Outcome**:
A canonical Encounter Outcome kind that makes one Venue known to the Player, causing it to appear in Town.
_Avoid_: Discover Venue, Find Venue, generic reveal-target Outcome

**Discovery**:
A durable, player-scoped knowledge milestone recorded the first time the Player identifies a Base Item. Discovery occurs once per Player and Base Item; it is distinct from entering a Cell, receiving an Encounter, acquiring an Item, or identifying later Items generated from the same Base Item.
_Avoid_: Exploration, Encounter, first acquisition, every identification

**Identification**:
The process that reveals which stable Base Item generated an Item and resolves each Variable Property Selector from the Item’s exact Base Item Version, permanently flattening the selected Property Values into the Item. The rule is derived: an Item needs Identification exactly when its stable Base Item has not yet been Discovered by the Player **or** its Base Item Version defines one or more Variable Properties. The first Identification records Discovery against the stable Base Item identity and rolls any Property Values. After Discovery, later Items whose Base Item Version has no Variable Properties are automatically identified; every later Item whose Version has Variable Properties still requires Identification so its values can be selected. Every Item that completes Identification—automatic or explicit—in a Discipline-mapped Item Category grants normal XP to that Discipline; Food and Orb Identification grants no Discipline XP. Identification runs once and never reruns its Selectors.
_Avoid_: Discovery as a synonym; latest Base Item Version lookup; rolling Property Values before Identification; recomputing or rerolling values after Identification; configurable requires-identification flag

**Index**:
The player-facing projection of Base Items the Player has Discovered. Index records durable knowledge; Pack contains the Player’s owned Item instances.
_Avoid_: Field Guide, Journal, Pack

**State**:
The geographic scope between Country and City in EarthNova’s worldwide hierarchy. EarthNova uses State globally rather than varying the term by local jurisdiction.
_Avoid_: Province, Administrative Region


**Home**:
The Player’s one persistent personal-base identity in EarthNova. Every Player owns exactly one Home; relocation, upgrades, or module changes do not create additional Homes.
_Avoid_: Sanctuary, Place, Venue, multiple Homes per Player

**Home Module**:
A component belonging to the Player’s Home. One Home may contain multiple Home Modules; their kinds, limits, installation rules, and lifecycle remain unresolved.
_Avoid_: separate Home, Venue

**Item Category**:
A category of related Base Items that defines common Variable Property schemas. Each new Base Item Version resolves the Item Category’s current common definitions and may add or refine properties for its generated Items.
EarthNova has seven canonical Item Categories: **Fauna, Flora, Mineral, Fossil, Artifact, Food, and Orb**. Category membership and generated Item identity are minimally resolved for all seven. Food has exactly six canonical Base Items, called **Food Types**: **Veg, Fruit, Critter, Fish, Grub, and Nectar**. Orb purpose and behavior remain open.

**Discipline**:
A real-world field of study that is both the authority for one knowledge Item Category’s scientific language and a repeatable, activity-based Player progression track. The canonical mappings are **Zoology → Fauna**, **Botany → Flora**, **Geology → Mineral**, **Paleontology → Fossil**, and **Archaeology → Artifact**; every Player advances in these five through repeated category-relevant actions rather than one-time collection completion alone. Every Identification in a mapped Item Category is one canonical XP source; future Discipline-specific activities may add others. Food and Orb are Item Categories but not Disciplines. The exact XP amounts, level thresholds and curve, cap, other advancement sources, practices, mastery, and unlocks remain unresolved; the old five-Skills diagrams do not canonize them.
_Avoid_: separate Skill concept, first-Discovery-only progression, passive Index completion as the whole progression model, importing practices or unlocks from the old diagrams, forcing Food or Orb into a Discipline

**Discipline Progress**:
The Player-specific progression state for one Discipline, containing accumulated XP and a visible numeric Level derived from XP thresholds. Every Player has one Discipline Progress for each of the five Disciplines.
_Avoid_: separate Skill identity, milestone-only Level without XP, XP without Level

**Base Item**:
A stable abstract identity from which immutable Base Item Versions are authored. A Base Item belongs to one Item Category and exposes one current published Version for future generation. Authored Selectors reference the stable Base Item identity; Discovery and Index entries are also keyed to it, so a new content version does not create a new Discovery.
_Avoid_: Item Definition, Item Template, transitive version pinning in authored selectors, mutable latest-only definition

**Base Item Version**:
One immutable version of a Base Item, containing its intrinsic properties and the effective Variable Properties and Selectors inherited, added, or refined for that version. Editing a Base Item creates a new Version; publishing changes which Version future Item creation binds without changing existing Items.
_Avoid_: flattening full definitions into every Item, mutable selector lookup after binding

**Item**:
A specific player-owned instance generated from and permanently referencing the exact Base Item Version selected at generation. An Item has its own identity and permanently stores the Property Values flattened into it during Identification.
_Avoid_: Base Item, latest Base Item Version lookup, Find, owned find

**Fauna Base Item**:
A Base Item in the Fauna Item Category containing the shared definition for its generated Fauna Items, including taxonomy and Conservation Status. Its friendly player-facing name is **Fauna Species**.
_Avoid_: generic Species when the Fauna/Flora distinction matters; Fauna Item

**Flora Base Item**:
A Base Item in the Flora Item Category containing the shared plant definition for its generated Flora Items. Its friendly player-facing name is **Flora Species**.
_Avoid_: generic Species when the Fauna/Flora distinction matters

**Fauna Item**:
An Item generated from a Fauna Base Item, representing one individual animal. A Fauna Item may be unidentified or identified.
_Avoid_: fauna find, specimen, Fauna Base Item

**Flora Item**:
An Item generated from a Flora Base Item, representing one individual living plant. Harvested materials or produce are separate Items rather than the Flora Item itself.
_Avoid_: plant specimen, harvest stack, Flora Base Item


**Mineral Base Item**:
A Base Item in the Mineral Item Category containing the shared mineralogical definition for its generated Mineral Items. Its friendly player-facing name is **Mineral Species**.
_Avoid_: Mineral Type, Mineral Item

**Mineral Item**:
An Item generated from a Mineral Base Item, representing one physical collected mineral piece. Its friendly player-facing name is **Mineral Specimen**.
_Avoid_: Mineral Sample, Mineral Base Item

**Fossil Base Item**:
A Base Item in the Fossil Item Category containing the shared paleontological classification for its generated Fossil Items. Its friendly player-facing name is **Fossil Taxon**.
_Avoid_: Fossil Type, Fossil Item

**Fossil Item**:
An Item generated from a Fossil Base Item, representing one collected fossil object that may consist of one or several related pieces. Its friendly player-facing name is **Fossil Specimen**.
_Avoid_: Fossil Base Item

**Artifact Base Item**:
A Base Item in the Artifact Item Category containing the shared archaeological object definition for its generated Artifact Items. Its friendly player-facing name is **Artifact Type**.
_Avoid_: Object Type, Artifact Item

**Artifact Item**:
An Item generated from an Artifact Base Item, representing one portable physical object manufactured, modified, or used by humans. Its friendly player-facing name is **Artifact**.
_Avoid_: assemblage, Artifact Base Item

**Food Type**:
The category-specific Base Item concept for Food. EarthNova currently has exactly six canonical Food Types: **Veg, Fruit, Critter, Fish, Grub, and Nectar**. Each Food Type generates discrete Food Items. Food membership comes only from one of these defined Food Types; edibility, origin, or preparation state does not automatically place another Item in Food.
_Avoid_: separate Food Base Item concept; using Critter as an Encounter kind; inferring Food membership from edible, harvested, ingredient, processed, or prepared status

**Food Item**:
An Item generated from a Food Type, representing one discrete unit of that defined food. Its friendly player-facing name is **Food**. Any Pack grouping of equivalent Food Items is an aggregation of units rather than the identity of one Food Item.

**Orb Base Item**:
An explicit Base Item definition whose generated Items belong to the Orb Item Category. Its friendly player-facing name is **Orb Type**. No currency, crafting, container, production, or consumption behavior is implied.
_Avoid_: Orb denomination, inferring Orb purpose from old backlog concepts

**Orb Item**:
An Item generated from an explicitly defined Orb Base Item, representing one discrete Orb unit. Its friendly player-facing name is **Orb**.
_Avoid_: treating Orb as a stack identity or currency without a later decision

**Selector**:
A reusable weighted-choice definition containing Selector Candidates. At resolution, it filters out candidates whose Conditions fail, then chooses exactly one eligible candidate using relative Weight. Zero eligible candidates is an invalid resolution, not a silent no-op or implicit fallback; legitimate optionality requires an explicit None candidate or a Condition on the owning content. The same Selector concept is used wherever EarthNova needs controlled randomness: candidate outcomes may be Base Items, possible values for a Variable Property, drops, or other outcomes.
_Avoid_: Encounter Selector, Item Selector, Base Item Selector, Property Selector, implicit no-op, fallback outside the candidate set, or other use-specific selector nouns unless a future specialization gains independent semantics

**Selector Candidate**:
One possible outcome in a Selector, containing the outcome, a Weight, and an optional Condition. An absent Condition means the candidate is eligible. Weights are applied only after ineligible candidates are removed.
_Avoid_: pre-filtered caller-owned candidate pool, percentage chance stored independently from Weight

**Condition**:
A reusable, typed, read-only predicate that evaluates current context as eligible or ineligible. Conditions compose recursively through typed leaf predicates plus **All**, **Any**, and **Not** nodes; an absent Condition means always eligible. The same Condition concept gates Encounters, Encounter Options, Selector candidates, Services, and other content. Conditions never mutate state and have no arbitrary script/custom-code escape hatch; concrete leaf kinds remain open.
_Avoid_: Encounter Condition, Option Condition, Selector Condition, Service Condition, mutation, generic script Condition, combinatorial purpose-built leaves

**Weight**:
A numeric selection property for a candidate outcome in a Selector. Weight is the only resolved property that controls selection likelihood.

**Variable Property**:
A reusable property definition describing one dimension that varies among Items and owning exactly one Selector for its possible values. Item Categories define common Variable Properties; Base Items may add or refine them. During Identification, every Variable Property defined for the Base Item resolves its Selector to select exactly one Property Value, which is permanently flattened into the Item; absence must be an explicit outcome such as None rather than omission.
_Avoid_: Property Value; storing generated instance values on the Base Item

**Property Value**:
The permanent, flattened result selected for one Variable Property on one specific Item during Identification. Later changes to the Variable Property or its Selector do not change an already identified Item.
_Avoid_: Variable Property, dynamic lookup, recomputation, rerolling through Identification

**Pack**:
The player-facing collection of the player’s Items.
_Avoid_: inventory when naming the product surface

**Venue**:
A discoverable location in EarthNova’s world associated with one or more Villagers, where those Villagers provide Services. Reveal Venue Outcome makes the Venue known from the Map; meeting its Villagers belongs to Venue Visits, not to Encounter resolution.
_Avoid_: Place

**Venue Visit**:
One recorded occurrence of a Player visiting a known Venue. Each Venue Visit automatically introduces every Villager currently associated with that Venue whom the Player has not already met; each newly met Villager and their Services there become visible in Town. The first Visit normally introduces the initial roster, while later Visits can introduce Villagers associated with the Venue afterward.
_Avoid_: Meet Villager Outcome, one-time Venue-wide roster snapshot, separate manual introduction for every Villager

**Villager**:
A named non-player person in EarthNova’s world, following cozy-game convention. A Villager becomes known through the first Venue Visit on which they are present and not already known; this also makes their Services there visible in Town. A Villager provides Services at their Venues.
_Avoid_: Character, NPC in domain or player-facing language

**Service**:
A capability a Villager provides to the Player at one of their Venues.
_Avoid_: Feature in domain or player-facing language

**Town**:
The player-facing index of Venues, Villagers, and Services known to the Player. Town is not a persistent world entity or an alias for a City.
_Avoid_: Town as a geographic container, Place

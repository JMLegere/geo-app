# Identification synchronization replay audit

**Date:** 2026-09-03  
**Outcome Contract:** GitHub Issue #592, approved first deployable slice  
**Command:** `identify_v3_item` only

## Result

The existing production command is suitable for durable client replay. No SQL change or generic command-receipt table is required.

## Evidence

- Migration `088_transactional_item_identification_command.sql` locks the owned Item and immutable receipt rows with `FOR UPDATE`.
- The command validates the authenticated owner, exact Base Item and Base Item Version, current Villager Service identities, dense complete Property plan, and deterministic selected candidates before writing.
- A matching existing explicit receipt and exact `resolution_plan` returns `v3_item_identification_aggregate(item_id)`; it does not write a second result.
- A mismatched replay raises a conflict before mutation.
- Item Property Values, the visible identified Item projection, first Discovery, and the immutable Identification receipt execute in one PostgreSQL function transaction. Any raised error rolls the statement back atomically.
- The aggregate is reconstructed from authoritative rows and the immutable receipt, so response-loss recovery returns canonical state.
- Migration `091_identification_runtime_security_cutover.sql` preserves only authenticated prepare/commit execution and removes the former direct Item update path.
- Existing executable SQL contract tests assert receipt immutability, full plan validation, canonical replay, complete aggregate shape, and absence of `v3_discipline_progress` writes.

## Guardrail

The durable client registry contains only `identify_item`. Cell Visit and every other command remain excluded. The queue persists the minimum already prepared exact identities and selected plan; it contains no auth token, phone number, password material, or provider secret.

# Extraction Fighter development handoff

## Current milestone

MVP 0.5.2 Arena Rewards, Item-for-Item Swap & Post-Match Loot is implemented for local development. A complete Arena victory now flows through results, reward selection, final confirmation, reward summary and lobby. Defeat shows a loss summary and returns to the lobby.

## Architecture

- `ArenaMatchResult` carries a unique result ID, mode, participants and individual inventory owners, winner/loser teams, score, configurable reward limit, processed state and committed transaction summaries.
- `ArenaTradeInventory` is an owner-specific 24-slot ledger over complete profile data. It resolves exact `ItemInstance` identities, eligible main-inventory items and equipped/protected state without pooling 2v2 teammates.
- `ItemSwapTransaction` identifies the result, both owners and exact TAKE/GIVE instance IDs.
- `ArenaRewardService` performs authoritative-result, ownership, eligibility, stale-reference, capacity, duplicate, item-reuse and per-winner limit checks. It snapshots both owners, swaps exact serialized instances, validates uniqueness/counts, persists both through an adapter and rolls back both if either save fails. Transaction/result histories make retries idempotent and results one-shot.
- `ArenaBotRewardFactory` builds deterministic synthetic Common–Rare inventories under independent IDs. Normal local-bot exchanges mutate only cloned ledgers and never save the player's profile.
- `ArenaMatchUI` provides results, three-column reward selection, existing item tooltip/comparison, rarity accents, final confirmation, feedback, subtle transitions and summary. The post-match input mode releases mouse look.
- `PlayerProfile` save version 6 preserves transaction/result histories. Versions 1–5 still migrate through the existing verified temporary-file/backup path.

## Rules and limits

- Every TAKE requires exactly one eligible GIVE; both main-inventory item counts remain unchanged.
- Exact IDs, rolled affixes, rarity and durability are transferred without rerolling.
- Equipped weapons/gear, all skills, keys and definitions marked non-tradable/permanently protected cannot be exchanged.
- 1v1 allows up to 3 swaps; 2v2 allows up to 2 swaps per winning owner. Fewer swaps and skip are valid.
- Rewards require a full non-abandoned authoritative match result. Round wins, kills and abandonment grant no reward access.

## Validation

Validated headlessly with the installed Godot 4.7.2 runtime. `--arena-reward-test` covers both sides of transfer, count/ID/affix/durability integrity, full 24-slot inventories, protected content, invalid owners/stale references, reused items, 1v1/2v2 limits and individual ownership, skip/reopen guards, idempotent retries, persistence rollback, save/restart, bot isolation, abandonment, authoritative gating and free cursor. `--arena-round-test` covers the existing first-to-4/first-to-3 round systems.

## Known limitations

- There is still no networking, matchmaking or remote account authority. Real PvP must supply trusted participant ledgers and a server-side persistence callback to the existing service.
- Local bot exchange is intentionally a non-persistent development simulation and contains no Legendary/Mythic items.
- Validation in this milestone is headless; a manual graphical pass at 1280×720, 1920×1080 and 2560×1440 remains recommended for typography and card density.

## Next safe task

Manually play one 1v1 and one 2v2 victory at each target resolution, inspect tooltip/card density and tune only reward-screen spacing or animation timing. Keep the bot simulation non-persistent.

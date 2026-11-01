# Slime game 202610: static code and feature audit

Date: 2026-10-02

## Scope and limits

Reviewed the supplied `slime game 202610.rbxmx` and the loose `.luau` exports in `D:\로블록스 게임 제작\구`. Read-only review copies are in `review_source/` and `slime game 202610.review.rbxmx`.

The current source folder contains 19 loose `.luau` files. Of these, 3 match their corresponding embedded model script exactly, 15 differ, and `ToppingPromptController.luau` is absent from the `.rbxmx`. The earlier `.rbxm` was visible when first checked, but is no longer present at that path; only the `.rbxmx` is available now. This describes the files currently accessible here, not which export the creator intended as canonical.

## Review copy created

`slime game 202610.reviewed.rbxmx` is a new working copy. It keeps the uploaded `.rbxmx` world/service tree, replaces the 18 matching embedded scripts with the corresponding loose `.luau` exports, removes the direct-root duplicate scripts/modules and the unused empty `DataManager`, and gives `DisplayShelfController` its own `DisplayShelfGui`. The second rebirth's worker-slot bonus is set to +1 so the configured reward is +1 slot per rebirth. `ToppingPromptController.luau` is not injected because it was absent from the model and currently scans all Workspace descendants every Heartbeat without a corresponding server-created pad prompt.

The resulting XML parses, contains 19 script/module instances, has no remaining direct-root script/module copies or `DataManager`, and has one shelf controller under `StarterGui/DisplayShelfGui`. This only verifies the XML/source layout. It does not prove that Roblox Studio accepts the file as a full place or that gameplay runs correctly. The original D: files and the provided model were not overwritten.

This is a static review. Roblox Studio is not connected in this session, so scripts could not be run in Roblox's server/client runtime, DataStore-enabled published server, or multi-client test. “Present” below means code/UI is present; it does not mean runtime-verified.

## High-priority structural findings

1. **The `.rbxmx` contains duplicate server script instances.** Six server scripts (`ToppingCleaningService`, `SlimeZoneServer`, `SlimePvpService`, `WorkerSlimeService`, `RebirthService`, `DisplayShelfServer`) and two modules (`PlayerDataService`, `DataManager`) appear once as direct children of the XML DataModel and again inside `ServerScriptService`, with matching source per pair. If both copies are brought into a live place, separate module instances can create separate player-data session tables and multiple server event handlers. Keep one authoritative copy of each runtime script/module in its intended service.
2. **The model and loose script exports are different revisions.** Several scripts embedded in the `.rbxmx` differ from the loose `.luau` files. Do not import the model over the loose scripts or vice versa until a canonical source is selected. The model's duplicate copies match each other, but they are not consistently the same revision as the loose exports.
3. **There are two worker implementations.** `SlimeZoneServer` creates `Worker_#` models under each plot's `Worker` folder and pays from `SlimePads` under unlocked zones. `WorkerSlimeService` expects a separate `WorkerSlime` model and a `SlimePads` folder directly under a plot. The supplied model has an empty `Worker` folder and zone-nested pads, so the older implementation is currently disconnected from the actual layout. Its upgrade event has no matching control in `WorkerShopGui`.
4. **Plot ownership is incomplete.** The model contains one `PlayerHousing_1` plot while the target server size is about 15. The plot is assigned an `OwnerUserId`, but `PlayerRemoving` does not release it. New players can run out of plots, and old ProximityPrompt connections can remain attached to a plot.
5. **Shelf ownership is global in the current server script.** Per-player slot tables are separate, but all displayed parts are created under `Workspace` at the same single `DisplayShelf` part. The result is not a private display per plot and different players' slots can overlap. The client hides its UI on distance; the server does not enforce distance or an open-shelf session on remote actions.
6. `DisplayShelfEvent` exists in the model but is unused; both shelf scripts create/use a different `DisplayEvent`. `DataManager` is an empty module. `DisplayShelfController` is nested under `ToppingCleaningGui` in the model, while its loose-file description expects a separate GUI.

## Feature status

| Feature | Status from code inspection | Main gap |
|---|---|---|
| Dirty topping machine | Partial | Gives a temporary `Tool`; no persisted Dirty Bag state. Any held/backpack Tool blocks another pull. Prompt discovery runs once at startup. |
| Cleaning table | Partial | Client minigame exists, but server `Start`/`Complete` does not verify the player is near/using the cleaning table. A client can call both remotes directly. Reward goes into a Tool and is not saved in canonical inventory. |
| Display shelf | Partial / unsafe | UI, ten slots, drag/swap and 3D placeholder parts exist. Data is session-only; not plot-private; inventory only permits one Tool; server remote lacks distance, ownership, and open-session checks. |
| Place/retrieve toppings | Partial / unsafe | Click handler and server placement exist. Server does not prove the hit part/position belongs to the caller's plot or validate the item through an inventory service. Items are destroyed/recreated as Tools and are not persisted. |
| Zone unlock | Partial | Configured zone prompts and current-gold spending exist. Saved unlock data is present, but single-plot ownership and prompt lifecycle need fixing. |
| Dirty Bag / Craft Basket / Gacha Cabinet | Not integrated | `BagDataModule` creates in-memory helper tables only. Craft Basket and Gacha Cabinet UI are static; there are no server inventory APIs, persistence, add/remove actions, or recipe save/load flow. |
| Rebirth | Partial | A server request checks configured gold and topping and writes progression through `PlayerDataService`. Still relies on display-name string matching and Tool scanning; aura toggle has no UI call or visual renderer; clearing tools can remove unrelated tools. Stage 2 adds two worker slots, so the configured bonuses accumulate to +3 after two rebirths even though the plan says +1 per rebirth. |
| Worker shop/income | Partial | The current shop can request purchases, and the newer zone worker adds gold. There is no worker upgrade UI flow, no clear feedback for rejected purchases, and the legacy worker service remains as a second, incompatible implementation. |
| PvP | Present but not isolated | Absorb/knockback and pellet growth handlers exist. Player-vs-player touch handling has no PvP-zone check, although PvP is marked non-priority in the plan. Keep it disabled until a dedicated arena/safe-zone rule exists. |
| Slime physical/ASMR | Partial | Character LocalScript has movement/jump/collision sounds and size pitch handling. No central sound manager, focus/mute controls, or priority mixing is connected. |
| Gacha zone / capsule / AFK coin / Robux purchase | Not implemented | No gacha machine/service, currency timer, capsule-open flow, product receipt handling, or stage access enforcement. Gacha Cabinet is only a static UI. |
| Base pump / capacity / upgrades | Not implemented | Only fields in the player-data defaults exist; no pump world object, collection API, refill, or upgrade flow. |
| Encyclopedia | Not implemented | An empty `CollectionBook` data field exists; no discovery recording or UI. |

## Cleanup and implementation order

1. **Freeze a canonical source.** Keep the loose `.luau` exports as the current editable set only after confirming they are the intended latest versions. Retain a backup. Remove/disable duplicate direct-root script copies in the Studio place after comparing their source with the chosen set. Do not keep both copies active.
2. **Set one data owner and schema.** Keep `PlayerDataService` as the only owner of currency/progression and add a server-owned `InventoryService` using stable `ItemId`s. Treat leaderstats and `Tool`s as display/equip projections, not ownership. Add schema version/migration for the existing saved records before changing field names.
3. **Consolidate worker logic.** Choose the newer plot-scoped `Worker_#` design or the old `WorkerSlime` design, then remove the other runtime implementation. Connect purchases, upgrades, income, max-worker slots, saved worker state, and UI to the same APIs.
4. **Finish current loop before adding systems.** Route machine pulls, cleaning results, shelf moves, topping placement/retrieval, and rebirth ingredient checks through the same inventory API. Add server validation for proximity, plot ownership, slot integer/range, inventory ownership, and request rate.
5. **Make plots/shelves per-player.** Assign/release plots by user ID, bind prompts once per plot, save shelf slots as item IDs, and parent display parts under the owning plot. Enforce distance/session validation on server actions.
6. **Finish rebirth semantics.** Store required toppings and rewards by stable IDs in `RebirthConfig`; decide whether the required topping is consumed; reset only declared resettable fields; preserve gacha/event items and collection progress. Apply each rebirth's worker-slot reward exactly once. Add the aura toggle control and renderer or remove the UI promise until implemented.
7. **Add new features only after the above is stable:** pump, encyclopedia, then gacha. For Robux purchases, use server receipt handling; never trust a client request to grant paid currency/items.
8. **Verify in Studio.** Test one player and multiple clients, rejoin/DataStore load-save, respawn, failed DataStore in Studio, plot reassignment, shelf distance/remote spoof attempts, rebirth reset/preserve cases, worker cap/income, and all three inventory flows.

## Cleanup candidates in the source

- Remove duplicate comment blocks and commented-out implementations after choosing the live worker path (`SlimeZoneServer`, `WorkerSlimeService`, `ToppingCleaningService`, `SlimePvpService`).
- Replace duplicated Remote creation with one bootstrap/remote registry that checks both name and class. Existing code often accepts a same-name object of the wrong class and later indexes methods that class does not have.
- Stop using localized display names as persistent identity. `ItemDataModule` should expose `ItemId`, display text, category, rarity, icon, buffs, effects, and tool/model template keys.
- Reduce client-created UI duplication by keeping one controller per feature and moving layout/data out of controller logic where practical.
- Remove unused `DataManager`, `DisplayShelfEvent`, and the legacy worker code only after checking actual Studio references.

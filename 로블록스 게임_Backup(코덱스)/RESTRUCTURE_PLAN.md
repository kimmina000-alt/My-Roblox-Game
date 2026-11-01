# Roblox project restructure: first pass

## Decision

Keep the existing gameplay. Do not rebuild from scratch. Pause new features until player state, currency, inventory ownership, and plot ownership have one server-side source of truth.

## Findings from the supplied Luau files

- `SlimeZoneServer` and `RebirthService` each create separate in-memory player data. Neither is currently the shared source of truth.
- `SlimeZoneServer` creates `Gold` and `Rebirth`; `RebirthService` creates `Total Gold` and `Rebirths`. The worker service pays `Gold`, while rebirth resets `CurrentGold` in its own table.
- The supplied `RebirthService` explicitly uses session-only data; no DataStore load/save path is present in that file.
- `WorkerSlimeService` connects plot startup twice and its upgrade handler targets `PlayerHousing_1` directly.
- `SlimeZoneServer` also targets `PlayerHousing_1`, so plot behavior is not owner-based yet.
- Rebirth checks its own `CommonMaterials` table and the character, but not a canonical inventory record or Backpack.
- `BagDataModule` defines bag-shaped tables, but it does not own persistence or inventory validation.

## Target Studio layout

```text
ReplicatedStorage
  Shared
    Config
      ItemDefinitions
      RebirthConfig
      ZoneConfig
    Remotes
      Inventory
      Rebirth
      Worker
      SlimeZone
ServerScriptService
  Bootstrap.server
  Services
    PlayerDataService
    CurrencyService
    InventoryService
    RebirthService
    PlotService
    WorkerService
    CleaningService
    DisplayShelfService
    SlimeZoneService
  Repositories
    PlayerDataRepository
StarterPlayer
  StarterPlayerScripts
    Controllers
      InventoryController
      RebirthController
      DisplayShelfController
      CleaningController
      ToppingInteractionController
StarterGui
  ... UI instances and their LocalScripts
```

Names are proposed destinations, not instructions to duplicate scripts. Keep one running server script per service and move/rename only after confirming the matching Studio instance.

## Canonical player data, first schema

```lua
{
  SchemaVersion = 1,
  CurrentGold = 300,
  LifetimeGold = 0,
  RebirthCount = 0,
  Inventory = {
    Dirty = {},
    Materials = {},
    Gacha = {},
  },
  UnlockedZones = { Zone_1 = true },
  Workers = { Owned = 0, Upgrades = {} },
  CollectionBook = {},
  Gacha = { Coins = 0, UnlockedZones = {} },
  Aura = { Unlocked = {}, Equipped = nil },
}
```

`leaderstats` becomes a display projection only. Use `Gold` for current spendable gold, `LifetimeGold` (or a clearly named display value) for cumulative earned gold, and `Rebirths` for the count. Gameplay services must call `CurrencyService` rather than creating or changing separate gold values.

## Safe implementation order

1. In Studio, map each supplied file to its actual Instance path and identify duplicate enabled scripts. Make a project backup before moving Instances.
2. Define the canonical schema, currency meanings, item IDs, and rebirth reset/preserve policy. Do not migrate live saves until the schema is agreed and backed up.
3. Add `PlayerDataService` and a repository that load, validate, migrate, and save one record. Preserve the current first-join grant of 300 only for genuinely new records.
4. Make `leaderstats` a projection of that record. Remove competing creation from `SlimeZoneServer` and `RebirthService`.
5. Route worker earnings, upgrades, zone purchases, and rebirth through the shared currency/data services. Resolve plot ownership by `OwnerUserId`, not `PlayerHousing_1`.
6. Connect inventory ownership and item IDs to cleaning, display shelf, placement, and rebirth requirement checks.
7. Only after the existing loop is coherent, add pump, collection book, and gacha features.

## Decisions that must be made before implementation

- Is `LifetimeGold` lifetime earned gold or lifetime net amount after purchases? The suggested schema assumes earned gross total.
- Does a required rebirth topping get consumed on rebirth?
- Does every rebirth give one additional worker, and is income bonus multiplicative per stage or additive?
- Are display shelf slots part of the same owned inventory, or do displayed items leave the inventory? Recommended: display is a location for an owned item, not a second copy.
- Which item IDs correspond to the current Korean display names? Do not use display names as persistent IDs.

## Studio mapping before Explorer moves

The service scripts now have a shared player-data path, but the supplied files are loose exports rather than the `.rbxlx` project. Before moving Instances into folders, confirm their actual Explorer parents and whether any duplicate scripts are enabled. Put `PlayerDataService.luau` in ServerScriptService as a **ModuleScript** beside the three server scripts that require it.

## Implemented in the supplied loose-script folder

The following first-pass changes were made under `D:\로블록스 게임 제작\구` after saving all 18 files in `_codex_backup_20261002_all`. That snapshot was taken after the earlier WorkerSlime duplicate-loop fix; `_codex_backup_20261002` contains the original versions of the four core files from before that first edit.

- Added `PlayerDataService.luau` as the server-side owner of saved player progression, current and lifetime gold, leaderstats, load/save, autosave, and runtime-only worker references.
- Reworked `RebirthService.luau` to validate against the shared player record, reset current gold and ordinary materials, preserve gacha/limited tools by attributes, award configured rewards, and stop creating separate leaderstats/session data.
- Updated `RebirthConfig.luau` so an undefined next stage returns `nil` instead of silently repeating the last rebirth forever.
- Connected `SlimeZoneServer.luau` worker income, worker purchases, zone purchases, and plot owner assignment to the shared data service. Worker counts now live in the saved record and are reconstructed on join.
- Connected `WorkerSlimeService.luau` income and upgrades to the shared currency service and removed the duplicate worker-loop startup registration.
- Updated the rebirth UI for a completed final stage and removed the nonfunctional rebirth button from `WorkerShopGui.luau`.

## Still pending before calling the architecture complete

- `ToppingCleaningService`, `DisplayShelfServer`, `InventoryClientController`, and `BagDataModule` still use Tool/local tables as item state. Their inventory ownership is not yet persisted by `PlayerDataService`.
- `DisplayShelfServer` has one shared Workspace shelf and keeps slot state in memory. It needs to move slot data into saved per-player state and use a player-owned plot/shelf relationship.
- Current item identity still uses localized item names instead of stable IDs. Item migration and backward-compatible save normalization remain pending.
- The worker service's older `WorkerSlime` path and SlimeZone's spawned `Worker_#` models remain separate implementations; only their gold and progression authority was aligned.
- Aura unlock/toggle state is saved, but no character visual effect renderer is connected yet.
- Map the actual Studio Instances before rearranging Explorer folders. Place `PlayerDataService.luau` as a ModuleScript under ServerScriptService, and confirm DataStore access settings before publishing.

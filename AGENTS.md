# FarmGame agent instructions

## Working agreement

- Work directly in the user's local FarmGame checkout, where `default.project.json` and `resources.project.json` live. Check the working tree before editing and preserve the user's changes. Use the current checkout and Rojo mappings to verify paths, instance names, and behavior.
- Use Git for inspection only. Do not stage changes, create branches or worktrees, run `git commit`, or run `git push`. Leave the edits in place for the owner to review and commit in Sourcetree.
- Make the smallest change that completes the request. Take routine implementation decisions yourself. Confirm material gameplay choices, major rewrites, destructive changes, and publishing with the owner. For diagnosis-only requests, report the cause and the proposed fix in chat.

## Luau style

- Do not add comments to code, including Luau embedded in Roblox assets. Use clear names, direct control flow, and the style of the surrounding code. Keep functions short enough to follow without sacrificing clarity.
- Extend the module or service that owns the behavior. Generalize a working implementation when current features share the same rule. Reuse the project's configs, handlers, and helpers. Avoid duplicate systems, boilerplate, speculative abstractions, and unrelated cleanup.
- Keep essential validation at the boundary that owns it, especially remote input, ownership, inventory and balance changes, and persistence. Reuse established checks and rely on their guarantees in downstream code.

## Rojo and Studio

| Project file | Mappings |
| --- | --- |
| `default.project.json` | Farm. `src/server` → `ServerScriptService`, `src/shared` → `ReplicatedStorage`, `src/client` → `StarterPlayer.StarterPlayerScripts`, `src/gui` → `StarterGui`, `src/workspace` → `Workspace`. |
| `resources.project.json` | Resource world. Maps the shared `WorldTravelService`, `PortalHandler`, and `WorldTravelConfig`, plus `src/places/ResourceWorld/TravelPortals` → `Workspace.TravelPortals`. |

- Use the Rojo version pinned in `rokit.toml`. Serve the farm with `rojo serve` and the resource world with `rojo serve resources.project.json`. Follow the existing `.server.lua`, `.client.lua`, `.lua`, and `.rbxmx` conventions. Change Rojo mappings only when the task requires it.
- Check which place is open and which instances Rojo manages before syncing or editing in Studio. Preserve Studio-only instances and unsaved work. Save changes to Rojo-managed scripts, GUIs, and models in their mapped source files. For a required Studio-only edit, give the owner the exact Explorer location and properties if it needs to be applied manually.

## Gameplay systems

### Economy and inventory

- Use `ItemDefinitions` for stable item IDs, icons, and `BuyPriceCents` / `SellPriceCents`. Keep prices and balances in integer cents and format them for display in the GUI. Reuse `BuyService`, `SellService`, `MoneyService`, `InventoryService`, and `StorageService` where applicable.
- Keep the server authoritative for prices, item counts, permissions, and inventory capacity. Preserve existing remote contracts and the six-slot inventory's stacking behavior. A rejected purchase, sale, transfer, or craft must leave money and items consistent. Reuse `InventoryService` exchange methods for multi-item changes.

### Player data

- Follow the existing `PlayerDataHandler` and `PlayerDataService` lifecycle for money, inventory, and placed objects. Preserve the `DataLoaded` gate and the save paths for leaving, server shutdown, and travel. Use defaults for genuinely new players and keep failed loads from overwriting progress.
- Keep the DataStore name, player key format, and saved item IDs compatible. Reuse `PlotDataService`, `PlantDataService`, `ProductionDataService`, and `StorageService` for serialization. Preserve plot-relative pivots and support older saves when adding fields. Use isolated test data for save and rejoin checks.

### Plots, farming, and production

- The farm uses four plots in `Workspace.Plots`. Reuse `PlayerPlotService`, `PlacementRules`, `PlacementService`, and `PlantService` for ownership, placement, planting, growth, and harvesting. Preserve the `PlotName` and `OwnerUserId` contracts. Keep model anchors such as `PlacementRoot` and `PlantingSpots` stable when changing visuals. Keep access to spawns and shops clear when editing the map.
- Extend `ProductionService`, `ProductionRecipes`, and the existing production controllers and GUI for new stations. Opening HandMill mode and selecting a recipe are separate from starting a batch. Keep completed output in the station's `OutputInventory` until collection succeeds. Preserve cancellation and restore input and camera state on exit or interruption.
- Treat ideas from design chats, such as seed discovery and breeding, as proposals until requested. When extending progression, make item value and available upgrades easy to see in the existing UI.

### GUI

- Reuse the existing shop, inventory, storage, and production views. Populate item and recipe lists from their definitions and use shared card templates where the behavior matches. Keep layout work focused on the requested screen and preserve instance names and embedded scripts that other code relies on.
- Match the game's warm colors, readable labels, and item icons. Use a supplied Figma design or screenshot as a visual reference. Verify desktop and both phone orientations, including scrolling, tap targets, and space for movement and jump controls.

### World travel

- Reuse `PortalHandler`, `WorldTravelService`, and `WorldTravelConfig` for both portal directions. Keep place IDs in the config and verify both Rojo mappings when changing shared travel code. Preserve the farm save before departure, recovery on failure, and the return-to-farm fallback. Use teleport metadata for routing only.
- Check portal setup in Studio. Verify actual round-trip travel and restored progress in an authorized published test environment.

## Verification and handoff

- Review the diff and run the checks relevant to the change. For Rojo-managed edits, build the affected project to a temporary file. For gameplay, use Studio Play when available and check Output. Exercise the normal flow and the affected failure case, such as a full inventory, a save and rejoin, or another player trying to use a plot they do not own.
- Reply briefly in Russian with the changes and what you verified. Name the files and functions when that helps review, and list any remaining Studio steps. Put explanations in chat and create only the files needed for the task. End with one proposed Git commit message for the owner to use.

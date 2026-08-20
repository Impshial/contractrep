# Contract

Contract is a small Godot 4.7.1 learning project. The current milestone builds an open-world factory board, camera zoom/pan, reusable Conveyor placement, generic item transport, finite Wood, Iron Ore, Coal, and Stone resources, Miners, Furnaces, Exchangers, Iron Plates, controllable Basic Bots with manual harvesting and depositing, data-driven JSON content definitions, and named in-game saves.

## Project Structure

- `scenes/main.tscn` is the startup scene.
- `scenes/buildings/conveyor.tscn` is the Conveyor building scene.
- `scenes/buildings/miner.tscn` is the Miner building scene.
- `scenes/buildings/furnace.tscn` is the Furnace building scene.
- `scenes/buildings/exchanger.tscn` is the Exchanger building scene.
- `scenes/items/iron_ore.tscn` is the current generic item scene; the script configures whether it displays Iron Ore, Coal, Stone, or Iron Plate.
- `scenes/ui/toolbar.tscn` contains the bottom toolbar.
- `scripts/Board.gd` owns grid coordinate conversion, bounds checks, terrain state, resource deposits, and cell occupancy.
- `scripts/CameraController.gd` controls zooming, panning, and the initial centered view.
- `data/contract/` contains the built-in Contract content package.
- `scripts/data/DefinitionLoader.gd`, `DefinitionManager.gd`, and `DefinitionValidator.gd` load and validate JSON content definitions.
- `scripts/data/GameDefinitions.gd` is a compatibility facade over the loaded definition registry.
- `scripts/FactorySimulation.gd` advances factory logic at a fixed tick rate.
- `scripts/GridRenderer.gd` draws visible open-world terrain, resource deposits, and the optional grid.
- `scripts/buildings/Building.gd` is the reusable base class for grid buildings.
- `scripts/buildings/Conveyor.gd` draws conveyors and tracks up to six stackable held items.
- `scripts/buildings/Miner.gd` tracks Miner production progress and pending output.
- `scripts/buildings/Furnace.gd` owns Furnace inventory rules and smelting progress.
- `scripts/buildings/Exchanger.gd` owns one-item transfer state and directional logistics behavior.
- `scripts/inventory/Inventory.gd` and `scripts/inventory/InventorySlot.gd` define slot-based inventories shared by Containers, Furnaces, the Player, and bot internals.
- `scripts/items/FactoryItem.gd` stores item type, logical grid position, and smooth visual movement.
- `scripts/PlacementController.gd` handles preview, rotation, placement, removal, and canceling placement mode.
- `scripts/resources/ResourceDeposit.gd` defines reusable terrain resource deposit data.
- `scripts/SaveManager.gd` saves and loads placed factory state as JSON.
- `scripts/ui/Toolbar.gd` emits which building the player selected.
- `scripts/MainGame.gd` connects the toolbar to placement, robot controls, and prototype input actions.
- `scripts/robots/Robot.gd` owns one robot unit, its selected state, assigned sprite, path-following movement, and facing direction.
- `scripts/robots/RobotNavigation.gd` owns the shared `AStarGrid2D` navigation data for robot pathfinding.
- `scripts/robots/RobotController.gd` owns robot spawning, selection, multi-selection, movement commands, path requests, simple visual separation, and robot save/load state.
- `scripts/WorldGenerator.gd` generates deterministic terrain and forest variant choices from the active world seed.

## JSON Definitions And Data Mods

Contract loads configurable startup content from JSON. GDScript still implements behavior, while JSON defines content values such as item names/icons, resource properties, building inventory layouts, machine timing, bot stats, terrain metadata, recipes, and world-generation tuning.

Built-in content is loaded as the base package from `data/contract/manifest.json`. Future data mods are discovered from `user://mods/`, where each mod folder needs a `manifest.json` and any supported definition folders:

```text
user://mods/example_mod/
    manifest.json
    items/
    resources/
    buildings/
    bots/
    recipes/
    worldgen/
    patches/
```

Definition IDs are namespaced, such as `contract:stone`, `contract:container`, and `contract:basic_bot`. Existing legacy IDs such as `stone`, `iron_ore`, and `chest` are normalized for compatibility with older saves and current runtime paths.

Load order is base `contract`, then user mods in `user://mods/`, then explicit patch files. Duplicate full definitions are rejected unless the replacement includes `"override": true`. Patch files can alter one existing value without copying an entire definition; see `examples/mods/basic_bot_slow_harvest/`.

Asset paths in JSON are package-relative. The base package sets `"asset_root": "res://"` so `"assets/resources/stone.png"` resolves to `res://assets/resources/stone.png`. User mods default to their own mod folder.

Current supported definition types are `item`, `resource`, `building`, `bot`, `player`, `recipe`, `terrain`, and `worldgen`. Code mods, hot reload, mod browser support, and arbitrary mod scripts are intentionally not supported yet.

Saves include loaded content-pack metadata. When loading a save, Contract checks that required content packs are present before building the world. Static definitions are not serialized into saves; save files store runtime state and definition IDs.

## Procedural Terrain

Contract generates open-world terrain from deterministic world coordinates and a world seed using Godot's `FastNoiseLite`. The current terrain layer supports four types: Ground, Water, Rock, and Forest.

Terrain is stored on `Board` separately from resource deposits, buildings, and factory items. `WorldGenerator.gd` reads tuning from `contract:default_planet`, uses seed `847291` by default, and forces the starting site around `(0, 0)` to clear Ground.

Forest tiles use one of 16 supplied transparent `48x48` variants from `assets/terrain/forest/`. The selected forest variant is deterministic per cell, so zooming, resizing, saving, loading, or redrawing does not reshuffle the trees. Reusing the same seed reproduces the same terrain and Forest variant layout; changing the seed through `Board.generate_terrain(seed_value)` creates a different world.

## Resource Deposits

Resource deposits are board data, not buildings. A cell can contain an Iron Ore, Coal, or Stone deposit and still have an empty building slot. This lets a Miner be placed on top of a resource without treating the deposit itself as an occupied building.

The current world procedurally generates finite Iron Ore, Coal, and Stone fields from the active world seed, and every Forest tile is also a finite Wood resource. A starter field of each mined resource appears within about 25 tiles of spawn. Beyond the starter fields, deposits are intentionally rare and spaced out. Stone is the most common field type, Coal is less common, and Iron Ore is rarest. Field occurrence is independent from field size, and large fields are rare. Individual deposit tiles are richest near the center of a generated field and thinner near the edges. `GridRenderer.gd` loads resource textures from JSON definitions. When a resource reaches zero, it no longer draws as a resource; depleted Forest turns into traversable Ground and remains gone after save/load.

## Definitions And Categories

Resources and placeables are intentionally separate concepts.

- Resource deposits are terrain data, such as Iron Ore, Coal, and Stone.
- Factory items are things that can move on belts. Iron Ore, Coal, Stone, and Lumber are all `RESOURCE` items.
- Placeables are player-built entities. Conveyors and Exchangers are `LOGISTICS`; Miners are `EXTRACTION`; Furnaces are `SMELTING`.
- Iron Plate is an `INTERMEDIATE` factory item. Furnace inventory contents are still items, not placeables.
- Placeable categories are loaded from building definitions. Containers are `STORAGE`, Conveyors and Exchangers are `LOGISTICS`, Miners are `EXTRACTION`, and Furnaces are `SMELTING`.

Conveyors transport generic `FactoryItem` instances. They do not contain Iron-Ore-specific, Coal-specific, Stone-specific, Lumber-specific, or Iron-Plate-specific movement logic.

## Camera

The board uses large open-world bounds. The camera starts centered around spawn, zoomed to show roughly the original 20-cell-wide working area.

- Mouse wheel zooms in and out.
- Middle mouse drag pans.
- `W`, `A`, `S`, and `D` pan the camera.

## Placement System

The toolbar emits a `PackedScene` for the selected building. `PlacementController` instantiates a translucent preview and asks the preview building whether the mouse-snapped grid cell is valid.

Placed buildings are registered in `Board` by their `Vector2i` grid cell. The board dictionary lets the game ask whether a cell is occupied and which `Building` is in that cell.

If a conveyor containing items is removed, the current prototype deletes those items too. That keeps board and item state consistent until a later inventory or item-dropping system exists.

Conveyors can be placed on any empty in-bounds cell. Miners can only be placed on an empty cell containing a supported resource deposit.

## Factory Simulation

The `FactorySimulation` node starts running when a new game or loaded game begins, and runs while the toolbar button says `Pause`. It accumulates frame time in `_process()` and advances factory logic every `tick_seconds`.

Each tick has two phases:

1. Plan valid moves from the current conveyor state.
2. Apply those moves after planning is complete.

This avoids conveyor movement depending on Godot scene-tree order. An item moves at most one conveyor cell per simulation tick. If the next conveyor is missing or outside the board, the item waits. If the next conveyor is full, the item moves only when that destination has room or enough outgoing items planned during the same tick.

## Conveyor Transport

Each conveyor may hold up to six stackable `FactoryItem` instances. Conveyors do not care whether that item is Iron Ore, Coal, Stone, Lumber, or Iron Plate. On a tick, a conveyor tries to move its item to the adjacent grid cell in its facing direction. If that destination cell contains an empty compatible logistics target and the item is not entering from a rejected direction, the item transfers to it. The next tick uses the new holder's direction, so turns work naturally.

Logical item movement and visual movement are separate. The item's `logical_grid_position` changes immediately when the tick transfers it. Its `Node2D.global_position` follows a queue of conveyor-center waypoints at a speed matched to the simulation tick, so ore follows turns cleanly instead of cutting diagonally when its next target changes.

## Miner Production

Miners are normal rotatable buildings. A Miner can only be placed on a resource deposit and produces one item matching the deposit underneath it every `PRODUCTION_DURATION_SECONDS`.

Miner production is advanced by `FactorySimulation` ticks, not by per-Miner timers. Each tick, conveyors move first, then Miners advance production and try to output.

Miner state is intentionally small:

1. `production_progress` fills while producing.
2. `pending_output` becomes true when one Iron Ore is ready.
3. If the facing cell contains an empty Conveyor, the pending item is spawned onto that Conveyor.
4. If output is blocked, missing, or outside the board, the Miner keeps that one pending item and stops producing more until output succeeds.

The Miner progress bar is green while producing and orange while output is blocked.

## Slot Inventories

Containers, Furnaces, and the Player use the same slot inventory model. Each slot holds one item stack up to 100 units and has a role: `Storage`, `Input`, or `Output`.

- Containers have 40 Storage slots in four rows of 10.
- The Player inventory has 30 Storage slots in a left-side drawer.
- Furnaces have two Input slots, one Output slot, and 10 manually usable Storage slots.

Left click an inventory-capable building to open the centered inventory window. The Player drawer remains usable at the same time, so items can be moved between the drawer and the building window. A global cursor stack follows the mouse while an item is held; closing windows or clicking outside inventory slots leaves the held stack unchanged. Left click picks up or places a whole stack, `Shift + left click` picks up one item, and `Ctrl + left click` picks up half rounded up. Output slots allow manual removal but reject manual placement.

## Furnace Smelting

Furnaces are one-tile `SMELTING` placeables. A Furnace has no dedicated input or output side. Adjacent Exchangers load ingredients and unload products.

Each Furnace owns a slot inventory. Its dedicated Input slots accept Iron Ore and Coal, and its Output slot accepts machine-produced Iron Plates. Its 10 Storage slots are visible and manually usable, but the current recipe only consumes from the dedicated Input slots and only produces into the dedicated Output slot.

The current recipe is `1 Iron Ore + 1 Coal -> 1 Iron Plate` and takes 2.0 seconds. Furnace smelting is advanced by `FactorySimulation`, not by a per-Furnace timer. The Furnace only progresses while it has at least one Iron Ore, at least one Coal, and output space for an Iron Plate. Ingredients are consumed only when the Iron Plate can be stored.

Left click a Furnace while not placing a building to open the shared inventory window. The window closes with `Escape` or `X`.

## Exchangers

Exchangers are one-tile `LOGISTICS` placeables. Each Exchanger can hold one `FactoryItem` and moves material in the direction of its arrow. It is a stationary transfer tile, not a moving arm.

An Exchanger beside a building can operate in two building-agnostic directions:

- `LOAD BUILDING`: the arrow points from the logistics side toward the building. The Exchanger asks the building if it can accept the held item.
- `UNLOAD BUILDING`: the arrow points away from the building. The Exchanger asks the building if it can provide an item, then creates that item as its held transfer state.

Press `R` while placing an Exchanger, or while hovering a placed Exchanger, to flip its arrow 180 degrees. Exchangers automatically align to an adjacent inventory-capable building when placement is along a new axis.

Buildings own inventory policy through methods such as `can_accept_factory_item`, `accept_factory_item`, `can_provide_factory_item`, `peek_provided_factory_item_type`, and `provide_factory_item`. The Exchanger does not know Furnace-specific slot rules. For this milestone, Furnace accepts Iron Ore and Coal, rejects Iron Plate as input, and only provides Iron Plate.

Exchanger-to-Conveyor transfers use the Conveyor's existing `can_accept_item_from` directional-entry rule. Exchanger-to-Exchanger transfers require the destination Exchanger to be empty and facing so the item enters from its logistics input side.

Exchangers can also bridge two conveyor lines. When an empty Exchanger has a charged transfer, it may pull an item from the logistics holder behind its arrow and move that item toward the holder in front of its arrow, even if the source Conveyor is traveling in another direction. Exchanger transfers use a 0.75 second cadence, slower than the 0.5 second Conveyor tick.

When an Exchanger points away from a Container, it treats the container as a source inventory and automatically pulls the first belt-compatible stored item. Current belt-compatible container items are Iron Ore, Coal, Stone, Lumber, and Iron Plate.

## Manufacturing Robots

New games spawn three Basic Bots near the center starting area. All Basic Bots use the same transparent `48x48` robot sprite from `assets/robots/robot_04.png`.

Robot sprites are authored facing South. While a robot moves, `Robot.gd` rotates the assigned sprite to face one of eight directions, including diagonals. When a robot stops, it keeps the last movement-facing direction.

Controls:

- Left click a robot to select only that robot.
- Shift + left click a robot to add or remove it from the current selection.
- Left click empty terrain to clear robot selection.
- Right click terrain to move all selected robots with grid-based pathfinding.
- Right click a harvestable resource to send selected robots to adjacent walkable cells and harvest it manually.
- Right click a Container to send selected robots there and deposit their carried inventory.

Robot navigation uses one shared `AStarGrid2D` built from the Board's terrain and occupancy data. Ground and resource-deposit cells are walkable. Forest, Rock, and Water are blocked. Placed buildings block robot movement, except Conveyors, which remain walkable for now. Robot paths can include diagonal steps when the diagonal route is traversable.

If the player right-clicks an impassable non-resource tile, the controller searches nearby cells for the nearest reachable walkable destination. If the player right-clicks a harvestable resource, each selected bot tries to reserve one of the eight neighboring walkable cells before harvesting from there. If no route exists, the robot rejects the command and stays put. Multiple selected robots reserve nearby destination cells around the clicked target, and a small visual separation offset keeps robots from drawing directly on top of one another without pushing them off their valid path.

Basic Bots carry an internal inventory and harvest in configurable cycles from `contract:basic_bot`. The current Basic Bot holds 5 items, and each harvest cycle takes 5.0 seconds and yields 1 item. The in-world harvesting bar shows cycle progress. Cycle payout is atomic: the bot only starts/completes a payout when its inventory can accept the full cycle yield. Harvesting reduces the shared resource quantity only when a cycle completes, so multiple bots can work the same resource without duplicating the final units. Manual harvest assignments are represented as lightweight `BotJob` instances, separate from the bot's current movement, harvesting, depositing, or waiting state. When a target resource depletes, the bot searches for the nearest reachable resource that produces the same inventory item and continues the same harvest job there. When a bot needs to unload while harvesting, it finds the nearest reachable Container with enough room, falls back to the nearest reachable Container with any room, deposits from any reachable adjacent side, and returns to the same resource if it still exists. If no Container is available but the bot still has inventory space, it keeps harvesting until its inventory is full. Once a new reachable Container is placed, waiting harvest bots route to it, unload, and resume their harvest target. They do not build, use tools, consume energy, handle terrain costs, clear non-resource obstacles, build bridges or roads, or perform advanced crowd simulation yet.

Robot inspection shows a current work designation derived from the active task. Wood harvesting displays `Wood Cutter`, mining resources such as Iron Ore, Coal, and Stone displays `Miner`, container trips display `Hauler` when no harvest target is active, and idle bots display `Idle`.

## Saving And Loading

When Contract starts, a centered startup dialog offers `New Game`, `Load Game`, and `Quit`. `New Game` clears the current factory state and generates a fresh terrain seed. `Load Game` opens the existing load dialog. `Quit` exits the game.

Use the Escape menu or `F5` to open the Save dialog during play. Saves are named by the user. Use the Escape menu or `F9` to open the Load dialog, choose a named save, and preview its thumbnail.

The game stores a JSON save catalog internally at `user://contract_saves.json`; the player interacts only with in-game dialogs. Each save stores:

- Placed Conveyors and their facing directions.
- Placed Miners, their facing directions, mined resource type, production progress, and pending-output state.
- Placed Furnaces, their slot inventories, and smelting progress.
- Placed Containers and their slot inventories.
- Placed Exchangers, their facing directions, and any held item.
- Items currently assigned to Conveyors, including whether each item is Iron Ore, Coal, Stone, or Iron Plate.
- Player inventory slots.
- A small thumbnail captured from the game view.
- The active world seed, so loading restores the same generated terrain layout.
- Robot positions, Basic Bot numbers, inventories, selected sprite design, facing directions, and movement state. Moving robots recalculate their saved route after loading; active harvesting resumes as Idle after loading.

Resource quantities are stored in the save file, including partial and depleted resources. Terrain is regenerated from the saved world seed, then saved resource quantities are restored before buildings and items are restored. Loading pauses the simulation so the restored layout starts in a stable state.

When the renamed Contract save catalog does not exist yet, `SaveManager` performs a one-time compatibility migration by looking for the previous save catalog and copying its contents into `user://contract_saves.json`. The old save data is left in place.

## Diagnostics Logs

Contract writes freeze and heartbeat diagnostics to `user://diagnostics.log`, which maps to `C:\Users\impsh\AppData\Roaming\Godot\app_userdata\Contract\diagnostics.log` on this Windows machine. The diagnostics logger also prints the same main-thread events into Godot's normal run log.

Diagnostic entries include a startup line, periodic heartbeat stats, `FRAME_STALL` entries when a frame resumes after at least 500 ms, and `WATCHDOG_HANG` entries when a background watchdog sees the main thread stop updating for at least 2 seconds. During play, this PowerShell command tails the diagnostics log:

```powershell
Get-Content "$env:APPDATA\Godot\app_userdata\Contract\diagnostics.log" -Wait -Tail 50
```

## Temporary Test Spawning

This is a development-only control for testing transport:

- Exit placement mode with `Escape` if needed.
- Hold `Shift` and left click an empty conveyor to spawn one Iron Ore item.
- Spawning fails safely if the cell has no conveyor or the conveyor is full.

## Controls

- Click `Conveyor` to enter placement mode.
- Click `Miner` to enter Miner placement mode.
- Click `Furnace` to enter Furnace placement mode.
- Click `Exchanger` to enter Exchanger placement mode.
- Click `New Bot` to spawn and select one additional Basic Bot near the center start area.
- Move the mouse to snap the preview to the grid.
- Press `R` to rotate clockwise.
- Left click to place on a valid empty cell.
- Hold left click and drag while placing Conveyors to paint multiple belts.
- Press `R` while not placing to rotate the placed building under the mouse. Exchangers flip between load and unload directions.
- Left click a Container or Furnace while not placing to open its inventory.
- Click the left-side `INV` tab to open or close the Player inventory drawer.
- Right click an existing conveyor to remove it.
- Select a Basic Bot and right click a tree, Iron Ore deposit, Coal deposit, or Stone deposit to harvest from an adjacent tile. Accepted harvest commands flash a short marker on the clicked resource.
- Select a loaded Basic Bot and right click a Container to deposit carried resources.
- Press `Escape` to exit placement mode.
- Hold `Shift` and left click a conveyor while not placing to spawn Iron Ore.
- New and loaded games start running automatically. Click `Pause` to stop conveyor ticks, and `Run` to resume them.
- Open the Escape menu or press `F5` to save the current factory.
- Open the Escape menu or press `F9` to load a saved factory.
- Press `F3` to toggle the Details overlay with FPS and current Conveyor, Miner, Furnace, Exchanger, Iron Ore, Coal, Stone, and Iron Plate counts.
- Mouse wheel zooms the camera.
- Middle mouse drag or `WASD` pans the camera.

## Miner Manual Tests

- Place a Miner on Iron Ore: it should place successfully.
- Place a Miner on Coal: it should place successfully.
- Place a Miner on Stone: it should place successfully.
- Try placing a Miner on normal ground: placement should be rejected.
- Build `Miner -> Conveyor -> Conveyor` and wait: Iron Ore should periodically enter the belt.
- Build from a Coal Miner into Conveyors: Coal should periodically enter the belt.
- Build from a Stone Miner into Conveyors: Stone should periodically enter the belt.
- Rotate a Miner south and place Conveyors below it: ore should exit south.
- Run a Miner with no output Conveyor: the progress bar should fill, turn blocked, and keep one pending ore.
- Add an output Conveyor after blockage: the pending ore should release and production should resume.
- Back up a Conveyor line: the Miner should become output-blocked instead of deleting or duplicating ore.
- Remove the output Conveyor during operation: the Miner should safely hold pending output until a Conveyor is replaced.
- Remove a Miner while producing or blocked: it should disappear cleanly without errors.
- Put Iron Ore, Coal, and Stone on the same Conveyor system: all three resource items should move with the same transport rules.

## Furnace Manual Tests

- Place a Furnace on normal empty ground: it should place successfully and occupy one tile.
- Place Exchangers beside multiple Furnace sides: each should place independently.
- Build `Iron Ore Miner -> Conveyor -> Exchanger -> Furnace`, with the Exchanger arrow pointing into the Furnace: Iron Ore should enter the Iron Ore slot.
- Build `Coal Miner -> Conveyor -> Exchanger -> Furnace`, with the Exchanger arrow pointing into the Furnace: Coal should enter the Coal slot.
- With at least one Iron Ore and one Coal in a Furnace, run the simulation: smelting progress should fill and then produce one Iron Plate.
- Place an Exchanger with its arrow pointing away from a Furnace and toward a Conveyor: Iron Plates should unload onto the logistics line.
- Block an Exchanger, next Exchanger, or Conveyor: the held item should wait without duplicating or disappearing.
- Save a factory with Furnace inventory/progress and Exchanger held items, then load it: production and transfer should resume from the restored state.

## Inventory Manual Tests

- Left click a Container: it should show exactly 40 Storage slots in four rows.
- Open the Player drawer: it should show exactly 30 Storage slots in three rows.
- Left click a Furnace: it should show two Input slots, one Output slot, and 10 Storage slots.
- Pick up whole stacks, one item with `Shift`, and half stacks with `Ctrl`.
- Merge matching stacks up to 100, swap different stacks when the destination accepts the held item, and confirm Output slots reject manual placement but allow removal.
- Close inventory windows while holding a stack: the cursor stack should remain held.

## Adding Future Buildings

Create a new building scene that extends `Building.gd`, draw or compose its visuals, then expose that scene through the UI. The placement controller works with any scene whose root script extends `Building`.

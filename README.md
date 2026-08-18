# Contract

Contract is a small Godot 4.7.1 learning project. The current milestone builds a 100 by 100 board, camera zoom/pan, reusable Conveyor placement, generic item transport, fixed Iron Ore and Coal deposits, Miners, Furnaces, Exchangers, Iron Plates, controllable manufacturing robots, and named in-game saves.

## Project Structure

- `scenes/main.tscn` is the startup scene.
- `scenes/buildings/conveyor.tscn` is the Conveyor building scene.
- `scenes/buildings/miner.tscn` is the Miner building scene.
- `scenes/buildings/furnace.tscn` is the Furnace building scene.
- `scenes/buildings/exchanger.tscn` is the Exchanger building scene.
- `scenes/items/iron_ore.tscn` is the current generic item scene; the script configures whether it displays Iron Ore, Coal, or Iron Plate.
- `scenes/ui/toolbar.tscn` contains the bottom toolbar.
- `scripts/Board.gd` owns grid coordinate conversion, bounds checks, terrain state, resource deposits, and cell occupancy.
- `scripts/CameraController.gd` controls zooming, panning, and the initial centered view.
- `scripts/data/GameDefinitions.gd` defines item and placeable categories.
- `scripts/FactorySimulation.gd` advances factory logic at a fixed tick rate.
- `scripts/GridRenderer.gd` draws terrain, resource deposits, and the visible 100 by 100 grid.
- `scripts/buildings/Building.gd` is the reusable base class for grid buildings.
- `scripts/buildings/Conveyor.gd` draws conveyors and tracks up to four stackable held items.
- `scripts/buildings/Miner.gd` tracks Miner production progress and pending output.
- `scripts/buildings/Furnace.gd` owns Furnace inventory rules and smelting progress.
- `scripts/buildings/Exchanger.gd` owns one-item transfer state and directional logistics behavior.
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

## Procedural Terrain

Contract now generates the 100 by 100 landscape from a deterministic world seed using Godot's `FastNoiseLite`. The current terrain layer supports four types: Ground, Water, Rock, and Forest.

Terrain is stored on `Board` separately from resource deposits, buildings, and factory items. `WorldGenerator.gd` fills the board terrain layer from the active seed, currently `847291`, and forces the central 20 by 15 starting site near `(50, 50)` to clear Ground.

Forest tiles use one of 16 supplied transparent `48x48` variants from `assets/terrain/forest/`. The selected forest variant is stored per cell, so zooming, resizing, saving, loading, or redrawing does not reshuffle the trees. Reusing the same seed reproduces the same terrain and Forest variant layout; changing the seed through `Board.generate_terrain(seed_value)` creates a different map.

## Resource Deposits

Resource deposits are board data, not buildings. A cell can contain an Iron Ore or Coal deposit and still have an empty building slot. This lets a Miner be placed on top of a resource without treating the deposit itself as an occupied building.

The current map has fixed infinite Iron Ore and Coal patches defined in `Board.gd`. `GridRenderer.gd` draws Iron Ore as brown/orange rocky cells and Coal as dark gray/black rocky cells. Resource depletion is not implemented yet.

## Definitions And Categories

Resources and placeables are intentionally separate concepts.

- Resource deposits are terrain data, such as Iron Ore and Coal.
- Factory items are things that can move on belts. Iron Ore and Coal are both `RESOURCE` items.
- Placeables are player-built entities. Conveyors and Exchangers are `LOGISTICS`; Miners are `EXTRACTION`; Furnaces are `SMELTING`.
- Iron Plate is an `INTERMEDIATE` factory item. Furnace inventory contents are still items, not placeables.
- Future buildings already have category slots in `GameDefinitions.gd`: Chests and Warehouses are `STORAGE`, and future assemblers can use `CRAFTING`.

Conveyors transport generic `FactoryItem` instances. They do not contain Iron-Ore-specific, Coal-specific, or Iron-Plate-specific movement logic.

## Camera

The board is 100 by 100 cells. The camera starts centered on the middle of the board, zoomed to show roughly the original 20-cell-wide working area.

- Mouse wheel zooms in and out.
- Middle mouse drag pans.
- `W`, `A`, `S`, and `D` pan the camera.

## Placement System

The toolbar emits a `PackedScene` for the selected building. `PlacementController` instantiates a translucent preview and asks the preview building whether the mouse-snapped grid cell is valid.

Placed buildings are registered in `Board` by their `Vector2i` grid cell. The board dictionary lets the game ask whether a cell is occupied and which `Building` is in that cell.

If a conveyor containing items is removed, the current prototype deletes those items too. That keeps board and item state consistent until a later inventory or item-dropping system exists.

Conveyors can be placed on any empty in-bounds cell. Miners can only be placed on an empty cell containing a supported resource deposit.

## Factory Simulation

The `FactorySimulation` node runs only while the toolbar button says `Pause`. It accumulates frame time in `_process()` and advances factory logic every `tick_seconds`.

Each tick has two phases:

1. Plan valid moves from the current conveyor state.
2. Apply those moves after planning is complete.

This avoids conveyor movement depending on Godot scene-tree order. An item moves at most one conveyor cell per simulation tick. If the next conveyor is missing or outside the board, the item waits. If the next conveyor is full, the item moves only when that destination has room or enough outgoing items planned during the same tick.

## Conveyor Transport

Each conveyor may hold up to four stackable `FactoryItem` instances. Conveyors do not care whether that item is Iron Ore, Coal, or Iron Plate. On a tick, a conveyor tries to move its item to the adjacent grid cell in its facing direction. If that destination cell contains an empty compatible logistics target and the item is not entering from a rejected direction, the item transfers to it. The next tick uses the new holder's direction, so turns work naturally.

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

## Furnace Smelting

Furnaces are one-tile `SMELTING` placeables. A Furnace has no dedicated input or output side. Adjacent Exchangers load ingredients and unload products.

Each Furnace owns exactly three inventory counts:

- Iron Ore input, up to 100.
- Coal input, up to 100.
- Iron Plate output, up to 100.

The current recipe is `1 Iron Ore + 1 Coal -> 1 Iron Plate` and takes 2.0 seconds. Furnace smelting is advanced by `FactorySimulation`, not by a per-Furnace timer. The Furnace only progresses while it has at least one Iron Ore, at least one Coal, and output space for an Iron Plate. Ingredients are consumed only when the Iron Plate can be stored.

Left click a Furnace while not placing a building to inspect its inventory and smelting progress. The window closes with `Escape` or `X`.

## Exchangers

Exchangers are one-tile `LOGISTICS` placeables. Each Exchanger can hold one `FactoryItem` and moves material in the direction of its arrow. It is a stationary transfer tile, not a moving arm.

An Exchanger beside a building can operate in two building-agnostic directions:

- `LOAD BUILDING`: the arrow points from the logistics side toward the building. The Exchanger asks the building if it can accept the held item.
- `UNLOAD BUILDING`: the arrow points away from the building. The Exchanger asks the building if it can provide an item, then creates that item as its held transfer state.

Press `R` while placing an Exchanger, or while hovering a placed Exchanger, to flip its arrow 180 degrees. Exchangers automatically align to an adjacent inventory-capable building when placement is along a new axis.

Buildings own inventory policy through methods such as `can_accept_factory_item`, `accept_factory_item`, `can_provide_factory_item`, `peek_provided_factory_item_type`, and `provide_factory_item`. The Exchanger does not know Furnace-specific slot rules. For this milestone, Furnace accepts Iron Ore and Coal, rejects Iron Plate as input, and only provides Iron Plate.

Exchanger-to-Conveyor transfers use the Conveyor's existing `can_accept_item_from` directional-entry rule. Exchanger-to-Exchanger transfers require the destination Exchanger to be empty and facing so the item enters from its logistics input side.

Exchangers can also bridge two conveyor lines. When an empty Exchanger has a charged transfer, it may pull an item from the logistics holder behind its arrow and move that item toward the holder in front of its arrow, even if the source Conveyor is traveling in another direction. Exchanger transfers use a 0.75 second cadence, slower than the 0.5 second Conveyor tick.

## Manufacturing Robots

New games spawn five manufacturing robots near the center starting area. Each robot receives one of eight supplied transparent `48x48` robot sprites from `assets/robots/` and keeps that assigned design for its lifetime.

Robot sprites are authored facing South. While a robot moves, `Robot.gd` uses the dominant movement axis to face South, North, East, or West by rotating the assigned sprite. When a robot stops, it keeps the last movement-facing direction.

Controls:

- Left click a robot to select only that robot.
- Shift + left click a robot to add or remove it from the current selection.
- Left click empty terrain to clear robot selection.
- Right click terrain to move all selected robots with grid-based pathfinding.

Robot navigation uses one shared `AStarGrid2D` built from the Board's terrain and occupancy data. Ground and resource-deposit cells are walkable. Forest, Rock, and Water are blocked. Placed buildings block robot movement, except Conveyors, which remain walkable for now.

If the player right-clicks an impassable tile, the controller searches nearby cells for the nearest reachable walkable destination. If no route exists, the robot rejects the command and stays put. Multiple selected robots reserve nearby destination cells around the clicked target, and a small visual separation offset keeps robots from drawing directly on top of one another without pushing them off their valid path.

Robots still do not have jobs, inventories, terrain costs, harvesting, clearing, bridges, roads, or advanced crowd simulation yet.

## Saving And Loading

When Contract starts, a centered startup dialog offers `New Game`, `Load Game`, and `Quit`. `New Game` clears the current factory state and generates a fresh terrain seed. `Load Game` opens the existing load dialog. `Quit` exits the game.

Use `Save` or `F5` to open the Save dialog during play. Saves are named by the user. Use `Load` or `F9` to open the Load dialog, choose a named save, and preview its thumbnail.

The game stores a JSON save catalog internally at `user://contract_saves.json`; the player interacts only with in-game dialogs. Each save stores:

- Placed Conveyors and their facing directions.
- Placed Miners, their facing directions, mined resource type, production progress, and pending-output state.
- Placed Furnaces, their inventory counts, and smelting progress.
- Placed Exchangers, their facing directions, and any held item.
- Items currently assigned to Conveyors, including whether each item is Iron Ore, Coal, or Iron Plate.
- A small thumbnail captured from the game view.
- The active world seed, so loading restores the same generated terrain layout.
- Robot positions, destinations, selected sprite designs, facing directions, and movement state. Moving robots recalculate their saved route after loading.

Resource deposits are fixed map data, so they are recreated by the board rather than stored in the save file. Terrain is regenerated from the saved world seed before buildings and items are restored. Loading pauses the simulation so the restored layout starts in a stable state.

When the renamed Contract save catalog does not exist yet, `SaveManager` performs a one-time compatibility migration by looking for the previous save catalog and copying its contents into `user://contract_saves.json`. The old save data is left in place.

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
- Move the mouse to snap the preview to the grid.
- Press `R` to rotate clockwise.
- Left click to place on a valid empty cell.
- Hold left click and drag while placing Conveyors to paint multiple belts.
- Press `R` while not placing to rotate the placed building under the mouse. Exchangers flip between load and unload directions.
- Left click a Furnace while not placing to inspect its inventory.
- Right click an existing conveyor to remove it.
- Press `Escape` to exit placement mode.
- Hold `Shift` and left click a conveyor while not placing to spawn Iron Ore.
- Click `Run` to start conveyor ticks, and `Pause` to stop them.
- Click `Save` or press `F5` to save the current factory.
- Click `Load` or press `F9` to load the saved factory.
- Press `F3` to toggle the Details overlay with current Conveyor, Miner, Furnace, Exchanger, Iron Ore, Coal, and Iron Plate counts.
- Mouse wheel zooms the camera.
- Middle mouse drag or `WASD` pans the camera.

## Miner Manual Tests

- Place a Miner on Iron Ore: it should place successfully.
- Place a Miner on Coal: it should place successfully.
- Try placing a Miner on normal ground: placement should be rejected.
- Build `Miner -> Conveyor -> Conveyor`, click `Run`, and wait: Iron Ore should periodically enter the belt.
- Build from a Coal Miner into Conveyors: Coal should periodically enter the belt.
- Rotate a Miner south and place Conveyors below it: ore should exit south.
- Run a Miner with no output Conveyor: the progress bar should fill, turn blocked, and keep one pending ore.
- Add an output Conveyor after blockage: the pending ore should release and production should resume.
- Back up a Conveyor line: the Miner should become output-blocked instead of deleting or duplicating ore.
- Remove the output Conveyor during operation: the Miner should safely hold pending output until a Conveyor is replaced.
- Remove a Miner while producing or blocked: it should disappear cleanly without errors.
- Put Iron Ore and Coal on the same Conveyor system: both items should move with the same transport rules.

## Furnace Manual Tests

- Place a Furnace on normal empty ground: it should place successfully and occupy one tile.
- Place Exchangers beside multiple Furnace sides: each should place independently.
- Build `Iron Ore Miner -> Conveyor -> Exchanger -> Furnace`, with the Exchanger arrow pointing into the Furnace: Iron Ore should enter the Iron Ore slot.
- Build `Coal Miner -> Conveyor -> Exchanger -> Furnace`, with the Exchanger arrow pointing into the Furnace: Coal should enter the Coal slot.
- With at least one Iron Ore and one Coal in a Furnace, run the simulation: smelting progress should fill and then produce one Iron Plate.
- Place an Exchanger with its arrow pointing away from a Furnace and toward a Conveyor: Iron Plates should unload onto the logistics line.
- Block an Exchanger, next Exchanger, or Conveyor: the held item should wait without duplicating or disappearing.
- Save a factory with Furnace inventory/progress and Exchanger held items, then load it: production and transfer should resume from the restored state.

## Adding Future Buildings

Create a new building scene that extends `Building.gd`, draw or compose its visuals, then expose that scene through the UI. The placement controller works with any scene whose root script extends `Building`.

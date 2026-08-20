# Contract Checklist

## Completed

- [x] Basic Bots can receive manual harvest commands from right-clicking harvestable resources.
- [x] Harvest commands path selected bots to adjacent walkable cells instead of occupying blocked resource tiles.
- [x] Harvesting uses centralized resource definitions for produced inventory item IDs and harvestability.
- [x] Basic Bots harvest in configurable 5.0-second cycles that pay out up to 10 resources per completed cycle.
- [x] Harvest transfer is atomic: resource removal is capped by robot inventory capacity before inventory insertion.
- [x] Full robot inventories stop harvesting and enter `Inventory Full`.
- [x] Full harvesting bots automatically find a nearby reachable Container, deposit inventory, and return to the same harvest target.
- [x] Harvesting bots keep working until full if no Container exists but they still have internal inventory space.
- [x] Harvesting bots waiting for storage detect newly placed Containers, unload, and resume harvesting.
- [x] Bot harvest assignments now have a lightweight `BotJob`, separate from the bot's current movement/work/deposit state.
- [x] Accepted right-click harvest commands show a short in-world resource marker.
- [x] Depleted resources stop harvesting, update inspection values, and remove their resource visuals.
- [x] Bots retarget to the nearest reachable resource that produces the same inventory item when their current target depletes.
- [x] Depleted forest resources become traversable Ground and persist through save/load.
- [x] Multiple selected bots can harvest one shared resource instance without negative quantities.
- [x] New move, deposit, or harvest commands cancel any previous harvest task.
- [x] Resource and robot inspection panels refresh during harvesting.
- [x] Basic Bots use one universal robot sprite matching the supplied reference closest: `assets/robots/robot_04.png`.
- [x] Stone exists as a mined inventory item, conveyor item, storage item, and Mineable resource deposit.
- [x] Lumber has a transparent item icon and belt-compatible factory item mapping while keeping the existing `wood` inventory id.
- [x] Stone deposit art is processed into eight transparent `48x48` resource variants plus one transparent `48x48` belt item icon.
- [x] Iron Ore, Coal, and Stone fields are procedurally generated across the map with guaranteed starter fields near the center.
- [x] Resource generation uses rare distant fields, smaller Stone fields, larger Coal fields, and commonness weighted Stone, Coal, then Iron Ore.
- [x] Generated resource tiles use richer amounts near field centers and lower amounts near field edges.
- [x] Rocky terrain is more reddish/tan and the generator creates more impassable rocky terrain.
- [x] Slot-based inventories now back Containers, Furnaces, Player inventory, and bot-compatible storage behavior.
- [x] Containers expose 40 Storage slots, Furnaces expose Input/Output/Storage sections, and Player inventory exposes 30 Storage slots.
- [x] Shared inventory UI supports whole, single, half, merge, swap, invalid-destination, and persistent cursor-stack interactions.
- [x] Furnace smelting, Exchanger loading/unloading, Container automation, bot deposits, item counts, and save/load read/write slot inventories.
- [x] Added a central JSON definition loader, manager, and validator for base content and future data mods.
- [x] Moved built-in items, resources, buildings, player inventory, Basic Bot stats, terrain metadata, recipes, and worldgen tuning into `data/contract/`.
- [x] Kept `GameDefinitions.gd` as a compatibility facade over loaded JSON definitions instead of a duplicate hardcoded data source.
- [x] Added namespaced IDs with legacy normalization for current saves and runtime IDs.
- [x] Building inventories, player inventory, Basic Bot capacity/harvest stats, item textures, resource textures, Furnace recipe data, Miner support/timing, Conveyor capacity/timing, and Exchanger timing now consume definitions.
- [x] Saves record content-pack metadata and refuse loads with missing required content packs.
- [x] Added an example disabled-by-default data mod patch under `examples/mods/basic_bot_slow_harvest/`.

## Follow-Up Tasks

- [ ] Add dedicated harvesting animations and effects.
- [ ] Add richer hauling rules for container reservations, partial unloads, and unreachable/full container feedback.
- [ ] Add future specialized bot types through stats and capabilities.
- [ ] Add player-facing slot filters once recipes or logistics need configurable filters.
- [ ] Add richer worker-slot or crowd-management behavior around busy resource tiles.
- [ ] Add more harvestable resource definitions and art such as Copper Ore when those deposits exist in world generation.
- [ ] Add construction uses for Stone once production chains need it.
- [ ] Expand data mod validation tests into automated scenes or command-line checks.
- [ ] Add player-facing missing-mod UI instead of only logging a load refusal.
- [ ] Decide whether active harvest/move-to-resource tasks should resume after loading instead of returning to Idle.

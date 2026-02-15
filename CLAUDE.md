# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Steal a Brainrot** is a Roblox tycoon/collection game where players:
- Collect Brainrot pieces that spawn in an arena
- Craft complete Brainrot creatures from collected pieces (Head + Body + Legs)
- Place crafted Brainrots in their base to generate passive income
- Buy additional slots to expand their base
- Complete sets for bonus rewards
- Steal Brainrots from other players' bases using a bat combat system
- Defend their base with doors and stun mechanics

## Development Commands

### Server Sync
```bash
npm start
```
Starts the Express server on ports 3000 (HTTP) and 3001 (WebSocket) for syncing files with Roblox Studio.

### File Structure
- Source code in `GamePlace/` directory
- Manual import to Roblox Studio required (see [GamePlace/IMPORT_GUIDE.md](GamePlace/IMPORT_GUIDE.md))
- Phase guides (`PHASE_X_GUIDE.md`) document implementation steps

## Architecture

### Client-Server Separation
**Critical Principle**: Server validates EVERYTHING. Client only sends requests and displays results.

```
CLIENT                              SERVER
Detects inputs          →          Validates ALL actions
Sends requests          →          Executes game logic
Displays results        ←          Sends updates
NEVER trusted           →          Single source of truth
```

### Communication Flow
All client-server communication goes through RemoteEvents/Functions:
1. Client detects user input
2. Client sends RemoteEvent with minimal data
3. Server's NetworkHandler receives event
4. NetworkHandler routes to appropriate System
5. System validates and executes logic
6. System fires sync RemoteEvent back to client(s)
7. Client's UIController updates display

### Core Services (ServerScriptService/Core/)
- **GameServer.server.lua**: Entry point, initializes all services and systems (including Phase 8 BatSystem/StealSystem)
- **DataService.module.lua**: DataStore management with auto-save (60s intervals), offline mode for Studio
- **PlayerService.module.lua**: Handles player join/leave, data loading/saving, base assignment, runtime data (CarriedBrainrot)
- **NetworkSetup.module.lua**: Creates RemoteEvents/Functions in ReplicatedStorage/Remotes from Constants.RemoteNames

### Game Systems (ServerScriptService/Systems/)
Each system is a ModuleScript with Init(services) and specific methods:
- **BaseSystem**: Manages player bases, slot purchases, floor unlocking
- **DoorSystem**: Controls base doors with timed open/close cycles, collision groups
- **EconomySystem**: Cash management, passive income from placed Brainrots
- **ArenaSystem**: Spawns Brainrot pieces in the arena at intervals
- **InventorySystem**: Manages pieces in player's hand (max 3)
- **CraftingSystem**: Combines Head+Body+Legs into complete Brainrots
- **CodexService**: Tracks discovered Brainrot combinations (note: file is `CodexService.module.lua`)
- **PlacementSystem**: Places/removes Brainrots in base slots
- **BrainrotModelSystem**: Assembles 3D models using Attachments for precise alignment
- **BatSystem**: Bat equipment on right hand, hit detection, stun mechanics (5s PlatformStand)
- **StealSystem**: Steal Brainrots from other bases, carry on left hand (40% scale), place in own slots

### Client Controllers (StarterPlayer/StarterPlayerScripts/Controllers/)
- **ClientMain.client.lua**: Entry point, connects all remotes and initializes controllers
- **UIController.module.lua**: Updates UI with player data
- **DoorController.module.lua**: Door state updates
- **EconomyController.module.lua**: Economy UI updates
- **ArenaController.module.lua**: Arena piece visuals
- **CodexController.module.lua**: Codex UI management
- **PreviewBrainrotController.module.lua**: 3D preview following player
- **BatController.client.lua**: Left-click hit detection, swing animation via Tween on shoulder Motor6D
- **StealController.client.lua**: ProximityPrompts for stealing (hold E 3s) and placing stolen Brainrots

### Network Layer (ServerScriptService/Handlers/)
- **NetworkHandler.module.lua**: Routes all RemoteEvents to appropriate system methods

### Other Server Scripts
- **ActivationPadManager.server.lua**: Door activation pad logic
- **SpinnerRotation.server.lua**: Arena spinner rotation

### Configuration (ReplicatedStorage/)
- **Config/GameConfig.module.lua**: Economy rates, spawn intervals, DataStore settings, combat parameters
- **Config/FeatureFlags.module.lua**: Toggle features on/off
- **Data/BrainrotData.module.lua**: Registry of all Brainrot sets (rarity, prices, spawn weights)
- **Data/SlotPrices.module.lua**: Progressive pricing for base slots
- **Data/DefaultPlayerData.module.lua**: Default player data structure
- **Shared/Constants.module.lua**: Shared enums, RemoteNames, ActionResults
- **Shared/Utils.module.lua**: Shared utility functions
- **Shared/SoundHelper.module.lua**: Sound effects helper

## Key Technical Details

### Data Structure
Player data stored in DataStore (persistent):
```lua
{
    Cash = 100,
    OwnedSlots = 1,
    Inventory = {}, -- {pieceId = {set, part}}
    PlacedBrainrots = {}, -- {slotId = {headSet, bodySet, legsSet}}
    Codex = {}, -- {setName = {Head = true, Body = false, ...}}
}
```

Runtime data in `PlayerService._runtimeData` (not saved, resets each session):
```lua
{
    PiecesInHand = {},
    CarriedBrainrot = nil, -- {HeadSet, BodySet, LegsSet, SetName, StolenFromUserId, StolenFromSlotId}
    AssignedBase = nil,
    BaseIndex = nil,
    DoorState = "Open",
    DoorCloseTime = 0,
    DoorReopenTime = 0,
    JoinTime = os.time(),
    LastSaveTime = os.time(),
}
```

### Brainrot Assembly System
Uses Attachment-based positioning for precise alignment:
- **HeadTemplate**: Has BottomAttachment
- **BodyTemplate**: Has TopAttachment and BottomAttachment
- **LegsTemplate**: Has TopAttachment
- Assembly uses CFrame math: `bodyPart.CFrame * bodyTopAtt.CFrame * headBottomAtt.CFrame:Inverse()`
- Automatic WeldConstraints between assembled parts
- Falls back to manual positioning if Attachments missing

### Bat & Steal System (Phase 8)
**Combat flow**:
1. All players spawn with a bat welded to their right hand (WeldConstraint pattern)
2. Left-click triggers BatHit → server validates distance (10 studs), cooldown (1s)
3. Victim gets stunned for 5s (PlatformStand = true, ragdoll effect)
4. If victim was carrying a stolen Brainrot, it's returned to its original slot

**Steal flow**:
1. Client creates StealPrompts (ProximityPrompt, hold E 3s) on other players' placed Brainrots
2. Server validates: not own base, not already carrying, inventory empty, has available slot, within 15 studs
3. Stolen Brainrot stored as `CarriedBrainrot` in runtime data (not in Inventory/PiecesInHand)
4. Visual model attached to left hand at 40% scale
5. Client creates PlacePrompts on own empty slots when carrying
6. Player places stolen Brainrot in own slot via PlaceStolenBrainrot remote

**Key config** (in GameConfig):
- `StunDuration = 5`, `BatCooldown = 1`, `BatMaxDistance = 10`
- `StealDuration = 3` (hold time), `StealMaxDistance = 15`

### RemoteEvents/Functions
All defined in `Constants.module.lua > RemoteNames`, auto-created by `NetworkSetup`.
Located in `ReplicatedStorage/Remotes`:

**Client → Server:**
- PickupPiece, Craft, BuySlot, CollectSlotCash, ActivateDoor, DropPieces
- StealBrainrot (ownerId, slotId), PlaceStolenBrainrot (slotIndex), BatHit (victimId)

**Server → Client:**
- SyncPlayerData, SyncInventory, SyncCodex, SyncDoorState, Notification
- SyncPlacedBrainrots, SyncCarriedBrainrot, SyncStunState

**RemoteFunction:**
- GetFullPlayerData (initial data request)

### Key Patterns
- **WeldConstraint for hand attachments**: Used by BatSystem (right hand) and StealSystem (left hand)
- **ProximityPrompts**: Client creates/destroys dynamically for E-key interactions (steal, place)
- **Base identification**: `base:GetAttribute("OwnerUserId") == player.UserId`
- **Dependency injection**: Systems use `Init(services)`, GameServer wires everything together
- **Runtime vs persistent data**: PlayerService._runtimeData (session only) vs DataService (saved to DataStore)

### Development Workflow
1. Edit Lua files in `GamePlace/` directory
2. Files automatically sync via server.js if running
3. Or manually copy-paste into Roblox Studio (see IMPORT_GUIDE.md)
4. Test in Studio Play Solo mode
5. Check Output window for logs and errors

### Offline Mode
DataService automatically enables offline mode in Studio (when DataStore unavailable):
- Data stored in memory only
- No persistence between sessions
- Auto-save still runs (but doesn't save to DataStore)

## Phase-Based Development

Project uses phased development documented in PHASE_X_GUIDE.md files:
- Each phase has a guide (PHASE_X_GUIDE.md) and status tracker (PHASE_X_STATUS.md)
- Phases build incrementally on previous work
- **Phase 1-3**: Backend core (DataService, PlayerService, base systems)
- **Phase 4-5**: Game systems (Arena, Inventory, Crafting, Codex, Economy)
- **Phase 6**: UI controllers and client-side display
- **Phase 7**: 3D model assembly (BrainrotModelSystem, Attachments)
- **Phase 8**: Bat combat + Steal system (BatSystem, StealSystem, controllers)

## Testing

Test files in `GamePlace/`:
- **TEST_SERVER_HANDLER.server.lua**: Server-side testing
- **TEST_SERVER.client.lua**: Client-side testing
- **TEST_UI.client.lua**: UI testing

Check Output window for logs during Studio playtest. Look for initialization messages from each service/system.

## Important Notes

- Always validate server-side, never trust client data
- Use RemoteEvents for client→server communication, never call server functions directly
- Keep Systems modular and independent
- Use DataService for all player data modifications
- Check FeatureFlags before implementing optional features
- Follow existing naming conventions (ModuleScripts end with .module.lua)
- Server scripts end with .server.lua, client scripts end with .client.lua
- All RemoteEvent names must be added to `Constants.module.lua > RemoteNames`

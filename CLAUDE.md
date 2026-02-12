# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Steal a Brainrot** is a Roblox tycoon/collection game where players:
- Collect Brainrot pieces that spawn in an arena
- Craft complete Brainrot creatures from collected pieces (Head + Body + Legs)
- Place crafted Brainrots in their base to generate passive income
- Buy additional slots to expand their base
- Complete sets for bonus rewards

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
- **GameServer.server.lua**: Entry point, initializes all services and systems
- **DataService.module.lua**: DataStore management with auto-save (60s intervals), offline mode for Studio
- **PlayerService.module.lua**: Handles player join/leave, data loading/saving, base assignment
- **NetworkSetup.module.lua**: Creates RemoteEvents/Functions in ReplicatedStorage/Remotes

### Game Systems (ServerScriptService/Systems/)
Each system is a ModuleScript with Init() and specific methods:
- **BaseSystem**: Manages player bases, slot purchases, floor unlocking
- **DoorSystem**: Controls base doors with timed open/close cycles, collision groups
- **EconomySystem**: Cash management, passive income from placed Brainrots
- **ArenaSystem**: Spawns Brainrot pieces in the arena at intervals
- **InventorySystem**: Manages pieces in player's hand (max 3)
- **CraftingSystem**: Combines Head+Body+Legs into complete Brainrots
- **CodexSystem**: Tracks discovered Brainrot combinations
- **PlacementSystem**: Places/removes Brainrots in base slots
- **BrainrotModelSystem**: Assembles 3D models using Attachments for precise alignment

### Network Layer (ServerScriptService/Handlers/)
- **NetworkHandler.module.lua**: Routes all RemoteEvents to appropriate system methods

### Configuration (ReplicatedStorage/)
- **Config/GameConfig.module.lua**: Economy rates, spawn intervals, DataStore settings
- **Config/FeatureFlags.module.lua**: Toggle features on/off
- **Data/BrainrotData.module.lua**: Registry of all Brainrot sets (rarity, prices, spawn weights)
- **Data/SlotPrices.module.lua**: Progressive pricing for base slots
- **Data/DefaultPlayerData.module.lua**: Default player data structure
- **Shared/Constants.lua**: Shared enums and constants
- **Shared/Utils.lua**: Shared utility functions

## Key Technical Details

### Data Structure
Player data stored in DataStore with structure:
```lua
{
    Cash = 100,
    OwnedSlots = 1,
    Inventory = {}, -- {pieceId = {set, part}}
    PlacedBrainrots = {}, -- {slotId = {headSet, bodySet, legsSet}}
    Codex = {}, -- {setName = {Head = true, Body = false, ...}}
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

### RemoteEvents/Functions
All located in `ReplicatedStorage/Remotes`:
- PickupPiece, Craft, BuySlot, CollectSlotCash, ActivateDoor, DropPieces (client→server)
- SyncPlayerData, SyncInventory, SyncCodex, SyncDoorState, Notification (server→client)
- GetFullPlayerData (RemoteFunction for initial data request)

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
- Current phases include backend core, systems, UI, and 3D model assembly

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

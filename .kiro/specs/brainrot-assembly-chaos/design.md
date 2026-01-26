# Design Document: Brainrot Assembly Chaos

## Overview

Brainrot Assembly Chaos is a multiplayer arena game built around three core gameplay loops: collection (catching body parts from cannons), assembly (combining parts into complete Brainrots), and competition (stealing from opponents while defending your own base). The design emphasizes chaotic, fast-paced gameplay with physics-based interactions and real-time multiplayer synchronization.

The architecture follows a client-server model with authoritative server logic for game state management and client-side prediction for responsive controls. The game will be built using a modern game engine (Unity or Godot) with built-in networking support.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Game Server                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Game Session │  │ Physics      │  │ Network      │      │
│  │ Manager      │──│ Simulation   │──│ Sync Manager │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         ▼                  ▼                  ▼              │
│  ┌──────────────────────────────────────────────────┐      │
│  │           Authoritative Game State               │      │
│  │  - Player States    - Body Parts                 │      │
│  │  - Cannon System    - Central Laser              │      │
│  │  - Base States      - Brainrot Collections       │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Network Updates
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Game Clients (2-8)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Input        │  │ Rendering    │  │ Audio        │      │
│  │ Handler      │──│ Engine       │──│ Manager      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         ▼                  ▼                  ▼              │
│  ┌──────────────────────────────────────────────────┐      │
│  │         Client-Side Predicted State              │      │
│  │  - Local Player Position                         │      │
│  │  - Visual Effects    - UI Updates                │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

**Server Components:**
- **Game Session Manager**: Handles player connections, match lifecycle, and win conditions
- **Physics Simulation**: Runs authoritative physics for all game objects
- **Network Sync Manager**: Broadcasts state updates to clients and processes client inputs
- **Cannon System**: Spawns and launches body parts at intervals
- **Central Laser Controller**: Manages laser rotation and collision detection
- **Codex Manager**: Tracks discovered Brainrots and awards progression rewards

**Client Components:**
- **Input Handler**: Captures player inputs (movement, punch, interact) and sends to server
- **Rendering Engine**: Displays game state with visual effects and animations
- **Audio Manager**: Plays sound effects and music based on game events
- **UI System**: Displays player names, inventory, Codex, and match information

## Components and Interfaces

### Core Data Structures

#### BodyPart
```
BodyPart {
  id: string
  type: BodyPartType (HEAD | BODY | LEGS)
  nameFragment: string
  position: Vector3
  velocity: Vector3
  rotation: Quaternion
  isCollected: boolean
}
```

#### Player
```
Player {
  id: string
  username: string
  position: Vector3
  rotation: Quaternion
  inventory: BodyPart[] (max 3)
  baseLocation: Vector3
  score: int
  lastPunchTime: timestamp
  isBarrierActive: boolean
  barrierEndTime: timestamp
}
```

#### Brainrot
```
Brainrot {
  id: string
  name: string (combined from 3 name fragments)
  headPart: BodyPart
  bodyPart: BodyPart
  legsPart: BodyPart
  ownerId: string
  pedestalIndex: int
  lockEndTime: timestamp
  isLocked: boolean
}
```

#### GameState
```
GameState {
  sessionId: string
  players: Map<string, Player>
  bodyParts: Map<string, BodyPart>
  brainrots: Map<string, Brainrot>
  centralLaser: CentralLaser
  matchStartTime: timestamp
  matchDuration: int
  isMatchActive: boolean
}
```

### Cannon System

The Cannon System manages body part spawning and launching.

**Interface:**
```
CannonSystem {
  cannons: Cannon[]
  spawnInterval: float (2-5 seconds)
  lastSpawnTime: timestamp
  
  initialize(arenaRadius: float, cannonCount: int)
  update(deltaTime: float)
  spawnBodyPart(): BodyPart
  selectRandomCannon(): Cannon
  generateNameFragment(type: BodyPartType): string
}
```

**Cannon Structure:**
```
Cannon {
  position: Vector3
  direction: Vector3 (pointing toward arena center)
  launchForce: float (randomized 10-20 units)
  launchAngle: float (30-60 degrees)
}
```

**Spawning Logic:**
1. Track time since last spawn
2. When interval elapsed, select random cannon
3. Generate random body part type (33% chance each)
4. Generate random name fragment from predefined lists
5. Calculate launch trajectory toward arena center with randomized arc
6. Apply initial velocity and spawn body part
7. Broadcast spawn event to all clients

**Name Fragment Generation:**
- Maintain three lists: headFragments[], bodyFragments[], legsFragments[]
- Each list contains 20-30 silly name fragments ("Brr Brr", "Skibidi", "Gyatt", "Rizz", etc.)
- Randomly select from appropriate list based on body part type

### Collection System

**Interface:**
```
CollectionSystem {
  checkCollisions(player: Player, bodyParts: BodyPart[])
  collectBodyPart(player: Player, bodyPart: BodyPart): boolean
  updatePlayerName(player: Player)
  checkForCompletion(player: Player): Brainrot | null
}
```

**Collection Logic:**
1. Check distance between player and all uncollected body parts
2. If distance < collectionRadius (1.5 units), attempt collection
3. Verify player inventory has space (< 3 items)
4. Add body part to player inventory
5. Update player's displayed name with new fragment
6. Remove body part from world
7. Check if player now has complete set (1 head, 1 body, 1 legs)
8. If complete, trigger assembly

**Name Display Logic:**
- Start with player username
- Append head fragment if head in inventory
- Append body fragment if body in inventory
- Append legs fragment if legs in inventory
- Example: "Player1" → "Player1 Brr" → "Player1 Brr Skibidi" → "Player1 Brr Skibidi Gyatt"

### Assembly System

**Interface:**
```
AssemblySystem {
  assemblebrainrot(player: Player): Brainrot
  findAvailablePedestal(player: Player): int
  placeBrainrot(brainrot: Brainrot, player: Player, pedestalIndex: int)
  activateLockTimer(brainrot: Brainrot, duration: float)
}
```

**Assembly Logic:**
1. Verify player has exactly 1 head, 1 body, 1 legs
2. Combine three name fragments into complete Brainrot name
3. Create Brainrot object with combined parts
4. Find available pedestal in player's base (3 pedestals per base)
5. Place Brainrot on pedestal
6. Activate 10-second lock timer
7. Clear player inventory
8. Reset player displayed name to username
9. Trigger visual/audio celebration effects
10. Update Codex if new combination discovered
11. Broadcast assembly event to all clients

### Central Laser System

**Interface:**
```
CentralLaserSystem {
  position: Vector3 (arena center)
  currentAngle: float
  rotationSpeed: float
  maxRotationSpeed: float
  accelerationRate: float
  laserLength: float
  laserWidth: float
  
  update(deltaTime: float, matchElapsedTime: float)
  checkCollisions(players: Player[]): Player[]
  knockbackPlayer(player: Player, laserAngle: float)
  dropInventory(player: Player): BodyPart[]
}
```

**Rotation Logic:**
1. Start at 30 degrees/second
2. Accelerate based on match elapsed time: `speed = 30 + (matchTime / 60) * 90`
3. Cap at 120 degrees/second
4. Update angle each frame: `angle += speed * deltaTime`
5. Wrap angle at 360 degrees

**Collision Detection:**
1. Represent laser as line segment from center to edge
2. Check distance from each player to line segment
3. If distance < (laserWidth / 2 + playerRadius), collision detected
4. Calculate knockback direction perpendicular to laser
5. Apply knockback force (15 units)
6. Drop all inventory items with scatter

**Inventory Drop Logic:**
1. For each body part in player inventory
2. Calculate random scatter direction (360 degrees around player)
3. Calculate random scatter distance (2-5 units)
4. Set body part position to player position + scatter offset
5. Apply small random velocity for bounce effect
6. Clear player inventory
7. Broadcast drop event to all clients

### Combat System

**Interface:**
```
CombatSystem {
  punchCooldown: float (1 second)
  punchRange: float (2 units)
  punchKnockback: float (5 units)
  
  executePunch(attacker: Player, players: Player[]): Player | null
  canPunch(player: Player, currentTime: timestamp): boolean
  dropLastItem(target: Player, punchDirection: Vector3): BodyPart | null
}
```

**Punch Logic:**
1. Check if cooldown elapsed since last punch
2. Calculate punch hitbox (cone in front of player, 2 units range, 60-degree arc)
3. Check all other players for intersection with hitbox
4. Select closest player in range
5. If hit detected:
   - Remove most recent body part from target's inventory
   - Calculate eject direction (attacker forward direction)
   - Spawn body part at target position with velocity in eject direction
   - Update target's displayed name
   - Play impact sound and particle effect
   - Set attacker's lastPunchTime
6. Broadcast punch event to all clients

### Base Protection System

**Interface:**
```
BaseProtectionSystem {
  barrierDuration: float (5 seconds)
  barrierRadius: float (5 units)
  
  checkPressurePlate(player: Player): boolean
  activateBarrier(player: Player)
  updateBarriers(players: Player[], currentTime: timestamp)
  checkBarrierCollision(player: Player, bases: Player[]): boolean
}
```

**Pressure Plate Logic:**
1. Each base has circular pressure plate (1 unit radius) at center
2. Check if player position within plate radius
3. Only activate for base owner
4. If activated, set barrier active and record end time
5. Render red translucent dome around base

**Barrier Collision:**
1. For each player, check if they're inside another player's base radius
2. If base barrier is active and player is not owner:
   - Calculate repulsion vector (from base center to player)
   - Apply repulsion force (10 units)
   - Prevent player from moving closer to base center
3. Allow owner to move freely regardless of barrier state

### Theft System

**Interface:**
```
TheftSystem {
  interactionRange: float (2 units)
  
  checkInteraction(thief: Player, bases: Player[]): Brainrot | null
  canSteal(brainrot: Brainrot, currentTime: timestamp): boolean
  stealBrainrot(brainrot: Brainrot, thief: Player)
  transferToBase(brainrot: Brainrot, newOwner: Player)
}
```

**Theft Logic:**
1. Check if player is inside another player's base (not their own)
2. Check if player presses interact button
3. Find closest pedestal within interaction range
4. Check if pedestal has Brainrot
5. Check if Brainrot lock timer expired
6. If stealable:
   - Remove Brainrot from original pedestal
   - Find available pedestal in thief's base
   - Place Brainrot on thief's pedestal
   - Activate new 10-second lock timer
   - Update Brainrot owner
   - Broadcast theft event to all clients

### Visual Effects System

**Interface:**
```
VFXSystem {
  playCompletionEffect(position: Vector3, brainrotName: string)
  playCollectionEffect(position: Vector3, partType: BodyPartType)
  playHitEffect(position: Vector3, effectType: HitType)
  applyScreenShake(player: Player, intensity: float, duration: float)
  renderNeonGlow(object: GameObject, color: Color)
}
```

**Effect Specifications:**
- **Completion Effect**: Burst of particles in neon colors (pink, cyan, yellow), expanding outward, 2-second duration
- **Collection Effect**: Small sparkle particles matching body part color, 0.5-second duration
- **Laser Hit Effect**: Red impact particles with electric arc effects, 1-second duration
- **Punch Hit Effect**: Yellow star burst particles, 0.5-second duration
- **Screen Shake**: Camera shake with decreasing intensity, 0.3-second duration for completion, 0.2 seconds for hits
- **Neon Glow**: Emissive material with bloom post-processing, color-coded by type (Head=cyan, Body=pink, Legs=yellow)

### Audio System

**Interface:**
```
AudioSystem {
  playSoundEffect(soundId: string, position: Vector3, volume: float)
  playMusicTrack(trackId: string, loop: boolean)
  stopAllSounds()
}
```

**Sound Effect List:**
- **completion_sound**: Ridiculous victory sound (airhorn, meme sound)
- **collection_sound**: Pop or ding sound
- **laser_hit_sound**: Electric zap sound
- **punch_hit_sound**: Cartoon punch sound (boing, pow)
- **cannon_fire_sound**: Whoosh or launch sound
- **barrier_activate_sound**: Force field hum
- **theft_sound**: Sneaky sound effect

### Codex System

**Interface:**
```
CodexSystem {
  discoveredBrainrots: Set<string>
  playerCurrency: Map<string, int>
  playerBadges: Map<string, Badge[]>
  
  recordDiscovery(playerId: string, brainrotName: string): boolean
  awardCurrency(playerId: string, amount: int)
  checkMilestones(playerId: string): Badge[]
  saveProgress(playerId: string)
  loadProgress(playerId: string)
}
```

**Discovery Logic:**
1. When Brainrot assembled, check if combination exists in player's discovered set
2. If new, add to discovered set
3. Award 100 currency
4. Check milestone thresholds (10, 25, 50, 100 discoveries)
5. Award badges for milestones
6. Persist to player profile storage
7. Display notification to player

**Badge System:**
- **Collector**: Discover 10 unique Brainrots
- **Enthusiast**: Discover 25 unique Brainrots
- **Expert**: Discover 50 unique Brainrots
- **Master**: Discover 100 unique Brainrots

## Data Models

### Network Message Formats

All network messages use a common envelope structure:

```
NetworkMessage {
  messageType: MessageType
  timestamp: long
  senderId: string
  payload: object
}
```

**Message Types:**

**PlayerInput:**
```
{
  type: "PLAYER_INPUT"
  movement: Vector2
  rotation: float
  punchPressed: boolean
  interactPressed: boolean
}
```

**StateUpdate:**
```
{
  type: "STATE_UPDATE"
  players: Player[]
  bodyParts: BodyPart[]
  centralLaserAngle: float
}
```

**BodyPartSpawned:**
```
{
  type: "BODY_PART_SPAWNED"
  bodyPart: BodyPart
  cannonIndex: int
}
```

**BodyPartCollected:**
```
{
  type: "BODY_PART_COLLECTED"
  playerId: string
  bodyPartId: string
  newDisplayName: string
}
```

**BrainrotCompleted:**
```
{
  type: "BRAINROT_COMPLETED"
  playerId: string
  brainrot: Brainrot
  isNewDiscovery: boolean
}
```

**PlayerHit:**
```
{
  type: "PLAYER_HIT"
  playerId: string
  hitType: HitType (LASER | PUNCH)
  droppedParts: BodyPart[]
  knockbackDirection: Vector3
}
```

**BrainrotStolen:**
```
{
  type: "BRAINROT_STOLEN"
  brainrotId: string
  originalOwnerId: string
  newOwnerId: string
}
```

### Persistence Schema

**Player Profile:**
```
PlayerProfile {
  playerId: string
  username: string
  discoveredBrainrots: string[]
  currency: int
  badges: string[]
  totalMatches: int
  totalBrainrotsCompleted: int
  totalBrainrotsStolen: int
  createdAt: timestamp
  lastPlayedAt: timestamp
}
```

Stored in database (SQLite for local, PostgreSQL for server) or JSON files for simpler implementation.

### Configuration Data

**Game Configuration:**
```
GameConfig {
  maxPlayers: int (default: 8)
  matchDuration: int (default: 300 seconds)
  cannonCount: int (default: 6)
  cannonSpawnInterval: float (default: 3 seconds)
  laserStartSpeed: float (default: 30 deg/s)
  laserMaxSpeed: float (default: 120 deg/s)
  lockTimerDuration: float (default: 10 seconds)
  barrierDuration: float (default: 5 seconds)
  punchCooldown: float (default: 1 second)
  pedestalsPerBase: int (default: 3)
}
```

**Name Fragment Lists:**
```
NameFragments {
  headFragments: string[] (e.g., ["Brr Brr", "Skibidi", "Gyatt", "Rizz", ...])
  bodyFragments: string[] (e.g., ["Pata", "Dop", "Sigma", "Ohio", ...])
  legsFragments: string[] (e.g., ["Pim", "Yes", "Mog", "Fanum", ...])
}
```

Loaded from JSON configuration files for easy modding and expansion.



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I've identified several areas where properties can be consolidated:

- **Collection and name display** (2.5, 11.2): Both test that collecting parts updates names - can be combined
- **Inventory clearing** (3.4) is implied by **assembly triggering** (3.1) - assembly should handle full flow
- **Audio/visual triggers** (8.1-8.5): Can be grouped into event triggering properties rather than separate properties per effect
- **Network broadcast properties** (10.2-10.4): Can be consolidated into general event broadcasting
- **Barrier mechanics** (6.2, 6.6): Both test barrier blocking - can be combined

### Cannon System Properties

**Property 1: Spawn interval bounds**
*For any* sequence of body part spawns, the time between consecutive spawns should be between 2 and 5 seconds.
**Validates: Requirements 1.1**

**Property 2: Spawned parts have physics**
*For any* body part spawned by a cannon, it should have non-zero velocity and be subject to physics simulation.
**Validates: Requirements 1.2, 1.5**

**Property 3: Body part type distribution**
*For any* sufficiently large set of spawned body parts (n > 100), each type (Head, Body, Legs) should appear with frequency between 25% and 42% (allowing for randomness variance).
**Validates: Requirements 1.3**

**Property 4: Name fragments assigned**
*For any* spawned body part, it should have a non-empty name fragment from the appropriate fragment list for its type.
**Validates: Requirements 1.4**

**Property 5: Cannon distribution**
*For any* sufficiently large set of spawns (n > 100), each cannon should be used at least once.
**Validates: Requirements 1.6**

### Collection System Properties

**Property 6: Collision triggers collection**
*For any* player with inventory space (< 3 items) and any uncollected body part, when they collide, the body part should be added to the player's inventory and removed from the arena.
**Validates: Requirements 2.1, 2.2**

**Property 7: Inventory capacity enforcement**
*For any* player, they should be able to collect body parts if and only if their inventory contains fewer than 3 items.
**Validates: Requirements 2.3, 2.4**

**Property 8: Collection updates displayed name**
*For any* player who collects a body part, their displayed name should contain the name fragment from that body part.
**Validates: Requirements 2.5, 11.2**

**Property 9: Name fragment ordering**
*For any* player with multiple body parts, their displayed name should show fragments in the order: Head fragment (if present), Body fragment (if present), Legs fragment (if present).
**Validates: Requirements 11.3**

**Property 10: Empty inventory shows username**
*For any* player with an empty inventory, their displayed name should equal their username.
**Validates: Requirements 11.1**

### Assembly System Properties

**Property 11: Complete set triggers assembly**
*For any* player whose inventory contains exactly one Head, one Body, and one Legs, a Brainrot assembly should be automatically triggered.
**Validates: Requirements 3.1**

**Property 12: Brainrot name composition**
*For any* completed Brainrot, its name should be the concatenation of the head fragment, body fragment, and legs fragment in that order.
**Validates: Requirements 3.2**

**Property 13: Assembly clears inventory and resets name**
*For any* player who completes a Brainrot, their inventory should be empty and their displayed name should be reset to their username.
**Validates: Requirements 3.4, 11.4**

**Property 14: Brainrot placement on pedestal**
*For any* completed Brainrot, it should be placed on an available pedestal in the completing player's base.
**Validates: Requirements 3.3**

**Property 15: Lock timer activation**
*For any* newly placed Brainrot, it should have an active lock timer preventing theft for 10 seconds.
**Validates: Requirements 3.6**

**Property 16: Assembly triggers celebration**
*For any* Brainrot completion, the system should trigger both visual particle effects and victory sound effects.
**Validates: Requirements 3.5, 8.1, 8.2**

### Central Laser Properties

**Property 17: Continuous rotation**
*For any* time interval during an active match, the central laser's angle should increase monotonically (always rotating forward).
**Validates: Requirements 4.1**

**Property 18: Speed acceleration with cap**
*For any* active match, the laser rotation speed should increase with match duration and never exceed 120 degrees per second.
**Validates: Requirements 4.3**

**Property 19: Laser hit causes knockback**
*For any* player hit by the central laser, they should be pushed away from the arena center.
**Validates: Requirements 4.4**

**Property 20: Laser hit drops all inventory**
*For any* player hit by the central laser, all body parts in their inventory should be dropped and scattered within 5 units of their position.
**Validates: Requirements 4.5, 4.6**

### Combat System Properties

**Property 21: Punch hits drop last item**
*For any* player with a non-empty inventory who is hit by a punch, they should drop their most recently collected body part in the direction of the punch.
**Validates: Requirements 5.2, 5.3**

**Property 22: Punch cooldown enforcement**
*For any* player, they should not be able to execute two punches within 1 second of each other.
**Validates: Requirements 5.4**

**Property 23: Punch triggers effects**
*For any* successful punch hit, the system should trigger both impact sound effects and hit particle effects.
**Validates: Requirements 5.5**

### Base Protection Properties

**Property 24: Pressure plate activates barrier**
*For any* player who steps on their own base pressure plate, their barrier should activate for 5 seconds.
**Validates: Requirements 6.1**

**Property 25: Barrier blocks non-owners**
*For any* active barrier, non-owning players should be unable to enter the protected base area and should be pushed away if they attempt entry.
**Validates: Requirements 6.2, 6.6**

**Property 26: Barrier allows owner passage**
*For any* active barrier, the owning player should be able to move freely in and out of their base.
**Validates: Requirements 6.3**

**Property 27: Barrier deactivation**
*For any* barrier, it should deactivate after its 5-second duration expires.
**Validates: Requirements 6.4**

### Theft System Properties

**Property 28: Lock timer prevents theft**
*For any* Brainrot with an active lock timer, it should not be stealable by other players.
**Validates: Requirements 7.2**

**Property 29: Expired lock allows theft**
*For any* Brainrot whose lock timer has expired, it should be stealable by players who enter the base and interact with it.
**Validates: Requirements 7.3, 7.1**

**Property 30: Theft transfers ownership**
*For any* stolen Brainrot, it should be removed from the original owner's pedestal and placed on an available pedestal in the thief's base.
**Validates: Requirements 7.4, 7.5**

**Property 31: Theft reactivates lock**
*For any* stolen Brainrot, a new lock timer should be activated preventing immediate re-theft.
**Validates: Requirements 7.6**

### Visual and Audio Properties

**Property 32: Body part color coding**
*For any* body part, its rendered color should correspond to its type (Head=cyan, Body=pink, Legs=yellow).
**Validates: Requirements 8.6**

**Property 33: Collection triggers sound**
*For any* body part collection, a collection sound effect should be played.
**Validates: Requirements 8.3**

**Property 34: Laser hit triggers sound**
*For any* player hit by the central laser, an impact sound effect should be played.
**Validates: Requirements 8.4**

### Codex Properties

**Property 35: New discovery recording**
*For any* Brainrot combination completed for the first time by a player, it should be added to that player's discovered set in the Codex.
**Validates: Requirements 9.1**

**Property 36: Discovery awards currency**
*For any* new Brainrot discovery, the player should receive currency.
**Validates: Requirements 9.2**

**Property 37: Milestone badges**
*For any* player who reaches a collection milestone (10, 25, 50, or 100 discoveries), they should be awarded the corresponding badge.
**Validates: Requirements 9.5**

**Property 38: Codex persistence round trip**
*For any* player's Codex data, saving and then loading should produce equivalent data (all discoveries, currency, and badges preserved).
**Validates: Requirements 9.6**

### Multiplayer Properties

**Property 39: Event broadcasting**
*For any* game event (collection, assembly, laser hit, theft), the system should broadcast the event to all connected clients.
**Validates: Requirements 10.2, 10.3, 10.4**

**Property 40: Player capacity limits**
*For any* game session, it should accept between 2 and 8 players and reject additional join attempts.
**Validates: Requirements 10.5**

**Property 41: Disconnect cleanup**
*For any* player who disconnects, their player character should be removed and their base should be marked inactive.
**Validates: Requirements 10.6**

### Arena Boundary Properties

**Property 42: Boundary collision for players**
*For any* player at the arena boundary, they should be unable to move beyond the boundary.
**Validates: Requirements 12.2**

**Property 43: Boundary collision for body parts**
*For any* body part that reaches the arena boundary, it should remain within the playable area (bounce or stop).
**Validates: Requirements 12.3**

**Property 44: Cannon placement**
*For any* cannon, it should be positioned at the arena boundary and face toward the arena center.
**Validates: Requirements 12.5**

### Session Management Properties

**Property 45: Player join assigns base**
*For any* player who joins a session, they should be assigned a unique base location and spawn at that location.
**Validates: Requirements 13.1, 13.2**

**Property 46: Match end displays scores**
*For any* match that ends, the system should display final scores and Brainrot completion counts for all players.
**Validates: Requirements 13.6**

## Error Handling

### Network Error Handling

**Connection Loss:**
- Detect client disconnection within 5 seconds
- Remove disconnected player from game state
- Broadcast disconnection to remaining clients
- Mark player's base as inactive
- Drop any body parts in disconnected player's inventory into arena

**Packet Loss:**
- Use UDP for position updates with client-side prediction
- Use TCP for critical events (collection, assembly, theft)
- Implement acknowledgment system for critical events
- Retry failed critical events up to 3 times
- Log unrecoverable packet loss for debugging

**Desynchronization:**
- Server is authoritative for all game state
- Clients send inputs, server processes and broadcasts results
- Implement periodic full state sync (every 5 seconds)
- Detect desync by comparing client prediction with server state
- Force client state correction when desync detected

### Game Logic Error Handling

**Invalid Inventory State:**
- Validate inventory size before collection (< 3 items)
- Validate inventory composition before assembly (1 head, 1 body, 1 legs)
- Log and reject invalid operations
- Broadcast corrected state to clients

**Pedestal Overflow:**
- Check available pedestals before placement
- If no pedestals available, drop Brainrot in arena as body parts
- Notify player of pedestal shortage
- Log pedestal overflow events

**Collision Detection Failures:**
- Implement spatial partitioning (grid or quadtree) for efficient collision checks
- Use bounding sphere approximations for initial collision tests
- Fall back to precise collision only when spheres intersect
- Log excessive collision check times (> 16ms per frame)

**Physics Instability:**
- Clamp body part velocities to maximum (50 units/second)
- Clamp player velocities to maximum (20 units/second)
- Detect stuck objects (velocity near zero for > 5 seconds)
- Teleport stuck objects to arena center with small random offset

### Input Validation

**Player Input Validation:**
- Validate movement vector magnitude (should be ≤ 1.0)
- Validate rotation angle (should be 0-360 degrees)
- Rate limit input messages (max 60 per second per client)
- Reject inputs from disconnected players

**Interaction Validation:**
- Validate interaction range (player must be within 2 units of target)
- Validate interaction permissions (e.g., cannot steal locked Brainrots)
- Validate target existence (object must still exist in game state)
- Log and reject invalid interactions

### Resource Management

**Memory Management:**
- Pool body part objects (pre-allocate 100 objects)
- Pool particle effect objects (pre-allocate 50 objects)
- Destroy body parts that fall out of arena bounds
- Limit maximum body parts in arena (50 parts)
- Clean up old body parts (> 60 seconds old) if limit reached

**Performance Monitoring:**
- Track frame time and log warnings if > 33ms (< 30 FPS)
- Track network message queue size and log warnings if > 100 messages
- Track active game objects and log warnings if > 500 objects
- Implement emergency cleanup if performance degrades

## Testing Strategy

### Dual Testing Approach

This project will use both unit testing and property-based testing to ensure comprehensive coverage:

**Unit Tests** will focus on:
- Specific examples of game mechanics (e.g., "player with 2 items can collect a third")
- Edge cases (e.g., "player with exactly 3 items cannot collect more")
- Error conditions (e.g., "invalid network messages are rejected")
- Integration points between systems (e.g., "assembly system correctly interacts with codex")

**Property-Based Tests** will focus on:
- Universal properties that hold for all inputs (e.g., "for any player, inventory size ≤ 3")
- Randomized input generation to find unexpected bugs
- Invariants that must always hold (e.g., "total body parts in world + in inventories = constant")
- State machine properties (e.g., "barrier state transitions are valid")

Both approaches are complementary: unit tests catch concrete bugs and verify specific behaviors, while property tests verify general correctness across many scenarios.

### Property-Based Testing Configuration

**Testing Library:** We will use the appropriate property-based testing library for the chosen implementation language:
- **C#/Unity**: Use FsCheck or Hedgehog
- **GDScript/Godot**: Use GUT (Godot Unit Test) with custom property test helpers
- **Python**: Use Hypothesis
- **TypeScript**: Use fast-check

**Test Configuration:**
- Each property test must run a minimum of 100 iterations
- Use deterministic random seeds for reproducibility
- Each test must reference its design document property with a comment tag
- Tag format: `// Feature: brainrot-assembly-chaos, Property {number}: {property_text}`

**Example Property Test Structure (C#/FsCheck):**
```csharp
// Feature: brainrot-assembly-chaos, Property 7: Inventory capacity enforcement
[Property]
public Property InventoryCapacityEnforcement()
{
    return Prop.ForAll<Player, BodyPart>((player, bodyPart) =>
    {
        var canCollect = player.Inventory.Count < 3;
        var result = collectionSystem.TryCollect(player, bodyPart);
        return result == canCollect;
    });
}
```

### Test Coverage Goals

**Core Systems (Must Have 100% Property Coverage):**
- Collection System (Properties 6-10)
- Assembly System (Properties 11-16)
- Combat System (Properties 21-23)
- Theft System (Properties 28-31)

**Supporting Systems (Must Have 80% Property Coverage):**
- Cannon System (Properties 1-5)
- Central Laser (Properties 17-20)
- Base Protection (Properties 24-27)
- Codex (Properties 35-38)

**Integration Systems (Unit Tests + Manual Testing):**
- Multiplayer Synchronization (Properties 39-41)
- Visual/Audio Effects (Properties 32-34)
- Session Management (Properties 45-46)

### Test Data Generation

**Random Generators Needed:**
- **Player Generator**: Random position, rotation, inventory (0-3 items), username
- **BodyPart Generator**: Random type, name fragment, position, velocity
- **Brainrot Generator**: Random combination of three parts
- **GameState Generator**: Random set of players, body parts, laser state
- **Arena Generator**: Random boundary shape (circle or rectangle), size

**Constraints for Generators:**
- Player positions must be within arena bounds
- Body part types must be valid (HEAD, BODY, LEGS)
- Name fragments must be from predefined lists
- Inventory size must be 0-3
- Timestamps must be valid and ordered

### Integration Testing

**Multiplayer Integration Tests:**
- Simulate 2-8 clients connecting to server
- Verify state synchronization across clients
- Test disconnection and reconnection scenarios
- Verify event broadcasting reaches all clients
- Test concurrent actions (e.g., two players collecting same part)

**Physics Integration Tests:**
- Verify body parts follow realistic trajectories
- Test collision detection between all object types
- Verify boundary collisions work correctly
- Test knockback and repulsion forces

**End-to-End Gameplay Tests:**
- Simulate complete match from start to finish
- Verify win conditions trigger correctly
- Test full gameplay loop: spawn → collect → assemble → steal
- Verify Codex updates persist across sessions

### Performance Testing

**Benchmarks:**
- Frame time must stay below 16ms (60 FPS) with 8 players and 50 body parts
- Network message processing must complete within 5ms per frame
- Collision detection must complete within 5ms per frame
- State synchronization must complete within 10ms per frame

**Load Testing:**
- Test with maximum players (8) and maximum body parts (50)
- Test with rapid cannon spawning (minimum interval)
- Test with maximum laser speed (120 deg/s)
- Test with all players punching simultaneously

### Manual Testing Checklist

**Gameplay Feel:**
- [ ] Body parts feel satisfying to catch
- [ ] Laser creates appropriate tension
- [ ] Punching feels responsive and impactful
- [ ] Stealing feels risky but rewarding
- [ ] Visual effects are flashy but not overwhelming
- [ ] Sound effects enhance chaos without being annoying

**Balance Testing:**
- [ ] Match duration feels appropriate (not too short/long)
- [ ] Cannon spawn rate creates good competition
- [ ] Laser acceleration creates escalating difficulty
- [ ] Lock timer duration balances defense and offense
- [ ] Barrier duration provides adequate protection

**User Experience:**
- [ ] Controls are intuitive and responsive
- [ ] Player names are clearly visible
- [ ] Inventory state is obvious at a glance
- [ ] Base locations are easy to identify
- [ ] Codex is satisfying to fill out

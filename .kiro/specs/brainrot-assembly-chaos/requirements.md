# Requirements Document: Brainrot Assembly Chaos

## Introduction

Brainrot Assembly Chaos is a chaotic multiplayer arena game where players compete to assemble complete "Brainrot" creatures by collecting body parts shot from cannons. Players must navigate a dangerous arena with a rotating central laser, compete for falling pieces, and defend their completed assemblies from other players while attempting to steal from opponents.

## Glossary

- **Game_System**: The overall game application managing all game logic, rendering, and multiplayer synchronization
- **Cannon_System**: The subsystem responsible for spawning and launching body parts into the arena
- **Body_Part**: A collectible game object representing one of three types (Head, Body, Legs) with an associated name fragment
- **Brainrot**: A complete assembly of three body parts (one Head, one Body, one Legs) forming a named creature
- **Player**: A human-controlled character in the arena with inventory and collision detection
- **Central_Laser**: A rotating obstacle that spins around the arena center and knocks back players on contact
- **Player_Base**: A designated safe zone for each player containing a pressure plate, barrier, and pedestals
- **Barrier**: A protective force field that blocks other players from entering a base
- **Pedestal**: A display stand in a player's base that holds completed Brainrots
- **Codex**: A persistent collection tracking all discovered Brainrot combinations
- **Arena**: The playable game space containing all game objects and boundaries
- **Inventory**: A player's current collection of carried body parts (maximum 3 pieces)
- **Lock_Timer**: A countdown period during which a completed Brainrot cannot be stolen from its pedestal

## Requirements

### Requirement 1: Cannon Body Part Spawning

**User Story:** As a player, I want body parts to be regularly shot from cannons around the arena, so that I have opportunities to collect pieces and assemble Brainrots.

#### Acceptance Criteria

1. THE Cannon_System SHALL spawn body parts at regular intervals between 2 and 5 seconds
2. WHEN a cannon fires, THE Cannon_System SHALL launch a Body_Part with physics-based velocity and trajectory
3. THE Cannon_System SHALL randomly select the body part type (Head, Body, or Legs) for each spawn
4. THE Cannon_System SHALL assign a random name fragment to each spawned Body_Part
5. WHEN a Body_Part lands in the Arena, THE Game_System SHALL apply physics simulation for realistic bouncing and rolling
6. THE Cannon_System SHALL distribute spawns across multiple cannon locations around the Arena perimeter

### Requirement 2: Body Part Collection

**User Story:** As a player, I want to collect body parts that land near me, so that I can assemble complete Brainrots.

#### Acceptance Criteria

1. WHEN a Player collides with a Body_Part, THE Game_System SHALL add the Body_Part to the Player's Inventory
2. WHEN a Body_Part is collected, THE Game_System SHALL remove the Body_Part from the Arena
3. WHILE a Player's Inventory contains fewer than 3 Body_Parts, THE Game_System SHALL allow collection of additional pieces
4. WHEN a Player's Inventory reaches 3 Body_Parts, THE Game_System SHALL prevent collection of additional pieces until inventory space is available
5. WHEN a Player collects a Body_Part, THE Game_System SHALL update the Player's displayed name to reflect collected name fragments

### Requirement 3: Brainrot Assembly

**User Story:** As a player, I want to complete Brainrot assemblies by collecting one Head, one Body, and one Legs piece, so that I can score points and progress in the game.

#### Acceptance Criteria

1. WHEN a Player's Inventory contains exactly one Head, one Body, and one Legs, THE Game_System SHALL automatically complete a Brainrot assembly
2. WHEN a Brainrot is completed, THE Game_System SHALL combine the three name fragments into a complete Brainrot name
3. WHEN a Brainrot is completed, THE Game_System SHALL place the completed Brainrot on an available Pedestal in the Player's Player_Base
4. WHEN a Brainrot is completed, THE Game_System SHALL clear the Player's Inventory
5. WHEN a Brainrot is completed, THE Game_System SHALL play a victory sound effect and display visual celebration effects
6. WHEN a Brainrot is placed on a Pedestal, THE Game_System SHALL activate a Lock_Timer preventing theft for 10 seconds

### Requirement 4: Central Laser Obstacle

**User Story:** As a player, I want a dangerous rotating laser in the center of the arena, so that the game remains challenging and chaotic.

#### Acceptance Criteria

1. THE Central_Laser SHALL rotate continuously around the center point of the Arena
2. THE Central_Laser SHALL start with an initial rotation speed of 30 degrees per second
3. WHILE the game session duration increases, THE Central_Laser SHALL gradually accelerate up to a maximum of 120 degrees per second
4. WHEN the Central_Laser collides with a Player, THE Game_System SHALL apply a knockback force pushing the Player away from the center
5. WHEN the Central_Laser hits a Player, THE Game_System SHALL cause the Player to drop all Body_Parts from their Inventory
6. WHEN a Player is hit by the Central_Laser, THE Game_System SHALL scatter dropped Body_Parts in random directions within 5 units of the Player's position

### Requirement 5: Player Combat System

**User Story:** As a player, I want to punch other players to make them drop pieces, so that I can compete more aggressively for body parts.

#### Acceptance Criteria

1. WHEN a Player activates the punch action, THE Game_System SHALL execute a melee attack in the Player's facing direction
2. WHEN a punch connects with another Player, THE Game_System SHALL cause the target Player to drop their most recently collected Body_Part
3. WHEN a Player drops a Body_Part from being punched, THE Game_System SHALL eject the Body_Part in the direction of the punch with moderate velocity
4. THE Game_System SHALL enforce a cooldown period of 1 second between punch actions for each Player
5. WHEN a punch connects, THE Game_System SHALL play an impact sound effect and display hit particle effects

### Requirement 6: Base Protection System

**User Story:** As a player, I want to protect my base from other players, so that I can safely store my completed Brainrots.

#### Acceptance Criteria

1. WHEN a Player steps on their own base pressure plate, THE Game_System SHALL activate their Barrier for 5 seconds
2. WHILE a Barrier is active, THE Game_System SHALL prevent other Players from entering the protected Player_Base area
3. WHILE a Barrier is active, THE Game_System SHALL allow the owning Player to move freely in and out of their Player_Base
4. WHEN a Barrier activation duration expires, THE Game_System SHALL deactivate the Barrier
5. THE Game_System SHALL render active Barriers with a visible red translucent effect
6. WHEN a non-owning Player attempts to enter an active Barrier, THE Game_System SHALL apply a repulsion force pushing them away

### Requirement 7: Brainrot Theft System

**User Story:** As a player, I want to steal completed Brainrots from other players' bases, so that I can gain points by raiding opponents.

#### Acceptance Criteria

1. WHEN a Player enters another Player's Player_Base, THE Game_System SHALL allow interaction with Pedestals containing unlocked Brainrots
2. WHILE a Brainrot's Lock_Timer is active, THE Game_System SHALL prevent theft of that Brainrot
3. WHEN a Brainrot's Lock_Timer expires, THE Game_System SHALL mark the Brainrot as stealable
4. WHEN a Player interacts with a stealable Brainrot, THE Game_System SHALL transfer the Brainrot to the stealing Player's Player_Base
5. WHEN a Brainrot is stolen, THE Game_System SHALL place it on an available Pedestal in the thief's Player_Base
6. WHEN a Brainrot is stolen, THE Game_System SHALL activate a new Lock_Timer for that Brainrot

### Requirement 8: Visual and Audio Feedback

**User Story:** As a player, I want flashy visual effects and meme sounds, so that the game feels chaotic and entertaining.

#### Acceptance Criteria

1. WHEN a Brainrot is completed, THE Game_System SHALL display particle effects with neon colors at the Player's location
2. WHEN a Brainrot is completed, THE Game_System SHALL apply screen shake effect for the completing Player
3. WHEN a Player collects a Body_Part, THE Game_System SHALL play a collection sound effect
4. WHEN a Player is hit by the Central_Laser, THE Game_System SHALL play an impact sound effect
5. WHEN a punch connects, THE Game_System SHALL play a meme-style sound effect
6. THE Game_System SHALL render all Body_Parts with bright neon colors corresponding to their type
7. THE Game_System SHALL render the Central_Laser with glowing neon effects and particle trails

### Requirement 9: Codex Progression System

**User Story:** As a player, I want to track all Brainrot combinations I've discovered, so that I can collect them all and earn rewards.

#### Acceptance Criteria

1. WHEN a Player completes a new Brainrot combination for the first time, THE Codex SHALL record the discovery
2. WHEN a new Brainrot is discovered, THE Game_System SHALL award the Player with currency
3. THE Codex SHALL display all discovered Brainrot combinations with their complete names
4. THE Codex SHALL display silhouettes for undiscovered Brainrot combinations
5. WHEN a Player achieves specific collection milestones, THE Codex SHALL award badges
6. THE Codex SHALL persist across game sessions for each Player

### Requirement 10: Multiplayer Synchronization

**User Story:** As a player, I want smooth multiplayer gameplay with other players, so that competition feels fair and responsive.

#### Acceptance Criteria

1. THE Game_System SHALL synchronize Player positions across all connected clients with a maximum latency of 100 milliseconds
2. WHEN a Body_Part is collected by any Player, THE Game_System SHALL broadcast the collection event to all clients
3. WHEN a Brainrot is completed, THE Game_System SHALL synchronize the completion event across all clients
4. WHEN the Central_Laser hits a Player, THE Game_System SHALL synchronize the knockback and dropped pieces across all clients
5. THE Game_System SHALL support 2 to 8 simultaneous Players in a single Arena
6. WHEN a Player disconnects, THE Game_System SHALL remove their Player character and mark their Player_Base as inactive

### Requirement 11: Player Name Display

**User Story:** As a player, I want my displayed name to update dynamically as I collect pieces, so that I can see my progress toward completing a Brainrot.

#### Acceptance Criteria

1. WHEN a Player has no Body_Parts in Inventory, THE Game_System SHALL display the Player's default username
2. WHEN a Player collects a Body_Part, THE Game_System SHALL append the name fragment to the Player's displayed name
3. THE Game_System SHALL display name fragments in the order: Head fragment, Body fragment, Legs fragment
4. WHEN a Player completes a Brainrot, THE Game_System SHALL reset the displayed name to the Player's default username
5. THE Game_System SHALL render the displayed name above each Player character with clear visibility

### Requirement 12: Arena Boundaries

**User Story:** As a player, I want clear arena boundaries, so that I understand the playable area and don't fall off the map.

#### Acceptance Criteria

1. THE Game_System SHALL define a circular or rectangular Arena boundary
2. WHEN a Player reaches the Arena boundary, THE Game_System SHALL prevent movement beyond the boundary
3. WHEN a Body_Part reaches the Arena boundary, THE Game_System SHALL apply collision to keep it within the playable area
4. THE Game_System SHALL render visible boundary markers or walls around the Arena perimeter
5. THE Game_System SHALL position all Cannon locations along the Arena boundary facing inward

### Requirement 13: Game Session Management

**User Story:** As a player, I want to join and leave game sessions easily, so that I can play when I want.

#### Acceptance Criteria

1. WHEN a Player joins a game session, THE Game_System SHALL assign them a Player_Base location
2. WHEN a Player joins a game session, THE Game_System SHALL spawn their Player character at their Player_Base
3. WHEN a game session starts, THE Game_System SHALL initialize the Central_Laser at its starting rotation speed
4. WHEN a game session starts, THE Cannon_System SHALL begin spawning Body_Parts
5. THE Game_System SHALL support match-based gameplay with configurable time limits or score targets
6. WHEN a match ends, THE Game_System SHALL display final scores and Brainrot completion counts for all Players

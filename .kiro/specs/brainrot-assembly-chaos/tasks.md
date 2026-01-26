# Implementation Plan: Brainrot Assembly Chaos

## Overview

This implementation plan breaks down the Brainrot Assembly Chaos game into discrete coding tasks. The approach follows an incremental development strategy: core data structures → basic gameplay systems → multiplayer networking → visual/audio polish → progression systems.

**Note:** This task list is game engine agnostic. Before beginning implementation, choose your target platform (Unity/C#, Godot/GDScript, Phaser/TypeScript, etc.) and adapt the tasks accordingly.

## Tasks

- [x] 1. Project setup and core data structures
  - Set up game project with chosen engine/framework
  - Create core data structure classes: BodyPart, Player, Brainrot, GameState
  - Define enums: BodyPartType, HitType, MessageType
  - Set up testing framework (unit tests and property-based testing library)
  - Create configuration file for game constants (spawn intervals, speeds, durations)
  - _Requirements: All requirements depend on these foundations_

- [x] 2. Implement Arena and boundary system
  - [x] 2.1 Create Arena class with configurable boundary (circular or rectangular)
    - Define arena dimensions and center point
    - Implement boundary collision detection for point-in-bounds checks
    - _Requirements: 12.1, 12.2, 12.3_
  
  - [x] 2.2 Write property test for boundary collision
    - **Property 42: Boundary collision for players**
    - **Property 43: Boundary collision for body parts**
    - **Validates: Requirements 12.2, 12.3**
  
  - [x] 2.3 Implement visual boundary rendering
    - Create boundary markers or walls around arena perimeter
    - _Requirements: 12.4_

- [x] 3. Implement Cannon System
  - [x] 3.1 Create Cannon class and CannonSystem manager
    - Define cannon positions around arena boundary facing inward
    - Implement spawn timer with 2-5 second randomized intervals
    - Load name fragment lists from configuration
    - _Requirements: 1.1, 1.6, 12.5_
  
  - [x] 3.2 Implement body part spawning and launching
    - Generate random body part type (Head, Body, Legs)
    - Assign random name fragment based on type
    - Calculate launch trajectory with physics-based velocity
    - Apply initial velocity and spawn body part in arena
    - _Requirements: 1.2, 1.3, 1.4, 1.5_
  
  - [x] 3.3 Write property tests for cannon system
    - **Property 1: Spawn interval bounds**
    - **Property 3: Body part type distribution**
    - **Property 4: Name fragments assigned**
    - **Property 5: Cannon distribution**
    - **Validates: Requirements 1.1, 1.3, 1.4, 1.6**
  
  - [x] 3.4 Write unit tests for cannon edge cases
    - Test cannon initialization with different arena sizes
    - Test name fragment selection from empty lists (error case)
    - _Requirements: 1.1-1.6_

- [-] 4. Implement Collection System
  - [x] 4.1 Create CollectionSystem class
    - Implement collision detection between players and body parts
    - Implement inventory management (add/remove items, capacity checks)
    - Implement player name display update logic
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 11.1, 11.2, 11.3_
  
  - [ ] 4.2 Write property tests for collection system
    - **Property 6: Collision triggers collection**
    - **Property 7: Inventory capacity enforcement**
    - **Property 8: Collection updates displayed name**
    - **Property 9: Name fragment ordering**
    - **Property 10: Empty inventory shows username**
    - **Validates: Requirements 2.1-2.5, 11.1-11.3**
  
  - [ ] 4.3 Write unit tests for collection edge cases
    - Test collecting when inventory is full
    - Test collecting with empty name fragments
    - Test name display with various fragment combinations
    - _Requirements: 2.1-2.5, 11.1-11.3_

- [ ] 5. Implement Assembly System
  - [x] 5.1 Create AssemblySystem class
    - Implement completion detection (1 head + 1 body + 1 legs)
    - Implement Brainrot name combination logic
    - Implement pedestal management (find available, place Brainrot)
    - Implement lock timer activation
    - Implement inventory clearing after assembly
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 11.4_
  
  - [ ] 5.2 Write property tests for assembly system
    - **Property 11: Complete set triggers assembly**
    - **Property 12: Brainrot name composition**
    - **Property 13: Assembly clears inventory and resets name**
    - **Property 14: Brainrot placement on pedestal**
    - **Property 15: Lock timer activation**
    - **Validates: Requirements 3.1-3.4, 3.6, 11.4**
  
  - [ ] 5.3 Write unit tests for assembly edge cases
    - Test assembly with no available pedestals
    - Test assembly with duplicate body part types
    - Test name combination with special characters
    - _Requirements: 3.1-3.6_

- [ ] 6. Checkpoint - Core gameplay loop functional
  - Verify cannons spawn body parts
  - Verify players can collect body parts
  - Verify assembly completes when player has full set
  - Ensure all tests pass, ask the user if questions arise

- [ ] 7. Implement Central Laser System
  - [x] 7.1 Create CentralLaserSystem class
    - Implement continuous rotation around arena center
    - Implement speed acceleration based on match time (30 → 120 deg/s)
    - Implement collision detection with players
    - Implement knockback force calculation
    - Implement inventory drop with scatter logic
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [ ] 7.2 Write property tests for central laser
    - **Property 17: Continuous rotation**
    - **Property 18: Speed acceleration with cap**
    - **Property 19: Laser hit causes knockback**
    - **Property 20: Laser hit drops all inventory**
    - **Validates: Requirements 4.1, 4.3, 4.4, 4.5, 4.6**
  
  - [ ] 7.3 Write unit tests for laser edge cases
    - Test initial rotation speed (30 deg/s)
    - Test maximum rotation speed cap (120 deg/s)
    - Test scatter distance bounds (within 5 units)
    - _Requirements: 4.1-4.6_

- [ ] 8. Implement Combat System
  - [x] 8.1 Create CombatSystem class
    - Implement punch action with cooldown tracking
    - Implement punch hitbox detection (cone in front of player)
    - Implement item drop logic (drop most recent item)
    - Implement item ejection with velocity in punch direction
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [ ] 8.2 Write property tests for combat system
    - **Property 21: Punch hits drop last item**
    - **Property 22: Punch cooldown enforcement**
    - **Validates: Requirements 5.2, 5.3, 5.4**
  
  - [ ] 8.3 Write unit tests for combat edge cases
    - Test punch with empty inventory
    - Test punch cooldown timing
    - Test punch range limits
    - _Requirements: 5.1-5.4_

- [ ] 9. Implement Base Protection System
  - [x] 9.1 Create BaseProtectionSystem class
    - Implement pressure plate detection for base owners
    - Implement barrier activation with 5-second timer
    - Implement barrier collision detection
    - Implement repulsion force for non-owners
    - Implement owner passage through own barrier
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6_
  
  - [ ] 9.2 Write property tests for base protection
    - **Property 24: Pressure plate activates barrier**
    - **Property 25: Barrier blocks non-owners**
    - **Property 26: Barrier allows owner passage**
    - **Property 27: Barrier deactivation**
    - **Validates: Requirements 6.1-6.4, 6.6**
  
  - [ ] 9.3 Write unit tests for barrier edge cases
    - Test barrier activation by non-owner (should fail)
    - Test barrier expiration timing
    - Test multiple players attempting entry simultaneously
    - _Requirements: 6.1-6.6_

- [ ] 10. Implement Theft System
  - [x] 10.1 Create TheftSystem class
    - Implement interaction detection (player in base, near pedestal)
    - Implement lock timer checking
    - Implement Brainrot transfer logic
    - Implement pedestal management for stolen Brainrots
    - Implement lock timer reactivation after theft
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_
  
  - [ ] 10.2 Write property tests for theft system
    - **Property 28: Lock timer prevents theft**
    - **Property 29: Expired lock allows theft**
    - **Property 30: Theft transfers ownership**
    - **Property 31: Theft reactivates lock**
    - **Validates: Requirements 7.1-7.6**
  
  - [ ] 10.3 Write unit tests for theft edge cases
    - Test theft attempt on locked Brainrot (should fail)
    - Test theft with no available pedestals in thief's base
    - Test theft from own base (should fail)
    - _Requirements: 7.1-7.6_

- [ ] 11. Checkpoint - All core systems integrated
  - Verify laser rotates and hits players
  - Verify punching works and drops items
  - Verify barriers protect bases
  - Verify theft works after lock expires
  - Ensure all tests pass, ask the user if questions arise

- [ ] 12. Implement Codex System
  - [x] 12.1 Create CodexSystem class
    - Implement discovery tracking (set of discovered Brainrot names)
    - Implement currency management
    - Implement badge system with milestone checking
    - Implement persistence (save/load to file or database)
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_
  
  - [ ] 12.2 Write property tests for codex system
    - **Property 35: New discovery recording**
    - **Property 36: Discovery awards currency**
    - **Property 37: Milestone badges**
    - **Property 38: Codex persistence round trip**
    - **Validates: Requirements 9.1, 9.2, 9.5, 9.6**
  
  - [ ] 12.3 Write unit tests for codex edge cases
    - Test duplicate discovery (should not award currency twice)
    - Test milestone boundary conditions (exactly 10, 25, 50, 100)
    - Test persistence with corrupted save data
    - _Requirements: 9.1-9.6_

- [ ] 13. Implement Session Management
  - [x] 13.1 Create GameSessionManager class
    - Implement player join/leave handling
    - Implement base assignment for new players
    - Implement player spawn at base location
    - Implement match lifecycle (start, end, timer)
    - Implement score tracking and final score display
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_
  
  - [ ] 13.2 Write property tests for session management
    - **Property 45: Player join assigns base**
    - **Property 46: Match end displays scores**
    - **Validates: Requirements 13.1, 13.2, 13.6**
  
  - [ ] 13.3 Write unit tests for session edge cases
    - Test laser initialization at start (30 deg/s)
    - Test cannon activation at start
    - Test match timer expiration
    - _Requirements: 13.1-13.6_

- [ ] 14. Implement Multiplayer Networking
  - [ ] 14.1 Set up client-server architecture
    - Implement server-side authoritative game state
    - Implement client-side prediction for local player
    - Set up network message serialization/deserialization
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [ ] 14.2 Implement network synchronization
    - Implement player input message handling
    - Implement state update broadcasting
    - Implement event broadcasting (collection, assembly, hits, theft)
    - Implement periodic full state sync (every 5 seconds)
    - _Requirements: 10.2, 10.3, 10.4_
  
  - [ ] 14.3 Implement connection management
    - Implement player connection handling (2-8 players)
    - Implement disconnection detection and cleanup
    - Implement reconnection support
    - _Requirements: 10.5, 10.6_
  
  - [ ] 14.4 Write property tests for networking
    - **Property 39: Event broadcasting**
    - **Property 40: Player capacity limits**
    - **Property 41: Disconnect cleanup**
    - **Validates: Requirements 10.2-10.6**
  
  - [ ] 14.5 Write integration tests for multiplayer
    - Test state synchronization with 2 clients
    - Test state synchronization with 8 clients
    - Test concurrent collection of same body part
    - Test disconnection during active gameplay
    - _Requirements: 10.1-10.6_

- [ ] 15. Checkpoint - Multiplayer functional
  - Verify multiple clients can connect
  - Verify state synchronizes across clients
  - Verify events broadcast correctly
  - Verify disconnection cleanup works
  - Ensure all tests pass, ask the user if questions arise

- [ ] 16. Implement Visual Effects System
  - [ ] 16.1 Create VFXSystem class
    - Implement particle effect pooling
    - Implement completion effect (neon burst particles)
    - Implement collection effect (sparkle particles)
    - Implement hit effects (laser, punch)
    - Implement screen shake effect
    - Implement neon glow rendering for body parts and laser
    - _Requirements: 3.5, 8.1, 8.2, 8.6, 8.7_
  
  - [ ] 16.2 Implement visual feedback triggers
    - Wire assembly completion to celebration effects
    - Wire collection to sparkle effects
    - Wire laser hits to impact effects
    - Wire punch hits to star burst effects
    - _Requirements: 3.5, 8.1, 8.2_
  
  - [ ] 16.3 Write property tests for visual effects
    - **Property 16: Assembly triggers celebration**
    - **Property 32: Body part color coding**
    - **Validates: Requirements 3.5, 8.1, 8.2, 8.6**
  
  - [ ] 16.4 Write unit tests for VFX edge cases
    - Test particle pooling with many simultaneous effects
    - Test color assignment for each body part type
    - Test screen shake intensity and duration
    - _Requirements: 8.1, 8.2, 8.6, 8.7_

- [ ] 17. Implement Audio System
  - [ ] 17.1 Create AudioSystem class
    - Load sound effect assets
    - Implement sound effect playback with spatial audio
    - Implement music track management
    - _Requirements: 3.5, 5.5, 8.3, 8.4, 8.5_
  
  - [ ] 17.2 Implement audio feedback triggers
    - Wire completion to victory sound
    - Wire collection to pop sound
    - Wire laser hits to zap sound
    - Wire punch hits to cartoon punch sound
    - Wire cannon fire to whoosh sound
    - Wire barrier activation to force field hum
    - Wire theft to sneaky sound
    - _Requirements: 3.5, 5.5, 8.3, 8.4, 8.5_
  
  - [ ] 17.3 Write property tests for audio system
    - **Property 23: Punch triggers effects**
    - **Property 33: Collection triggers sound**
    - **Property 34: Laser hit triggers sound**
    - **Validates: Requirements 5.5, 8.3, 8.4**
  
  - [ ] 17.4 Write unit tests for audio edge cases
    - Test sound playback with missing audio files
    - Test simultaneous sound effects (many at once)
    - Test spatial audio positioning
    - _Requirements: 3.5, 5.5, 8.3-8.5_

- [ ] 18. Implement UI System
  - [ ] 18.1 Create player name display
    - Render player names above characters
    - Update names dynamically as inventory changes
    - _Requirements: 2.5, 11.1-11.5_
  
  - [ ] 18.2 Create Codex UI
    - Display discovered Brainrots with names
    - Display silhouettes for undiscovered combinations
    - Display currency and badges
    - _Requirements: 9.3, 9.4_
  
  - [ ] 18.3 Create match UI
    - Display match timer
    - Display player scores
    - Display final scores at match end
    - _Requirements: 13.5, 13.6_
  
  - [ ] 18.4 Write unit tests for UI components
    - Test name rendering with long names
    - Test Codex display with many discoveries
    - Test score display with multiple players
    - _Requirements: 9.3, 9.4, 11.5, 13.6_

- [ ] 19. Implement Error Handling and Validation
  - [ ] 19.1 Add network error handling
    - Implement connection loss detection
    - Implement packet loss handling with retries
    - Implement desynchronization detection and correction
    - _Requirements: 10.1-10.6_
  
  - [ ] 19.2 Add game logic validation
    - Validate inventory state before operations
    - Validate pedestal availability before placement
    - Validate interaction permissions and ranges
    - _Requirements: 2.1-2.4, 3.3, 7.1-7.6_
  
  - [ ] 19.3 Add resource management
    - Implement body part pooling and cleanup
    - Implement particle effect pooling
    - Implement performance monitoring and logging
    - _Requirements: 1.1-1.6_
  
  - [ ] 19.4 Write unit tests for error handling
    - Test invalid inventory operations
    - Test pedestal overflow scenarios
    - Test invalid interaction attempts
    - Test resource cleanup under load
    - _Requirements: All requirements_

- [ ] 20. Performance Optimization and Polish
  - [ ] 20.1 Optimize collision detection
    - Implement spatial partitioning (grid or quadtree)
    - Use bounding sphere approximations
    - Profile and optimize hot paths
    - _Requirements: 2.1, 4.4, 5.1_
  
  - [ ] 20.2 Optimize network traffic
    - Implement delta compression for state updates
    - Reduce update frequency for distant objects
    - Batch multiple events into single messages
    - _Requirements: 10.1-10.4_
  
  - [ ] 20.3 Add performance monitoring
    - Track frame time and log warnings
    - Track network message queue size
    - Track active game object count
    - Implement emergency cleanup if performance degrades
    - _Requirements: All requirements_
  
  - [ ] 20.4 Run performance benchmarks
    - Test with 8 players and 50 body parts
    - Test with maximum laser speed
    - Test with rapid cannon spawning
    - Verify 60 FPS maintained under load
    - _Requirements: All requirements_

- [ ] 21. Final Integration and Testing
  - [ ] 21.1 Run full integration test suite
    - Execute all property-based tests (100+ iterations each)
    - Execute all unit tests
    - Execute all multiplayer integration tests
    - _Requirements: All requirements_
  
  - [ ] 21.2 Conduct manual gameplay testing
    - Test gameplay feel and balance
    - Test visual and audio polish
    - Test user experience and controls
    - _Requirements: All requirements_
  
  - [ ] 21.3 Fix any discovered issues
    - Address test failures
    - Fix gameplay balance issues
    - Polish rough edges
    - _Requirements: All requirements_

- [ ] 22. Final checkpoint - Game complete
  - Verify all systems work together seamlessly
  - Verify all tests pass
  - Verify multiplayer works with 2-8 players
  - Verify game is fun and chaotic
  - Ask the user for final feedback

## Notes

- All tasks are required for comprehensive implementation
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation throughout development
- Property tests validate universal correctness properties with 100+ iterations each
- Unit tests validate specific examples, edge cases, and error conditions
- Integration tests verify systems work together correctly
- The implementation order prioritizes core gameplay first, then multiplayer, then polish

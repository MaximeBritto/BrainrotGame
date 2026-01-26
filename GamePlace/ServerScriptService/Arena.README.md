# Arena Module

## Overview

The Arena module manages arena boundaries and collision detection for the Brainrot Assembly Chaos game. It supports both circular and rectangular arena boundaries.

## Requirements

Implements requirements:
- **12.1**: Define arena boundaries (circular or rectangular)
- **12.2**: Prevent player movement beyond boundaries
- **12.3**: Apply collision to keep body parts within playable area

## Features

### Boundary Types

- **Circular**: Defined by a center point and radius
- **Rectangular**: Defined by a center point, width, and length

### Core Functions

#### `Arena.new(boundaryType, center, dimensions)`
Creates a new Arena instance.

**Parameters:**
- `boundaryType` (string): Either `Arena.BoundaryType.CIRCULAR` or `Arena.BoundaryType.RECTANGULAR`
- `center` (Vector3): The center point of the arena
- `dimensions` (table): 
  - For circular: `{radius = number}`
  - For rectangular: `{width = number, length = number}`

**Returns:** Arena instance

**Example:**
```lua
local Arena = require(game.ServerScriptService.Arena)

-- Create circular arena
local circularArena = Arena.new(
    Arena.BoundaryType.CIRCULAR,
    Vector3.new(0, 0, 0),
    {radius = 50}
)

-- Create rectangular arena
local rectangularArena = Arena.new(
    Arena.BoundaryType.RECTANGULAR,
    Vector3.new(0, 0, 0),
    {width = 100, length = 80}
)
```

#### `Arena.createDefault()`
Creates a circular arena using default configuration from GameConfig.

**Returns:** Arena instance with default settings

**Example:**
```lua
local arena = Arena.createDefault()
```

#### `Arena:IsInBounds(position)`
Checks if a position is within the arena boundaries.

**Parameters:**
- `position` (Vector3): The position to check

**Returns:** boolean - true if within bounds, false otherwise

**Example:**
```lua
local playerPosition = Vector3.new(10, 0, 10)
if arena:IsInBounds(playerPosition) then
    print("Player is inside arena")
else
    print("Player is outside arena")
end
```

#### `Arena:GetClosestPointOnBoundary(position)`
Gets the closest point on the boundary to a given position. Useful for collision response.

**Parameters:**
- `position` (Vector3): The position to find the closest boundary point for

**Returns:** Vector3 - The closest point on the boundary

**Example:**
```lua
local bodyPartPosition = Vector3.new(100, 5, 0)
local boundaryPoint = arena:GetClosestPointOnBoundary(bodyPartPosition)
-- Use boundaryPoint to bounce or stop the body part
```

#### `Arena:ConstrainToBounds(position)`
Constrains a position to be within arena bounds. If the position is outside, returns the closest point on the boundary.

**Parameters:**
- `position` (Vector3): The position to constrain

**Returns:** Vector3 - The constrained position

**Example:**
```lua
local newPosition = arena:ConstrainToBounds(player.Position)
player.Position = newPosition
```

#### `Arena:GetDimensions()`
Gets the arena dimensions for external use.

**Returns:** table with arena information

**Example:**
```lua
local dims = arena:GetDimensions()
print("Arena type:", dims.type)
print("Center:", dims.center)
if dims.type == "CIRCULAR" then
    print("Radius:", dims.radius)
else
    print("Width:", dims.width, "Length:", dims.length)
end
```

## Implementation Details

### Circular Boundary
- Uses 2D distance calculation (ignoring Y axis)
- Distance from center: `sqrt((x - centerX)^2 + (z - centerZ)^2)`
- Point is in bounds if distance ≤ radius

### Rectangular Boundary
- Uses axis-aligned bounding box
- Checks if position is within width/2 and length/2 from center
- Point is in bounds if both X and Z are within bounds

### Y-Axis Handling
- Boundary checks ignore the Y coordinate (vertical axis)
- This allows for vertical movement while constraining horizontal movement
- Y coordinate is preserved in all boundary operations

## Testing

Run the unit tests using:
```lua
local ArenaTests = require(game.ServerScriptService["Arena.test"])
ArenaTests.runAll()
```

Or use the test runner script:
```lua
-- The RunArenaTests.server.lua script will automatically run tests
```

## Usage in Game Systems

### Player Movement System
```lua
local Arena = require(game.ServerScriptService.Arena)
local arena = Arena.createDefault()

-- In player movement update
local newPosition = player.Position + velocity * deltaTime
if not arena:IsInBounds(newPosition) then
    -- Constrain to boundary
    newPosition = arena:ConstrainToBounds(newPosition)
    -- Optionally apply bounce or stop velocity
end
player.Position = newPosition
```

### Body Part Physics
```lua
-- In body part physics update
local bodyPart = bodyParts[id]
local newPosition = bodyPart.position + bodyPart.velocity * deltaTime

if not arena:IsInBounds(newPosition) then
    -- Get boundary point for collision response
    local boundaryPoint = arena:GetClosestPointOnBoundary(newPosition)
    
    -- Calculate bounce direction
    local normal = (newPosition - boundaryPoint).Unit
    bodyPart.velocity = bodyPart.velocity - 2 * bodyPart.velocity:Dot(normal) * normal
    
    -- Constrain position
    bodyPart.position = arena:ConstrainToBounds(newPosition)
end
```

### Cannon Placement
```lua
-- Place cannons around arena perimeter
local arena = Arena.createDefault()
local dims = arena:GetDimensions()

for i = 1, GameConfig.CANNON_COUNT do
    local angle = (i - 1) * (360 / GameConfig.CANNON_COUNT)
    local radians = math.rad(angle)
    
    -- Position on boundary
    local x = dims.center.X + dims.radius * math.cos(radians)
    local z = dims.center.Z + dims.radius * math.sin(radians)
    local position = Vector3.new(x, 5, z)
    
    -- Direction toward center
    local direction = (dims.center - position).Unit
    
    local cannon = DataStructures.CreateCannon(position, direction)
    table.insert(gameState.cannons, cannon)
end
```

## Configuration

Arena settings are defined in `GamePlace/ReplicatedStorage/GameConfig.lua`:

```lua
GameConfig.ARENA_RADIUS = 50 -- studs
GameConfig.ARENA_CENTER = Vector3.new(0, 0, 0)
```

## Notes

- The Arena module is server-side only (in ServerScriptService)
- Boundary collision is 2D (horizontal plane only)
- Y coordinate is preserved in all operations
- Both boundary types use the same interface for consistency
- Validation ensures invalid configurations throw errors early

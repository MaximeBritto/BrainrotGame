-- Arena Visuals Server Script
-- Creates visual boundary markers around the arena
-- Requirements: 12.4

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(script.Parent.Arena)

local ArenaVisuals = {}

-- Create a circular boundary wall
function ArenaVisuals.CreateCircularBoundary(arena)
	local dims = arena:GetDimensions()
	local folder = Instance.new("Folder")
	folder.Name = "ArenaBoundary"
	folder.Parent = Workspace
	
	-- Create segments around the circle
	local segmentCount = 60 -- More segments = smoother circle
	local segmentAngle = 360 / segmentCount
	
	for i = 1, segmentCount do
		local angle1 = math.rad((i - 1) * segmentAngle)
		local angle2 = math.rad(i * segmentAngle)
		
		-- Calculate positions
		local x1 = dims.center.X + dims.radius * math.cos(angle1)
		local z1 = dims.center.Z + dims.radius * math.sin(angle1)
		local x2 = dims.center.X + dims.radius * math.cos(angle2)
		local z2 = dims.center.Z + dims.radius * math.sin(angle2)
		
		local pos1 = Vector3.new(x1, dims.center.Y, z1)
		local pos2 = Vector3.new(x2, dims.center.Y, z2)
		
		-- Create wall segment
		local segment = Instance.new("Part")
		segment.Name = "BoundarySegment" .. i
		segment.Size = Vector3.new(0.5, 10, (pos2 - pos1).Magnitude)
		segment.Position = (pos1 + pos2) / 2 + Vector3.new(0, 5, 0)
		segment.Anchored = true
		segment.CanCollide = true
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(255, 255, 255)
		segment.Transparency = 0.3
		
		-- Rotate to face tangent
		local direction = (pos2 - pos1).Unit
		segment.CFrame = CFrame.new(segment.Position, segment.Position + direction)
		
		segment.Parent = folder
	end
	
	return folder
end

-- Create a rectangular boundary wall
function ArenaVisuals.CreateRectangularBoundary(arena)
	local dims = arena:GetDimensions()
	local folder = Instance.new("Folder")
	folder.Name = "ArenaBoundary"
	folder.Parent = Workspace
	
	local halfWidth = dims.width / 2
	local halfLength = dims.length / 2
	
	-- Create 4 walls
	local walls = {
		-- North wall
		{
			position = Vector3.new(dims.center.X, dims.center.Y + 5, dims.center.Z + halfLength),
			size = Vector3.new(dims.width, 10, 0.5)
		},
		-- South wall
		{
			position = Vector3.new(dims.center.X, dims.center.Y + 5, dims.center.Z - halfLength),
			size = Vector3.new(dims.width, 10, 0.5)
		},
		-- East wall
		{
			position = Vector3.new(dims.center.X + halfWidth, dims.center.Y + 5, dims.center.Z),
			size = Vector3.new(0.5, 10, dims.length)
		},
		-- West wall
		{
			position = Vector3.new(dims.center.X - halfWidth, dims.center.Y + 5, dims.center.Z),
			size = Vector3.new(0.5, 10, dims.length)
		}
	}
	
	for i, wallData in ipairs(walls) do
		local wall = Instance.new("Part")
		wall.Name = "BoundaryWall" .. i
		wall.Size = wallData.size
		wall.Position = wallData.position
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = Enum.Material.Neon
		wall.Color = Color3.fromRGB(255, 255, 255)
		wall.Transparency = 0.3
		wall.Parent = folder
	end
	
	return folder
end

-- Create boundary based on arena type
function ArenaVisuals.CreateBoundary(arena)
	local dims = arena:GetDimensions()
	
	if dims.type == "CIRCULAR" then
		return ArenaVisuals.CreateCircularBoundary(arena)
	elseif dims.type == "RECTANGULAR" then
		return ArenaVisuals.CreateRectangularBoundary(arena)
	end
	
	return nil
end

-- Initialize arena visuals based on ArenaFloor in workspace
print("🔍 Searching for ArenaFloor...")

-- Function to recursively search for ArenaFloor
local function findArenaFloorRecursive(parent, depth)
	depth = depth or 0
	if depth > 5 then return nil end -- Limit recursion depth
	
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == "ArenaFloor" and child:IsA("BasePart") then
			return child
		end
		
		-- Search in folders and models
		if child:IsA("Folder") or child:IsA("Model") then
			local found = findArenaFloorRecursive(child, depth + 1)
			if found then return found end
		end
	end
	
	return nil
end

-- Try multiple search strategies
local arenaFloor = nil

-- Strategy 1: Direct child of Workspace
arenaFloor = Workspace:FindFirstChild("ArenaFloor")
if arenaFloor and arenaFloor:IsA("BasePart") then
	print(string.format("✓ Found ArenaFloor as direct child of Workspace"))
else
	-- Strategy 2: Recursive search from Workspace
	arenaFloor = findArenaFloorRecursive(Workspace)
	if arenaFloor then
		print(string.format("✓ Found ArenaFloor via recursive search: %s", arenaFloor:GetFullName()))
	else
		-- Strategy 3: Wait a bit and try again (in case it's loading)
		print("⏳ Waiting for ArenaFloor to load...")
		task.wait(0.5)
		arenaFloor = findArenaFloorRecursive(Workspace)
		if arenaFloor then
			print(string.format("✓ Found ArenaFloor after waiting: %s", arenaFloor:GetFullName()))
		end
	end
end

-- Debug: List all parts in Workspace if still not found
if not arenaFloor then
	print("❌ ArenaFloor not found! Listing all BaseParts in Workspace:")
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child:IsA("BasePart") and child.Name:lower():find("floor") then
			print(string.format("  - Found part with 'floor' in name: %s (%s)", child:GetFullName(), tostring(child.Size)))
		end
	end
end

local arena
if arenaFloor and arenaFloor:IsA("BasePart") then
	-- Create arena based on ArenaFloor dimensions
	local floorSize = arenaFloor.Size
	local floorPosition = arenaFloor.Position
	
	print(string.format("✓ Found ArenaFloor: size=%s, position=%s", tostring(floorSize), tostring(floorPosition)))
	
	-- Determine if we should use circular or rectangular based on floor shape
	local isCircular = math.abs(floorSize.X - floorSize.Z) < 5 -- If X and Z are similar, treat as circular
	
	if isCircular then
		-- Use the average of X and Z as DIAMETER, then divide by 2 for radius
		local diameter = (floorSize.X + floorSize.Z) / 2
		local radius = diameter / 2
		arena = Arena.createCircular(floorPosition, radius)
		print(string.format("✓ Created circular arena from ArenaFloor (diameter: %.1f, radius: %.1f)", diameter, radius))
	else
		-- Use rectangular
		arena = Arena.createRectangular(floorPosition, floorSize.X, floorSize.Z)
		print(string.format("✓ Created rectangular arena from ArenaFloor (%.1f x %.1f)", floorSize.X, floorSize.Z))
	end
	
	-- Don't create visual boundary walls - just use ArenaFloor surface
	print("✓ Arena configured (using ArenaFloor surface only, no boundary walls)")
else
	warn("❌ ArenaFloor not found anywhere! Using default arena.")
	warn("⚠️ Please check where ArenaFloor is located in your Studio hierarchy.")
	
	arena = Arena.createDefault()
	
	-- Don't create visual boundary walls
	print("✓ Arena configured (default, no boundary walls)")
end

-- Store arena globally so GameServer can access it
_G.Arena = arena

return ArenaVisuals

-- Arena Visuals Server Script
-- Creates visual boundary markers around the arena
-- Requirements: 12.4

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(script.Parent.Arena)
local GameConfig = require(ReplicatedStorage.GameConfig)

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

-- Initialize arena visuals on server start
local arena = Arena.createDefault()
local boundaryFolder = ArenaVisuals.CreateBoundary(arena)

print("✓ Arena boundary created:", arena:GetDimensions().type)

return ArenaVisuals

-- Cannon System Module
-- Manages body part spawning and launching from cannons
-- Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 12.5

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)
local NameFragments = require(ReplicatedStorage.NameFragments)

local CannonSystem = {}
CannonSystem.__index = CannonSystem

--[[
	Creates a new CannonSystem instance
	
	@param arena Arena - The arena instance for cannon placement
	@return CannonSystem - New CannonSystem instance
]]
function CannonSystem.new(arena)
	local self = setmetatable({}, CannonSystem)
	
	self.cannons = {}
	self.lastSpawnTime = 0
	self.nextSpawnInterval = math.random(
		GameConfig.CANNON_SPAWN_INTERVAL_MIN,
		GameConfig.CANNON_SPAWN_INTERVAL_MAX
	)
	self.arena = arena
	self.bodyParts = {} -- Map of id -> BodyPart
	
	-- Initialize cannons around arena perimeter
	self:InitializeCannons()
	
	return self
end

--[[
	Initializes cannons around the arena boundary facing inward
	Requirements: 1.6, 12.5
]]
function CannonSystem:InitializeCannons()
	local dims = self.arena:GetDimensions()
	
	if dims.type == "CIRCULAR" then
		-- Place cannons evenly around circle
		for i = 1, GameConfig.CANNON_COUNT do
			local angle = (i - 1) * (360 / GameConfig.CANNON_COUNT)
			local radians = math.rad(angle)
			
			-- Position on boundary
			local x = dims.center.X + dims.radius * math.cos(radians)
			local z = dims.center.Z + dims.radius * math.sin(radians)
			local position = Vector3.new(x, dims.center.Y + 5, z)
			
			-- Direction toward center
			local direction = (dims.center - position).Unit
			
			local cannon = DataStructures.CreateCannon(position, direction)
			table.insert(self.cannons, cannon)
		end
	elseif dims.type == "RECTANGULAR" then
		-- Place cannons evenly around rectangle perimeter
		local halfWidth = dims.width / 2
		local halfLength = dims.length / 2
		local cannonsPerSide = math.ceil(GameConfig.CANNON_COUNT / 4)
		
		-- North side
		for i = 1, cannonsPerSide do
			local x = dims.center.X - halfWidth + (i / (cannonsPerSide + 1)) * dims.width
			local position = Vector3.new(x, dims.center.Y + 5, dims.center.Z + halfLength)
			local direction = (dims.center - position).Unit
			table.insert(self.cannons, DataStructures.CreateCannon(position, direction))
		end
		
		-- East side
		for i = 1, cannonsPerSide do
			local z = dims.center.Z - halfLength + (i / (cannonsPerSide + 1)) * dims.length
			local position = Vector3.new(dims.center.X + halfWidth, dims.center.Y + 5, z)
			local direction = (dims.center - position).Unit
			table.insert(self.cannons, DataStructures.CreateCannon(position, direction))
		end
		
		-- South side
		for i = 1, cannonsPerSide do
			local x = dims.center.X - halfWidth + (i / (cannonsPerSide + 1)) * dims.width
			local position = Vector3.new(x, dims.center.Y + 5, dims.center.Z - halfLength)
			local direction = (dims.center - position).Unit
			table.insert(self.cannons, DataStructures.CreateCannon(position, direction))
		end
		
		-- West side
		for i = 1, cannonsPerSide do
			local z = dims.center.Z - halfLength + (i / (cannonsPerSide + 1)) * dims.length
			local position = Vector3.new(dims.center.X - halfWidth, dims.center.Y + 5, z)
			local direction = (dims.center - position).Unit
			table.insert(self.cannons, DataStructures.CreateCannon(position, direction))
		end
	end
	
	print(string.format("✓ Initialized %d cannons around arena", #self.cannons))
end

--[[
	Selects a random cannon from the available cannons
	
	@return Cannon - Randomly selected cannon
]]
function CannonSystem:SelectRandomCannon()
	return self.cannons[math.random(1, #self.cannons)]
end

--[[
	Generates a random body part type
	Requirements: 1.3
	
	@return string - Body part type (HEAD, BODY, or LEGS)
]]
function CannonSystem:GenerateRandomBodyPartType()
	local types = {
		DataStructures.BodyPartType.HEAD,
		DataStructures.BodyPartType.BODY,
		DataStructures.BodyPartType.LEGS
	}
	return types[math.random(1, #types)]
end

--[[
	Spawns a new body part from a random cannon
	Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
	
	@return BodyPart - The spawned body part
	@return Cannon - The cannon that spawned it
]]
function CannonSystem:SpawnBodyPart()
	-- Select random cannon
	local cannon = self:SelectRandomCannon()
	
	-- Generate random body part type
	local bodyPartType = self:GenerateRandomBodyPartType()
	
	-- Generate random name fragment
	local nameFragment = NameFragments.GetRandom(bodyPartType)
	
	-- Randomize launch parameters
	cannon.launchForce = math.random(
		GameConfig.CANNON_LAUNCH_FORCE_MIN,
		GameConfig.CANNON_LAUNCH_FORCE_MAX
	)
	cannon.launchAngle = math.random(
		GameConfig.CANNON_LAUNCH_ANGLE_MIN,
		GameConfig.CANNON_LAUNCH_ANGLE_MAX
	)
	
	-- Calculate launch trajectory
	local angleRad = math.rad(cannon.launchAngle)
	local horizontalForce = cannon.launchForce * math.cos(angleRad)
	local verticalForce = cannon.launchForce * math.sin(angleRad)
	
	-- Calculate velocity vector
	local velocity = cannon.direction * horizontalForce + Vector3.new(0, verticalForce, 0)
	
	-- Create body part data
	local bodyPart = DataStructures.CreateBodyPart(
		nil, -- ID will be auto-generated
		bodyPartType,
		nameFragment,
		cannon.position,
		velocity
	)
	
	-- CREATE PHYSICAL OBJECT IN WORKSPACE
	local templates = ReplicatedStorage:FindFirstChild("BodyPartTemplates")
	if templates then
		local templateName = bodyPartType == DataStructures.BodyPartType.HEAD and "HeadTemplate"
			or bodyPartType == DataStructures.BodyPartType.BODY and "BodyTemplate"
			or "LegsTemplate"
		
		local template = templates:FindFirstChild(templateName)
		if template then
			-- Clone the template
			local physicalPart = template:Clone()
			physicalPart.Name = bodyPart.id
			
			-- Add tag to identify as collectible body part
			physicalPart:SetAttribute("IsBodyPart", true)
			physicalPart:SetAttribute("BodyPartId", bodyPart.id)
			
			-- Position it at cannon
			if physicalPart:IsA("Model") and physicalPart.PrimaryPart then
				physicalPart:SetPrimaryPartCFrame(CFrame.new(cannon.position))
			elseif physicalPart:IsA("Model") then
				local mainPart = physicalPart:FindFirstChildWhichIsA("BasePart")
				if mainPart then
					mainPart.CFrame = CFrame.new(cannon.position)
				end
			end
			
			-- Apply velocity to main part
			local mainPart = physicalPart.PrimaryPart or physicalPart:FindFirstChildWhichIsA("BasePart")
			if mainPart then
				mainPart.Anchored = false
				mainPart.AssemblyLinearVelocity = velocity
			end
			
			-- Parent to workspace
			physicalPart.Parent = game.Workspace
			
			-- Store reference
			bodyPart.physicalObject = physicalPart
			
			-- Register with physics manager for collision detection
			if _G.RegisterBodyPart then
				_G.RegisterBodyPart(physicalPart, bodyPart.id)
			end
			
			print(string.format("🚀 Spawned %s: %s at %s", bodyPartType, nameFragment, tostring(cannon.position)))
		else
			warn(string.format("❌ Template not found: %s", templateName))
		end
	else
		warn("❌ BodyPartTemplates folder not found in ReplicatedStorage")
	end
	
	-- Store in system
	self.bodyParts[bodyPart.id] = bodyPart
	
	return bodyPart, cannon
end

--[[
	Updates the cannon system (call every frame)
	Handles spawn timing
	
	@param deltaTime number - Time since last update in seconds
	@param currentTime number - Current game time
	@return BodyPart|nil - Spawned body part if one was spawned this frame
	@return Cannon|nil - Cannon that spawned the part
]]
function CannonSystem:Update(deltaTime, currentTime)
	-- Check if it's time to spawn
	local timeSinceLastSpawn = currentTime - self.lastSpawnTime
	
	if timeSinceLastSpawn >= self.nextSpawnInterval then
		-- Spawn body part
		local bodyPart, cannon = self:SpawnBodyPart()
		
		-- Update timing
		self.lastSpawnTime = currentTime
		self.nextSpawnInterval = math.random(
			GameConfig.CANNON_SPAWN_INTERVAL_MIN,
			GameConfig.CANNON_SPAWN_INTERVAL_MAX
		)
		
		return bodyPart, cannon
	end
	
	return nil, nil
end

--[[
	Gets all active body parts
	
	@return table - Map of id -> BodyPart
]]
function CannonSystem:GetBodyParts()
	return self.bodyParts
end

--[[
	Removes a body part from the system (when collected)
	
	@param bodyPartId string - ID of the body part to remove
]]
function CannonSystem:RemoveBodyPart(bodyPartId)
	self.bodyParts[bodyPartId] = nil
end

--[[
	Gets cannon count
	
	@return number - Number of cannons
]]
function CannonSystem:GetCannonCount()
	return #self.cannons
end

--[[
	Gets all cannons
	
	@return table - Array of Cannon objects
]]
function CannonSystem:GetCannons()
	return self.cannons
end

return CannonSystem

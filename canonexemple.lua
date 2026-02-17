-- Cannon System Module
-- Manages body part spawning and launching from cannons
-- Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 12.5

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)
local NameFragments = require(ReplicatedStorage.NameFragments)

-- Load GameEvents for body part registration
local ServerScriptService = game:GetService("ServerScriptService")
local GameEvents = require(ServerScriptService.GameEvents)

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
	Initializes cannons by finding physical cannon models in workspace
	Requirements: 1.6, 12.5
]]
function CannonSystem:InitializeCannons()
	-- Find physical cannons in workspace
	local workspace = game:GetService("Workspace")
	local cannonsFolder = workspace:FindFirstChild("Cannons")
	
	if cannonsFolder then
		-- Use physical cannons from Roblox Studio
		for _, cannonModel in ipairs(cannonsFolder:GetChildren()) do
			if cannonModel:IsA("Model") or cannonModel:IsA("BasePart") then
				-- Find the barrel or main part
				local barrelPart = cannonModel:FindFirstChild("Barrel") 
					or cannonModel:FindFirstChild("CannonBarrel")
					or cannonModel.PrimaryPart
					or cannonModel:FindFirstChildWhichIsA("BasePart")
				
				if barrelPart then
					local position = barrelPart.Position
					
					-- Calculate direction toward arena center
					local dims = self.arena:GetDimensions()
					local direction = (dims.center - position).Unit
					
					local cannon = DataStructures.CreateCannon(position, direction)
					cannon.physicalModel = cannonModel -- Store reference to physical model
					cannon.barrelPart = barrelPart -- Store barrel reference for effects
					table.insert(self.cannons, cannon)
					
					print(string.format("✓ Found cannon: %s at %s", cannonModel.Name, tostring(position)))
				end
			end
		end
		
		if #self.cannons > 0 then
			print(string.format("✓ Initialized %d physical cannons from workspace", #self.cannons))
			return
		end
	end
	
	-- Fallback: create virtual cannons if no physical ones found
	print("⚠️ No physical cannons found in workspace, creating virtual cannons")
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
	end
	
	print(string.format("✓ Initialized %d virtual cannons", #self.cannons))
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
	Creates a visual firing effect at the cannon
	
	@param cannon Cannon - The cannon that's firing
]]
function CannonSystem:CreateFireEffect(cannon)
	local barrelPart = cannon.barrelPart
	if not barrelPart then
		return
	end
	
	-- Create muzzle flash
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(3, 3, 3)
	flash.Position = barrelPart.Position + cannon.direction * 3
	flash.BrickColor = BrickColor.new("Deep orange")
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 0
	flash.Parent = game.Workspace
	
	-- Fade out flash
	task.spawn(function()
		for i = 0, 1, 0.1 do
			if flash and flash.Parent then
				flash.Transparency = i
				flash.Size = flash.Size * 1.2
			end
			task.wait(0.05)
		end
		if flash and flash.Parent then
			flash:Destroy()
		end
	end)
	
	-- Create smoke puff
	local smoke = Instance.new("Part")
	smoke.Name = "Smoke"
	smoke.Shape = Enum.PartType.Ball
	smoke.Size = Vector3.new(2, 2, 2)
	smoke.Position = barrelPart.Position + cannon.direction * 2
	smoke.BrickColor = BrickColor.new("Medium stone grey")
	smoke.Material = Enum.Material.SmoothPlastic
	smoke.Anchored = true
	smoke.CanCollide = false
	smoke.Transparency = 0.3
	smoke.Parent = game.Workspace
	
	-- Expand and fade smoke
	task.spawn(function()
		for i = 0, 1, 0.05 do
			if smoke and smoke.Parent then
				smoke.Transparency = 0.3 + (i * 0.7)
				smoke.Size = smoke.Size * 1.15
				smoke.Position = smoke.Position + Vector3.new(0, 0.5, 0)
			end
			task.wait(0.05)
		end
		if smoke and smoke.Parent then
			smoke:Destroy()
		end
	end)
	
	print(string.format("💥 Cannon fired at %s", tostring(barrelPart.Position)))
end

--[[
	Gets a random position on the ArenaFloor
	
	@return Vector3 - Random position on the arena floor
]]
function CannonSystem:GetRandomArenaFloorPosition()
	local workspace = game:GetService("Workspace")
	
	-- Try recursive search first
	local arenaFloor = workspace:FindFirstChild("ArenaFloor", true)
	
	if arenaFloor and arenaFloor:IsA("BasePart") then
		local floorPos = arenaFloor.Position
		local floorSize = arenaFloor.Size
		local floorCFrame = arenaFloor.CFrame
		
		local localWidth = floorSize.Y
		local localLength = floorSize.Z
		
		local marginWidth = localWidth * 0.40
		local marginLength = localLength * 0.40
		
		local localX = (math.random() * 2 - 1) * marginWidth
		local localZ = (math.random() * 2 - 1) * marginLength
		local localY = (floorSize.X / 2) + 2
		
		local localOffset = Vector3.new(0, localX, localZ)
		local worldOffset = floorCFrame:VectorToWorldSpace(localOffset)
		local targetPos = floorPos + worldOffset + Vector3.new(0, localY, 0)
		
		return targetPos
	else
		print("⚠️ ArenaFloor not found, using fallback circular arena")
		-- Fallback: use arena dimensions
		local dims = self.arena:GetDimensions()
		
		-- Random position within arena radius (with some margin)
		local margin = dims.radius * 0.7 -- Use 70% of radius
		local randomAngle = math.random() * 2 * math.pi
		local randomDistance = math.random() * margin
		local randomX = dims.center.X + math.cos(randomAngle) * randomDistance
		local randomZ = dims.center.Z + math.sin(randomAngle) * randomDistance
		
		local targetPos = Vector3.new(randomX, dims.center.Y + 2, randomZ)
		return targetPos
	end
end

--[[
	Calculates ballistic trajectory to hit a target position
	
	@param startPos Vector3 - Starting position (cannon)
	@param targetPos Vector3 - Target position (where to land)
	@param launchAngle number - Launch angle in degrees
	@return Vector3 - Velocity vector
	@return number - Time to reach target
]]
function CannonSystem:CalculateBallisticTrajectory(startPos, targetPos, launchAngle)
	local gravity = 196.2 -- Roblox gravity
	local angleRad = math.rad(launchAngle)
	
	-- Calculate horizontal distance
	local dx = targetPos.X - startPos.X
	local dz = targetPos.Z - startPos.Z
	local horizontalDistance = math.sqrt(dx * dx + dz * dz)
	
	-- Calculate height difference
	local dy = targetPos.Y - startPos.Y
	
	-- Calculate required velocity using ballistic formula
	-- v = sqrt(g * d / (sin(2*angle) - 2*cos(angle)^2 * dy/d))
	local sin2a = math.sin(2 * angleRad)
	local cosa = math.cos(angleRad)
	local sina = math.sin(angleRad)
	
	-- Avoid division by zero
	if horizontalDistance < 1 then
		horizontalDistance = 1
	end
	
	local denominator = sin2a - (2 * cosa * cosa * dy / horizontalDistance)
	
	if denominator <= 0 or denominator ~= denominator then
		denominator = 0.5
	end
	
	local velocity = math.sqrt(math.abs(gravity * horizontalDistance / denominator))
	velocity = math.clamp(velocity, 50, 200)
	
	-- Calculate velocity components
	local horizontalVelocity = velocity * cosa
	local verticalVelocity = velocity * sina
	
	-- Direction vector (normalized horizontal direction)
	local direction = Vector3.new(dx, 0, dz).Unit
	
	-- Final velocity vector
	local velocityVector = direction * horizontalVelocity + Vector3.new(0, verticalVelocity, 0)
	
	-- Calculate time to reach target
	local timeToTarget = horizontalDistance / (horizontalVelocity + 0.001) -- Avoid division by zero
	
	return velocityVector, timeToTarget
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
	
	-- Create visual firing effect
	self:CreateFireEffect(cannon)
	
	-- Generate random body part type
	local bodyPartType = self:GenerateRandomBodyPartType()
	
	-- Generate random name fragment
	local nameFragment = NameFragments.GetRandom(bodyPartType)
	
	-- Get random target position on ArenaFloor
	local targetPosition = self:GetRandomArenaFloorPosition()
	
	-- Random launch angle for variety
	local launchAngle = math.random(55, 70)
	
	-- Calculate ballistic trajectory to hit target
	local velocity, _timeToTarget = self:CalculateBallisticTrajectory(
		cannon.position,
		targetPosition,
		launchAngle
	)
	
	-- Create body part data
	local bodyPart = DataStructures.CreateBodyPart(
		nil, -- ID will be auto-generated
		bodyPartType,
		nameFragment,
		cannon.position,
		velocity
	)
	
	-- CREATE VISUAL PROJECTILE (bigger, more visible cannonball)
	local projectile = Instance.new("Part")
	projectile.Name = "CannonProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(3, 3, 3) -- Bigger projectile
	projectile.Position = cannon.position
	projectile.BrickColor = BrickColor.new("Really red")
	projectile.Material = Enum.Material.Neon
	projectile.Anchored = false
	projectile.CanCollide = false
	projectile.Transparency = 0.2
	projectile.Parent = game.Workspace
	
	-- Add trail effect (longer, more visible)
	local attachment0 = Instance.new("Attachment")
	attachment0.Parent = projectile
	
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment0
	trail.Lifetime = 1.0 -- Longer trail
	trail.MinLength = 0
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0))
	trail.Transparency = NumberSequence.new(0.3)
	trail.WidthScale = NumberSequence.new(1)
	trail.Parent = projectile
	
	-- Add particle emitter for smoke trail
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Rate = 50
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.Color = ColorSequence.new(Color3.fromRGB(100, 100, 100))
	particles.Transparency = NumberSequence.new(0.5, 1)
	particles.Size = NumberSequence.new(2, 3)
	particles.Parent = projectile
	
	-- Apply velocity to projectile
	projectile.AssemblyLinearVelocity = velocity
	
	-- CREATE PHYSICAL BODY PART (will appear when projectile lands)
	local templates = ReplicatedStorage:FindFirstChild("BodyPartTemplates")
	if templates then
		-- Find the template Model by nameFragment
		-- Search in subfolders (HeadTemplate, BodyTemplate, LegsTemplate)
		local template = nil
		
		-- Try to find in appropriate subfolder based on body part type
		local subfolderName = bodyPartType == DataStructures.BodyPartType.HEAD and "HeadTemplate"
			or bodyPartType == DataStructures.BodyPartType.BODY and "BodyTemplate"
			or "LegsTemplate"
		
		local subfolder = templates:FindFirstChild(subfolderName)
		if subfolder then
			template = subfolder:FindFirstChild(nameFragment)
		end
		
		-- Fallback: search directly in BodyPartTemplates
		if not template then
			template = templates:FindFirstChild(nameFragment)
		end
		
		if template then
			-- Clone the template
			local physicalPart = template:Clone()
			physicalPart.Name = bodyPart.id
			
			-- Add tag to identify as collectible body part
			physicalPart:SetAttribute("IsBodyPart", true)
			physicalPart:SetAttribute("BodyPartId", bodyPart.id)
			
			-- Make it invisible initially
			for _, child in ipairs(physicalPart:GetDescendants()) do
				if child:IsA("BasePart") then
					child.Transparency = 1
					child.CanCollide = false
				end
			end
			
			-- Parent to workspace but invisible
			physicalPart.Parent = game.Workspace
			
			-- Store reference
			bodyPart.physicalObject = physicalPart
			
			-- Store target position for landing detection
			local targetPos = targetPosition
			
			-- Detect when projectile lands
			task.spawn(function()
				local startTime = tick()
				local maxFlightTime = 15
				
				while projectile and projectile.Parent and (tick() - startTime) < maxFlightTime do
					local distanceToTarget = (projectile.Position - targetPos).Magnitude
					local isDescending = projectile.AssemblyLinearVelocity.Y < -5
					local isLowEnough = projectile.Position.Y < 30
					
					if isDescending and (distanceToTarget < 15 or projectile.Position.Y < 10) and isLowEnough then
						
						local landingY = math.max(projectile.Position.Y + 2, 2)
						local landingPosition = Vector3.new(
							projectile.Position.X,
							landingY,
							projectile.Position.Z
						)
						
						-- Make body part visible and physical
						for _, child in ipairs(physicalPart:GetDescendants()) do
							if child:IsA("BasePart") then
								child.Transparency = 0
								child.Anchored = true
								child.CanCollide = true
								child.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
							end
						end
						
						-- Position the body part at landing location
						if physicalPart:IsA("Model") then
							physicalPart:PivotTo(CFrame.new(landingPosition))
						else
							local mainPart = physicalPart:FindFirstChildWhichIsA("BasePart")
							if mainPart then
								mainPart.CFrame = CFrame.new(landingPosition)
							end
						end
						
						-- Unanchor so it can be picked up
						for _, child in ipairs(physicalPart:GetDescendants()) do
							if child:IsA("BasePart") then
								child.Anchored = false
							end
						end
						
						-- Create landing impact effect
						local impact = Instance.new("Part")
						impact.Name = "Impact"
						impact.Shape = Enum.PartType.Cylinder
						impact.Size = Vector3.new(0.5, 4, 4)
						impact.Position = landingPosition
						impact.Orientation = Vector3.new(0, 0, 90)
						impact.BrickColor = BrickColor.new("Bright yellow")
						impact.Material = Enum.Material.Neon
						impact.Anchored = true
						impact.CanCollide = false
						impact.Transparency = 0.3
						impact.Parent = game.Workspace
						
						-- Expand and fade impact
						task.spawn(function()
							for i = 0, 1, 0.1 do
								if impact and impact.Parent then
									impact.Transparency = 0.3 + (i * 0.7)
									impact.Size = impact.Size * 1.3
								end
								task.wait(0.05)
							end
							if impact and impact.Parent then
								impact:Destroy()
							end
						end)
						
						-- Destroy projectile
						projectile:Destroy()
						
						-- Register with GameEvents instead of _G
						GameEvents:FireBodyPartRegistered(physicalPart, bodyPart.id)
						
						print(string.format("🚀 Spawned %s: %s", bodyPartType, nameFragment))
						break
					end
					
					task.wait(0.1)
				end
				
				-- Cleanup if projectile didn't land properly
				if projectile and projectile.Parent then
					local landingY = math.max(projectile.Position.Y + 2, 2)
					local finalPosition = Vector3.new(
						projectile.Position.X,
						landingY,
						projectile.Position.Z
					)
					
					-- Make visible and anchor first
					for _, child in ipairs(physicalPart:GetDescendants()) do
						if child:IsA("BasePart") then
							child.Transparency = 0
							child.Anchored = true
							child.CanCollide = true
							child.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						end
					end
					
					-- Position body part at target location
					if physicalPart:IsA("Model") and physicalPart.PrimaryPart then
						physicalPart:SetPrimaryPartCFrame(CFrame.new(finalPosition))
					elseif physicalPart:IsA("Model") then
						local mainPart = physicalPart:FindFirstChildWhichIsA("BasePart")
						if mainPart then
							mainPart.CFrame = CFrame.new(finalPosition)
						end
					end
					
					-- Unanchor after positioning
					for _, child in ipairs(physicalPart:GetDescendants()) do
						if child:IsA("BasePart") then
							child.Anchored = false
						end
					end
					
					projectile:Destroy()
					
					-- Register with GameEvents instead of _G
					GameEvents:FireBodyPartRegistered(physicalPart, bodyPart.id)
				end
			end)
		else
			warn(string.format("❌ Template not found for nameFragment: %s", nameFragment))
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

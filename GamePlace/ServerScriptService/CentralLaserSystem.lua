-- Central Laser System Module
-- Manages the rotating central laser obstacle
-- Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local CentralLaserSystem = {}
CentralLaserSystem.__index = CentralLaserSystem

function CentralLaserSystem.new(arenaCenter)
	local self = setmetatable({}, CentralLaserSystem)
	
	self.position = arenaCenter or GameConfig.ARENA_CENTER
	self.currentAngle = 0
	self.rotationSpeed = GameConfig.LASER_START_SPEED
	self.maxRotationSpeed = GameConfig.LASER_MAX_SPEED
	self.laserLength = GameConfig.ARENA_RADIUS
	self.laserWidth = GameConfig.LASER_WIDTH
	
	-- Find physical laser in workspace
	self.physicalLaser = game.Workspace:FindFirstChild("Arena") and game.Workspace.Arena:FindFirstChild("CentralLaser")
	if not self.physicalLaser then
		self.physicalLaser = game.Workspace:FindFirstChild("CentralLaser")
	end
	
	if self.physicalLaser then
		print("✓ Found CentralLaser in Workspace")
		
		-- Setup collision detection
		self.physicalLaser.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = game:GetService("Players"):GetPlayerFromCharacter(character)
			
			if player and self.onPlayerHit then
				self.onPlayerHit(player.UserId)
			end
		end)
	else
		warn("❌ CentralLaser not found in Workspace - laser won't be visible")
	end
	
	return self
end

-- Set callback for when laser hits a player
function CentralLaserSystem:SetPlayerHitCallback(callback)
	self.onPlayerHit = callback
end

function CentralLaserSystem:Update(deltaTime, matchElapsedTime)
	-- Accelerate based on match time: speed = 30 + (matchTime / 60) * 90
	self.rotationSpeed = GameConfig.LASER_START_SPEED + (matchElapsedTime / 60) * GameConfig.LASER_ACCELERATION_RATE
	
	-- Cap at max speed
	if self.rotationSpeed > self.maxRotationSpeed then
		self.rotationSpeed = self.maxRotationSpeed
	end
	
	-- Update angle
	self.currentAngle = self.currentAngle + self.rotationSpeed * deltaTime
	
	-- Wrap at 360
	if self.currentAngle >= 360 then
		self.currentAngle = self.currentAngle - 360
	end
	
	-- ROTATE PHYSICAL LASER
	if self.physicalLaser then
		local angleRad = math.rad(self.currentAngle)
		self.physicalLaser.CFrame = CFrame.new(self.position) * CFrame.Angles(0, angleRad, 0)
	end
end

function CentralLaserSystem:CheckCollisions(players)
	local hitPlayers = {}
	
	-- Calculate laser line segment
	local angleRad = math.rad(self.currentAngle)
	local laserEnd = self.position + Vector3.new(
		self.laserLength * math.cos(angleRad),
		0,
		self.laserLength * math.sin(angleRad)
	)
	
	for id, player in pairs(players) do
		-- Calculate distance from player to laser line (2D)
		local px = player.position.X - self.position.X
		local pz = player.position.Z - self.position.Z
		
		local lx = laserEnd.X - self.position.X
		local lz = laserEnd.Z - self.position.Z
		
		-- Project player onto laser line
		local t = (px * lx + pz * lz) / (lx * lx + lz * lz)
		t = math.clamp(t, 0, 1)
		
		-- Closest point on laser
		local closestX = self.position.X + t * lx
		local closestZ = self.position.Z + t * lz
		
		-- Distance to laser
		local distance = math.sqrt((player.position.X - closestX)^2 + (player.position.Z - closestZ)^2)
		
		if distance < (self.laserWidth / 2 + 2) then -- 2 = player radius
			table.insert(hitPlayers, player)
		end
	end
	
	return hitPlayers
end

function CentralLaserSystem:KnockbackPlayer(player, laserAngle)
	-- Calculate knockback direction (perpendicular to laser)
	local angleRad = math.rad(laserAngle)
	local laserDir = Vector3.new(math.cos(angleRad), 0, math.sin(angleRad))
	
	-- Determine which side of laser player is on
	local toPlayer = (player.position - self.position)
	local cross = laserDir.X * toPlayer.Z - laserDir.Z * toPlayer.X
	
	-- Perpendicular direction
	local knockbackDir
	if cross > 0 then
		knockbackDir = Vector3.new(-laserDir.Z, 0, laserDir.X)
	else
		knockbackDir = Vector3.new(laserDir.Z, 0, -laserDir.X)
	end
	
	-- Apply knockback
	player.position = player.position + knockbackDir.Unit * GameConfig.LASER_KNOCKBACK_FORCE
	
	return knockbackDir
end

function CentralLaserSystem:DropInventory(player)
	local droppedParts = {}
	
	for _, bodyPart in ipairs(player.inventory) do
		-- Random scatter direction
		local angle = math.random() * 2 * math.pi
		local distance = math.random(GameConfig.SCATTER_DISTANCE_MIN, GameConfig.SCATTER_DISTANCE_MAX)
		
		-- Calculate scatter position
		local scatterOffset = Vector3.new(
			distance * math.cos(angle),
			0,
			distance * math.sin(angle)
		)
		
		bodyPart.position = player.position + scatterOffset
		bodyPart.velocity = scatterOffset.Unit * 5 -- Small bounce velocity
		bodyPart.isCollected = false
		
		table.insert(droppedParts, bodyPart)
	end
	
	-- Clear inventory
	player.inventory = {}
	player.displayName = player.username
	
	return droppedParts
end

return CentralLaserSystem

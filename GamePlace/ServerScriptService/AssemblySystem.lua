-- Assembly System Module
-- Manages Brainrot assembly from collected body parts
-- Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 11.4

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)

local AssemblySystem = {}
AssemblySystem.__index = AssemblySystem

--[[
	Creates a new AssemblySystem instance
	
	@return AssemblySystem - New AssemblySystem instance
]]
function AssemblySystem.new()
	local self = setmetatable({}, AssemblySystem)
	return self
end

--[[
	Assembles a Brainrot from player's inventory
	Requirements: 3.1, 3.2
	
	@param player Player - The player data structure
	@param headPart BodyPart - The head part
	@param bodyPart BodyPart - The body part
	@param legsPart BodyPart - The legs part
	@return Brainrot - The assembled Brainrot
]]
function AssemblySystem:AssembleBrainrot(player, headPart, bodyPart, legsPart)
	-- Create Brainrot with combined name
	local brainrot = DataStructures.CreateBrainrot(headPart, bodyPart, legsPart, player.id)
	
	return brainrot
end

--[[
	Finds an available pedestal in player's base
	Requirements: 3.3
	
	@param player Player - The player data structure
	@param brainrots table - Map of id -> Brainrot
	@return number - Pedestal index (0-2), or -1 if none available
]]
function AssemblySystem:FindAvailablePedestal(player, brainrots)
	-- Track which pedestals are occupied
	local occupiedPedestals = {}
	
	for id, brainrot in pairs(brainrots) do
		if brainrot.ownerId == player.id and brainrot.pedestalIndex >= 0 then
			occupiedPedestals[brainrot.pedestalIndex] = true
		end
	end
	
	-- Find first available pedestal
	for i = 0, GameConfig.PEDESTALS_PER_BASE - 1 do
		if not occupiedPedestals[i] then
			return i
		end
	end
	
	return -1 -- No available pedestals
end

--[[
	Places a Brainrot on a pedestal
	Requirements: 3.3
	
	@param brainrot Brainrot - The Brainrot to place
	@param pedestalIndex number - The pedestal index
]]
function AssemblySystem:PlaceBrainrot(brainrot, pedestalIndex)
	brainrot.pedestalIndex = pedestalIndex
end

--[[
	Activates lock timer on a Brainrot
	Requirements: 3.6
	
	@param brainrot Brainrot - The Brainrot to lock
	@param currentTime number - Current game time
]]
function AssemblySystem:ActivateLockTimer(brainrot, currentTime)
	brainrot.isLocked = true
	brainrot.lockEndTime = currentTime + GameConfig.LOCK_TIMER_DURATION
end

--[[
	Completes a Brainrot assembly for a player
	Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 11.4
	
	@param player Player - The player data structure
	@param headPart BodyPart - The head part
	@param bodyPart BodyPart - The body part
	@param legsPart BodyPart - The legs part
	@param brainrots table - Map of id -> Brainrot
	@param currentTime number - Current game time
	@return Brainrot|nil - The completed Brainrot, or nil if no pedestal available
]]
function AssemblySystem:CompleteBrainrot(player, headPart, bodyPart, legsPart, brainrots, currentTime)
	-- Find available pedestal
	local pedestalIndex = self:FindAvailablePedestal(player, brainrots)
	
	if pedestalIndex < 0 then
		-- No available pedestals
		return nil
	end
	
	-- Assemble Brainrot
	local brainrot = self:AssembleBrainrot(player, headPart, bodyPart, legsPart)
	
	-- Place on pedestal
	self:PlaceBrainrot(brainrot, pedestalIndex)
	
	-- Activate lock timer
	self:ActivateLockTimer(brainrot, currentTime)
	
	-- Clear player inventory
	player.inventory = {}
	
	-- Reset player displayed name
	player.displayName = player.username
	
	-- Increment player score
	player.score = player.score + 1
	
	-- Store in brainrots map
	brainrots[brainrot.id] = brainrot
	
	return brainrot
end

--[[
	Checks if a Brainrot's lock timer has expired
	
	@param brainrot Brainrot - The Brainrot to check
	@param currentTime number - Current game time
	@return boolean - True if lock has expired
]]
function AssemblySystem:IsLockExpired(brainrot, currentTime)
	return currentTime >= brainrot.lockEndTime
end

--[[
	Updates lock status for a Brainrot
	
	@param brainrot Brainrot - The Brainrot to update
	@param currentTime number - Current game time
]]
function AssemblySystem:UpdateLockStatus(brainrot, currentTime)
	if brainrot.isLocked and self:IsLockExpired(brainrot, currentTime) then
		brainrot.isLocked = false
	end
end

return AssemblySystem

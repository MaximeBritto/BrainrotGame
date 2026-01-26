-- Collection System Module
-- Manages body part collection by players
-- Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 11.1, 11.2, 11.3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)

local CollectionSystem = {}
CollectionSystem.__index = CollectionSystem

--[[
	Creates a new CollectionSystem instance
	
	@return CollectionSystem - New CollectionSystem instance
]]
function CollectionSystem.new()
	local self = setmetatable({}, CollectionSystem)
	return self
end

--[[
	Checks if a player can collect more body parts
	Requirements: 2.3, 2.4
	
	@param player Player - The player data structure
	@return boolean - True if player has inventory space
]]
function CollectionSystem:CanCollect(player)
	return #player.inventory < GameConfig.INVENTORY_MAX_SIZE
end

--[[
	Checks collision between player and body parts
	Requirements: 2.1
	
	@param player Player - The player data structure
	@param bodyParts table - Map of id -> BodyPart
	@return BodyPart|nil - The body part to collect, or nil
]]
function CollectionSystem:CheckCollisions(player, bodyParts)
	if not self:CanCollect(player) then
		return nil
	end
	
	-- Find closest uncollected body part within collection radius
	local closestPart = nil
	local closestDistance = GameConfig.COLLECTION_RADIUS
	
	for id, bodyPart in pairs(bodyParts) do
		if not bodyPart.isCollected then
			local distance = (bodyPart.position - player.position).Magnitude
			
			if distance <= closestDistance then
				closestDistance = distance
				closestPart = bodyPart
			end
		end
	end
	
	return closestPart
end

--[[
	Collects a body part for a player
	Requirements: 2.1, 2.2, 2.5
	
	@param player Player - The player data structure
	@param bodyPart BodyPart - The body part to collect
	@return boolean - True if collection was successful
]]
function CollectionSystem:CollectBodyPart(player, bodyPart)
	-- Verify player has space
	if not self:CanCollect(player) then
		return false
	end
	
	-- Add to inventory
	table.insert(player.inventory, bodyPart)
	bodyPart.isCollected = true
	
	-- Update player's displayed name
	self:UpdatePlayerName(player)
	
	return true
end

--[[
	Updates player's displayed name based on inventory
	Requirements: 2.5, 11.1, 11.2, 11.3
	
	@param player Player - The player data structure
]]
function CollectionSystem:UpdatePlayerName(player)
	-- Start with username
	local displayName = player.username
	
	-- Find parts by type
	local headPart = nil
	local bodyPart = nil
	local legsPart = nil
	
	for _, part in ipairs(player.inventory) do
		if part.type == DataStructures.BodyPartType.HEAD then
			headPart = part
		elseif part.type == DataStructures.BodyPartType.BODY then
			bodyPart = part
		elseif part.type == DataStructures.BodyPartType.LEGS then
			legsPart = part
		end
	end
	
	-- Append fragments in order: Head, Body, Legs
	if headPart then
		displayName = displayName .. " " .. headPart.nameFragment
	end
	if bodyPart then
		displayName = displayName .. " " .. bodyPart.nameFragment
	end
	if legsPart then
		displayName = displayName .. " " .. legsPart.nameFragment
	end
	
	player.displayName = displayName
end

--[[
	Checks if player has a complete set (1 head, 1 body, 1 legs)
	Requirements: 3.1
	
	@param player Player - The player data structure
	@return boolean - True if player has complete set
	@return BodyPart|nil - Head part
	@return BodyPart|nil - Body part
	@return BodyPart|nil - Legs part
]]
function CollectionSystem:CheckForCompletion(player)
	local headPart = nil
	local bodyPart = nil
	local legsPart = nil
	
	for _, part in ipairs(player.inventory) do
		if part.type == DataStructures.BodyPartType.HEAD and not headPart then
			headPart = part
		elseif part.type == DataStructures.BodyPartType.BODY and not bodyPart then
			bodyPart = part
		elseif part.type == DataStructures.BodyPartType.LEGS and not legsPart then
			legsPart = part
		end
	end
	
	-- Check if we have all three types
	if headPart and bodyPart and legsPart then
		return true, headPart, bodyPart, legsPart
	end
	
	return false, nil, nil, nil
end

--[[
	Gets the count of each body part type in player's inventory
	
	@param player Player - The player data structure
	@return table - {HEAD = count, BODY = count, LEGS = count}
]]
function CollectionSystem:GetInventoryCounts(player)
	local counts = {
		HEAD = 0,
		BODY = 0,
		LEGS = 0
	}
	
	for _, part in ipairs(player.inventory) do
		counts[part.type] = counts[part.type] + 1
	end
	
	return counts
end

--[[
	Clears player's inventory
	
	@param player Player - The player data structure
]]
function CollectionSystem:ClearInventory(player)
	player.inventory = {}
	player.displayName = player.username
end

return CollectionSystem

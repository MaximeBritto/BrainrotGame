-- Physics Manager Module
-- Handles physical interactions between players and body parts
-- Bridges the gap between physical Roblox objects and game logic

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PhysicsManager = {}
PhysicsManager.__index = PhysicsManager

--[[
	Creates a new PhysicsManager instance
	
	@return PhysicsManager - New PhysicsManager instance
]]
function PhysicsManager.new()
	local self = setmetatable({}, PhysicsManager)
	
	-- Track active body parts
	self.activeBodyParts = {}
	
	-- Track nearby parts for each player
	self.nearbyParts = {} -- Format: { [userId] = bodyPartId }
	
	-- Callback for when a body part is collected
	self.collectionCallback = nil
	
	return self
end

--[[
	Sets the callback for when a body part is collected
	
	@param callback function - The function to call when a part is collected
]]
function PhysicsManager:SetCollectionCallback(callback)
	self.collectionCallback = callback
end

--[[
	Sets up proximity detection on a body part
	
	@param bodyPartModel Model - The physical model
	@param bodyPartId string - The unique ID
]]
function PhysicsManager:RegisterBodyPart(bodyPartModel, bodyPartId)
	if not bodyPartModel then return end
	
	-- Find the main part
	local mainPart = bodyPartModel.PrimaryPart or bodyPartModel:FindFirstChildWhichIsA("BasePart")
	if not mainPart then return end
	
	-- Store reference
	self.activeBodyParts[bodyPartId] = {
		model = bodyPartModel,
		part = mainPart,
		id = bodyPartId,
		collected = false
	}
	
	-- Setup proximity detection (no auto-collect, just track nearby)
	mainPart.Touched:Connect(function(hit)
		-- Check if touched by a player
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		if player and self.activeBodyParts[bodyPartId] and not self.activeBodyParts[bodyPartId].collected then
			-- Mark as nearby (don't collect yet)
			self.nearbyParts[player.UserId] = bodyPartId
		end
	end)
	
	-- Setup leaving proximity
	mainPart.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		if player and self.nearbyParts[player.UserId] == bodyPartId then
			-- No longer nearby
			self.nearbyParts[player.UserId] = nil
		end
	end)
end

--[[
	Attempts to collect a nearby part for a player
	Called when player presses E key
	
	@param userId number - The player's UserId
	@return boolean - True if collection was successful
]]
function PhysicsManager:CollectNearbyPart(userId)
	local bodyPartId = self.nearbyParts[userId]
	
	if not bodyPartId then
		return false -- No nearby part
	end
	
	if not self.activeBodyParts[bodyPartId] or self.activeBodyParts[bodyPartId].collected then
		return false -- Part already collected
	end
	
	-- Mark as collected
	self.activeBodyParts[bodyPartId].collected = true
	
	-- Get the model
	local bodyPartModel = self.activeBodyParts[bodyPartId].model
	
	-- Call the callback if set
	if self.collectionCallback then
		self.collectionCallback(userId, bodyPartId, bodyPartModel)
	end
	
	-- Remove from tracking
	self.activeBodyParts[bodyPartId] = nil
	self.nearbyParts[userId] = nil
	
	print(string.format("✓ Player collected body part %s with E key", bodyPartId))
	
	return true
end

--[[
	Cleans up a body part
	
	@param bodyPartId string - The ID of the body part to cleanup
]]
function PhysicsManager:CleanupBodyPart(bodyPartId)
	if self.activeBodyParts[bodyPartId] then
		local data = self.activeBodyParts[bodyPartId]
		if data.model and data.model.Parent then
			data.model:Destroy()
		end
		self.activeBodyParts[bodyPartId] = nil
	end
end

return PhysicsManager

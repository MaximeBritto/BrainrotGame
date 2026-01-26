-- Physics Manager
-- Handles physical interactions between players and body parts
-- Bridges the gap between physical Roblox objects and game logic

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Track active body parts
local activeBodyParts = {}

-- Track nearby parts for each player
local nearbyParts = {} -- Format: { [userId] = bodyPartId }

-- Callback for when a body part is collected
local collectionCallback = nil

-- Function to setup proximity detection on a body part
local function SetupBodyPartProximity(bodyPartModel, bodyPartId)
	if not bodyPartModel then return end
	
	-- Find the main part
	local mainPart = bodyPartModel.PrimaryPart or bodyPartModel:FindFirstChildWhichIsA("BasePart")
	if not mainPart then return end
	
	-- Store reference
	activeBodyParts[bodyPartId] = {
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
		
		if player and activeBodyParts[bodyPartId] and not activeBodyParts[bodyPartId].collected then
			-- Mark as nearby (don't collect yet)
			nearbyParts[player.UserId] = bodyPartId
		end
	end)
	
	-- Setup leaving proximity
	mainPart.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		if player and nearbyParts[player.UserId] == bodyPartId then
			-- No longer nearby
			nearbyParts[player.UserId] = nil
		end
	end)
end

-- Listen for E key press to collect nearby part
_G.CollectNearbyPart = function(userId)
	local bodyPartId = nearbyParts[userId]
	
	if not bodyPartId then
		return false -- No nearby part
	end
	
	if not activeBodyParts[bodyPartId] or activeBodyParts[bodyPartId].collected then
		return false -- Part already collected
	end
	
	-- Mark as collected
	activeBodyParts[bodyPartId].collected = true
	
	-- Get the model
	local bodyPartModel = activeBodyParts[bodyPartId].model
	
	-- Call the callback if set
	if collectionCallback then
		collectionCallback(userId, bodyPartId, bodyPartModel)
	end
	
	-- Remove from tracking
	activeBodyParts[bodyPartId] = nil
	nearbyParts[userId] = nil
	
	print(string.format("✓ Player collected body part %s with E key", bodyPartId))
	
	return true
end

-- Listen for new body parts spawned
-- This will be called by CannonSystem when it spawns a part
_G.RegisterBodyPart = function(bodyPartModel, bodyPartId)
	SetupBodyPartProximity(bodyPartModel, bodyPartId)
end

-- Set collection callback (called by GameServer)
_G.SetCollectionCallback = function(callback)
	collectionCallback = callback
end

-- Cleanup function
local function CleanupBodyPart(bodyPartId)
	if activeBodyParts[bodyPartId] then
		local data = activeBodyParts[bodyPartId]
		if data.model and data.model.Parent then
			data.model:Destroy()
		end
		activeBodyParts[bodyPartId] = nil
	end
end

-- Expose cleanup function
_G.CleanupBodyPart = CleanupBodyPart

print("✓ Physics Manager initialized (E to collect)")

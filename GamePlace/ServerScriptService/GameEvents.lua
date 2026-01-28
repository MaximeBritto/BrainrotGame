-- Game Events Module
-- Centralized event system to replace _G globals
-- Provides BindableEvents for inter-system communication

local GameEvents = {}

-- Create BindableEvents for communication
local bodyPartRegistered = Instance.new("BindableEvent")
local bodyPartCollected = Instance.new("BindableEvent")
local collectionRequested = Instance.new("BindableEvent")

-- Event accessors
GameEvents.BodyPartRegistered = bodyPartRegistered
GameEvents.BodyPartCollected = bodyPartCollected
GameEvents.CollectionRequested = collectionRequested

--[[
	Fires when a body part is spawned and needs to be registered for collection
	@param bodyPartModel Model - The physical model
	@param bodyPartId string - The unique ID
]]
function GameEvents:FireBodyPartRegistered(bodyPartModel, bodyPartId)
	bodyPartRegistered:Fire(bodyPartModel, bodyPartId)
end

--[[
	Fires when a body part is collected by a player
	@param userId number - The player's UserId
	@param bodyPartId string - The body part ID
	@param physicalModel Model - The physical model
]]
function GameEvents:FireBodyPartCollected(userId, bodyPartId, physicalModel)
	bodyPartCollected:Fire(userId, bodyPartId, physicalModel)
end

--[[
	Fires when a player requests to collect a nearby part (E key)
	@param userId number - The player's UserId
	@return boolean - True if collection was successful
]]
function GameEvents:RequestCollection(userId)
	-- This is a synchronous request, so we need a different approach
	-- We'll use a callback system instead
	if self.collectionHandler then
		return self.collectionHandler(userId)
	end
	return false
end

--[[
	Sets the handler for collection requests
	@param handler function - The function to call when collection is requested
]]
function GameEvents:SetCollectionHandler(handler)
	self.collectionHandler = handler
end

--[[
	Sets the callback for when a body part is collected
	@param callback function - The function to call
]]
function GameEvents:SetCollectionCallback(callback)
	self.collectionCallback = callback
end

--[[
	Gets the collection callback
	@return function|nil - The callback function
]]
function GameEvents:GetCollectionCallback()
	return self.collectionCallback
end

return GameEvents

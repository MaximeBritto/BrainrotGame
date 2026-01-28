-- Slot Inventory System
-- Manages 3 independent Brainrot slots for each player
-- Each slot can hold 1 HEAD, 1 BODY, 1 LEGS

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local SlotInventorySystem = {}
SlotInventorySystem.__index = SlotInventorySystem

--[[
	Creates a new SlotInventorySystem instance
	
	@return SlotInventorySystem
]]
function SlotInventorySystem.new()
	local self = setmetatable({}, SlotInventorySystem)
	
	-- Track player inventories
	-- Format: { [userId] = { slots = { {head, body, legs}, {head, body, legs}, {head, body, legs} } } }
	self.playerSlots = {}
	
	return self
end

--[[
	Initializes slots for a player
	
	@param userId number - The player's UserId
]]
function SlotInventorySystem:InitializePlayer(userId)
	self.playerSlots[userId] = {
		slots = {
			{ head = nil, body = nil, legs = nil, assembled = false, brainrotName = nil }, -- Slot 1
			{ head = nil, body = nil, legs = nil, assembled = false, brainrotName = nil }, -- Slot 2
			{ head = nil, body = nil, legs = nil, assembled = false, brainrotName = nil }  -- Slot 3
		}
	}
end

--[[
	Adds a body part to the first available slot
	
	@param userId number - The player's UserId
	@param bodyPart BodyPart - The body part to add
	@return number|nil - The slot index (1-3) where it was added, or nil if no space
	@return string - The part type that was added
]]
function SlotInventorySystem:AddBodyPart(userId, bodyPart)
	if not self.playerSlots[userId] then
		self:InitializePlayer(userId)
	end
	
	local slots = self.playerSlots[userId].slots
	local partType = bodyPart.type:lower() -- "HEAD", "BODY", "LEGS" -> "head", "body", "legs"
	
	-- Find first slot that doesn't have this part type
	for slotIndex = 1, 3 do
		local slot = slots[slotIndex]
		
		if not slot[partType] then
			slot[partType] = bodyPart
			return slotIndex, partType
		end
	end
	
	-- No space available
	return nil, nil
end

--[[
	Checks if a slot is complete (has all 3 parts)
	
	@param userId number - The player's UserId
	@param slotIndex number - The slot index (1-3)
	@return boolean - True if slot is complete
	@return BodyPart|nil - Head part
	@return BodyPart|nil - Body part
	@return BodyPart|nil - Legs part
]]
function SlotInventorySystem:IsSlotComplete(userId, slotIndex)
	if not self.playerSlots[userId] then
		return false, nil, nil, nil
	end
	
	local slot = self.playerSlots[userId].slots[slotIndex]
	
	if slot.head and slot.body and slot.legs then
		return true, slot.head, slot.body, slot.legs
	end
	
	return false, nil, nil, nil
end

--[[
	Clears a slot after Brainrot completion
	
	@param userId number - The player's UserId
	@param slotIndex number - The slot index (1-3)
]]
function SlotInventorySystem:ClearSlot(userId, slotIndex)
	if not self.playerSlots[userId] then
		return
	end
	
	local slot = self.playerSlots[userId].slots[slotIndex]
	slot.head = nil
	slot.body = nil
	slot.legs = nil
	slot.assembled = false
	slot.brainrotName = nil
end

--[[
	Gets all parts in a slot
	
	@param userId number - The player's UserId
	@param slotIndex number - The slot index (1-3)
	@return table - Array of body parts in the slot
]]
function SlotInventorySystem:GetSlotParts(userId, slotIndex)
	if not self.playerSlots[userId] then
		return {}
	end
	
	local slot = self.playerSlots[userId].slots[slotIndex]
	local parts = {}
	
	if slot.head then table.insert(parts, slot.head) end
	if slot.body then table.insert(parts, slot.body) end
	if slot.legs then table.insert(parts, slot.legs) end
	
	return parts
end

--[[
	Gets all parts across all slots for UI display
	
	@param userId number - The player's UserId
	@return table - Array of {slotIndex, partType, bodyPart}
]]
function SlotInventorySystem:GetAllParts(userId)
	if not self.playerSlots[userId] then
		return {}
	end
	
	local allParts = {}
	
	for slotIndex = 1, 3 do
		local slot = self.playerSlots[userId].slots[slotIndex]
		
		if slot.head then
			table.insert(allParts, {
				slotIndex = slotIndex,
				partType = "HEAD",
				bodyPart = slot.head
			})
		end
		if slot.body then
			table.insert(allParts, {
				slotIndex = slotIndex,
				partType = "BODY",
				bodyPart = slot.body
			})
		end
		if slot.legs then
			table.insert(allParts, {
				slotIndex = slotIndex,
				partType = "LEGS",
				bodyPart = slot.legs
			})
		end
	end
	
	return allParts
end

--[[
	Marks a slot as assembled with a Brainrot name
	
	@param userId number - The player's UserId
	@param slotIndex number - The slot index (1-3)
	@param brainrotName string - The name of the assembled Brainrot
]]
function SlotInventorySystem:MarkSlotAssembled(userId, slotIndex, brainrotName)
	if not self.playerSlots[userId] then
		return
	end
	
	local slot = self.playerSlots[userId].slots[slotIndex]
	slot.assembled = true
	slot.brainrotName = brainrotName
end

--[[
	Checks if a slot is assembled
	
	@param userId number - The player's UserId
	@param slotIndex number - The slot index (1-3)
	@return boolean - True if slot is assembled
	@return string|nil - The Brainrot name if assembled
]]
function SlotInventorySystem:IsSlotAssembled(userId, slotIndex)
	if not self.playerSlots[userId] then
		return false, nil
	end
	
	local slot = self.playerSlots[userId].slots[slotIndex]
	return slot.assembled, slot.brainrotName
end

--[[
	Clears all slots for a player
	
	@param userId number - The player's UserId
]]
function SlotInventorySystem:ClearAllSlots(userId)
	if not self.playerSlots[userId] then
		return
	end
	
	for i = 1, 3 do
		self:ClearSlot(userId, i)
	end
end

return SlotInventorySystem

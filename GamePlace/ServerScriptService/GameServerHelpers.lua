-- Game Server Helper Functions
-- Utility functions to reduce code duplication in GameServer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameServerHelpers = {}

--[[
	Finds a Roblox Player instance from userId
	@param userId number - The user ID to find
	@return Player|nil - The Roblox player or nil
]]
function GameServerHelpers.FindPlayerByUserId(userId)
	for _, player in pairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

--[[
	Updates player's inventory UI
	@param player Player - Roblox player instance
	@param userId number - User ID
	@param slotInventorySystem - The slot inventory system
]]
function GameServerHelpers.UpdatePlayerInventoryUI(player, userId, slotInventorySystem)
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then return end
	
	local updateInventory = remoteEvents:FindFirstChild("UpdateInventory")
	if not updateInventory then return end
	
	local allParts = slotInventorySystem:GetAllParts(userId)
	local inventoryData = {}
	
	for _, partInfo in ipairs(allParts) do
		local assembled, assembledName = slotInventorySystem:IsSlotAssembled(userId, partInfo.slotIndex)
		
		table.insert(inventoryData, {
			slotIndex = partInfo.slotIndex,
			type = partInfo.partType,
			nameFragment = partInfo.bodyPart.nameFragment,
			assembled = assembled,
			brainrotName = assembledName
		})
	end
	
	updateInventory:FireClient(player, inventoryData)
end

--[[
	Welds all parts in a model to the main part
	@param model Model - The model containing parts
	@param mainPart BasePart - The main part to weld to
]]
function GameServerHelpers.WeldModelParts(model, mainPart)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= mainPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = mainPart
			weld.Part1 = descendant
			weld.Parent = mainPart
		end
	end
end

--[[
	Processes a body part model (head, body, or legs) for Brainrot assembly
	@param partModel Model - The model to process
	@param pedestalTop Vector3 - The top position of the pedestal
	@param previousBottomAttachment Attachment|nil - Previous part's bottom attachment
	@param previousBottomPartCFrame CFrame|nil - Previous part's CFrame (for attachment calculations)
	@param previousMainPart BasePart|nil - Previous part's main part
	@param isBottomPart boolean - Whether this is the bottom-most part
	@param brainrotModel Model - The parent Brainrot model
	@return Attachment|nil - This part's bottom attachment
	@return CFrame|nil - This part's main part CFrame (for next attachment calculation)
	@return BasePart|nil - This part's main part
]]
function GameServerHelpers.ProcessBodyPartModel(partModel, pedestalTop, previousBottomAttachment, previousBottomPartCFrame, previousMainPart, isBottomPart, brainrotModel)
	if not partModel then return nil, nil, nil end
	
	local mainPart = partModel.PrimaryPart or partModel:FindFirstChildWhichIsA("BasePart")
	if not mainPart then return nil, nil, nil end
	
	-- Find attachments BEFORE any modifications
	local topAttachment = partModel:FindFirstChild("TopAttachment", true)
	local bottomAttachment = partModel:FindFirstChild("BottomAttachment", true)
	
	-- Calculate position BEFORE moving anything
	local targetCFrame
	if previousBottomAttachment and previousBottomPartCFrame and topAttachment and topAttachment:IsA("Attachment") then
		-- Align using attachments - use stored CFrame instead of Parent.CFrame
		local previousBottomWorldCFrame = previousBottomPartCFrame * previousBottomAttachment.CFrame
		local topAttachmentLocalCFrame = topAttachment.CFrame
		
		-- Calculate where mainPart should be to align attachments
		targetCFrame = previousBottomWorldCFrame * topAttachmentLocalCFrame:Inverse()
	else
		-- Fallback positioning
		if previousBottomAttachment and previousBottomPartCFrame then
			local previousBottomWorldPos = previousBottomPartCFrame * previousBottomAttachment.CFrame.Position
			targetCFrame = CFrame.new(previousBottomWorldPos.X, previousBottomWorldPos.Y - mainPart.Size.Y / 2, previousBottomWorldPos.Z)
		else
			targetCFrame = CFrame.new(pedestalTop)
		end
	end
	
	-- Apply position
	mainPart.CFrame = targetCFrame
	mainPart.Anchored = isBottomPart
	mainPart.CanCollide = false
	
	-- Store the CFrame BEFORE moving children
	local mainPartCFrame = mainPart.CFrame
	
	-- Weld all parts in this model together
	GameServerHelpers.WeldModelParts(partModel, mainPart)
	
	-- Weld to previous part
	if previousMainPart then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = previousMainPart
		weld.Part1 = mainPart
		weld.Parent = previousMainPart
	end
	
	-- Store bottom attachment reference before moving children
	local bottomAttachmentToReturn = nil
	if bottomAttachment and bottomAttachment:IsA("Attachment") then
		bottomAttachmentToReturn = bottomAttachment
	end
	
	-- Move children to brainrot model
	for _, child in ipairs(partModel:GetChildren()) do
		child.Parent = brainrotModel
	end
	partModel:Destroy()
	
	-- Return this part's bottom attachment, CFrame, and main part
	return bottomAttachmentToReturn, mainPartCFrame, mainPart
end

return GameServerHelpers

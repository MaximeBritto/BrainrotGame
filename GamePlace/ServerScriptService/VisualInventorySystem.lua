-- Visual Inventory System
-- Manages the visual display of body parts on player characters
-- Shows collected parts floating above the player's head

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualInventorySystem = {}
VisualInventorySystem.__index = VisualInventorySystem

function VisualInventorySystem.new()
	local self = setmetatable({}, VisualInventorySystem)
	
	-- Track visual parts attached to players
	-- Format: { [userId] = { [partId] = model } }
	self.attachedParts = {}
	
	-- Track BillboardGuis for slot names
	-- Format: { [userId] = { [slotIndex] = BillboardGui } }
	self.slotNameGuis = {}
	
	return self
end

--[[
	Gets the attachment point for a body part based on slot and what's in that slot
	Slots are positioned: Slot 1 (left), Slot 2 (center), Slot 3 (right)
	
	@param player Player - The player data structure
	@param bodyPartType string - The type of body part (HEAD, BODY, LEGS)
	@param slotIndex number - The slot index (1-3)
	@param slotParts table - The parts currently in this slot
	@return Instance - The parent object to attach to
	@return Vector3 - The position offset
]]
function VisualInventorySystem:GetSlotAttachmentPoint(player, bodyPartType, slotIndex, slotParts)
	local character = player.character
	local head = character:FindFirstChild("Head")
	
	if not head then
		return nil, Vector3.new(0, 0, 0)
	end
	
	-- Calculate horizontal offset based on slot
	local horizontalOffset = 0
	if slotIndex == 1 then
		horizontalOffset = -4 -- Left
	elseif slotIndex == 2 then
		horizontalOffset = 0 -- Center
	elseif slotIndex == 3 then
		horizontalOffset = 4 -- Right
	end
	
	-- Find what parts we already have in this slot
	local hasHead = false
	local hasBody = false
	local headModel = nil
	local bodyModel = nil
	
	for _, part in ipairs(slotParts) do
		if part.type == "HEAD" then
			hasHead = true
			headModel = part.physicalObject
		elseif part.type == "BODY" then
			hasBody = true
			bodyModel = part.physicalObject
		end
	end
	
	-- Determine where to attach based on part type and what we have
	if bodyPartType == "HEAD" then
		-- Heads attach to player head at slot position
		return head, Vector3.new(horizontalOffset, 3, 0)
		
	elseif bodyPartType == "BODY" then
		-- Body attaches under the head if we have one, otherwise to player head
		if hasHead and headModel then
			local headPart = headModel.PrimaryPart or headModel:FindFirstChildWhichIsA("BasePart")
			if headPart then
				return headPart, Vector3.new(0, -2.5, 0) -- Attach below head
			end
		end
		-- No head, attach to player head at slot position
		return head, Vector3.new(horizontalOffset, 1, 0)
		
	elseif bodyPartType == "LEGS" then
		-- Legs attach under body if we have one, otherwise under head, otherwise to player head
		if hasBody and bodyModel then
			local bodyPart = bodyModel.PrimaryPart or bodyModel:FindFirstChildWhichIsA("BasePart")
			if bodyPart then
				return bodyPart, Vector3.new(0, -2.5, 0) -- Attach below body
			end
		elseif hasHead and headModel then
			local headPart = headModel.PrimaryPart or headModel:FindFirstChildWhichIsA("BasePart")
			if headPart then
				return headPart, Vector3.new(0, -5, 0) -- Attach below head (leave space for body)
			end
		end
		-- No head or body, attach to player head at slot position
		return head, Vector3.new(horizontalOffset, -2, 0)
	end
	
	-- Default fallback
	return head, Vector3.new(horizontalOffset, 2, 0)
end

--[[
	Attaches a body part model to a player's character in a specific slot
	
	@param player Player - The player data structure
	@param bodyPart BodyPart - The body part to attach
	@param slotIndex number - The slot index (1-3)
	@param slotParts table - The parts currently in this slot
]]
function VisualInventorySystem:AttachPartToPlayer(player, bodyPart, slotIndex, slotParts)
	if not player.character then
		warn("Cannot attach part: player has no character")
		return
	end
	
	local character = player.character
	local head = character:FindFirstChild("Head")
	
	if not head then
		warn("Cannot attach part: character has no head")
		return
	end
	
	-- Get the physical model
	local partModel = bodyPart.physicalObject
	if not partModel then
		warn("Cannot attach part: no physical object")
		return
	end
	
	-- Remove the IsBodyPart attribute so it's no longer detected as collectible
	partModel:SetAttribute("IsBodyPart", false)
	
	-- Make sure the model is not anchored
	for _, part in ipairs(partModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	
	-- Get attachment point based on assembly logic and slot
	local attachToObject, positionOffset = self:GetSlotAttachmentPoint(player, bodyPart.type, slotIndex, slotParts or {})
	
	if not attachToObject then
		warn("Cannot attach part: no attachment point found")
		return
	end
	
	-- Create attachment point on the parent object
	local attachment = Instance.new("Attachment")
	attachment.Name = "BodyPartAttachment_" .. bodyPart.id
	attachment.Position = positionOffset
	attachment.Parent = attachToObject
	
	-- Get main part of the model
	local mainPart = partModel.PrimaryPart or partModel:FindFirstChildWhichIsA("BasePart")
	if not mainPart then
		warn("Cannot attach part: model has no parts")
		return
	end
	
	-- Create attachment on the part
	local partAttachment = Instance.new("Attachment")
	partAttachment.Name = "PlayerAttachment"
	partAttachment.Parent = mainPart
	
	-- Create AlignPosition to make it follow
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Attachment0 = partAttachment
	alignPosition.Attachment1 = attachment
	alignPosition.MaxForce = 10000
	alignPosition.Responsiveness = 20
	alignPosition.Parent = mainPart
	
	-- Create AlignOrientation to keep it upright
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = partAttachment
	alignOrientation.Attachment1 = attachment
	alignOrientation.MaxTorque = 10000
	alignOrientation.Responsiveness = 20
	alignOrientation.Parent = mainPart
	
	-- Store reference
	if not self.attachedParts[player.id] then
		self.attachedParts[player.id] = {}
	end
	self.attachedParts[player.id][bodyPart.id] = {
		model = partModel,
		attachment = attachment,
		type = bodyPart.type,
		attachedTo = attachToObject,
		slotIndex = slotIndex  -- Track which slot this part belongs to
	}
	
	print(string.format("✨ Attached %s to %s in Slot %d (connected to %s)", 
		bodyPart.type, player.username, slotIndex, attachToObject.Name))
end

--[[
	Detaches a body part from a player's character
	
	@param player Player - The player data structure
	@param bodyPart BodyPart - The body part to detach
	@return Model - The detached model
]]
function VisualInventorySystem:DetachPartFromPlayer(player, bodyPart)
	if not self.attachedParts[player.id] then
		return nil
	end
	
	local partData = self.attachedParts[player.id][bodyPart.id]
	if not partData then
		return nil
	end
	
	-- Remove attachment
	if partData.attachment and partData.attachment.Parent then
		partData.attachment:Destroy()
	end
	
	-- Remove constraints from model
	local model = partData.model
	if model then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") then
				descendant:Destroy()
			end
			if descendant:IsA("Attachment") and descendant.Name == "PlayerAttachment" then
				descendant:Destroy()
			end
			if descendant:IsA("BasePart") then
				descendant.CanCollide = true
			end
		end
	end
	
	-- Remove from tracking
	self.attachedParts[player.id][bodyPart.id] = nil
	
	print(string.format("✨ Detached %s from %s", bodyPart.type, player.username))
	
	return model
end

--[[
	Detaches all parts from a player
	
	@param player Player - The player data structure
	@return table - Array of detached models
]]
function VisualInventorySystem:DetachAllParts(player)
	local detachedModels = {}
	
	if not self.attachedParts[player.id] then
		return detachedModels
	end
	
	for partId, partData in pairs(self.attachedParts[player.id]) do
		-- Remove attachment
		if partData.attachment and partData.attachment.Parent then
			partData.attachment:Destroy()
		end
		
		-- Remove constraints from model
		local model = partData.model
		if model then
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") then
					descendant:Destroy()
				end
				if descendant:IsA("Attachment") and descendant.Name == "PlayerAttachment" then
					descendant:Destroy()
				end
				if descendant:IsA("BasePart") then
					descendant.CanCollide = true
				end
			end
			
			table.insert(detachedModels, model)
		end
	end
	
	-- Clear tracking
	self.attachedParts[player.id] = {}
	
	print(string.format("✨ Detached all parts from %s (%d parts)", player.username, #detachedModels))
	
	return detachedModels
end

--[[
	Shows a BillboardGui with the Brainrot name above a slot
	
	@param player Player - The player data structure
	@param slotIndex number - The slot index (1-3)
	@param brainrotName string - The name to display
	@param slotParts table - The parts in this slot (to attach the GUI to)
]]
function VisualInventorySystem:ShowSlotName(player, slotIndex, brainrotName, slotParts)
	if not player.character then
		return
	end
	
	-- Remove old GUI if exists
	self:HideSlotName(player, slotIndex)
	
	-- Find the head part in this slot to attach the GUI to
	local attachToPart = nil
	for _, part in ipairs(slotParts) do
		if part.type == "HEAD" and part.physicalObject then
			local model = part.physicalObject
			attachToPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			break
		end
	end
	
	-- If no head, use body, then legs
	if not attachToPart then
		for _, part in ipairs(slotParts) do
			if part.type == "BODY" and part.physicalObject then
				local model = part.physicalObject
				attachToPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				break
			end
		end
	end
	
	if not attachToPart then
		for _, part in ipairs(slotParts) do
			if part.type == "LEGS" and part.physicalObject then
				local model = part.physicalObject
				attachToPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				break
			end
		end
	end
	
	if not attachToPart then
		warn("Cannot show slot name: no part to attach to")
		return
	end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SlotName_" .. slotIndex
	billboard.Size = UDim2.new(6, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0) -- Above the part
	billboard.AlwaysOnTop = true
	billboard.Parent = attachToPart
	
	-- Create TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = brainrotName
	label.TextColor3 = Color3.fromRGB(255, 255, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard
	
	-- Store reference
	if not self.slotNameGuis[player.id] then
		self.slotNameGuis[player.id] = {}
	end
	self.slotNameGuis[player.id][slotIndex] = billboard
	
	print(string.format("📛 Showing name for Slot %d: %s", slotIndex, brainrotName))
end

--[[
	Hides the BillboardGui for a slot
	
	@param player Player - The player data structure
	@param slotIndex number - The slot index (1-3)
]]
function VisualInventorySystem:HideSlotName(player, slotIndex)
	if not self.slotNameGuis[player.id] then
		return
	end
	
	local gui = self.slotNameGuis[player.id][slotIndex]
	if gui and gui.Parent then
		gui:Destroy()
	end
	
	self.slotNameGuis[player.id][slotIndex] = nil
end

--[[
	Detaches parts from a specific slot only
	
	@param player Player - The player data structure
	@param slotIndex number - The slot index (1-3)
	@return table - Array of detached models
]]
function VisualInventorySystem:DetachSlotParts(player, slotIndex)
	local detachedModels = {}
	
	if not self.attachedParts[player.id] then
		return detachedModels
	end
	
	-- Find and detach only parts from the specified slot
	local partsToRemove = {}
	
	for partId, partData in pairs(self.attachedParts[player.id]) do
		if partData.slotIndex == slotIndex then
			-- Remove attachment
			if partData.attachment and partData.attachment.Parent then
				partData.attachment:Destroy()
			end
			
			-- Remove constraints from model
			local model = partData.model
			if model then
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") then
						descendant:Destroy()
					end
					if descendant:IsA("Attachment") and descendant.Name == "PlayerAttachment" then
						descendant:Destroy()
					end
					if descendant:IsA("BasePart") then
						descendant.CanCollide = true
					end
				end
				
				table.insert(detachedModels, model)
			end
			
			-- Mark for removal
			table.insert(partsToRemove, partId)
		end
	end
	
	-- Remove from tracking
	for _, partId in ipairs(partsToRemove) do
		self.attachedParts[player.id][partId] = nil
	end
	
	-- Also hide the slot name
	self:HideSlotName(player, slotIndex)
	
	print(string.format("✨ Detached Slot %d parts from %s (%d parts)", slotIndex, player.username, #detachedModels))
	
	return detachedModels
end

return VisualInventorySystem

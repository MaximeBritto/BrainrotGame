-- Visual Inventory System
-- Manages the visual display of body parts on player characters

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttachmentHelper = require(script.Parent.AttachmentHelper)

local VisualInventorySystem = {}
VisualInventorySystem.__index = VisualInventorySystem

function VisualInventorySystem.new()
	local self = setmetatable({}, VisualInventorySystem)
	self.attachedParts = {}
	self.slotNameGuis = {}
	return self
end

-- Get attachment point for a body part based on slot and what's in that slot
function VisualInventorySystem:GetSlotAttachmentPoint(player, bodyPartType, slotIndex, slotParts)
	local character = player.character
	local head = character:FindFirstChild("Head")
	
	if not head then
		return nil, Vector3.new(0, 0, 0), nil
	end
	
	-- Delegate to AttachmentHelper
	return AttachmentHelper.GetSlotAttachmentPoint(head, bodyPartType, slotIndex, slotParts)
end

-- Attaches a body part model to a player's character in a specific slot
function VisualInventorySystem:AttachPartToPlayer(player, bodyPart, slotIndex, slotParts)
	if not player.character then
		return
	end
	
	local character = player.character
	local head = character:FindFirstChild("Head")
	
	if not head then
		return
	end
	
	local partModel = bodyPart.physicalObject
	if not partModel then
		return
	end
	
	local mainPart = partModel.PrimaryPart or partModel:FindFirstChildWhichIsA("BasePart")
	if not mainPart then
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
	
	-- Get attachment point
	local attachToObject, positionOffset, customAttachment = self:GetSlotAttachmentPoint(player, bodyPart.type, slotIndex, slotParts or {})
	
	if not attachToObject then
		return
	end
	
	-- Create attachment point on the parent object
	local attachment = nil
	
	if customAttachment then
		attachment = customAttachment
	else
		attachment = Instance.new("Attachment")
		attachment.Name = "BodyPartAttachment_" .. bodyPart.id
		attachment.Position = positionOffset
		attachment.Parent = attachToObject
	end
	
	-- Look for TopAttachment in the body part model (for BODY and LEGS)
	local partTopAttachment = AttachmentHelper.FindAttachment(partModel, "TopAttachment")
	
	-- Create attachment on the part
	local partAttachment = nil
	
	if partTopAttachment and (bodyPart.type == "BODY" or bodyPart.type == "LEGS") then
		partAttachment = partTopAttachment
	else
		partAttachment = Instance.new("Attachment")
		partAttachment.Name = "PlayerAttachment"
		partAttachment.Parent = mainPart
	end
	
	-- Calculate forces based on model mass
	local totalMass = AttachmentHelper.CalculateTotalMass(partModel)
	local maxForce, maxTorque = AttachmentHelper.CalculateConstraintForces(totalMass)
	
	-- Create AlignPosition to make it follow
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Attachment0 = partAttachment
	alignPosition.Attachment1 = attachment
	alignPosition.MaxForce = maxForce
	alignPosition.Responsiveness = 25
	alignPosition.RigidityEnabled = true
	alignPosition.Parent = mainPart
	
	-- Create AlignOrientation to keep it upright
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = partAttachment
	alignOrientation.Attachment1 = attachment
	alignOrientation.MaxTorque = maxTorque
	alignOrientation.Responsiveness = 25
	alignOrientation.RigidityEnabled = true
	alignOrientation.Parent = mainPart
	
	-- Store reference
	if not self.attachedParts[player.id] then
		self.attachedParts[player.id] = {}
	end
	self.attachedParts[player.id][bodyPart.id] = {
		model = partModel,
		attachment = customAttachment and nil or attachment,
		type = bodyPart.type,
		attachedTo = attachToObject,
		slotIndex = slotIndex,
		usingCustomAttachment = customAttachment ~= nil
	}
end

-- Detaches a body part from a player's character
function VisualInventorySystem:DetachPartFromPlayer(player, bodyPart)
	if not self.attachedParts[player.id] then
		return nil
	end
	
	local partData = self.attachedParts[player.id][bodyPart.id]
	if not partData then
		return nil
	end
	
	-- Remove attachment (only if we created it, not if it's a custom one)
	if partData.attachment and partData.attachment.Parent and not partData.usingCustomAttachment then
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
	
	return model
end

-- Detaches all parts from a player
function VisualInventorySystem:DetachAllParts(player)
	local detachedModels = {}
	
	if not self.attachedParts[player.id] then
		return detachedModels
	end
	
	for partId, partData in pairs(self.attachedParts[player.id]) do
		if partData.attachment and partData.attachment.Parent and not partData.usingCustomAttachment then
			partData.attachment:Destroy()
		end
		
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
	
	self.attachedParts[player.id] = {}
	
	return detachedModels
end

-- Shows a BillboardGui with the Brainrot name above a slot
function VisualInventorySystem:ShowSlotName(player, slotIndex, brainrotName, slotParts)
	if not player.character then
		return
	end
	
	self:HideSlotName(player, slotIndex)
	
	-- Find the head part in this slot to attach the GUI to
	local attachToPart = nil
	
	-- Try HEAD first
	for _, part in ipairs(slotParts) do
		if part.type == "HEAD" and part.physicalObject then
			attachToPart = AttachmentHelper.FindMainPart(part.physicalObject)
			if attachToPart then break end
		end
	end
	
	-- Try BODY if no HEAD
	if not attachToPart then
		for _, part in ipairs(slotParts) do
			if part.type == "BODY" and part.physicalObject then
				attachToPart = AttachmentHelper.FindMainPart(part.physicalObject)
				if attachToPart then break end
			end
		end
	end
	
	-- Try LEGS if no HEAD or BODY
	if not attachToPart then
		for _, part in ipairs(slotParts) do
			if part.type == "LEGS" and part.physicalObject then
				attachToPart = AttachmentHelper.FindMainPart(part.physicalObject)
				if attachToPart then break end
			end
		end
	end
	
	if not attachToPart then
		return
	end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SlotName_" .. slotIndex
	billboard.Size = UDim2.new(6, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
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
end

-- Hides the BillboardGui for a slot
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

-- Detaches parts from a specific slot only
function VisualInventorySystem:DetachSlotParts(player, slotIndex)
	local detachedModels = {}
	
	if not self.attachedParts[player.id] then
		return detachedModels
	end
	
	local partsToRemove = {}
	
	for partId, partData in pairs(self.attachedParts[player.id]) do
		if partData.slotIndex == slotIndex then
			if partData.attachment and partData.attachment.Parent and not partData.usingCustomAttachment then
				partData.attachment:Destroy()
			end
			
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
			
			table.insert(partsToRemove, partId)
		end
	end
	
	for _, partId in ipairs(partsToRemove) do
		self.attachedParts[player.id][partId] = nil
	end
	
	self:HideSlotName(player, slotIndex)
	
	return detachedModels
end

return VisualInventorySystem

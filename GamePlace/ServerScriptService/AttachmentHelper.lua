-- Attachment Helper Module
-- Handles calculation of attachment points and offsets for body parts
-- Separates positioning logic from visual inventory management

local AttachmentHelper = {}

--[[
	Calculates horizontal offset based on slot index
	
	@param slotIndex number - Slot index (1, 2, or 3)
	@return number - Horizontal offset
]]
function AttachmentHelper.CalculateSlotHorizontalOffset(slotIndex)
	if slotIndex == 1 then
		return -4
	elseif slotIndex == 2 then
		return 0
	elseif slotIndex == 3 then
		return 4
	end
	return 0
end

--[[
	Finds the main part of a model (PrimaryPart or first BasePart)
	
	@param model Model - The model to search
	@return BasePart|nil - The main part or nil
]]
function AttachmentHelper.FindMainPart(model)
	if not model then return nil end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

--[[
	Finds a specific attachment in a model by name (recursive search)
	
	@param model Model - The model to search
	@param attachmentName string - Name of the attachment
	@return Attachment|nil - The attachment or nil
]]
function AttachmentHelper.FindAttachment(model, attachmentName)
	if not model then return nil end
	
	local attachment = model:FindFirstChild(attachmentName, true)
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	
	return nil
end

--[[
	Analyzes what parts are already in a slot
	
	@param slotParts table - Array of body parts in the slot
	@return boolean - Has head
	@return boolean - Has body
	@return Model|nil - Head model
	@return Model|nil - Body model
]]
function AttachmentHelper.AnalyzeSlotParts(slotParts)
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
	
	return hasHead, hasBody, headModel, bodyModel
end

--[[
	Calculates attachment point for a HEAD part
	
	@param head BasePart - Player's head
	@param horizontalOffset number - Horizontal offset for slot
	@return BasePart - Attachment parent
	@return Vector3 - Position offset
	@return Attachment|nil - Custom attachment (nil for HEAD)
]]
function AttachmentHelper.GetHeadAttachmentPoint(head, horizontalOffset)
	return head, Vector3.new(horizontalOffset, 3, 0), nil
end

--[[
	Calculates attachment point for a BODY part
	
	@param head BasePart - Player's head
	@param horizontalOffset number - Horizontal offset for slot
	@param hasHead boolean - Whether slot has a head
	@param headModel Model|nil - Head model if present
	@return BasePart - Attachment parent
	@return Vector3 - Position offset
	@return Attachment|nil - Custom attachment if using head's bottom
]]
function AttachmentHelper.GetBodyAttachmentPoint(head, horizontalOffset, hasHead, headModel)
	-- If we have a head, try to attach to its bottom
	if hasHead and headModel then
		local headBottomAttachment = AttachmentHelper.FindAttachment(headModel, "BottomAttachment")
		
		if headBottomAttachment then
			-- Use the head's bottom attachment
			return headBottomAttachment.Parent, Vector3.new(0, 0, 0), headBottomAttachment
		else
			-- No attachment, use offset from head part
			local headPart = AttachmentHelper.FindMainPart(headModel)
			if headPart then
				return headPart, Vector3.new(0, -2.5, 0), nil
			end
		end
	end
	
	-- Default: attach to player's head
	return head, Vector3.new(horizontalOffset, 1, 0), nil
end

--[[
	Calculates attachment point for LEGS part
	
	@param head BasePart - Player's head
	@param horizontalOffset number - Horizontal offset for slot
	@param hasHead boolean - Whether slot has a head
	@param hasBody boolean - Whether slot has a body
	@param headModel Model|nil - Head model if present
	@param bodyModel Model|nil - Body model if present
	@return BasePart - Attachment parent
	@return Vector3 - Position offset
	@return Attachment|nil - Custom attachment if using body's bottom
]]
function AttachmentHelper.GetLegsAttachmentPoint(head, horizontalOffset, hasHead, hasBody, headModel, bodyModel)
	-- Priority 1: Attach to body's bottom if we have a body
	if hasBody and bodyModel then
		local bodyBottomAttachment = AttachmentHelper.FindAttachment(bodyModel, "BottomAttachment")
		
		if bodyBottomAttachment then
			-- Use the body's bottom attachment
			return bodyBottomAttachment.Parent, Vector3.new(0, 0, 0), bodyBottomAttachment
		else
			-- No attachment, use offset from body part
			local bodyPart = AttachmentHelper.FindMainPart(bodyModel)
			if bodyPart then
				return bodyPart, Vector3.new(0, -2.5, 0), nil
			end
		end
	end
	
	-- Priority 2: Attach below head if we have a head but no body
	if hasHead and headModel then
		local headPart = AttachmentHelper.FindMainPart(headModel)
		if headPart then
			return headPart, Vector3.new(0, -5, 0), nil
		end
	end
	
	-- Default: attach to player's head
	return head, Vector3.new(horizontalOffset, -2, 0), nil
end

--[[
	Main function: Gets attachment point for a body part based on slot and existing parts
	
	@param playerHead BasePart - Player's head
	@param bodyPartType string - Type of body part (HEAD, BODY, LEGS)
	@param slotIndex number - Slot index (1, 2, or 3)
	@param slotParts table - Array of parts already in the slot
	@return BasePart|nil - Object to attach to
	@return Vector3 - Position offset
	@return Attachment|nil - Custom attachment (if using existing attachment)
]]
function AttachmentHelper.GetSlotAttachmentPoint(playerHead, bodyPartType, slotIndex, slotParts)
	if not playerHead then
		return nil, Vector3.new(0, 0, 0), nil
	end
	
	-- Calculate horizontal offset for this slot
	local horizontalOffset = AttachmentHelper.CalculateSlotHorizontalOffset(slotIndex)
	
	-- Analyze what parts we already have in this slot
	local hasHead, hasBody, headModel, bodyModel = AttachmentHelper.AnalyzeSlotParts(slotParts or {})
	
	-- Determine attachment point based on part type
	if bodyPartType == "HEAD" then
		return AttachmentHelper.GetHeadAttachmentPoint(playerHead, horizontalOffset)
		
	elseif bodyPartType == "BODY" then
		return AttachmentHelper.GetBodyAttachmentPoint(playerHead, horizontalOffset, hasHead, headModel)
		
	elseif bodyPartType == "LEGS" then
		return AttachmentHelper.GetLegsAttachmentPoint(playerHead, horizontalOffset, hasHead, hasBody, headModel, bodyModel)
	end
	
	-- Fallback
	return playerHead, Vector3.new(horizontalOffset, 2, 0), nil
end

--[[
	Calculates total mass of a model (sum of all BaseParts)
	
	@param model Model - The model to calculate mass for
	@return number - Total mass
]]
function AttachmentHelper.CalculateTotalMass(model)
	local totalMass = 0
	
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			totalMass = totalMass + part.Mass
		end
	end
	
	return totalMass
end

--[[
	Calculates appropriate force/torque values based on mass
	
	@param totalMass number - Total mass of the model
	@return number - Max force
	@return number - Max torque
]]
function AttachmentHelper.CalculateConstraintForces(totalMass)
	local maxForce = math.max(10000, totalMass * 500)
	local maxTorque = math.max(10000, totalMass * 500)
	
	return maxForce, maxTorque
end

return AttachmentHelper

-- Brainrot Assembler Module
-- Handles the complex logic of assembling and placing Brainrots on pedestals

local GameServerHelpers = require(script.Parent.GameServerHelpers)

local BrainrotAssembler = {}

--[[
	Assembles a Brainrot from slot parts and places it on a pedestal
	@param slotParts table - Array of body parts from the slot
	@param detachedModels table - Array of detached models from player
	@param pedestalTop Vector3 - Top position of the pedestal
	@param brainrotName string - Name of the Brainrot
	@return Model - The assembled Brainrot model
]]
function BrainrotAssembler.AssembleAndPlace(slotParts, detachedModels, pedestalTop, brainrotName)
	-- Create Brainrot model
	local brainrotModel = Instance.new("Model")
	brainrotModel.Name = brainrotName
	
	-- Create a map of bodyPartId -> model
	local modelMap = {}
	for _, model in ipairs(detachedModels) do
		if model and model.Parent then
			local bodyPartId = model:GetAttribute("BodyPartId")
			if bodyPartId then
				modelMap[bodyPartId] = model
			end
		end
	end
	
	-- Find each part type
	local headModel, bodyModel, legsModel = nil, nil, nil
	
	for _, part in ipairs(slotParts) do
		if part.type == "HEAD" then
			headModel = modelMap[part.id]
		elseif part.type == "BODY" then
			bodyModel = modelMap[part.id]
		elseif part.type == "LEGS" then
			legsModel = modelMap[part.id]
		end
	end
	
	-- Assemble parts hierarchically
	local previousBottomAttachment = nil
	local previousPartCFrame = nil
	local previousMainPart = nil
	
	-- Process HEAD
	local isBottomPart = (bodyModel == nil and legsModel == nil)
	previousBottomAttachment, previousPartCFrame, previousMainPart = GameServerHelpers.ProcessBodyPartModel(
		headModel, 
		pedestalTop, 
		nil, 
		nil,
		nil, 
		isBottomPart, 
		brainrotModel
	)
	
	-- Process BODY
	if bodyModel then
		isBottomPart = (legsModel == nil)
		previousBottomAttachment, previousPartCFrame, previousMainPart = GameServerHelpers.ProcessBodyPartModel(
			bodyModel, 
			pedestalTop, 
			previousBottomAttachment,
			previousPartCFrame, 
			previousMainPart, 
			isBottomPart, 
			brainrotModel
		)
	end
	
	-- Process LEGS
	if legsModel then
		GameServerHelpers.ProcessBodyPartModel(
			legsModel, 
			pedestalTop, 
			previousBottomAttachment,
			previousPartCFrame, 
			previousMainPart, 
			true, -- Always anchored
			brainrotModel
		)
	end
	
	brainrotModel.Parent = workspace
	
	return brainrotModel
end

return BrainrotAssembler

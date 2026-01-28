-- Pedestal UI Module
-- Handles creation and management of UI elements for pedestals
-- Separates UI logic from pedestal business logic

local PedestalUI = {}

--[[
	Creates a base owner label above a player's base
	
	@param baseCenter BasePart - The center part of the base
	@param playerName string - The player's name
	@return BillboardGui - The created billboard
]]
function PedestalUI.CreateBaseOwnerLabel(baseCenter, playerName)
	if not baseCenter then return nil end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BaseOwnerLabel"
	billboard.Size = UDim2.new(8, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = baseCenter
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.5
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = "🏠 " .. playerName .. "'s Base"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard
	
	return billboard
end

--[[
	Creates a label on a pedestal showing the Brainrot name
	
	@param pedestal Part - The pedestal to add the label to
	@param brainrotName string - The name of the Brainrot
	@return BillboardGui - The created billboard
]]
function PedestalUI.CreatePedestalLabel(pedestal, brainrotName)
	if not pedestal then return nil end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PedestalLabel"
	billboard.Size = UDim2.new(6, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pedestal
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
	label.Text = brainrotName
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard
	
	return billboard
end

--[[
	Applies visual effects to a pedestal when occupied
	
	@param pedestal Part - The pedestal to style
]]
function PedestalUI.StyleOccupiedPedestal(pedestal)
	if not pedestal then return end
	
	pedestal.Material = Enum.Material.Neon
	pedestal.Color = Color3.fromRGB(0, 255, 0)
end

--[[
	Resets a pedestal to its default appearance
	
	@param pedestal Part - The pedestal to reset
]]
function PedestalUI.StyleEmptyPedestal(pedestal)
	if not pedestal then return end
	
	pedestal.Material = Enum.Material.SmoothPlastic
	pedestal.Color = Color3.fromRGB(163, 162, 165)
end

--[[
	Removes the label from a pedestal
	
	@param pedestal Part - The pedestal to remove label from
]]
function PedestalUI.RemovePedestalLabel(pedestal)
	if not pedestal then return end
	
	local label = pedestal:FindFirstChild("PedestalLabel")
	if label then
		label:Destroy()
	end
end

--[[
	Removes the base owner label
	
	@param baseCenter BasePart - The center part of the base
]]
function PedestalUI.RemoveBaseOwnerLabel(baseCenter)
	if not baseCenter then return end
	
	local label = baseCenter:FindFirstChild("BaseOwnerLabel")
	if label then
		label:Destroy()
	end
end

return PedestalUI

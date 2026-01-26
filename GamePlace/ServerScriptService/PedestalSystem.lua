-- Pedestal System
-- Manages pedestals in player bases for placing completed Brainrots

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PedestalSystem = {}
PedestalSystem.__index = PedestalSystem

function PedestalSystem.new()
	local self = setmetatable({}, PedestalSystem)
	
	-- Track which pedestals are occupied
	-- Format: { [pedestalInstance] = { brainrotName = string, playerId = number } }
	self.occupiedPedestals = {}
	
	-- Track player bases
	-- Format: { [userId] = { base = Folder, pedestals = {Pedestal1, Pedestal2, Pedestal3} } }
	self.playerBases = {}
	
	return self
end

--[[
	Initializes pedestals for a player's base
	
	@param userId number - The player's UserId
	@param baseNumber number - The base number (1-8)
]]
function PedestalSystem:InitializePlayerBase(userId, baseNumber)
	local workspace = game:GetService("Workspace")
	local playerBases = workspace:FindFirstChild("PlayerBases")
	
	if not playerBases then
		warn("PlayerBases folder not found in Workspace")
		return false
	end
	
	local baseName = "Base" .. baseNumber
	local base = playerBases:FindFirstChild(baseName)
	
	if not base then
		warn(string.format("Base %s not found", baseName))
		return false
	end
	
	-- Mark this base as owned by this player
	base:SetAttribute("PlayerOwner", userId)
	
	-- Get player name
	local playerName = "Player"
	for _, p in pairs(Players:GetPlayers()) do
		if p.UserId == userId then
			playerName = p.Name
			break
		end
	end
	
	-- Create a BillboardGui above the base to show player name
	local baseCenter = base:FindFirstChild("SpawnLocation") or base:FindFirstChildWhichIsA("BasePart")
	if baseCenter then
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
	end
	
	-- Find the 3 pedestals
	local pedestals = {}
	for i = 1, 3 do
		local pedestal = base:FindFirstChild("Pedestal" .. i)
		if pedestal then
			table.insert(pedestals, pedestal)
		else
			warn(string.format("Pedestal%d not found in %s", i, baseName))
		end
	end
	
	if #pedestals == 0 then
		warn(string.format("No pedestals found in %s", baseName))
		return false
	end
	
	self.playerBases[userId] = {
		base = base,
		pedestals = pedestals
	}
	
	print(string.format("✓ Initialized %d pedestals for player base %d", #pedestals, baseNumber))
	return true
end

--[[
	Finds the nearest empty pedestal in the player's base
	
	@param userId number - The player's UserId
	@param playerPosition Vector3 - The player's current position
	@param maxDistance number - Maximum distance to check (default 10 studs)
	@return Part|nil - The nearest empty pedestal, or nil
	@return number - The distance to the pedestal
]]
function PedestalSystem:FindNearestEmptyPedestal(userId, playerPosition, maxDistance)
	maxDistance = maxDistance or 10
	
	local playerBase = self.playerBases[userId]
	if not playerBase then
		return nil, math.huge
	end
	
	local nearestPedestal = nil
	local nearestDistance = maxDistance
	
	for _, pedestal in ipairs(playerBase.pedestals) do
		-- Check if pedestal is empty
		if not self.occupiedPedestals[pedestal] then
			local distance = (pedestal.Position - playerPosition).Magnitude
			
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPedestal = pedestal
			end
		end
	end
	
	return nearestPedestal, nearestDistance
end

--[[
	Places a Brainrot on a pedestal
	
	@param pedestal Part - The pedestal to place on
	@param userId number - The player's UserId
	@param brainrotName string - The name of the Brainrot
	@param brainrotModel Model - The visual model of the Brainrot (optional)
]]
function PedestalSystem:PlaceBrainrotOnPedestal(pedestal, userId, brainrotName, brainrotModel)
	-- Mark pedestal as occupied
	self.occupiedPedestals[pedestal] = {
		brainrotName = brainrotName,
		playerId = userId
	}
	
	-- Create a visual representation on the pedestal
	if brainrotModel and brainrotModel.Parent then
		-- Position the model on top of the pedestal
		local pedestalTop = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + 2, 0)
		
		-- Anchor all parts
		for _, part in ipairs(brainrotModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		
		-- Position the model
		if brainrotModel.PrimaryPart then
			brainrotModel:SetPrimaryPartCFrame(CFrame.new(pedestalTop))
		else
			local mainPart = brainrotModel:FindFirstChildWhichIsA("BasePart")
			if mainPart then
				mainPart.CFrame = CFrame.new(pedestalTop)
			end
		end
	end
	
	-- Create a label on the pedestal
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
	
	-- Add a glow effect to the pedestal
	pedestal.Material = Enum.Material.Neon
	pedestal.Color = Color3.fromRGB(0, 255, 0)
	
	print(string.format("🏆 Placed '%s' on pedestal", brainrotName))
end

--[[
	Checks if a pedestal is occupied
	
	@param pedestal Part - The pedestal to check
	@return boolean - True if occupied
	@return string|nil - The Brainrot name if occupied
]]
function PedestalSystem:IsPedestalOccupied(pedestal)
	local data = self.occupiedPedestals[pedestal]
	if data then
		return true, data.brainrotName
	end
	return false, nil
end

--[[
	Gets the number of Brainrots placed by a player
	
	@param userId number - The player's UserId
	@return number - Count of placed Brainrots
]]
function PedestalSystem:GetPlacedCount(userId)
	local count = 0
	
	for pedestal, data in pairs(self.occupiedPedestals) do
		if data.playerId == userId then
			count = count + 1
		end
	end
	
	return count
end

return PedestalSystem

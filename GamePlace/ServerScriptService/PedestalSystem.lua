-- Pedestal System
-- Manages pedestals in player bases for placing completed Brainrots

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PedestalUI = require(script.Parent.PedestalUI)

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
		PedestalUI.CreateBaseOwnerLabel(baseCenter, playerName)
	end
	
	-- Find the 10 pedestals (or however many exist)
	local pedestals = {}
	for i = 1, 10 do
		local pedestal = base:FindFirstChild("Pedestal" .. i)
		if pedestal then
			table.insert(pedestals, pedestal)
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
		local isOccupied = self.occupiedPedestals[pedestal] ~= nil
		
		-- Check if pedestal is empty and within range
		if not isOccupied then
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
	
	-- Create UI label and style pedestal
	PedestalUI.CreatePedestalLabel(pedestal, brainrotName)
	PedestalUI.StyleOccupiedPedestal(pedestal)
	
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

--[[
	Clears all Brainrots from a player's base (when they disconnect)
	
	@param userId number - The player's UserId
]]
function PedestalSystem:ClearPlayerBase(userId)
	local playerBase = self.playerBases[userId]
	if not playerBase then
		return
	end
	
	-- Clear all pedestals
	for _, pedestal in ipairs(playerBase.pedestals) do
		if self.occupiedPedestals[pedestal] then
			-- Remove UI and reset appearance
			PedestalUI.RemovePedestalLabel(pedestal)
			PedestalUI.StyleEmptyPedestal(pedestal)
			
			-- Find and destroy any Brainrot models on this pedestal
			for _, child in ipairs(workspace:GetChildren()) do
				if child:IsA("Model") and child:FindFirstChild("Part") then
					local part = child:FindFirstChildWhichIsA("BasePart")
					if part then
						local distance = (part.Position - pedestal.Position).Magnitude
						if distance < 10 then -- If close to pedestal, it's probably the Brainrot
							child:Destroy()
						end
					end
				end
			end
			
			-- Mark as empty
			self.occupiedPedestals[pedestal] = nil
		end
	end
	
	-- Remove base from tracking
	self.playerBases[userId] = nil
	
	print(string.format("✓ Cleared base for player %d", userId))
end

return PedestalSystem

-- Pedestal UI Client Script
-- Shows UI when near a pedestal and allows placing Brainrots with F key

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Settings
local DETECTION_RADIUS = 10 -- Distance to detect pedestals

-- State
local character = nil
local rootPart = nil
local nearestPedestal = nil
local currentBillboard = nil
local assembledSlots = {} -- Track which slots are assembled

-- Get RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local placeBrainrotEvent = remoteEvents:WaitForChild("PlaceBrainrotEvent")
local updateInventory = remoteEvents:WaitForChild("UpdateInventory")

-- Function to setup character
local function SetupCharacter(newCharacter)
	character = newCharacter
	rootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Reset state
	nearestPedestal = nil
	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	
	print("✓ Pedestal UI connected to character")
end

-- Setup initial character
if player.Character then
	SetupCharacter(player.Character)
end

-- Reconnect on respawn
player.CharacterAdded:Connect(SetupCharacter)

-- Listen for inventory updates to know which slots are assembled
updateInventory.OnClientEvent:Connect(function(inventoryData)
	-- Clear assembled slots
	assembledSlots = {}
	
	-- Track which slots are assembled
	for _, part in ipairs(inventoryData) do
		if part.assembled then
			assembledSlots[part.slotIndex] = part.brainrotName
		end
	end
end)

-- Function to create billboard UI
local function CreateBillboard(pedestal)
	-- Remove old billboard if exists
	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	
	-- Find which slot to place (first assembled slot)
	local slotToPlace = nil
	local brainrotName = nil
	
	for slot = 1, 3 do
		if assembledSlots[slot] then
			slotToPlace = slot
			brainrotName = assembledSlots[slot]
			break
		end
	end
	
	if not slotToPlace then
		return -- No assembled Brainrots
	end
	
	-- Create new billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PedestalUI"
	billboard.Size = UDim2.new(5, 0, 1.5, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pedestal
	
	-- Background frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard
	
	-- Text label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = "[F] Placer: " .. brainrotName
	label.TextColor3 = Color3.new(0, 1, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = frame
	
	currentBillboard = billboard
	return billboard
end

-- Function to find nearest empty pedestal in player's base ONLY
local function FindNearestPedestal()
	if not character or not rootPart or not rootPart.Parent then
		return nil
	end
	
	local workspace = game:GetService("Workspace")
	local playerBases = workspace:FindFirstChild("PlayerBases")
	
	if not playerBases then
		return nil
	end
	
	local nearestDistance = DETECTION_RADIUS
	local nearest = nil
	
	-- Find player's base by checking which base has a PlayerOwner attribute matching our UserId
	for _, base in pairs(playerBases:GetChildren()) do
		-- Check if this base belongs to the player
		local ownerId = base:GetAttribute("PlayerOwner")
		
		if ownerId == player.UserId then
			-- This is the player's base, check its pedestals
			for i = 1, 3 do
				local pedestal = base:FindFirstChild("Pedestal" .. i)
				if pedestal and pedestal:IsA("BasePart") then
					-- Check if pedestal is empty (no PedestalLabel)
					if not pedestal:FindFirstChild("PedestalLabel") then
						local distance = (pedestal.Position - rootPart.Position).Magnitude
						
						if distance < nearestDistance then
							nearestDistance = distance
							nearest = pedestal
						end
					end
				end
			end
			break -- Found player's base, no need to check others
		end
	end
	
	return nearest
end

-- Handle F key input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.F then
		if nearestPedestal then
			-- Find which slot to place
			local slotToPlace = nil
			
			for slot = 1, 3 do
				if assembledSlots[slot] then
					slotToPlace = slot
					break
				end
			end
			
			if slotToPlace then
				print(string.format("📤 Placing Brainrot from Slot %d", slotToPlace))
				placeBrainrotEvent:FireServer(slotToPlace)
				
				-- Remove billboard
				if currentBillboard then
					currentBillboard:Destroy()
					currentBillboard = nil
				end
				nearestPedestal = nil
			end
		end
	end
end)

-- Main update loop
RunService.RenderStepped:Connect(function(deltaTime)
	-- Skip if no character or no assembled Brainrots
	if not character or not rootPart or not rootPart.Parent then
		return
	end
	
	-- Check if we have any assembled Brainrots
	local hasAssembled = false
	for _ in pairs(assembledSlots) do
		hasAssembled = true
		break
	end
	
	if not hasAssembled then
		-- No assembled Brainrots, hide UI
		if currentBillboard then
			currentBillboard:Destroy()
			currentBillboard = nil
		end
		nearestPedestal = nil
		return
	end
	
	-- Find nearest pedestal
	local newNearest = FindNearestPedestal()
	
	-- Update nearest pedestal
	if newNearest ~= nearestPedestal then
		nearestPedestal = newNearest
		
		-- Create or remove billboard
		if nearestPedestal then
			CreateBillboard(nearestPedestal)
		else
			if currentBillboard then
				currentBillboard:Destroy()
				currentBillboard = nil
			end
		end
	end
end)

print("✓ Pedestal UI initialized")

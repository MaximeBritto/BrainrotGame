-- Game HUD Client Script
-- Displays player inventory, match timer, and scores

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Inventory Display
local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryFrame"
inventoryFrame.Size = UDim2.new(0, 350, 0, 120)
inventoryFrame.Position = UDim2.new(0, 10, 1, -130)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
inventoryFrame.BackgroundTransparency = 0.3  -- More visible
inventoryFrame.BorderSizePixel = 2
inventoryFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
inventoryFrame.Parent = screenGui

local inventoryTitle = Instance.new("TextLabel")
inventoryTitle.Name = "Title"
inventoryTitle.Size = UDim2.new(1, 0, 0, 30)
inventoryTitle.BackgroundTransparency = 1
inventoryTitle.Text = "INVENTORY"
inventoryTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
inventoryTitle.TextSize = 18
inventoryTitle.Font = Enum.Font.GothamBold
inventoryTitle.Parent = inventoryFrame

local inventoryText = Instance.new("TextLabel")
inventoryText.Name = "InventoryText"
inventoryText.Size = UDim2.new(1, -20, 1, -40)
inventoryText.Position = UDim2.new(0, 10, 0, 35)
inventoryText.BackgroundTransparency = 1
inventoryText.Text = "Empty\nSlot 1: [ ] [ ] [ ]\nSlot 2: [ ] [ ] [ ]\nSlot 3: [ ] [ ] [ ]"
inventoryText.TextColor3 = Color3.fromRGB(200, 200, 200)
inventoryText.TextSize = 14
inventoryText.Font = Enum.Font.Gotham
inventoryText.TextXAlignment = Enum.TextXAlignment.Left
inventoryText.TextYAlignment = Enum.TextYAlignment.Top
inventoryText.TextWrapped = true
inventoryText.Parent = inventoryFrame

-- Match Timer Display
local timerFrame = Instance.new("Frame")
timerFrame.Name = "TimerFrame"
timerFrame.Size = UDim2.new(0, 200, 0, 60)
timerFrame.Position = UDim2.new(0.5, -100, 0, 10)
timerFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
timerFrame.BackgroundTransparency = 0.5
timerFrame.BorderSizePixel = 0
timerFrame.Parent = screenGui

local timerText = Instance.new("TextLabel")
timerText.Name = "TimerText"
timerText.Size = UDim2.new(1, 0, 1, 0)
timerText.BackgroundTransparency = 1
timerText.Text = "5:00"
timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
timerText.TextSize = 32
timerText.Font = Enum.Font.GothamBold
timerText.Parent = timerFrame

-- Score Display
local scoreFrame = Instance.new("Frame")
scoreFrame.Name = "ScoreFrame"
scoreFrame.Size = UDim2.new(0, 200, 0, 60)
scoreFrame.Position = UDim2.new(1, -210, 0, 10)
scoreFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scoreFrame.BackgroundTransparency = 0.5
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = screenGui

local scoreText = Instance.new("TextLabel")
scoreText.Name = "ScoreText"
scoreText.Size = UDim2.new(1, 0, 1, 0)
scoreText.BackgroundTransparency = 1
scoreText.Text = "Score: 0"
scoreText.TextColor3 = Color3.fromRGB(255, 255, 0)
scoreText.TextSize = 24
scoreText.Font = Enum.Font.GothamBold
scoreText.Parent = scoreFrame

-- Controls Help
local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "ControlsFrame"
controlsFrame.Size = UDim2.new(0, 250, 0, 120)
controlsFrame.Position = UDim2.new(1, -260, 1, -130)
controlsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
controlsFrame.BackgroundTransparency = 0.7
controlsFrame.BorderSizePixel = 0
controlsFrame.Parent = screenGui

local controlsText = Instance.new("TextLabel")
controlsText.Name = "ControlsText"
controlsText.Size = UDim2.new(1, -20, 1, -20)
controlsText.Position = UDim2.new(0, 10, 0, 10)
controlsText.BackgroundTransparency = 1
controlsText.Text = "CONTROLS:\nWASD - Move\nSpace - Jump\nE/Click - Punch\nF - Interact/Steal"
controlsText.TextColor3 = Color3.fromRGB(200, 200, 200)
controlsText.TextSize = 14
controlsText.Font = Enum.Font.Gotham
controlsText.TextXAlignment = Enum.TextXAlignment.Left
controlsText.TextYAlignment = Enum.TextYAlignment.Top
controlsText.Parent = controlsFrame

-- Update functions (these would be called by RemoteEvents from server)
local function UpdateInventory(inventoryData)
	print(string.format("📥 Client received inventory update: %d items", #inventoryData))
	print(string.format("📥 Raw data: %s", game:GetService("HttpService"):JSONEncode(inventoryData)))
	
	if #inventoryData == 0 then
		inventoryText.Text = "Empty\nSlot 1: [ ] [ ] [ ]\nSlot 2: [ ] [ ] [ ]\nSlot 3: [ ] [ ] [ ]"
	else
		-- Organize by slots
		local slots = {
			{head = nil, body = nil, legs = nil},
			{head = nil, body = nil, legs = nil},
			{head = nil, body = nil, legs = nil}
		}
		
		for _, part in ipairs(inventoryData) do
			print(string.format("📥 Processing part: slotIndex=%s, type=%s, nameFragment=%s", 
				tostring(part.slotIndex), tostring(part.type), tostring(part.nameFragment)))
			
			local slotIndex = part.slotIndex
			local partType = part.type:lower()
			
			if slots[slotIndex] then
				slots[slotIndex][partType] = part.nameFragment
			end
		end
		
		-- Build display text
		local text = ""
		for i = 1, 3 do
			local slot = slots[i]
			local headText = slot.head or "[ ]"
			local bodyText = slot.body or "[ ]"
			local legsText = slot.legs or "[ ]"
			
			text = text .. string.format("Slot %d: %s %s %s\n", i, headText, bodyText, legsText)
		end
		
		inventoryText.Text = text
	end
	
	print(string.format("📥 Inventory UI updated: %s", inventoryText.Text))
end

local function UpdateTimer(timeRemaining)
	local minutes = math.floor(timeRemaining / 60)
	local seconds = math.floor(timeRemaining % 60)
	timerText.Text = string.format("%d:%02d", minutes, seconds)
	
	-- Change color when time is running out
	if timeRemaining < 60 then
		timerText.TextColor3 = Color3.fromRGB(255, 0, 0)
	elseif timeRemaining < 120 then
		timerText.TextColor3 = Color3.fromRGB(255, 255, 0)
	else
		timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function UpdateScore(score)
	scoreText.Text = "Score: " .. score
end

-- Listen for updates from server
if ReplicatedStorage:FindFirstChild("RemoteEvents") then
	local remoteEvents = ReplicatedStorage.RemoteEvents
	
	if remoteEvents:FindFirstChild("UpdateInventory") then
		remoteEvents.UpdateInventory.OnClientEvent:Connect(UpdateInventory)
	end
	
	if remoteEvents:FindFirstChild("UpdateTimer") then
		remoteEvents.UpdateTimer.OnClientEvent:Connect(UpdateTimer)
	end
	
	if remoteEvents:FindFirstChild("UpdateScore") then
		remoteEvents.UpdateScore.OnClientEvent:Connect(UpdateScore)
	end
end

print("✓ Game HUD initialized")

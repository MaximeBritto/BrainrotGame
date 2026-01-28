-- Collection UI Client Script
-- Shows billboard and progress bar when near body parts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Settings
local DETECTION_RADIUS = 8 -- Distance to detect body parts
local COLLECTION_TIME = 0.7 -- Time to hold E to collect (seconds)

-- State
local character = nil
local rootPart = nil
local nearestPart = nil
local currentBillboard = nil
local isCollecting = false
local collectionProgress = 0

-- Get RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local collectEvent = remoteEvents:WaitForChild("CollectEvent")

-- Function to setup character
local function SetupCharacter(newCharacter)
	character = newCharacter
	rootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Reset state
	nearestPart = nil
	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	isCollecting = false
	collectionProgress = 0
	
	print("✓ Collection UI reconnected to character")
end

-- Setup initial character
if player.Character then
	SetupCharacter(player.Character)
end

-- Reconnect on respawn
player.CharacterAdded:Connect(SetupCharacter)

-- Function to create billboard UI
local function CreateBillboard(part)
	-- Remove old billboard if exists
	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	
	-- Create new billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CollectionUI"
	billboard.Size = UDim2.new(4, 0, 1.5, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	
	-- Background frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard
	
	-- Text label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.4, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = "[E] Ramasser"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = frame
	
	-- Progress bar background
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.8, 0, 0.2, 0)
	barBg.Position = UDim2.new(0.1, 0, 0.6, 0)
	barBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	barBg.BorderSizePixel = 2
	barBg.BorderColor3 = Color3.new(1, 1, 1)
	barBg.Parent = frame
	
	-- Progress bar fill
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.new(0.2, 1, 0.3)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	
	currentBillboard = billboard
	return billboard
end

-- Function to update progress bar
local function UpdateProgressBar(progress)
	if currentBillboard then
		local fill = currentBillboard:FindFirstChild("Frame"):FindFirstChild("Frame"):FindFirstChild("Fill")
		if fill then
			fill.Size = UDim2.new(progress, 0, 1, 0)
		end
	end
end

-- Function to find nearest body part
local function FindNearestBodyPart()
	local nearestDistance = DETECTION_RADIUS
	local nearest = nil
	
	-- Search in Workspace for body part models with IsBodyPart attribute
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBodyPart") == true then
			local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				local distance = (primaryPart.Position - rootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = obj
				end
			end
		end
	end
	
	return nearest
end

-- Handle E key input
local eKeyPressed = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		eKeyPressed = true
		
		if nearestPart and not isCollecting then
			isCollecting = true
			collectionProgress = 0
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		eKeyPressed = false
		
		-- Reset if not completed
		if isCollecting and collectionProgress < 1 then
			isCollecting = false
			collectionProgress = 0
			UpdateProgressBar(0)
		end
	end
end)

-- Main update loop
RunService.RenderStepped:Connect(function(deltaTime)
	-- Skip if no character
	if not character or not rootPart or not rootPart.Parent then
		return
	end
	
	-- Find nearest part
	local newNearest = FindNearestBodyPart()
	
	-- Update nearest part
	if newNearest ~= nearestPart then
		nearestPart = newNearest
		
		-- Create or remove billboard
		if nearestPart then
			local primaryPart = nearestPart.PrimaryPart or nearestPart:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				CreateBillboard(primaryPart)
			end
		else
			if currentBillboard then
				currentBillboard:Destroy()
				currentBillboard = nil
			end
			isCollecting = false
			collectionProgress = 0
		end
	end
	
	-- Update collection progress
	if isCollecting and eKeyPressed and nearestPart then
		collectionProgress = collectionProgress + (deltaTime / COLLECTION_TIME)
		
		if collectionProgress >= 1 then
			-- Collection complete!
			collectionProgress = 1
			UpdateProgressBar(1)
			
			-- Get the body part ID from the model
			local bodyPartId = nearestPart:GetAttribute("BodyPartId")
			
			-- Send to server with the body part ID
			if bodyPartId then
				collectEvent:FireServer(bodyPartId)
			else
				warn("❌ No BodyPartId attribute on model")
			end
			
			-- Reset
			isCollecting = false
			collectionProgress = 0
			
			-- Remove billboard
			if currentBillboard then
				currentBillboard:Destroy()
				currentBillboard = nil
			end
			nearestPart = nil
		else
			UpdateProgressBar(collectionProgress)
		end
	elseif not eKeyPressed and isCollecting then
		-- Reset if E released
		isCollecting = false
		collectionProgress = 0
		UpdateProgressBar(0)
	end
end)

print("✓ Collection UI initialized")

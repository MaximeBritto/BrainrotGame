-- Codex UI Client Script
-- Displays discovered Brainrots, currency, and badges

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CodexUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main Codex Frame (hidden by default)
local codexFrame = Instance.new("Frame")
codexFrame.Name = "CodexFrame"
codexFrame.Size = UDim2.new(0, 600, 0, 500)
codexFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
codexFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
codexFrame.BorderSizePixel = 2
codexFrame.BorderColor3 = Color3.fromRGB(255, 255, 0)
codexFrame.Visible = false
codexFrame.Parent = screenGui

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
title.Text = "🏆 BRAINROT CODEX 🏆"
title.TextColor3 = Color3.fromRGB(255, 255, 0)
title.TextSize = 28
title.Font = Enum.Font.GothamBold
title.Parent = codexFrame

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -45, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 24
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = codexFrame

-- Currency Display
local currencyLabel = Instance.new("TextLabel")
currencyLabel.Name = "CurrencyLabel"
currencyLabel.Size = UDim2.new(1, -20, 0, 30)
currencyLabel.Position = UDim2.new(0, 10, 0, 60)
currencyLabel.BackgroundTransparency = 1
currencyLabel.Text = "💰 Currency: 0"
currencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
currencyLabel.TextSize = 20
currencyLabel.Font = Enum.Font.GothamBold
currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
currencyLabel.Parent = codexFrame

-- Badges Display
local badgesLabel = Instance.new("TextLabel")
badgesLabel.Name = "BadgesLabel"
badgesLabel.Size = UDim2.new(1, -20, 0, 30)
badgesLabel.Position = UDim2.new(0, 10, 0, 95)
badgesLabel.BackgroundTransparency = 1
badgesLabel.Text = "🏅 Badges: None"
badgesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
badgesLabel.TextSize = 18
badgesLabel.Font = Enum.Font.Gotham
badgesLabel.TextXAlignment = Enum.TextXAlignment.Left
badgesLabel.Parent = codexFrame

-- Discoveries ScrollingFrame
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "DiscoveriesScroll"
scrollFrame.Size = UDim2.new(1, -20, 1, -145)
scrollFrame.Position = UDim2.new(0, 10, 0, 135)
scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
scrollFrame.BorderSizePixel = 1
scrollFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
scrollFrame.ScrollBarThickness = 8
scrollFrame.Parent = codexFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = scrollFrame

-- Toggle Button (always visible)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 120, 0, 40)
toggleButton.Position = UDim2.new(0, 10, 0, 80)
toggleButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
toggleButton.Text = "📖 CODEX"
toggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
toggleButton.TextSize = 18
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Parent = screenGui

-- Toggle functionality
local isOpen = false

local function ToggleCodex()
	isOpen = not isOpen
	codexFrame.Visible = isOpen
	
	if isOpen then
		-- Animate in
		codexFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
		codexFrame.Size = UDim2.new(0, 0, 0, 0)
		
		local tween = TweenService:Create(
			codexFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 600, 0, 500)}
		)
		tween:Play()
	end
end

toggleButton.MouseButton1Click:Connect(ToggleCodex)
closeButton.MouseButton1Click:Connect(ToggleCodex)

-- Keyboard shortcut (C key)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.C then
		ToggleCodex()
	end
end)

-- Update functions
local function UpdateCodex(codexData)
	-- Update currency
	currencyLabel.Text = "💰 Currency: " .. (codexData.currency or 0)
	
	-- Update badges
	if codexData.badges and #codexData.badges > 0 then
		badgesLabel.Text = "🏅 Badges: " .. table.concat(codexData.badges, ", ")
	else
		badgesLabel.Text = "🏅 Badges: None"
	end
	
	-- Clear existing discoveries
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Add discoveries
	if codexData.discoveries then
		for i, brainrotName in ipairs(codexData.discoveries) do
			local discoveryFrame = Instance.new("Frame")
			discoveryFrame.Size = UDim2.new(1, -10, 0, 40)
			discoveryFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			discoveryFrame.BorderSizePixel = 1
			discoveryFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
			discoveryFrame.Parent = scrollFrame
			
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -10, 1, 0)
			nameLabel.Position = UDim2.new(0, 5, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = brainrotName
			nameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
			nameLabel.TextSize = 16
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = discoveryFrame
		end
	end
	
	-- Update scroll canvas size
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end

-- Listen for updates from server
if game.ReplicatedStorage:FindFirstChild("RemoteEvents") then
	local remoteEvents = game.ReplicatedStorage.RemoteEvents
	
	if remoteEvents:FindFirstChild("UpdateCodex") then
		remoteEvents.UpdateCodex.OnClientEvent:Connect(UpdateCodex)
	end
end

print("✓ Codex UI initialized")

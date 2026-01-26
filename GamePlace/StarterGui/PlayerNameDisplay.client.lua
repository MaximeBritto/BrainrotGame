-- Player Name Display Client Script
-- Shows player names above their heads with collected fragments

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function CreateNameTag(character, displayName)
	-- Remove existing nametag
	local existingTag = character:FindFirstChild("NameTag")
	if existingTag then
		existingTag:Destroy()
	end
	
	local head = character:WaitForChild("Head", 5)
	if not head then return end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = character
	
	-- Background Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Parent = billboard
	
	-- Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 1, -10)
	nameLabel.Position = UDim2.new(0, 5, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Parent = frame
	
	return billboard
end

-- Update all player nametags
local function UpdateAllNameTags()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			CreateNameTag(player.Character, player.DisplayName or player.Name)
		end
	end
end

-- Listen for new players
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		wait(0.5) -- Wait for character to fully load
		CreateNameTag(character, player.DisplayName or player.Name)
	end)
end)

-- Update existing players
UpdateAllNameTags()

-- Listen for name updates from server
if ReplicatedStorage:FindFirstChild("RemoteEvents") then
	local remoteEvents = ReplicatedStorage.RemoteEvents
	
	if remoteEvents:FindFirstChild("UpdatePlayerName") then
		remoteEvents.UpdatePlayerName.OnClientEvent:Connect(function(playerId, newDisplayName)
			local player = Players:GetPlayerByUserId(playerId)
			if player and player.Character then
				CreateNameTag(player.Character, newDisplayName)
			end
		end)
	end
end

print("✓ Player name display initialized")

-- Player Controller Client Script
-- Handles player input and sends to server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Create RemoteEvents (these should be created on server first)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not RemoteEvents then
	warn("RemoteEvents folder not found in ReplicatedStorage!")
	return
end

local PunchEvent = RemoteEvents:WaitForChild("PunchEvent", 5)
local InteractEvent = RemoteEvents:WaitForChild("InteractEvent", 5)
-- CollectEvent is now handled by CollectionUI.client.lua

-- Input handling
local punchCooldown = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Punch (Left Click)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not punchCooldown then
		if PunchEvent then
			PunchEvent:FireServer()
			punchCooldown = true
			wait(1) -- Cooldown
			punchCooldown = false
		end
	end
	
	-- Interact (F key) - for stealing Brainrots
	if input.KeyCode == Enum.KeyCode.F then
		if InteractEvent then
			InteractEvent:FireServer()
		end
	end
end)

-- Send position updates to server periodically
RunService.Heartbeat:Connect(function()
	if rootPart then
		-- Position is automatically replicated by Roblox
		-- This is just a placeholder for custom networking if needed
	end
end)

print("✓ Player controller initialized for", player.Name)

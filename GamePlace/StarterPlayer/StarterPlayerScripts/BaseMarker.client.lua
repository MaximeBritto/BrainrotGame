-- Base Marker Client Script
-- Shows the player's head above their base for easy identification

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Wait for character
local character = player.Character or player.CharacterAdded:Wait()
local head = character:WaitForChild("Head")

-- Function to find player's base
local function FindPlayerBase()
	local workspace = game:GetService("Workspace")
	local playerBases = workspace:FindFirstChild("PlayerBases")
	
	if not playerBases then
		return nil
	end
	
	-- Find base with PlayerOwner attribute matching our UserId
	for _, base in pairs(playerBases:GetChildren()) do
		local ownerId = base:GetAttribute("PlayerOwner")
		
		if ownerId == player.UserId then
			return base
		end
	end
	
	return nil
end

-- Wait a bit for the base to be initialized
task.wait(2)

local playerBase = FindPlayerBase()

if playerBase then
	-- Find the center of the base
	local baseCenter = playerBase:FindFirstChild("SpawnLocation") or playerBase:FindFirstChildWhichIsA("BasePart")
	
	if baseCenter then
		-- Clone the player's head
		local headClone = head:Clone()
		headClone.Name = "PlayerBaseMarker"
		headClone.Anchored = true
		headClone.CanCollide = false
		headClone.Size = Vector3.new(4, 4, 4) -- Make it bigger
		
		-- Remove any accessories or face
		for _, child in ipairs(headClone:GetChildren()) do
			if not child:IsA("SpecialMesh") and not child:IsA("Decal") then
				child:Destroy()
			end
		end
		
		-- Position it above the base
		local basePosition = baseCenter.Position
		headClone.Position = basePosition + Vector3.new(0, 15, 0)
		
		-- Parent to workspace
		headClone.Parent = workspace
		
		-- Make it rotate slowly
		RunService.RenderStepped:Connect(function(deltaTime)
			if headClone and headClone.Parent then
				headClone.CFrame = headClone.CFrame * CFrame.Angles(0, math.rad(1), 0)
			end
		end)
		
		print(string.format("✓ Base marker created for %s", player.Name))
	end
else
	warn("Could not find player's base")
end

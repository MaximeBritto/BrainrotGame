-- Player Manager Module
-- Handles all player lifecycle management (join, spawn, leave)
-- Separates player management from game logic

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerManager = {}
PlayerManager.__index = PlayerManager

--[[
	Creates a new PlayerManager instance
	
	@param gameState table - The game state object
	@param arena Arena - The arena instance
	@param gameConfig table - Game configuration
	@param dataStructures table - DataStructures module
	@param codexSystem CodexSystem - Codex system instance
	@param pedestalSystem PedestalSystem - Pedestal system instance
	@return PlayerManager - New PlayerManager instance
]]
function PlayerManager.new(gameState, arena, gameConfig, dataStructures, codexSystem, pedestalSystem)
	local self = setmetatable({}, PlayerManager)
	
	self.gameState = gameState
	self.arena = arena
	self.gameConfig = gameConfig
	self.dataStructures = dataStructures
	self.codexSystem = codexSystem
	self.pedestalSystem = pedestalSystem
	
	return self
end

--[[
	Calculates the base location for a player based on player count
	
	@param playerCount number - Current number of players
	@return Vector3 - Base location for the player
]]
function PlayerManager:CalculatePlayerBaseLocation(playerCount)
	local dims = self.arena:GetDimensions()
	local angle = (playerCount * (360 / self.gameConfig.MAX_PLAYERS))
	local radians = math.rad(angle)
	
	local baseX, baseZ
	
	if dims.type == "CIRCULAR" then
		baseX = dims.center.X + (dims.radius * 0.7) * math.cos(radians)
		baseZ = dims.center.Z + (dims.radius * 0.7) * math.sin(radians)
	elseif dims.type == "RECTANGULAR" then
		local halfWidth = dims.width * 0.4
		local halfLength = dims.length * 0.4
		
		if angle < 90 then
			local t = angle / 90
			baseX = dims.center.X + (t * 2 - 1) * halfWidth
			baseZ = dims.center.Z + halfLength
		elseif angle < 180 then
			local t = (angle - 90) / 90
			baseX = dims.center.X + halfWidth
			baseZ = dims.center.Z + (1 - t * 2) * halfLength
		elseif angle < 270 then
			local t = (angle - 180) / 90
			baseX = dims.center.X + (1 - t * 2) * halfWidth
			baseZ = dims.center.Z - halfLength
		else
			local t = (angle - 270) / 90
			baseX = dims.center.X - halfWidth
			baseZ = dims.center.Z + (t * 2 - 1) * halfLength
		end
	else
		baseX = dims.center.X
		baseZ = dims.center.Z
	end
	
	local baseLocation = Vector3.new(baseX, dims.center.Y + 5, baseZ)
	
	return baseLocation
end

--[[
	Gets the current player count
	
	@return number - Number of players currently in game
]]
function PlayerManager:GetPlayerCount()
	local count = 0
	for _ in pairs(self.gameState.players) do
		count = count + 1
	end
	return count
end

--[[
	Handles character spawn/respawn
	
	@param player Player - The Roblox player
	@param playerData table - Player data from gameState
	@param baseLocation Vector3 - Base spawn location
	@param playerIndex number - Player index (1-based)
]]
function PlayerManager:OnCharacterAdded(player, playerData, baseLocation, playerIndex)
	local character = player.Character
	if not character then return end
	
	task.wait(0.1)
	
	local hrp = character:WaitForChild("HumanoidRootPart")
	
	local workspace = game:GetService("Workspace")
	local playerBases = workspace:FindFirstChild("PlayerBases")
	
	-- Try to spawn at physical base location
	if playerBases then
		local baseName = "Base" .. playerIndex
		local base = playerBases:FindFirstChild(baseName)
		
		if base then
			local spawnLocation = base:FindFirstChild("SpawnLocation")
			if spawnLocation and spawnLocation:IsA("BasePart") then
				hrp.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
			else
				hrp.CFrame = CFrame.new(baseLocation)
			end
		else
			hrp.CFrame = CFrame.new(baseLocation)
		end
	else
		hrp.CFrame = CFrame.new(baseLocation)
	end
	
	-- Update player data
	playerData.character = character
	
	-- Track player position
	RunService.Heartbeat:Connect(function()
		if character and character.Parent and hrp and hrp.Parent then
			playerData.position = hrp.Position
		end
	end)
end

--[[
	Adds a player to the game
	
	@param player Player - The Roblox player joining
]]
function PlayerManager:AddPlayer(player)
	local playerCount = self:GetPlayerCount()
	
	-- Check if server is full
	if playerCount >= self.gameConfig.MAX_PLAYERS then
		player:Kick("Server full")
		return
	end
	
	-- Calculate base location
	local baseLocation = self:CalculatePlayerBaseLocation(playerCount)
	
	-- Create player data
	local playerData = self.dataStructures.CreatePlayer(player.UserId, player.Name, baseLocation)
	self.gameState.players[player.UserId] = playerData
	
	-- Initialize codex profile
	self.codexSystem:GetOrCreateProfile(player.UserId, player.Name)
	
	-- Initialize player base with pedestals
	self.pedestalSystem:InitializePlayerBase(player.UserId, playerCount + 1)
	
	print(string.format("✅ Player joined: %s (Base %d)", player.Name, playerCount + 1))
	
	-- Setup character spawn handler
	local function onCharacterAdded(character)
		self:OnCharacterAdded(player, playerData, baseLocation, playerCount + 1)
	end
	
	player.CharacterAdded:Connect(onCharacterAdded)
	
	-- Handle existing character
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

--[[
	Removes a player from the game
	
	@param player Player - The Roblox player leaving
]]
function PlayerManager:RemovePlayer(player)
	-- Clear player base
	self.pedestalSystem:ClearPlayerBase(player.UserId)
	
	-- Remove from game state
	self.gameState.players[player.UserId] = nil
	
	print(string.format("❌ Player left: %s", player.Name))
end

--[[
	Initializes player management (connects to Roblox events)
]]
function PlayerManager:Initialize()
	-- Connect to player events
	Players.PlayerAdded:Connect(function(player)
		self:AddPlayer(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)
	
	-- Add existing players (for testing in Studio)
	for _, player in pairs(Players:GetPlayers()) do
		self:AddPlayer(player)
	end
	
	print("✓ Player Manager initialized")
end

return PlayerManager

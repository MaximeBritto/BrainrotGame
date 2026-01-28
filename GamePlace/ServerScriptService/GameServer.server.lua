-- Game Server Main Script
-- Orchestrates all game systems and manages game loop

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load all systems
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)
local Arena = require(script.Parent.Arena)
local CannonSystem = require(script.Parent.CannonSystem)
local SlotInventorySystem = require(script.Parent.SlotInventorySystem)
local CentralLaserSystem = require(script.Parent.CentralLaserSystem)
local CodexSystem = require(script.Parent.CodexSystem)
local VisualInventorySystem = require(script.Parent.VisualInventorySystem)
local PedestalSystem = require(script.Parent.PedestalSystem)
local GameServerHelpers = require(script.Parent.GameServerHelpers)
local BrainrotAssembler = require(script.Parent.BrainrotAssembler)
local GameEvents = require(script.Parent.GameEvents)
local PlayerManager = require(script.Parent.PlayerManager)

-- Initialize game state
local gameState = DataStructures.CreateGameState()

-- Wait for ArenaVisuals to initialize the arena
task.wait(0.2)

-- Get arena from _G (set by ArenaVisuals.server.lua)
local arena = _G.Arena or Arena.createDefault()
if not _G.Arena then
	warn("⚠️ Arena not found in _G, using default arena")
end
local cannonSystem = CannonSystem.new(arena)
local slotInventorySystem = SlotInventorySystem.new()
local centralLaserSystem = CentralLaserSystem.new(GameConfig.ARENA_CENTER)
local codexSystem = CodexSystem.new()
local visualInventorySystem = VisualInventorySystem.new()
local pedestalSystem = PedestalSystem.new()
local playerManager = PlayerManager.new(gameState, arena, GameConfig, DataStructures, codexSystem, pedestalSystem)

gameState.cannons = cannonSystem:GetCannons()
gameState.centralLaser = centralLaserSystem

print("🎮 Brainrot Assembly Chaos - Server Initialized")

local dims = arena:GetDimensions()
if dims.type == "CIRCULAR" then
	print(string.format("📍 Arena: CIRCULAR (Radius: %.1f)", dims.radius))
elseif dims.type == "RECTANGULAR" then
	print(string.format("📍 Arena: RECTANGULAR (%.1f x %.1f)", dims.width, dims.length))
end

print(string.format("🔫 Cannons: %d", #gameState.cannons))

task.wait(0.1)

-- Setup CollectEvent handler
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local collectEvent = remoteEvents:WaitForChild("CollectEvent")

collectEvent.OnServerEvent:Connect(function(player, bodyPartId)
	local bodyPart = gameState.bodyParts[bodyPartId]
	if not bodyPart then 
		warn("❌ Body part not found:", bodyPartId)
		return 
	end
	
	local playerData = gameState.players[player.UserId]
	if not playerData then 
		warn("❌ Player data not found:", player.UserId)
		return 
	end
	
	local physicalModel = bodyPart.physicalObject
	if not physicalModel or not physicalModel.Parent then 
		warn("❌ Physical model not found or destroyed")
		return 
	end
	
	-- Call the collection callback directly
	local callback = GameEvents:GetCollectionCallback()
	if callback then
		callback(player.UserId, bodyPartId, physicalModel)
	else
		warn("❌ No collection callback registered")
	end
end)

-- Setup PlaceBrainrotEvent handler
local placeBrainrotEvent = remoteEvents:WaitForChild("PlaceBrainrotEvent")

placeBrainrotEvent.OnServerEvent:Connect(function(player, slotIndex)
	local playerData = gameState.players[player.UserId]
	if not playerData then return end
	
	local assembled, brainrotName = slotInventorySystem:IsSlotAssembled(player.UserId, slotIndex)
	if not assembled then return end
	
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local currentPosition = humanoidRootPart.Position
	
	local pedestal, _distance = pedestalSystem:FindNearestEmptyPedestal(player.UserId, currentPosition, 100)
	if not pedestal then
		warn("⚠️ No empty pedestal nearby")
		return
	end
	
	-- Get the slot parts and detach from player
	local slotParts = slotInventorySystem:GetSlotParts(player.UserId, slotIndex)
	local detachedModels = visualInventorySystem:DetachSlotParts(playerData, slotIndex)
	
	-- Assemble the Brainrot
	local pedestalTop = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + 5, 0)
	local brainrotModel = BrainrotAssembler.AssembleAndPlace(slotParts, detachedModels, pedestalTop, brainrotName)
	
	-- Place on pedestal
	pedestalSystem:PlaceBrainrotOnPedestal(pedestal, player.UserId, brainrotName, brainrotModel)
	
	-- Record discovery
	local isNewDiscovery = codexSystem:RecordDiscovery(player.UserId, brainrotName)
	print(string.format("🎉 %s placed: %s%s", player.Name, brainrotName, isNewDiscovery and " (NEW!)" or ""))
	
	-- Update score
	playerData.score = playerData.score + 1
	
	-- Update Codex UI
	local updateCodex = remoteEvents:FindFirstChild("UpdateCodex")
	if updateCodex then
		local profile = codexSystem:GetOrCreateProfile(player.UserId, player.Name)
		updateCodex:FireClient(player, {
			currency = profile.currency,
			badges = profile.badges,
			discoveries = profile.discoveredBrainrots
		})
	end
	
	-- Clear slot and update UI
	slotInventorySystem:ClearSlot(player.UserId, slotIndex)
	
	local updateScore = remoteEvents:FindFirstChild("UpdateScore")
	if updateScore then
		updateScore:FireClient(player, playerData.score)
	end
	
	GameServerHelpers.UpdatePlayerInventoryUI(player, player.UserId, slotInventorySystem)
end)

-- Setup collection callback through GameEvents
local collectionCallback = function(userId, bodyPartId, physicalModel)
	print(string.format("🔍 Collection callback called: userId=%s, bodyPartId=%s", tostring(userId), tostring(bodyPartId)))
	
	local player = gameState.players[userId]
	local bodyPart = gameState.bodyParts[bodyPartId]
	
	if not player then
		warn("❌ Player not found in gameState:", userId)
		return
	end
	
	if not bodyPart then
		warn("❌ Body part not found in gameState:", bodyPartId)
		return
	end
	
	print(string.format("✓ Found player and body part, adding to inventory..."))
	
	bodyPart.physicalObject = physicalModel
	
	local slotIndex, _partType = slotInventorySystem:AddBodyPart(userId, bodyPart)
	
	if slotIndex then
		print(string.format("✓ Added to slot %d", slotIndex))
		gameState.bodyParts[bodyPartId] = nil
		
		local slotParts = slotInventorySystem:GetSlotParts(userId, slotIndex)
		visualInventorySystem:AttachPartToPlayer(player, bodyPart, slotIndex, slotParts)
		
		-- Find Roblox player and update UI
		local robloxPlayer = GameServerHelpers.FindPlayerByUserId(userId)
		if robloxPlayer then
			GameServerHelpers.UpdatePlayerInventoryUI(robloxPlayer, userId, slotInventorySystem)
		end
		
		-- Check if this slot is now complete
		local isComplete, headPart, bodyPartData, legsPart = slotInventorySystem:IsSlotComplete(userId, slotIndex)
		if isComplete then
			local brainrotName = headPart.nameFragment .. " " .. bodyPartData.nameFragment .. " " .. legsPart.nameFragment
			
			slotInventorySystem:MarkSlotAssembled(userId, slotIndex, brainrotName)
			visualInventorySystem:ShowSlotName(player, slotIndex, brainrotName, slotParts)
			
			print(string.format("✅ %s assembled: %s", player.username, brainrotName))
			
			-- Update UI to show assembled status
			if robloxPlayer then
				GameServerHelpers.UpdatePlayerInventoryUI(robloxPlayer, userId, slotInventorySystem)
			end
		end
	else
		warn("❌ Failed to add body part to inventory")
	end
end

-- Register callback with GameEvents
GameEvents:SetCollectionCallback(collectionCallback)

-- Setup laser hit callback
centralLaserSystem:SetPlayerHitCallback(function(userId)
	local player = gameState.players[userId]
	if not player or not player.character then return end
	
	local humanoid = player.character:FindFirstChild("Humanoid")
	local hrp = player.character:FindFirstChild("HumanoidRootPart")
	
	local allParts = slotInventorySystem:GetAllParts(userId)
	
	-- Hide all slot names
	for slotIndex = 1, 3 do
		visualInventorySystem:HideSlotName(player, slotIndex)
	end
	
	-- Detach all parts and clear inventory
	local detachedModels = visualInventorySystem:DetachAllParts(player)
	slotInventorySystem:ClearAllSlots(userId)
	
	-- Drop parts back into the world
	if #allParts > 0 then
		local dropPosition = hrp and hrp.Position or player.position
		
		for i, partInfo in ipairs(allParts) do
			local bodyPart = partInfo.bodyPart
			gameState.bodyParts[bodyPart.id] = bodyPart
			
			local model = detachedModels[i]
			if model and model.Parent then
				-- Remove slot name UI
				for _, child in ipairs(model:GetDescendants()) do
					if child:IsA("BillboardGui") and child.Name:match("SlotName") then
						child:Destroy()
					end
				end
				
				-- Position and setup for collection
				local offset = Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))
				local mainPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				
				if mainPart then
					mainPart.CFrame = CFrame.new(dropPosition + offset)
					mainPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					mainPart.CanCollide = true
					mainPart.Anchored = false
					
					model:SetAttribute("IsBodyPart", true)
					model:SetAttribute("BodyPartId", bodyPart.id)
					
					bodyPart.physicalObject = model
					
					-- Register with GameEvents instead of _G
					GameEvents:FireBodyPartRegistered(model, bodyPart.id)
				end
			end
		end
		
		-- Update UI
		local robloxPlayer = GameServerHelpers.FindPlayerByUserId(userId)
		if robloxPlayer then
			local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
			if remoteEvents then
				local updateInventory = remoteEvents:FindFirstChild("UpdateInventory")
				if updateInventory then
					updateInventory:FireClient(robloxPlayer, {})
				end
			end
		end
	end
	
	-- Kill player
	if humanoid then
		humanoid.Health = 0
	end
end)

-- Initialize player management
playerManager:Initialize()

-- Start match
local function StartMatch()
	gameState.isMatchActive = true
	gameState.matchStartTime = tick()
	print("🚀 Match started!")
end

-- Main game loop
local lastUpdateTime = tick()

game:GetService("RunService").Heartbeat:Connect(function()
	local currentTime = tick()
	local deltaTime = currentTime - lastUpdateTime
	lastUpdateTime = currentTime
	
	if not gameState.isMatchActive then
		return
	end
	
	local matchElapsedTime = currentTime - gameState.matchStartTime
	
	local spawnedPart, _cannon = cannonSystem:Update(deltaTime, currentTime)
	if spawnedPart then
		gameState.bodyParts[spawnedPart.id] = spawnedPart
	end
	
	centralLaserSystem:Update(deltaTime, matchElapsedTime)
	
	local hitPlayers = centralLaserSystem:CheckCollisions(gameState.players)
	for _, player in ipairs(hitPlayers) do
		centralLaserSystem:KnockbackPlayer(player, centralLaserSystem.currentAngle)
		local droppedParts = centralLaserSystem:DropInventory(player)
		
		for _, part in ipairs(droppedParts) do
			gameState.bodyParts[part.id] = part
		end
	end
	
	for id, brainrot in pairs(gameState.brainrots) do
		-- Lock status update removed - handled by PedestalSystem
	end
end)

-- Start the match after a delay
task.wait(2)
StartMatch()

-- Game Server Main Script
-- Orchestrates all game systems and manages game loop
-- Requirements: All requirements

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load all systems
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)
local Arena = require(script.Parent.Arena)
local CannonSystem = require(script.Parent.CannonSystem)
local SlotInventorySystem = require(script.Parent.SlotInventorySystem)
local AssemblySystem = require(script.Parent.AssemblySystem)
local CentralLaserSystem = require(script.Parent.CentralLaserSystem)
local CombatSystem = require(script.Parent.CombatSystem)
local BaseProtectionSystem = require(script.Parent.BaseProtectionSystem)
local TheftSystem = require(script.Parent.TheftSystem)
local CodexSystem = require(script.Parent.CodexSystem)
local VisualInventorySystem = require(script.Parent.VisualInventorySystem)
local PedestalSystem = require(script.Parent.PedestalSystem)

-- Initialize game state
local gameState = DataStructures.CreateGameState()
local arena = Arena.createDefault()
local cannonSystem = CannonSystem.new(arena)
local slotInventorySystem = SlotInventorySystem.new()
local assemblySystem = AssemblySystem.new()
local centralLaserSystem = CentralLaserSystem.new(GameConfig.ARENA_CENTER)
local combatSystem = CombatSystem.new()
local baseProtectionSystem = BaseProtectionSystem.new()
local theftSystem = TheftSystem.new()
local codexSystem = CodexSystem.new()
local visualInventorySystem = VisualInventorySystem.new()
local pedestalSystem = PedestalSystem.new()

gameState.cannons = cannonSystem:GetCannons()
gameState.centralLaser = centralLaserSystem

print("🎮 Brainrot Assembly Chaos - Server Initialized")
print(string.format("📍 Arena: %s (Radius: %d)", arena:GetDimensions().type, arena:GetDimensions().radius))
print(string.format("🔫 Cannons: %d", #gameState.cannons))

-- Wait for PhysicsManager to initialize
wait(0.1)

-- Setup CollectEvent handler
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local collectEvent = remoteEvents:WaitForChild("CollectEvent")

collectEvent.OnServerEvent:Connect(function(player, bodyPartId)
	print(string.format("🔍 Player %s wants to collect: %s", player.Name, tostring(bodyPartId)))
	
	-- Verify the body part exists
	local bodyPart = gameState.bodyParts[bodyPartId]
	if not bodyPart then
		print(string.format("❌ BodyPart not found: %s", tostring(bodyPartId)))
		return
	end
	
	-- Verify player data exists
	local playerData = gameState.players[player.UserId]
	if not playerData then
		print(string.format("❌ Player data not found: %s", player.Name))
		return
	end
	
	-- Get the physical model
	local physicalModel = bodyPart.physicalObject
	if not physicalModel or not physicalModel.Parent then
		print(string.format("❌ Physical model not found or destroyed"))
		return
	end
	
	-- Call the collection callback directly
	if _G.CollectionCallback then
		local callback = _G.CollectionCallback
		if callback then
			callback(player.UserId, bodyPartId, physicalModel)
		end
	end
end)

-- Setup PlaceBrainrotEvent handler
local placeBrainrotEvent = remoteEvents:WaitForChild("PlaceBrainrotEvent")

placeBrainrotEvent.OnServerEvent:Connect(function(player, slotIndex)
	print(string.format("🏆 Player %s wants to place Brainrot from Slot %d", player.Name, slotIndex))
	
	local playerData = gameState.players[player.UserId]
	if not playerData then
		print(string.format("❌ Player data not found"))
		return
	end
	
	-- Check if slot is assembled
	local assembled, brainrotName = slotInventorySystem:IsSlotAssembled(player.UserId, slotIndex)
	if not assembled then
		print(string.format("❌ Slot %d is not assembled", slotIndex))
		return
	end
	
	-- Find nearest empty pedestal
	local pedestal, distance = pedestalSystem:FindNearestEmptyPedestal(player.UserId, playerData.position, 10)
	if not pedestal then
		print(string.format("❌ No empty pedestal nearby"))
		return
	end
	
	print(string.format("✓ Found empty pedestal %.1f studs away", distance))
	
	-- Get the slot parts before clearing
	local slotParts = slotInventorySystem:GetSlotParts(player.UserId, slotIndex)
	
	-- Detach the parts from the player (pass playerData, not player)
	local detachedModels = visualInventorySystem:DetachSlotParts(playerData, slotIndex)
	
	-- Combine all 3 models into one Brainrot model
	local brainrotModel = Instance.new("Model")
	brainrotModel.Name = brainrotName
	
	-- Position for assembling parts vertically
	local pedestalTop = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	local currentY = pedestalTop.Y
	
	-- Add all parts to the combined model
	for i, model in ipairs(detachedModels) do
		if model and model.Parent then
			-- Get the main part
			local mainPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			
			if mainPart then
				-- Anchor and position the part
				mainPart.Anchored = true
				mainPart.CanCollide = false
				
				-- Stack parts vertically: HEAD on top, BODY in middle, LEGS at bottom
				-- Determine part type from slotParts
				local partType = slotParts[i] and slotParts[i].type or "UNKNOWN"
				local yOffset = 0
				
				if partType == "HEAD" then
					yOffset = 4 -- Top
				elseif partType == "BODY" then
					yOffset = 2 -- Middle
				elseif partType == "LEGS" then
					yOffset = 0 -- Bottom
				end
				
				mainPart.CFrame = CFrame.new(pedestalTop + Vector3.new(0, yOffset, 0))
				
				-- Move all children to the combined model
				for _, child in ipairs(model:GetChildren()) do
					child.Parent = brainrotModel
				end
				
				-- Destroy the old model container
				model:Destroy()
			end
		end
	end
	
	-- Set the combined model's parent
	brainrotModel.Parent = workspace
	
	-- Place on pedestal
	pedestalSystem:PlaceBrainrotOnPedestal(pedestal, player.UserId, brainrotName, brainrotModel)
	
	-- NOW validate in Codex and give score
	local isNewDiscovery = codexSystem:RecordDiscovery(player.UserId, brainrotName)
	
	print(string.format("🎉 %s placed on pedestal: %s%s", 
		player.Name, 
		brainrotName,
		isNewDiscovery and " (NEW!)" or ""
	))
	
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
	
	-- Clear the slot
	slotInventorySystem:ClearSlot(player.UserId, slotIndex)
	
	-- Update UI
	local updateScore = remoteEvents:FindFirstChild("UpdateScore")
	local updateInventory = remoteEvents:FindFirstChild("UpdateInventory")
	
	if updateScore then
		updateScore:FireClient(player, playerData.score)
	end
	
	if updateInventory then
		local allParts = slotInventorySystem:GetAllParts(player.UserId)
		local inventoryData = {}
		
		for _, partInfo in ipairs(allParts) do
			local assembled, assembledName = slotInventorySystem:IsSlotAssembled(player.UserId, partInfo.slotIndex)
			
			table.insert(inventoryData, {
				slotIndex = partInfo.slotIndex,
				type = partInfo.partType,
				nameFragment = partInfo.bodyPart.nameFragment,
				assembled = assembled,
				brainrotName = assembledName
			})
		end
		
		updateInventory:FireClient(player, inventoryData)
	end
end)

-- Setup collection callback for PhysicsManager
print(string.format("🔍 Checking _G.SetCollectionCallback: %s", tostring(_G.SetCollectionCallback ~= nil)))
if _G.SetCollectionCallback then
	local collectionCallback = function(userId, bodyPartId, physicalModel)
		print(string.format("🔍 Collection callback: userId=%s, bodyPartId=%s", tostring(userId), tostring(bodyPartId)))
		
		local player = gameState.players[userId]
		local bodyPart = gameState.bodyParts[bodyPartId]
		
		print(string.format("🔍 Player found: %s, BodyPart found: %s", tostring(player ~= nil), tostring(bodyPart ~= nil)))
		
		if player and bodyPart then
			-- Store physical model reference
			bodyPart.physicalObject = physicalModel
			
			-- Add to slot inventory system
			local slotIndex, partType = slotInventorySystem:AddBodyPart(userId, bodyPart)
			
			if slotIndex then
				-- Remove from game state
				gameState.bodyParts[bodyPartId] = nil
				
				-- Get all parts in this slot for visual attachment
				local slotParts = slotInventorySystem:GetSlotParts(userId, slotIndex)
				
				print(string.format("📦 Added to Slot %d: %d parts total", slotIndex, #slotParts))
				
				-- Attach part visually to player
				visualInventorySystem:AttachPartToPlayer(player, bodyPart, slotIndex, slotParts)
				
				-- Find Roblox player
				local robloxPlayer = nil
				for _, p in pairs(Players:GetPlayers()) do
					if p.UserId == userId then
						robloxPlayer = p
						break
					end
				end
				
				print(string.format("🔍 Roblox player found: %s", tostring(robloxPlayer ~= nil)))
				
				if robloxPlayer then
					-- Update UI with all slots
					local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
					print(string.format("🔍 RemoteEvents found: %s", tostring(remoteEvents ~= nil)))
					
					if remoteEvents then
						local updateInventory = remoteEvents:FindFirstChild("UpdateInventory")
						print(string.format("🔍 UpdateInventory found: %s", tostring(updateInventory ~= nil)))
						
						if updateInventory then
							-- Get all parts across all slots
							local allParts = slotInventorySystem:GetAllParts(userId)
							local inventoryData = {}
							
							for _, partInfo in ipairs(allParts) do
								table.insert(inventoryData, {
									slotIndex = partInfo.slotIndex,
									type = partInfo.partType,
									nameFragment = partInfo.bodyPart.nameFragment
								})
							end
							
							print(string.format("📤 Sending inventory update: %d items", #inventoryData))
							for i, item in ipairs(inventoryData) do
								print(string.format("  Item %d: Slot %d, %s, %s", i, item.slotIndex, item.type, item.nameFragment))
							end
							
							updateInventory:FireClient(robloxPlayer, inventoryData)
							print(string.format("📤 Sent inventory update to %s: %d items", player.username, #inventoryData))
						else
							warn("❌ UpdateInventory RemoteEvent not found!")
						end
					else
						warn("❌ RemoteEvents folder not found!")
					end
				end
				
				-- Check if this slot is now complete
				local isComplete, headPart, bodyPartData, legsPart = slotInventorySystem:IsSlotComplete(userId, slotIndex)
				if isComplete then
					print(string.format("✅ Slot %d complete! Assembling Brainrot...", slotIndex))
					
					-- Create the Brainrot name but DON'T validate it yet
					local brainrotName = headPart.nameFragment .. " " .. bodyPartData.nameFragment .. " " .. legsPart.nameFragment
					
					-- Mark slot as assembled
					slotInventorySystem:MarkSlotAssembled(userId, slotIndex, brainrotName)
					
					-- Show the Brainrot name above the slot (pass slotParts so it attaches to the right part)
					visualInventorySystem:ShowSlotName(player, slotIndex, brainrotName, slotParts)
					
					print(string.format("🎨 %s assembled Brainrot in Slot %d: %s (not validated yet)", 
						player.username, slotIndex, brainrotName))
					
					-- Update UI to show assembled status
					if robloxPlayer and remoteEvents then
						local updateInventory = remoteEvents:FindFirstChild("UpdateInventory")
						
						if updateInventory then
							local allParts = slotInventorySystem:GetAllParts(userId)
							local inventoryData = {}
							
							for _, partInfo in ipairs(allParts) do
								-- Check if this slot is assembled
								local assembled, assembledName = slotInventorySystem:IsSlotAssembled(userId, partInfo.slotIndex)
								
								table.insert(inventoryData, {
									slotIndex = partInfo.slotIndex,
									type = partInfo.partType,
									nameFragment = partInfo.bodyPart.nameFragment,
									assembled = assembled,
									brainrotName = assembledName
								})
							end
							
							updateInventory:FireClient(robloxPlayer, inventoryData)
						end
					end
				end
			else
				print(string.format("❌ No space in inventory (all 3 slots full)"))
			end
		else
			if not player then
				print(string.format("❌ Player not found for userId: %s", tostring(userId)))
			end
			if not bodyPart then
				print(string.format("❌ BodyPart not found for id: %s", tostring(bodyPartId)))
				print(string.format("🔍 Available bodyParts: %d", #gameState.bodyParts))
			end
		end
	end
	
	-- Store callback globally and register it
	_G.CollectionCallback = collectionCallback
	_G.SetCollectionCallback(collectionCallback)
end

-- Setup laser hit callback
centralLaserSystem:SetPlayerHitCallback(function(userId)
	local player = gameState.players[userId]
	if player and player.character then
		print(string.format("⚡ %s hit by laser!", player.username))
		
		local humanoid = player.character:FindFirstChild("Humanoid")
		local hrp = player.character:FindFirstChild("HumanoidRootPart")
		
		-- Get all parts from all slots BEFORE detaching
		local allParts = slotInventorySystem:GetAllParts(userId)
		
		-- Detach all parts and get the models
		local detachedModels = visualInventorySystem:DetachAllParts(player)
		
		-- Clear all slots
		slotInventorySystem:ClearAllSlots(userId)
		
		if #allParts > 0 then
			print(string.format("📤 Dropping %d parts at player position", #allParts))
			
			-- Spawn physical parts at drop location
			local dropPosition = hrp and hrp.Position or player.position
			
			for i, partInfo in ipairs(allParts) do
				local bodyPart = partInfo.bodyPart
				
				-- Re-add to game state
				gameState.bodyParts[bodyPart.id] = bodyPart
				
				-- Get the detached model
				local model = detachedModels[i]
				if model and model.Parent then
					-- Position it at drop location with slight offset
					local offset = Vector3.new(
						math.random(-3, 3),
						2,
						math.random(-3, 3)
					)
					
					local mainPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
					if mainPart then
						mainPart.CFrame = CFrame.new(dropPosition + offset)
						mainPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						mainPart.CanCollide = true
						
						-- CRITICAL: Re-add IsBodyPart attribute so it can be collected again
						model:SetAttribute("IsBodyPart", true)
						model:SetAttribute("BodyPartId", bodyPart.id)
						
						-- Re-register with physics manager
						if _G.RegisterBodyPart then
							_G.RegisterBodyPart(model, bodyPart.id)
						end
						
						print(string.format("✓ Dropped %s (ID: %s) at drop location", bodyPart.type, bodyPart.id))
					end
				end
			end
			
			-- Update UI
			local robloxPlayer = nil
			for _, p in pairs(Players:GetPlayers()) do
				if p.UserId == userId then
					robloxPlayer = p
					break
				end
			end
			
			if robloxPlayer then
				local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
				if remoteEvents then
					local updateInventory = remoteEvents:FindFirstChild("UpdateInventory")
					if updateInventory then
						updateInventory:FireClient(robloxPlayer, {}) -- Clear inventory
					end
				end
			end
		end
		
		-- KILL THE PLAYER (respawn)
		if humanoid then
			humanoid.Health = 0
			print(string.format("💀 %s killed by laser!", player.username))
		end
	end
end)

-- Player management
local function AssignPlayerBase(player)
	-- Assign base location around arena perimeter
	local playerCount = 0
	for _ in pairs(gameState.players) do
		playerCount = playerCount + 1
	end
	
	local angle = (playerCount * (360 / GameConfig.MAX_PLAYERS))
	local radians = math.rad(angle)
	local dims = arena:GetDimensions()
	
	local baseX = dims.center.X + (dims.radius * 0.7) * math.cos(radians)
	local baseZ = dims.center.Z + (dims.radius * 0.7) * math.sin(radians)
	local baseLocation = Vector3.new(baseX, dims.center.Y + 5, baseZ)
	
	return baseLocation
end

local function AddPlayer(player)
	-- Check player capacity
	local playerCount = 0
	for _ in pairs(gameState.players) do
		playerCount = playerCount + 1
	end
	
	if playerCount >= GameConfig.MAX_PLAYERS then
		player:Kick("Server full")
		return
	end
	
	-- Assign base location
	local baseLocation = AssignPlayerBase(player)
	
	-- Create player data
	local playerData = DataStructures.CreatePlayer(player.UserId, player.Name, baseLocation)
	gameState.players[player.UserId] = playerData
	
	-- Create player profile in codex
	codexSystem:GetOrCreateProfile(player.UserId, player.Name)
	
	-- Initialize pedestals for this player
	pedestalSystem:InitializePlayerBase(player.UserId, playerCount + 1)
	
	print(string.format("✅ Player joined: %s (Total: %d)", player.Name, playerCount + 1))
	
	-- Handle character spawning
	local function onCharacterAdded(character)
		local hrp = character:WaitForChild("HumanoidRootPart")
		hrp.CFrame = CFrame.new(baseLocation)
		playerData.character = character
		
		-- Update player position continuously
		game:GetService("RunService").Heartbeat:Connect(function()
			if character and character.Parent and hrp and hrp.Parent then
				playerData.position = hrp.Position
			end
		end)
	end
	
	-- Connect to future character spawns
	player.CharacterAdded:Connect(onCharacterAdded)
	
	-- Handle current character if it exists
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(AddPlayer)

-- Add players who are already in the game
for _, player in pairs(Players:GetPlayers()) do
	AddPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Remove player from game state
	gameState.players[player.UserId] = nil
	
	print(string.format("❌ Player left: %s", player.Name))
end)

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
	
	-- Update cannon system (spawn body parts)
	local spawnedPart, cannon = cannonSystem:Update(deltaTime, currentTime)
	if spawnedPart then
		gameState.bodyParts[spawnedPart.id] = spawnedPart
		-- Broadcast spawn event to clients
	end
	
	-- Update central laser
	centralLaserSystem:Update(deltaTime, matchElapsedTime)
	
	-- Check laser collisions
	local hitPlayers = centralLaserSystem:CheckCollisions(gameState.players)
	for _, player in ipairs(hitPlayers) do
		centralLaserSystem:KnockbackPlayer(player, centralLaserSystem.currentAngle)
		local droppedParts = centralLaserSystem:DropInventory(player)
		
		-- Add dropped parts back to game
		for _, part in ipairs(droppedParts) do
			gameState.bodyParts[part.id] = part
		end
	end
	
	-- Update barriers
	baseProtectionSystem:UpdateBarriers(gameState.players, currentTime)
	
	-- Update lock timers
	for id, brainrot in pairs(gameState.brainrots) do
		assemblySystem:UpdateLockStatus(brainrot, currentTime)
	end
	
	-- Check collections for each player
	for id, player in pairs(gameState.players) do
		-- Constrain player to arena bounds
		if not arena:IsInBounds(player.position) then
			player.position = arena:ConstrainToBounds(player.position)
		end
		
		-- Check barrier collisions
		baseProtectionSystem:CheckBarrierCollision(player, gameState.players)
		
		-- Note: Body part collection is now handled by E-key press via CollectEvent
		-- No automatic collection in game loop
	end
	
	-- Check match end condition
	if matchElapsedTime >= GameConfig.MATCH_DURATION then
		gameState.isMatchActive = false
		print("⏱️ Match ended!")
		
		-- Display final scores
		for id, player in pairs(gameState.players) do
			print(string.format("  %s: %d Brainrots", player.username, player.score))
		end
	end
end)

-- Start match after countdown
wait(GameConfig.MATCH_START_COUNTDOWN)
StartMatch()

return gameState

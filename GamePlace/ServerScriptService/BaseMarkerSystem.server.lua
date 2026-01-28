-- Base Marker System (Server)
-- Shows each player's head above their base for easy identification
-- Runs on server so all players can see all markers

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Track markers for cleanup
local playerMarkers = {} -- { [userId] = {head = Part, connection = RBXScriptConnection} }

-- Function to find player's base
local function FindPlayerBase(userId)
	local workspace = game:GetService("Workspace")
	local playerBases = workspace:FindFirstChild("PlayerBases")
	
	if not playerBases then
		return nil
	end
	
	-- Find base with PlayerOwner attribute matching userId
	for _, base in pairs(playerBases:GetChildren()) do
		local ownerId = base:GetAttribute("PlayerOwner")
		
		if ownerId == userId then
			return base
		end
	end
	
	return nil
end

-- Function to create base marker for a player
local function CreateBaseMarker(player)
	-- Wait a bit for character and base to be ready
	task.wait(2)
	
	local character = player.Character
	if not character then
		warn(string.format("❌ No character for %s", player.Name))
		return
	end
	
	local head = character:FindFirstChild("Head")
	if not head then
		warn(string.format("❌ No head for %s", player.Name))
		return
	end
	
	local playerBase = FindPlayerBase(player.UserId)
	if not playerBase then
		warn(string.format("❌ Could not find base for %s", player.Name))
		return
	end
	
	-- Find the center of the base
	local baseCenter = playerBase:FindFirstChild("SpawnLocation") or playerBase:FindFirstChildWhichIsA("BasePart")
	
	if not baseCenter then
		warn(string.format("❌ No base center for %s", player.Name))
		return
	end
	
	-- Create a Model to hold everything
	local markerModel = Instance.new("Model")
	markerModel.Name = "PlayerBaseMarker_" .. player.Name
	
	-- Clone the REAL head from the character
	local headClone = head:Clone()
	headClone.Name = "Head"
	headClone.Anchored = true
	headClone.CanCollide = false
	headClone.Size = head.Size * 2
	
	-- Scale up the mesh if it exists
	local mesh = headClone:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.Scale = mesh.Scale * 2
	end
	
	-- Remove any motor6d or welds from the cloned head
	for _, child in ipairs(headClone:GetChildren()) do
		if child:IsA("Motor6D") or child:IsA("Weld") or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	
	-- Copy the face
	local originalFace = headClone:FindFirstChildOfClass("Decal")
	if not originalFace or originalFace.Texture == "" then
		-- Try to get the player's face from their character appearance
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local success, humanoidDescription = pcall(function()
				return humanoid:GetAppliedDescription()
			end)
			
			if success and humanoidDescription and humanoidDescription.Face ~= 0 then
				local newFace = Instance.new("Decal")
				newFace.Name = "face"
				newFace.Face = Enum.NormalId.Front
				newFace.Texture = "rbxassetid://" .. humanoidDescription.Face
				newFace.Parent = headClone
			end
		end
	end
	
	-- Scale up attachments for accessories (they're already in the cloned head)
	for _, attachment in ipairs(headClone:GetChildren()) do
		if attachment:IsA("Attachment") then
			attachment.Position = attachment.Position * 2 -- Scale attachment positions
		end
	end
	
	-- Position above base
	local basePosition = baseCenter.Position
	headClone.Position = basePosition + Vector3.new(0, 15, 0)
	headClone.Parent = markerModel
	
	-- Set PrimaryPart
	markerModel.PrimaryPart = headClone
	
	-- Now find and clone accessories that go on the HEAD ONLY
	local accessoryCount = 0
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle then
				-- Check if this accessory attaches to the head
				local attachment = handle:FindFirstChildOfClass("Attachment")
				if attachment then
					-- Check attachment name - ONLY accept specific head attachments
					local attachmentName = attachment.Name:lower()
					
					-- List of VALID head attachment names (strict whitelist)
					local validHeadAttachments = {
						"hatattachment",
						"hairattachment", 
						"facefrontattachment",
						"facecenterattachment",
						"neckattachment",
						"headattachment"
					}
					
					-- Check if attachment is in the whitelist
					local isHeadAccessory = false
					for _, validName in ipairs(validHeadAttachments) do
						if attachmentName == validName then
							isHeadAccessory = true
							break
						end
					end
					
					-- Also check accessory name for common head items
					if not isHeadAccessory then
						local accessoryNameLower = accessory.Name:lower()
						isHeadAccessory = accessoryNameLower:match("^hat")
							or accessoryNameLower:match("^hair")
							or accessoryNameLower:match("^helmet")
							or accessoryNameLower:match("^mask")
							or accessoryNameLower:match("eyebrow")
							or accessoryNameLower:match("^glasses")
							or accessoryNameLower:match("^goggles")
					end
					
					if isHeadAccessory then
						-- Clone the accessory
						local accessoryClone = accessory:Clone()
						local handleClone = accessoryClone:FindFirstChild("Handle")
						
						if handleClone then
							-- Scale up the accessory
							handleClone.Size = handleClone.Size * 2
							handleClone.Anchored = false
							handleClone.CanCollide = false
							
							-- Remove old attachments/welds
							for _, child in ipairs(handleClone:GetChildren()) do
								if child:IsA("Weld") or child:IsA("Motor6D") then
									child:Destroy()
								end
							end
							
							-- Find the attachment in the handle
							local handleAttachment = handleClone:FindFirstChildOfClass("Attachment")
							
							if handleAttachment then
								-- Find matching attachment on head
								local headAttachment = headClone:FindFirstChild(handleAttachment.Name)
								
								if headAttachment then
									-- Create proper attachment weld
									local attachmentWeld = Instance.new("Weld")
									attachmentWeld.Part0 = headClone
									attachmentWeld.Part1 = handleClone
									-- Calculate offset from attachments
									attachmentWeld.C0 = headAttachment.CFrame
									attachmentWeld.C1 = handleAttachment.CFrame
									attachmentWeld.Parent = handleClone
								else
									-- Fallback: simple weld
									local weld = Instance.new("WeldConstraint")
									weld.Part0 = headClone
									weld.Part1 = handleClone
									weld.Parent = handleClone
									
									-- Position relative to head (approximate)
									handleClone.CFrame = headClone.CFrame * CFrame.new(0, headClone.Size.Y / 2, 0)
								end
							else
								-- No attachment found, use simple positioning
								local weld = Instance.new("WeldConstraint")
								weld.Part0 = headClone
								weld.Part1 = handleClone
								weld.Parent = handleClone
								
								-- Position relative to head (approximate)
								handleClone.CFrame = headClone.CFrame * CFrame.new(0, headClone.Size.Y / 2, 0)
							end
							
							accessoryClone.Parent = markerModel
							accessoryCount = accessoryCount + 1
						end
					end
				end
			end
		end
	end
	
	-- Store for cleanup
	playerMarkers[player.UserId] = {
		head = markerModel,
		connection = connection
	}
	
	print(string.format("✅ Base marker created for %s", player.Name))
end

-- Function to remove base marker
local function RemoveBaseMarker(userId)
	local marker = playerMarkers[userId]
	if marker then
		-- Disconnect rotation
		if marker.connection then
			marker.connection:Disconnect()
		end
		
		-- Destroy head
		if marker.head and marker.head.Parent then
			marker.head:Destroy()
		end
		
		playerMarkers[userId] = nil
	end
end

-- Handle player added
Players.PlayerAdded:Connect(function(player)
	-- Wait for character
	player.CharacterAdded:Connect(function(character)
		CreateBaseMarker(player)
	end)
	
	-- Handle current character if exists
	if player.Character then
		CreateBaseMarker(player)
	end
end)

-- Handle player removing
Players.PlayerRemoving:Connect(function(player)
	RemoveBaseMarker(player.UserId)
end)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	if player.Character then
		CreateBaseMarker(player)
	end
end

print("✓ Base Marker System initialized (server-side)")


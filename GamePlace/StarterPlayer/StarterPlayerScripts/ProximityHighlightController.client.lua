-- StarterPlayer/StarterPlayerScripts/ProximityHighlightController.client.lua
-- Gère la visibilité des highlights selon la distance du joueur

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local PROXIMITY_DISTANCE = 100 -- Distance en studs pour activer les highlights

-- Fonction pour vérifier et mettre à jour les highlights
local function updateHighlights()
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local playerPosition = humanoidRootPart.Position
	
	-- Vérifier les pièces dans l'arène (ActivePieces)
	local activePieces = Workspace:FindFirstChild("ActivePieces")
	if activePieces then
		for _, piece in ipairs(activePieces:GetChildren()) do
			if piece:IsA("Model") then
				local primaryPart = piece.PrimaryPart
				
				if primaryPart then
					local distance = (playerPosition - primaryPart.Position).Magnitude
					local isNear = distance <= PROXIMITY_DISTANCE
					
					-- Activer/désactiver le highlight
					local highlight = piece:FindFirstChild("PieceHighlight")
					if highlight and highlight:IsA("Highlight") then
						highlight.Enabled = isNear
					end
					
					-- Activer/désactiver le TypeLabel (qui est maintenant dans le BillboardGui principal)
					local billboard = primaryPart:FindFirstChildOfClass("BillboardGui")
					if billboard then
						local typeLabel = billboard:FindFirstChild("TypeLabel")
						if typeLabel and typeLabel:IsA("TextLabel") then
							typeLabel.Visible = isNear
						end
					end
				end
			end
		end
	end
	
	-- Vérifier les brainrots portés par d'autres joueurs
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local otherCharacter = otherPlayer.Character
			if otherCharacter then
				local carriedBrainrot = otherCharacter:FindFirstChild("CarriedBrainrot")
				if carriedBrainrot then
					-- Vérifier la distance au personnage qui porte le brainrot
					local otherRoot = otherCharacter:FindFirstChild("HumanoidRootPart")
					if otherRoot then
						local distance = (playerPosition - otherRoot.Position).Magnitude
						local isNear = distance <= PROXIMITY_DISTANCE
						
						-- Activer/désactiver tous les highlights et TypeLabels du brainrot porté
						for _, descendant in ipairs(carriedBrainrot:GetDescendants()) do
							if descendant:IsA("Highlight") then
								descendant.Enabled = isNear
							elseif descendant:IsA("BillboardGui") and descendant.Name == "TypeLabel" then
								descendant.Enabled = isNear
							end
						end
					end
				end
			end
		end
	end
end

-- Boucle de mise à jour (toutes les 0.1 secondes)
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= 0.1 then
		lastUpdate = now
		updateHighlights()
	end
end)

print("[ProximityHighlightController] Initialisé - Distance: " .. PROXIMITY_DISTANCE .. " studs")
